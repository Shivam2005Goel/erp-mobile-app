import 'dart:io';
import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app_state.dart';
import '../../data/erp_repository.dart';
import '../../widgets/erp_ui.dart';

// ── Office config ─────────────────────────────────────────────────────────────
const _officeLat = 28.4929;
const _officeLng = 77.1351;
// Check-in cutoff: 11:00 AM IST = 05:30 UTC
const _cutoffHourUtc = 5;
const _cutoffMinuteUtc = 30;

// ── Module ────────────────────────────────────────────────────────────────────
class AttendanceModule extends StatefulWidget {
  const AttendanceModule({super.key});

  @override
  State<AttendanceModule> createState() => _AttendanceModuleState();
}

class _AttendanceModuleState extends State<AttendanceModule> {
  final _repo = ErpRepository();
  List<Map<String, dynamic>> _records = [];
  Map<String, dynamic>? _todayRecord;
  bool _loading = true;
  bool _marking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final email =
          AppStateScope.of(context).currentUser?.email ?? '';
      final results = await Future.wait([
        _repo.attendance(),
        email.isNotEmpty
            ? _repo.todayAttendanceForUser(email)
            : Future.value(null),
      ]);
      if (mounted) {
        setState(() {
          _records = results[0] as List<Map<String, dynamic>>;
          _todayRecord = results[1] as Map<String, dynamic>?;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  // ── Haversine distance in metres ──────────────────────────────────
  static double _distanceTo(double lat, double lng) {
    const r = 6371000.0;
    final dlat = (_officeLat - lat) * pi / 180;
    final dlon = (_officeLng - lng) * pi / 180;
    final a = sin(dlat / 2) * sin(dlat / 2) +
        cos(lat * pi / 180) *
            cos(_officeLat * pi / 180) *
            sin(dlon / 2) *
            sin(dlon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  // ── Main mark-attendance flow ─────────────────────────────────────
  Future<void> _markAttendance() async {
    final user = AppStateScope.of(context).currentUser;
    if (user == null) {
      _snack('Please log in to mark attendance.');
      return;
    }

    final isCheckIn = _todayRecord == null;
    final isCheckOut =
        _todayRecord != null && _todayRecord!['check_out_time'] == null;

    if (!isCheckIn && !isCheckOut) {
      _snack('Attendance already fully marked for today.');
      return;
    }

    final label = isCheckIn ? 'Check In' : 'Check Out';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: Text(
          isCheckIn
              ? 'Take a selfie and record your location to mark check-in.'
              : 'Take a selfie and record your location to mark check-out.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: kBrand, foregroundColor: Colors.white),
            child: Text(label),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _marking = true);
    try {
      // ── Step 1: Capture selfie (mandatory — abort if skipped) ─────
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 75,
        maxWidth: 1280,
      );
      if (photo == null || !mounted) {
        setState(() => _marking = false);
        return;
      }
      final bytes = await File(photo.path).readAsBytes();

      // ── Step 2: GPS + upload run in parallel ──────────────────────
      _snack('Getting location & uploading photo…');

      final posResult = await _getLocation();   // best-effort, never throws
      final slug = user.email
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '_');
      final date = DateTime.now().toIso8601String().substring(0, 10);
      final ts = DateTime.now().millisecondsSinceEpoch;
      final type = isCheckIn ? 'in' : 'out';
      final storagePath = '$slug/${date}_${type}_$ts.jpg';

      // ── Step 3: Upload with 3 retries — REQUIRED to proceed ───────
      final photoPath =
          await _uploadWithRetry(storagePath, bytes);   // throws on all failures

      // ── Step 4: Compute metrics ───────────────────────────────────
      final lat = posResult?.latitude;
      final lng = posResult?.longitude;
      final distM =
          (lat != null && lng != null) ? _distanceTo(lat, lng) : null;
      final locationLabel = (lat != null && lng != null)
          ? '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'
              ' (±${posResult!.accuracy.toStringAsFixed(0)}m)'
          : null;

      // ── Step 5: Write to DB ───────────────────────────────────────
      if (isCheckIn) {
        final nowUtc = DateTime.now().toUtc();
        final cutoff = DateTime.utc(
          nowUtc.year,
          nowUtc.month,
          nowUtc.day,
          _cutoffHourUtc,
          _cutoffMinuteUtc,
        );
        final lateMin = nowUtc.isAfter(cutoff)
            ? nowUtc.difference(cutoff).inMinutes
            : 0;

        await _repo.markCheckIn(
          email: user.email,
          name: user.fullName,
          lat: lat,
          lng: lng,
          photoPath: photoPath,
          lateMinutes: lateMin,
          distanceM: distM,
          locationLabel: locationLabel,
          status: lateMin > 0 ? 'Late' : 'Present',
        );
        if (mounted) {
          _snack(lateMin > 0
              ? 'Checked in — $lateMin min late'
              : 'Checked in on time!');
        }
      } else {
        final checkInTime = DateTime.tryParse(
            _todayRecord!['check_in_time']?.toString() ?? '');
        final deltaMin = checkInTime != null
            ? DateTime.now().toUtc().difference(checkInTime).inMinutes
            : null;

        await _repo.markCheckOut(
          id: _todayRecord!['id'].toString(),
          lat: lat,
          lng: lng,
          photoPath: photoPath,
          checkoutDelta: deltaMin,
        );
        if (mounted) _snack('Checked out successfully!');
      }

      if (mounted) await _load();
    } catch (e) {
      if (mounted) {
        _snack('Could not mark attendance: $e');
      }
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  // ── GPS helper — best effort, never throws ───────────────────────
  Future<Position?> _getLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  // ── Upload with 3 retries + exponential backoff — THROWS if all fail ──
  Future<String> _uploadWithRetry(String storagePath, List<int> bytes) async {
    const maxAttempts = 3;
    Object? lastError;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await Supabase.instance.client.storage
            .from('attendance')
            .uploadBinary(
          storagePath,
          Uint8List.fromList(bytes),
          fileOptions: const FileOptions(
              contentType: 'image/jpeg', upsert: true),
        );
        return 'attendance/$storagePath';
      } catch (e) {
        lastError = e;
        if (attempt < maxAttempts) {
          await Future<void>.delayed(Duration(seconds: attempt * 2));
        }
      }
    }
    throw Exception(
        'Photo upload failed after $maxAttempts attempts. '
        'Check your internet connection and try again.\n$lastError');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Failed: $_error'),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    }

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final presentToday =
        _records.where((a) => a['date']?.toString() == today).length;
    final lateCount = _records
        .where((a) =>
            (num.tryParse('${a['late_by_minutes'] ?? 0}') ?? 0) > 0)
        .length;

    final isDone = _todayRecord != null &&
        _todayRecord!['check_out_time'] != null;

    // Group records by date
    final byDate = <String, List<Map<String, dynamic>>>{};
    for (final a in _records) {
      byDate.putIfAbsent(a['date']?.toString() ?? 'Unknown', () => []).add(a);
    }
    final dates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));

    return Stack(children: [
      RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            // ── Mark Attendance card ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: _MarkCard(
                todayRecord: _todayRecord,
                isDone: isDone,
                marking: _marking,
                onMark: _markAttendance,
              ),
            ),
            const SizedBox(height: 12),

            // ── Summary metrics ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: MetricRow(children: [
                MetricCard(
                  label: 'Present Today',
                  value: '$presentToday',
                  icon: Icons.how_to_reg,
                  color: kSuccess,
                ),
                MetricCard(
                  label: 'Records',
                  value: '${_records.length}',
                  icon: Icons.event_available,
                ),
                MetricCard(
                  label: 'Late Arrivals',
                  value: '$lateCount',
                  icon: Icons.running_with_errors,
                  color: kWarning,
                ),
              ]),
            ),
            const SizedBox(height: 12),

            // ── Daily log ─────────────────────────────────────────────
            for (final d in dates) ...[
              SectionTitle(fmtDate(d),
                  subtitle: '${byDate[d]!.length} present'),
              ...byDate[d]!.map((a) {
                final late =
                    num.tryParse('${a['late_by_minutes'] ?? 0}') ?? 0;
                return Card(
                  margin: const EdgeInsets.symmetric(
                      vertical: 3, horizontal: 12),
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: statusColor(a['status']?.toString())
                          .withValues(alpha: 0.15),
                      child: Icon(Icons.person,
                          size: 18,
                          color: statusColor(a['status']?.toString())),
                    ),
                    title:
                        Text(str(a['employee_name'], a['employee_email'])),
                    subtitle: Text([
                      if (a['check_in_time'] != null)
                        'In ${_fmt(a['check_in_time'])}',
                      if (a['check_out_time'] != null)
                        'Out ${_fmt(a['check_out_time'])}',
                      if ((a['location_label']?.toString().trim() ?? '')
                          .isNotEmpty)
                        a['location_label'],
                    ].join(' • ')),
                    trailing: late > 0
                        ? StatusChip('Late ${late}m', color: kWarning)
                        : StatusChip(str(a['status'], 'present'),
                            color: statusColor(a['status']?.toString())),
                  ),
                );
              }),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),

      // ── Loading overlay while marking ─────────────────────────────
      if (_marking)
        const ColoredBox(
          color: Colors.black45,
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 14),
              Text('Marking attendance…',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
            ]),
          ),
        ),
    ]);
  }

  static String _fmt(dynamic v) {
    final d = DateTime.tryParse(v.toString());
    return d == null ? '' : DateFormat('HH:mm').format(d.toLocal());
  }
}

// ── Mark Attendance Card ──────────────────────────────────────────────────────

class _MarkCard extends StatelessWidget {
  final Map<String, dynamic>? todayRecord;
  final bool isDone;
  final bool marking;
  final VoidCallback onMark;

  const _MarkCard({
    required this.todayRecord,
    required this.isDone,
    required this.marking,
    required this.onMark,
  });

  @override
  Widget build(BuildContext context) {
    final isCheckIn = todayRecord == null;
    final isCheckOut =
        todayRecord != null && todayRecord!['check_out_time'] == null;

    late String title;
    late String subtitle;
    late IconData icon;
    late Color color;

    if (isDone) {
      final inTime = DateTime.tryParse(
          todayRecord!['check_in_time']?.toString() ?? '');
      final outTime = DateTime.tryParse(
          todayRecord!['check_out_time']?.toString() ?? '');
      final inStr = inTime != null
          ? DateFormat('HH:mm').format(inTime.toLocal())
          : '—';
      final outStr = outTime != null
          ? DateFormat('HH:mm').format(outTime.toLocal())
          : '—';
      title = 'Attendance Complete';
      subtitle = 'In $inStr • Out $outStr';
      icon = Icons.check_circle;
      color = kSuccess;
    } else if (isCheckOut) {
      final inTime = DateTime.tryParse(
          todayRecord!['check_in_time']?.toString() ?? '');
      final inStr = inTime != null
          ? DateFormat('HH:mm').format(inTime.toLocal())
          : '—';
      title = 'Checked In at $inStr';
      subtitle = 'Tap Check Out when you leave for the day';
      icon = Icons.login;
      color = const Color(0xFF0ea5e9);
    } else {
      title = 'Not Checked In';
      subtitle = 'Take a selfie to mark your attendance';
      icon = Icons.fingerprint;
      color = kBrand;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          if (!isDone) ...[
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: marking ? null : onMark,
              icon: Icon(
                isCheckIn ? Icons.camera_alt : Icons.logout,
                size: 16,
              ),
              label: Text(
                isCheckIn ? 'Check In' : 'Check Out',
                style: const TextStyle(fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
