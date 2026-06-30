import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../data/erp_repository.dart';
import '../../widgets/erp_ui.dart';

/// Marketing: Meta Ads, Ad Costing/ROI, and Content Calendar.
class MarketingModule extends StatelessWidget {
  MarketingModule({super.key});
  final _repo = ErpRepository();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Meta Ads'),
              Tab(text: 'Ad Costing'),
              Tab(text: 'Content Calendar'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _MetaAds(repo: _repo),
                _AdCosting(repo: _repo),
                _Calendar(repo: _repo),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Meta Ads Tab ──────────────────────────────────────────────────────────────

class _MetaAds extends StatelessWidget {
  final ErpRepository repo;
  const _MetaAds({required this.repo});

  num _n(dynamic v) => v is num ? v : (num.tryParse('${v ?? ''}') ?? 0);

  @override
  Widget build(BuildContext context) {
    return AsyncSection<List<Map<String, dynamic>>>(
      loader: repo.metaCampaigns,
      isEmpty: (d) => d.isEmpty,
      emptyMessage: 'No Meta Ads campaign data.',
      builder: (context, rows, refresh) {
        final spend = rows.fold<num>(0, (s, r) => s + _n(r['spend']));
        final linkClicks =
            rows.fold<num>(0, (s, r) => s + _n(r['link_clicks']));
        final impressions =
            rows.fold<num>(0, (s, r) => s + _n(r['impressions']));
        final reach = rows.fold<num>(0, (s, r) => s + _n(r['reach']));
        final campaigns =
            rows.map((r) => r['campaign_id']).toSet().length;

        // Avg CTR weighted by impressions
        final totalImp = impressions > 0 ? impressions : 1;
        final avgCtr = rows.fold<num>(
                0,
                (s, r) =>
                    s + _n(r['ctr']) * _n(r['impressions']) / totalImp);

        // Daily spend chart
        final byDate = <String, num>{};
        for (final r in rows) {
          final d = r['date']?.toString();
          if (d == null) continue;
          byDate[d] = (byDate[d] ?? 0) + _n(r['spend']);
        }
        final dates = byDate.keys.toList()..sort();
        final last =
            dates.length > 30 ? dates.sublist(dates.length - 30) : dates;

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            // ── Metrics row ────────────────────────────────────────────────
            MetricRow(children: [
              MetricCard(
                label: 'Total Spend',
                value: fmtInr(spend),
                icon: Icons.payments,
                color: kBrand,
              ),
              MetricCard(
                label: 'Reach',
                value: fmtNum(reach),
                icon: Icons.people_outline,
                color: const Color(0xFF0ea5e9),
              ),
              MetricCard(
                label: 'Impressions',
                value: fmtNum(impressions),
                icon: Icons.visibility,
                color: const Color(0xFF8b5cf6),
              ),
              MetricCard(
                label: 'Link Clicks',
                value: fmtNum(linkClicks),
                icon: Icons.ads_click,
                color: const Color(0xFF16a34a),
              ),
              MetricCard(
                label: 'Avg CTR',
                value: '${avgCtr.toStringAsFixed(2)}%',
                icon: Icons.trending_up,
                color: const Color(0xFFf59e0b),
              ),
              MetricCard(
                label: 'Campaigns',
                value: '$campaigns',
                icon: Icons.campaign,
                color: const Color(0xFFec4899),
              ),
            ]),
            const SizedBox(height: 16),

            // ── Daily spend chart ──────────────────────────────────────────
            if (last.length > 1) ...[
              const SectionTitle('Daily Spend',
                  subtitle: 'Last 30 days with data (₹)'),
              SizedBox(
                height: 220,
                child: _SpendLineChart(
                    dates: last,
                    values: [for (final d in last) byDate[d]!]),
              ),
              const SizedBox(height: 8),
            ],

            // ── Campaign list ──────────────────────────────────────────────
            const SectionTitle('Campaigns'),
            ...rows.take(50).map((r) {
              final ctr = _n(r['ctr']);
              final cpm = _n(r['cpm']);
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: r['status'] == 'ACTIVE'
                                ? kSuccess
                                : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            str(r['campaign_name']),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        Text(
                          fmtInr(r['spend']),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      Text(
                        '${fmtDate(r['date'])} • ${str(r['objective'], '—')}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      Wrap(spacing: 8, runSpacing: 4, children: [
                        _StatChip(
                          icon: Icons.people_outline,
                          label: '${fmtNum(_n(r['reach']))} reach',
                        ),
                        _StatChip(
                          icon: Icons.ads_click,
                          label: '${fmtNum(_n(r['link_clicks']))} clicks',
                        ),
                        if (ctr > 0)
                          _StatChip(
                            icon: Icons.percent,
                            label: 'CTR ${ctr.toStringAsFixed(2)}%',
                          ),
                        if (cpm > 0)
                          _StatChip(
                            icon: Icons.attach_money,
                            label: 'CPM ₹${cpm.toStringAsFixed(0)}',
                          ),
                      ]),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

// ── Ad Costing / ROI Tab ──────────────────────────────────────────────────────

class _AdCosting extends StatelessWidget {
  final ErpRepository repo;
  const _AdCosting({required this.repo});

  num _n(dynamic v) => v is num ? v : (num.tryParse('${v ?? ''}') ?? 0);

  @override
  Widget build(BuildContext context) {
    return AsyncSection<List<Map<String, dynamic>>>(
      loader: repo.adsCosting,
      isEmpty: (d) => d.isEmpty,
      emptyMessage: 'No ad costing data.',
      builder: (context, rows, refresh) {
        final totalSpend =
            rows.fold<num>(0, (s, r) => s + _n(r['spend_inr']));
        final totalLeads =
            rows.fold<num>(0, (s, r) => s + _n(r['leads_count']));
        final totalDeals =
            rows.fold<num>(0, (s, r) => s + _n(r['closed_deals_count']));
        final totalRevenue =
            rows.fold<num>(0, (s, r) => s + _n(r['attributed_revenue_inr']));

        // Avg ROAS (exclude nulls)
        final roasRows =
            rows.where((r) => r['roas'] != null && _n(r['roas']) > 0).toList();
        final avgRoas = roasRows.isEmpty
            ? 0.0
            : roasRows.fold<num>(0, (s, r) => s + _n(r['roas'])) /
                roasRows.length;

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            MetricRow(children: [
              MetricCard(
                label: 'Total Ad Spend',
                value: fmtInr(totalSpend),
                icon: Icons.payments,
                color: kBrand,
              ),
              MetricCard(
                label: 'Total Leads',
                value: '${totalLeads.toInt()}',
                icon: Icons.people,
                color: const Color(0xFF0ea5e9),
              ),
              MetricCard(
                label: 'Deals Closed',
                value: '${totalDeals.toInt()}',
                icon: Icons.handshake,
                color: kSuccess,
              ),
              MetricCard(
                label: 'Revenue',
                value: fmtInr(totalRevenue),
                icon: Icons.trending_up,
                color: const Color(0xFF8b5cf6),
              ),
              if (avgRoas > 0)
                MetricCard(
                  label: 'Avg ROAS',
                  value: avgRoas.toStringAsFixed(2),
                  icon: Icons.show_chart,
                  color: const Color(0xFFf59e0b),
                ),
            ]),
            const SizedBox(height: 16),
            const SectionTitle('Campaign Breakdown'),
            ...rows.map((r) {
              final spend = _n(r['spend_inr']);
              final leads = _n(r['leads_count']).toInt();
              final deals = _n(r['closed_deals_count']).toInt();
              final roas = r['roas'] != null ? _n(r['roas']) : null;
              final cpl = r['cost_per_lead'] != null
                  ? _n(r['cost_per_lead'])
                  : null;
              final notes = r['notes']?.toString().trim() ?? '';
              return Card(
                margin:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(
                            str(r['campaign_name']),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                            maxLines: 2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          fmtInr(spend),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                        fmtDate(r['date']),
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      Wrap(spacing: 8, runSpacing: 4, children: [
                        if (leads > 0)
                          _StatChip(
                              icon: Icons.person_add,
                              label: '$leads leads'),
                        if (deals > 0)
                          _StatChip(
                              icon: Icons.handshake,
                              label: '$deals deals',
                              color: kSuccess),
                        if (roas != null && roas > 0)
                          _StatChip(
                              icon: Icons.show_chart,
                              label:
                                  'ROAS ${roas.toStringAsFixed(2)}x',
                              color: const Color(0xFF8b5cf6)),
                        if (cpl != null && cpl > 0)
                          _StatChip(
                              icon: Icons.attach_money,
                              label: 'CPL ${fmtInr(cpl)}'),
                      ]),
                      if (notes.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          notes,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

// ── Shared: stat chip ─────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _StatChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? kBrand;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: c),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: c, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── Spend line chart ──────────────────────────────────────────────────────────

class _SpendLineChart extends StatelessWidget {
  final List<String> dates;
  final List<num> values;
  const _SpendLineChart({required this.dates, required this.values});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
                sideTitles:
                    SideTitles(showTitles: true, reservedSize: 48)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: (values.length / 4).ceilToDouble(),
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= dates.length) return const SizedBox();
                  final d = dates[i];
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(d.length >= 10 ? d.substring(5) : d,
                        style: const TextStyle(fontSize: 9)),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              color: kBrand,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                  show: true, color: kBrand.withValues(alpha: 0.15)),
              spots: [
                for (var i = 0; i < values.length; i++)
                  FlSpot(i.toDouble(), values[i].toDouble()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Content Calendar Tab ──────────────────────────────────────────────────────

class _Calendar extends StatelessWidget {
  final ErpRepository repo;
  const _Calendar({required this.repo});

  @override
  Widget build(BuildContext context) {
    return AsyncSection<List<Map<String, dynamic>>>(
      loader: repo.socialCalendar,
      isEmpty: (d) => d.isEmpty,
      emptyMessage: 'No scheduled content.',
      builder: (context, list, refresh) => ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: list.length,
        itemBuilder: (context, i) {
          final c = list[i];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
            child: ListTile(
              leading: const Icon(Icons.event_note),
              title: Text(str(c['title'])),
              subtitle: Text([
                if ((c['platform']?.toString().trim() ?? '').isNotEmpty)
                  c['platform'],
                if ((c['format']?.toString().trim() ?? '').isNotEmpty)
                  c['format'],
                'Publish ${fmtDate(c['publish_date'])}',
              ].join(' • ')),
              trailing: StatusChip(str(c['status'], 'draft'),
                  color: statusColor(c['status']?.toString())),
            ),
          );
        },
      ),
    );
  }
}
