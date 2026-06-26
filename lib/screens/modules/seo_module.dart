import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../data/erp_repository.dart';
import '../../widgets/crud_list.dart';
import '../../widgets/erp_ui.dart';
import '../../widgets/record_form.dart';

// ── Time-range filter options ──────────────────────────────────────────────
const _kRanges = ['Today', '7 Days', '15 Days', '1 Month', '3 Months', '6 Months'];

int _daysFor(String range) {
  switch (range) {
    case 'Today':     return 1;
    case '7 Days':    return 7;
    case '15 Days':   return 15;
    case '1 Month':   return 30;
    case '3 Months':  return 90;
    case '6 Months':  return 180;
    default:          return 30;
  }
}

// ── Bundled data ───────────────────────────────────────────────────────────
class _SeoData {
  final List<Map<String, dynamic>> daily;
  final Map<String, dynamic> meta;
  final Map<String, dynamic>? realtime;
  const _SeoData(this.daily, this.meta, this.realtime);
}

/// SEO Analytics: GSC/GA4 daily performance, keyword tracking and backlinks.
class SeoModule extends StatelessWidget {
  SeoModule({super.key});
  final _repo = ErpRepository();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Analytics & Engagement'),
              Tab(text: 'Keyword Ranking'),
              Tab(text: 'Backlinks Profile'),
              Tab(text: 'Geographical Reach'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _Analytics(repo: _repo),
                _Keywords(repo: _repo),
                _Backlinks(repo: _repo),
                _GeoReach(repo: _repo),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Analytics & Engagement tab
// ══════════════════════════════════════════════════════════════════════════════
class _Analytics extends StatefulWidget {
  final ErpRepository repo;
  const _Analytics({required this.repo});
  @override
  State<_Analytics> createState() => _AnalyticsState();
}

class _AnalyticsState extends State<_Analytics> {
  _SeoData? _data;
  bool _loading = true;
  String? _error;
  String _range = '1 Month';
  Timer? _realtimeTimer;
  Map<String, dynamic>? _realtime;

  @override
  void initState() {
    super.initState();
    _load();
    // Auto-refresh realtime card every 30 s
    _realtimeTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshRealtime(),
    );
  }

  @override
  void dispose() {
    _realtimeTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        widget.repo.seoDaily(),
        widget.repo.seoMetadata(),
        widget.repo.realtimeTraffic(),
      ]);
      if (mounted) {
        setState(() {
          _data = _SeoData(
            results[0] as List<Map<String, dynamic>>,
            results[1] as Map<String, dynamic>,
            results[2] as Map<String, dynamic>?,
          );
          _realtime = _data!.realtime;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _refreshRealtime() async {
    try {
      final r = await widget.repo.realtimeTraffic();
      if (mounted) setState(() => _realtime = r);
    } catch (_) {}
  }

  num _n(dynamic v) => v is num ? v : (num.tryParse('${v ?? ''}') ?? 0);

  // Filter daily rows to the selected range
  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> rows) {
    final days = _daysFor(_range);
    if (days >= rows.length) return rows;
    return rows.sublist(rows.length - days);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Error: $_error'),
        const SizedBox(height: 10),
        ElevatedButton(onPressed: _load, child: const Text('Retry')),
      ]));
    }

    final data = _data!;
    final filtered = _filtered(data.daily);
    final today = data.daily.isNotEmpty ? data.daily.last : <String, dynamic>{};

    // KPIs from daily data
    final totalAudience  = _n(today['active_users']);
    final totalPageViews = _n(today['page_views']);
    final bounceRateToday = _n(today['bounce_rate']);
    final monthly30d = data.daily
        .reversed
        .take(30)
        .fold<num>(0, (s, r) => s + _n(r['active_users']));

    // Metadata
    final kpi = (data.meta['summary_kpi'] as Map?) ?? {};
    final topQueries = (data.meta['top_queries'] as List?)?.cast<Map>() ?? [];
    final sources = (data.meta['traffic_sources'] as List?)?.cast<Map>() ?? [];
    final sourcesVisible = sources.where((s) => _n(s['value']) > 0).toList();
    final topSource = sourcesVisible.isNotEmpty
        ? sourcesVisible.reduce((a, b) => _n(a['value']) >= _n(b['value']) ? a : b)
        : null;
    final sourcesTotal = sourcesVisible.fold<num>(0, (s, e) => s + _n(e['value']));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 10),
        children: [
          // ── LIVE badge ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: kSuccess),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 7, height: 7,
                      decoration: const BoxDecoration(
                          color: kSuccess, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  const Text('LIVE CREDENTIALS CONNECTED',
                      style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: kSuccess, letterSpacing: 0.5)),
                ]),
              ),
              const Spacer(),
              // Refresh button
              GestureDetector(
                onTap: _load,
                child: const Icon(Icons.sync, size: 18),
              ),
            ]),
          ),

          // ── Time range chips ─────────────────────────────────────────
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _kRanges.map((r) {
                final active = r == _range;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _range = r),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: active ? kBrand : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: active
                                ? kBrand
                                : Theme.of(context).dividerColor),
                      ),
                      child: Text(r,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: active
                                  ? Colors.white
                                  : Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // ── Realtime users card (full width) ────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _RealtimeCard(rt: _realtime, n: _n),
          ),
          const SizedBox(height: 10),

          // ── KPI 2×2 grid (full width each) ──────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: _KpiCard(
                    title: 'TOTAL AUDIENCE (VISITORS)',
                    value: fmtNum(totalAudience),
                    subtitle: "Today's active visitors",
                    valueColor: Theme.of(context).textTheme.headlineSmall?.color,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _KpiCard(
                    title: 'MONTHLY AUDIENCE (30D)',
                    value: fmtNum(monthly30d),
                    subtitle: 'Deduplicated 30-day baseline',
                    valueColor: kBrand,
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: _KpiCard(
                    title: 'TOTAL PAGE VIEWS',
                    value: fmtNum(totalPageViews),
                    subtitle: 'Gross content engagements',
                    valueColor: Theme.of(context).textTheme.headlineSmall?.color,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _KpiCard(
                    title: 'AVERAGE BOUNCE RATE',
                    value: bounceRateToday > 0
                        ? '${bounceRateToday.toStringAsFixed(1)}%'
                        : (kpi['bounceRate']?.toString() ?? '—'),
                    subtitle: 'Avg. session drop percentage',
                    valueColor: Theme.of(context).textTheme.headlineSmall?.color,
                  ),
                ),
              ]),
            ]),
          ),

          const SizedBox(height: 16),

          // ── Traffic Flow Timeline (full-width card) ──────────────────
          if (filtered.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.people_outline, size: 14, color: kBrand),
                        const SizedBox(width: 6),
                        const Text('TRAFFIC FLOW TIMELINE',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w800,
                                letterSpacing: 0.6, color: kBrand)),
                      ]),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: _DualLineChart(
                          rows: filtered,
                          n: _n,
                          series: [
                            _Series('Active Visitors', 'active_users', kBrand),
                            _Series('Page Views', 'page_views', kInfo),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        _Legend(kBrand, 'Active Visitors'),
                        const SizedBox(width: 16),
                        _Legend(kInfo, 'Page Views'),
                      ]),
                    ],
                  ),
                ),
              ),
            ),

          // ── Bounce Rate Trend (full-width card) ──────────────────────
          if (filtered.any((r) => _n(r['bounce_rate']) > 0))
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.percent, size: 14, color: kBrand),
                        const SizedBox(width: 6),
                        const Text('BOUNCE RATE TREND',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w800,
                                letterSpacing: 0.6, color: kBrand)),
                      ]),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 180,
                        child: _DualLineChart(
                          rows: filtered,
                          n: _n,
                          series: [
                            _Series('Bounce Rate', 'bounce_rate',
                                const Color(0xFF6b7280)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      _Legend(const Color(0xFF6b7280), 'Bounce Rate %'),
                    ],
                  ),
                ),
              ),
            ),

          // ── Traffic Channels Share (full-width card) ─────────────────
          if (sourcesVisible.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.pie_chart_outline, size: 14, color: kBrand),
                        const SizedBox(width: 6),
                        const Text('TRAFFIC CHANNELS SHARE',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w800,
                                letterSpacing: 0.6, color: kBrand)),
                      ]),
                      const SizedBox(height: 12),
                      ...sourcesVisible.map((s) {
                        final pct =
                            (_n(s['value']) / (sourcesTotal == 0 ? 1 : sourcesTotal))
                                .clamp(0.0, 1.0)
                                .toDouble();
                        final isOrganic =
                            (s['name']?.toString() ?? '').contains('Organic');
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(children: [
                            if (isOrganic)
                              Container(
                                  width: 8, height: 8,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: const BoxDecoration(
                                      color: kBrand, shape: BoxShape.circle))
                            else
                              const SizedBox(width: 14),
                            Expanded(
                                child: Text(s['name']?.toString() ?? '',
                                    style: const TextStyle(fontSize: 13))),
                            Text(
                              '${_n(s['value']).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700,
                                color: isOrganic ? kBrand : kWarning,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 0,
                              child: SizedBox(
                                width: 90,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: pct, minHeight: 6,
                                    backgroundColor: Theme.of(context)
                                        .colorScheme.surfaceContainerHighest,
                                    valueColor:
                                        const AlwaysStoppedAnimation(kBrand),
                                  ),
                                ),
                              ),
                            ),
                          ]),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),

          // ── Brand Acquisition Performance (full-width card) ──────────
          if (topSource != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.bar_chart, size: 14, color: kBrand),
                        const SizedBox(width: 6),
                        const Text('BRAND ACQUISITION PERFORMANCE',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w800,
                                letterSpacing: 0.6, color: kBrand)),
                      ]),
                      const SizedBox(height: 12),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${topSource['name']} Acquisition Campaign',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                            ),
                            Text('${_n(topSource['value']).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, color: kBrand)),
                          ]),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (_n(topSource['value']) / 100)
                              .clamp(0.0, 1.0).toDouble(),
                          minHeight: 8,
                          backgroundColor: Theme.of(context)
                              .colorScheme.surfaceContainerHighest,
                          valueColor: const AlwaysStoppedAnimation(kBrand),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Top traffic driver from ${topSource['name']}.',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Top Search Queries ───────────────────────────────────────
          if (topQueries.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Row(children: [
                const Icon(Icons.search, size: 14, color: kBrand),
                const SizedBox(width: 6),
                const Text('TOP SEARCH QUERIES',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                        letterSpacing: 0.6, color: kBrand)),
              ]),
            ),
            ...topQueries.map((q) => Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 2),
                  child: Card(
                    child: ListTile(
                      dense: true,
                      title: Text(q['query']?.toString() ?? '—',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          'Position ${q['position']} • CTR ${q['ctr']} • ${fmtNum(q['impressions'] ?? 0)} impressions'),
                      trailing: Text('${q['clicks']} clicks',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: kBrand)),
                    ),
                  ),
                )),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}

// ── Realtime card (auto-refreshed) ────────────────────────────────────────
class _RealtimeCard extends StatelessWidget {
  final Map<String, dynamic>? rt;
  final num Function(dynamic) n;
  const _RealtimeCard({required this.rt, required this.n});

  @override
  Widget build(BuildContext context) {
    final activeUsers = rt != null ? n(rt!['active_users']) : 0;
    final pageViews   = rt != null ? n(rt!['page_views_30m']) : 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('REALTIME USERS (30M)',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey,
                    letterSpacing: 0.8)),
            const SizedBox(width: 8),
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: rt != null ? kSuccess : Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _RTStat(activeUsers.toString(), 'Active Visitors', kSuccess),
            const SizedBox(width: 24),
            _RTStat(pageViews.toString(), 'Page Views',
                Theme.of(context).textTheme.headlineSmall?.color ?? Colors.black),
          ]),
        ]),
      ),
    );
  }
}

class _RTStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _RTStat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1)),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      );
}

// ── KPI scrollable card ───────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color? valueColor;
  const _KpiCard(
      {required this.title,
      required this.value,
      required this.subtitle,
      this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 185,
      margin: const EdgeInsets.only(right: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey,
                        letterSpacing: 0.5),
                    maxLines: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: valueColor,
                        height: 1.1)),
                Text(subtitle,
                    style:
                        const TextStyle(fontSize: 10.5, color: Colors.grey),
                    maxLines: 2),
              ]),
        ),
      ),
    );
  }
}

// ── Chart legend dot ──────────────────────────────────────────────────────
class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend(this.color, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 8,
          height: 8,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
    ]);
  }
}

// ── Line chart series descriptor ─────────────────────────────────────────
class _Series {
  final String label;
  final String field;
  final Color color;
  const _Series(this.label, this.field, this.color);
}

// ── Generic dual/single line chart ───────────────────────────────────────
class _DualLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final num Function(dynamic) n;
  final List<_Series> series;
  const _DualLineChart(
      {required this.rows, required this.n, required this.series});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox();
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 38)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: (rows.length / 4).ceilToDouble().clamp(1, 9999),
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= rows.length) return const SizedBox();
                final d = rows[i]['date']?.toString() ?? '';
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(d.length >= 10 ? d.substring(5) : d,
                      style: const TextStyle(fontSize: 9)),
                );
              },
            ),
          ),
        ),
        lineBarsData: series.map((s) {
          return LineChartBarData(
            isCurved: true,
            color: s.color,
            barWidth: 2.5,
            dotData: FlDotData(
              show: rows.length <= 5,
              getDotPainter: (spot, _, p2, p3) => FlDotCirclePainter(
                radius: 4,
                color: s.color,
                strokeWidth: 1.5,
                strokeColor: Colors.white,
              ),
            ),
            spots: [
              for (var i = 0; i < rows.length; i++)
                FlSpot(i.toDouble(), n(rows[i][s.field]).toDouble()),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Keyword Ranking tab
// ══════════════════════════════════════════════════════════════════════════════
class _KwData {
  final Map<String, dynamic>? latestDay; // latest row with impressions > 0
  final List<Map<String, dynamic>> topQueries;
  const _KwData(this.latestDay, this.topQueries);
}

class _Keywords extends StatefulWidget {
  final ErpRepository repo;
  const _Keywords({required this.repo});
  @override
  State<_Keywords> createState() => _KeywordsState();
}

class _KeywordsState extends State<_Keywords> {
  _KwData? _kwData;

  num _n(dynamic v) => v is num ? v : (num.tryParse('${v ?? ''}') ?? 0);

  Future<void> _loadMeta() async {
    try {
      final results = await Future.wait([
        widget.repo.seoDaily(),
        widget.repo.seoMetadata(),
      ]);
      final daily = results[0] as List<Map<String, dynamic>>;
      final meta  = results[1] as Map<String, dynamic>;
      // latest row with non-zero impressions
      final latestDay = daily.lastWhere(
        (r) => _n(r['impressions']) > 0,
        orElse: () => daily.isNotEmpty ? daily.last : {},
      );
      final topQueries =
          (meta['top_queries'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ?? [];
      if (mounted) setState(() => _kwData = _KwData(latestDay, topQueries));
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }


  @override
  Widget build(BuildContext context) {
    final kw = _kwData;
    final day = kw?.latestDay;

    return CrudList(
      repo: widget.repo,
      table: 'seo_keywords',
      idCol: 'id',
      addLabel: 'Add Keyword',
      editLabel: 'Edit Keyword',
      loader: widget.repo.seoKeywords,
      emptyMessage: 'No keywords tracked.',
      searchFields: const ['keyword', 'category', 'status'],
      searchHint: 'Search keywords…',
      fields: () => const [
        FieldSpec('keyword', 'Keyword', required: true),
        FieldSpec('category', 'Category',
            type: FieldType.dropdown,
            options: [
              'Chess', 'Table Tennis', 'Snooker', 'Pool Table',
              'Air Hockey', 'Bar Cabinet', 'Foosball', 'Carrom',
            ]),
        FieldSpec('status', 'Status',
            type: FieldType.dropdown,
            options: ['tracked', 'ranking', 'target', 'lost',
                      'active', 'Not Targeted']),
      ],
      showAddBar: false,
      header: (context, _, onAdd) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Add button at the top ──────────────────────────────────
          AddBar(label: 'Add Keyword', onTap: onAdd),
          const SizedBox(height: 12),

          // ── 4 organic stats cards ──────────────────────────────────
          if (day != null && day.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              child: Column(children: [
                Row(children: [
                  Expanded(child: _KwStatCard(
                    label: 'ORGANIC CLICK TRAFFIC',
                    value: fmtNum(_n(day['clicks'])),
                    subtitle: 'Latest available data',
                    valueColor: kBrand,
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: _KwStatCard(
                    label: 'ORGANIC IMPRESSIONS',
                    value: fmtNum(_n(day['impressions'])),
                    subtitle: 'Latest available data',
                  )),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _KwStatCard(
                    label: 'AVG. SEARCH CTR',
                    value: '${_n(day['ctr']).toStringAsFixed(2)}%',
                    subtitle: 'Latest available data',
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: _KwStatCard(
                    label: 'AVG. KEYWORD POSITION',
                    value: _n(day['position']).toStringAsFixed(1),
                    subtitle: 'Latest available data',
                    valueColor: kBrand,
                  )),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
          ],

          // ── "Tracked keywords" section label ──────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
            child: Row(children: [
              const Icon(Icons.tag, size: 14, color: kBrand),
              const SizedBox(width: 6),
              const Text('TRACKED KEYWORDS',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                      letterSpacing: 0.6, color: kBrand)),
            ]),
          ),
        ],
      ),
      tile: (k, onEdit, onDelete) {
        final kStatus = k['status']?.toString().trim() ?? '';
        final kCat    = k['category']?.toString().trim() ?? '';
        Color chipColor = kInfo;
        if (kStatus == 'ranking')           { chipColor = kSuccess; }
        else if (kStatus == 'target')       { chipColor = kWarning; }
        else if (kStatus == 'lost')         { chipColor = kDanger; }
        else if (kStatus == 'active')       { chipColor = kSuccess; }
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 3),
          child: ListTile(
            dense: true,
            onTap: onEdit,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: kBrand.withValues(alpha: 0.12),
              child: const Icon(Icons.tag, size: 15, color: kBrand),
            ),
            title: Text(str(k['keyword']),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: kCat.isNotEmpty ? Text(kCat) : null,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (kStatus.isNotEmpty)
                StatusChip(kStatus, color: chipColor),
              RowMenu(onEdit: onEdit, onDelete: onDelete),
            ]),
          ),
        );
      },
    );
  }
}

class _KwStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final Color? valueColor;
  const _KwStatCard({
    required this.label,
    required this.value,
    required this.subtitle,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 9.5, fontWeight: FontWeight.w700,
                    color: Colors.grey, letterSpacing: 0.5),
                maxLines: 2),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w900,
                    color: valueColor, height: 1.1)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Backlinks Profile tab — full CRUD
// ══════════════════════════════════════════════════════════════════════════════
class _Backlinks extends StatelessWidget {
  final ErpRepository repo;
  const _Backlinks({required this.repo});

  @override
  Widget build(BuildContext context) {
    return CrudList(
      repo: repo,
      table: 'backlinks',
      idCol: 'id',
      addLabel: 'Add Backlink',
      editLabel: 'Edit Backlink',
      loader: repo.backlinks,
      emptyMessage: 'No backlinks recorded yet.',
      searchFields: const ['source_url', 'target_url', 'keyword', 'type'],
      searchHint: 'Search by URL, keyword, type…',
      fields: () => const [
        FieldSpec('source_url', 'Source URL', required: true),
        FieldSpec('target_url', 'Target URL'),
        FieldSpec('type', 'Type',
            type: FieldType.dropdown,
            options: [
              'Profile submission',
              'Web 2.0',
              'Guest Post',
              'Directory',
              'Forum',
              'Social',
              'Press Release',
              'Other',
            ]),
        FieldSpec('keyword', 'Keyword / Anchor text'),
        FieldSpec('date_acquired', 'Date acquired', type: FieldType.date),
      ],
      tile: (b, onEdit, onDelete) {
        final typeText = b['type']?.toString().trim() ?? '';
        final keyword  = b['keyword']?.toString().trim() ?? '';
        final target   = b['target_url']?.toString().trim() ?? '';
        final source   = b['source_url']?.toString().trim() ?? '';
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: icon + type chip + actions
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.link, size: 18, color: kInfo),
                  const SizedBox(width: 8),
                  Expanded(
                    child: typeText.isNotEmpty
                        ? StatusChip(typeText, color: kInfo)
                        : const SizedBox(),
                  ),
                  RowMenu(onEdit: onEdit, onDelete: onDelete),
                ]),
                const SizedBox(height: 8),

                // Source URL — full, selectable
                _FieldRow(label: 'SOURCE', value: source, color: kInfo),

                if (target.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _FieldRow(label: 'TARGET', value: target),
                ],

                if (keyword.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _FieldRow(label: 'KEYWORD', value: keyword),
                ],

                const SizedBox(height: 6),
                _FieldRow(
                  label: 'ACQUIRED',
                  value: fmtDate(b['date_acquired']),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Geographical Reach tab
// ══════════════════════════════════════════════════════════════════════════════
class _GeoReach extends StatelessWidget {
  final ErpRepository repo;
  const _GeoReach({required this.repo});

  @override
  Widget build(BuildContext context) {
    return AsyncSection<List<Map<String, dynamic>>>(
      loader: repo.geoReach,
      isEmpty: (d) => d.isEmpty,
      emptyMessage: 'No geographic data yet.',
      builder: (context, rows, refresh) {
        final totalVisitors =
            rows.fold<num>(0, (s, r) => s + ((r['visitors'] as num?) ?? 0));

        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // ── Summary header ──────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  const Icon(Icons.public, color: kBrand, size: 28),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('TOTAL REACH',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey,
                            letterSpacing: 0.8)),
                    Text(fmtNum(totalVisitors),
                        style: const TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w900)),
                    Text('${rows.length} countries / regions',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 14),

            // ── Country section header ──────────────────────────────
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Icon(Icons.bar_chart, size: 14, color: kBrand),
                SizedBox(width: 6),
                Text('COUNTRY BREAKDOWN',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: kBrand)),
              ]),
            ),

            // ── Country rows ────────────────────────────────────────
            ...rows.map((r) {
              final visitors  = (r['visitors'] as num?) ?? 0;
              final pct       = (r['percentage'] as num?) ?? 0;
              final barWidth  = (pct / 100).clamp(0.0, 1.0).toDouble();
              final flag      = r['flag_emoji']?.toString() ?? '🌍';
              final country   = r['country']?.toString() ?? '—';
              final isTop     = rows.isNotEmpty && r == rows.first;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(flag,
                            style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(country,
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: isTop ? kBrand : null)),
                        ),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(fmtNum(visitors),
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: isTop ? kBrand : null)),
                          Text('visitors',
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.grey)),
                        ]),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 42,
                          child: Text(
                            '${pct.toStringAsFixed(1)}%',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: isTop ? kBrand : kWarning),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: barWidth,
                          minHeight: 6,
                          backgroundColor: Theme.of(context)
                              .colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation(
                              isTop ? kBrand : kInfo),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

// ── Label + full-value row used inside backlink cards ─────────────────────
class _FieldRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _FieldRow({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 68,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: Colors.grey,
              letterSpacing: 0.6,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
