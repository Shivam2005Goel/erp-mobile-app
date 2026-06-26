import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../data/erp_repository.dart';
import '../../widgets/erp_ui.dart';

/// Marketing: Meta Ads spend analytics, costing efficiency and content calendar.
class MarketingModule extends StatelessWidget {
  MarketingModule({super.key});
  final _repo = ErpRepository();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [Tab(text: 'Meta Ads'), Tab(text: 'Content Calendar')],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _MetaAds(repo: _repo),
                _Calendar(repo: _repo),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaAds extends StatelessWidget {
  final ErpRepository repo;
  const _MetaAds({required this.repo});

  num _n(dynamic v) => v is num ? v : (num.tryParse('${v ?? ''}') ?? 0);

  @override
  Widget build(BuildContext context) {
    return AsyncSection<List<Map<String, dynamic>>>(
      loader: repo.metaCampaigns,
      isEmpty: (d) => d.isEmpty,
      emptyMessage: 'No campaign data.',
      builder: (context, rows, refresh) {
        final spend = rows.fold<num>(0, (s, r) => s + _n(r['spend']));
        final clicks = rows.fold<num>(0, (s, r) => s + _n(r['clicks']));
        final impressions =
            rows.fold<num>(0, (s, r) => s + _n(r['impressions']));

        // Spend per day (sorted ascending).
        final byDate = <String, num>{};
        for (final r in rows) {
          final d = r['date']?.toString();
          if (d == null) continue;
          byDate[d] = (byDate[d] ?? 0) + _n(r['spend']);
        }
        final dates = byDate.keys.toList()..sort();
        final last = dates.length > 30 ? dates.sublist(dates.length - 30) : dates;

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            MetricRow(children: [
              MetricCard(
                  label: 'Total Spend',
                  value: fmtInr(spend),
                  icon: Icons.payments),
              MetricCard(
                  label: 'Clicks',
                  value: fmtNum(clicks),
                  icon: Icons.ads_click,
                  color: const Color(0xFF0ea5e9)),
              MetricCard(
                  label: 'Impressions',
                  value: fmtNum(impressions),
                  icon: Icons.visibility,
                  color: const Color(0xFF8b5cf6)),
              MetricCard(
                  label: 'Campaigns',
                  value: '${rows.map((r) => r['campaign_id']).toSet().length}',
                  icon: Icons.campaign,
                  color: const Color(0xFF16a34a)),
            ]),
            const SizedBox(height: 16),
            if (last.length > 1) ...[
              const SectionTitle('Daily Spend',
                  subtitle: 'Last 30 days with data (₹)'),
              SizedBox(
                height: 220,
                child: _SpendLineChart(
                    dates: last, values: [for (final d in last) byDate[d]!]),
              ),
              const SizedBox(height: 8),
            ],
            const SectionTitle('Recent Campaigns'),
            ...rows.take(40).map((r) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    dense: true,
                    title: Text(str(r['campaign_name'])),
                    subtitle: Text(
                        '${fmtDate(r['date'])} • ${str(r['objective'], '—')}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(fmtInr(r['spend']),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        Text('${fmtNum(r['clicks'])} clicks',
                            style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                )),
          ],
        );
      },
    );
  }
}

class _SpendLineChart extends StatelessWidget {
  final List<String> dates;
  final List<num> values;
  const _SpendLineChart({required this.dates, required this.values});

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
    );
  }
}

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
            margin: const EdgeInsets.symmetric(vertical: 4),
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
