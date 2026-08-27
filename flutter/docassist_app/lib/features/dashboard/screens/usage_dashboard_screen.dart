import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import '../../../core/theme/app_theme.dart';
import '../../../core/services/usage_tracker.dart';
import '../../../core/services/document_export_service.dart';
import '../../ai_features/screens/ai_feature_detail_screen.dart';
import '../../auth/providers/auth_provider.dart';

/// "Dashboard" screen reachable from Profile → Dashboard.
/// Shows the user's credits (total / used / balance), a last-7-days usage
/// chart, a per-feature breakdown, and CSV / PPT / Word export.
///
/// Visual language: a gradient hero card with soft blurred "orbs" behind it
/// for depth, animated ticking numbers instead of numbers just appearing,
/// and gradient-filled chart bars/progress rows — aiming for a premium,
/// designed feel rather than plain default Material cards.
class UsageDashboardScreen extends ConsumerStatefulWidget {
  const UsageDashboardScreen({super.key});
  @override
  ConsumerState<UsageDashboardScreen> createState() => _UsageDashboardScreenState();
}

class _UsageDashboardScreenState extends ConsumerState<UsageDashboardScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _stats;
  List<MapEntry<String, int>>? _last7Days;
  Map<String, int>? _credits;
  bool _loading = true;
  bool _exporting = false;

  late final AnimationController _entrance = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 650),
  );
  late final Animation<double> _fadeIn =
      CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
  late final Animation<Offset> _slideIn = Tween<Offset>(
    begin: const Offset(0, 0.06), end: Offset.zero,
  ).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final stats = await UsageTracker.getStats();
    final last7 = await UsageTracker.lastNDaysTotals(days: 7);
    final credits = await UsageTracker.getCreditsSummary();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _last7Days = last7;
      _credits = credits;
      _loading = false;
    });
    _entrance.forward(from: 0);
  }

  String _labelFor(String featureId) {
    final match = kAiFeatures.where((f) => f.id == featureId);
    if (match.isNotEmpty) return match.first.label;
    if (featureId == 'summarize') return 'Summarize';
    return featureId;
  }

  Color _colorFor(String featureId) {
    final match = kAiFeatures.where((f) => f.id == featureId);
    if (match.isNotEmpty) return match.first.color;
    return AppColors.primary;
  }

  IconData _iconFor(String featureId) {
    final match = kAiFeatures.where((f) => f.id == featureId);
    if (match.isNotEmpty) return match.first.icon;
    return Icons.auto_awesome_rounded;
  }

  String _dayLabel(String isoDay) {
    final parts = isoDay.split('-');
    if (parts.length != 3) return isoDay;
    const months = ['', 'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[int.parse(parts[1])]} ${int.parse(parts[2])}';
  }

  List<MapEntry<String, int>> _featureEntries() {
    final byFeature = Map<String, dynamic>.from(_stats?['byFeature'] ?? {});
    return byFeature.entries.map((e) => MapEntry(e.key, e.value as int)).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }

  Future<void> _export(String type) async {
    if (_exporting || _stats == null || _credits == null || _last7Days == null) return;
    setState(() => _exporting = true);
    try {
      final entries = _featureEntries();
      final totalRuns = _stats!['totalRuns'] as int? ?? 0;
      switch (type) {
        case 'csv':
          final rows = <List<String>>[
            ['Metric', 'Value'],
            ['Total Credits', '${_credits!['total']}'],
            ['Used Credits', '${_credits!['used']}'],
            ['Balance', '${_credits!['balance']}'],
            ['Total AI Runs', '$totalRuns'],
            [],
            ['Day', 'Runs'],
            ...(_last7Days!.map((e) => [_dayLabel(e.key), '${e.value}'])),
            [],
            ['Feature', 'Runs'],
            ...(entries.map((e) => [_labelFor(e.key), '${e.value}'])),
          ];
          await DocumentExportService.exportToCsv(title: 'Dashboard Summary', rows: rows);
          break;
        case 'word':
          final buffer = StringBuffer()
            ..writeln('Dashboard Summary')
            ..writeln()
            ..writeln('Total Credits: ${_credits!['total']}')
            ..writeln('Used Credits: ${_credits!['used']}')
            ..writeln('Balance: ${_credits!['balance']}')
            ..writeln('Total AI Runs: $totalRuns')
            ..writeln()
            ..writeln('Last 7 days')
            ..writeln(_last7Days!.map((e) => '${_dayLabel(e.key)}: ${e.value}').join('\n'))
            ..writeln()
            ..writeln('Usage by feature')
            ..writeln(entries.map((e) => '${_labelFor(e.key)}: ${e.value}').join('\n'));
          await DocumentExportService.exportToDocx(title: 'Dashboard Summary', content: buffer.toString());
          break;
        case 'ppt':
          await DocumentExportService.exportToPptx(title: 'Dashboard Summary', slides: [
            PptxSlide(title: 'Credits Overview', bullets: [
              'Total Credits: ${_credits!['total']}',
              'Used Credits: ${_credits!['used']}',
              'Balance: ${_credits!['balance']}',
              'Total AI Runs: $totalRuns',
            ]),
            PptxSlide(
              title: 'Last 7 Days',
              bullets: _last7Days!.map((e) => '${_dayLabel(e.key)}: ${e.value} runs').toList(),
            ),
            PptxSlide(
              title: 'Usage by Feature',
              bullets: entries.isEmpty
                  ? ['No AI features used yet.']
                  : entries.map((e) => '${_labelFor(e.key)}: ${e.value}').toList(),
            ),
          ]);
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userAsync = ref.watch(currentUserProvider);

    if (_loading || _stats == null || _last7Days == null || _credits == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final userName = userAsync.maybeWhen(
      data: (u) {
        final email = (u['email'] ?? '').toString();
        final name  = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
        if (name.isNotEmpty) return name;
        if (email.isNotEmpty) {
          final handle = email.split('@').first.replaceAll(RegExp(r'[._]'), ' ');
          return handle.split(' ').where((w) => w.isNotEmpty)
              .map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
        }
        return 'there';
      },
      orElse: () => 'there',
    );

    final entries = _featureEntries();
    final maxDayTotal = _last7Days!.isEmpty
        ? 1
        : _last7Days!.map((e) => e.value).fold<int>(0, (a, b) => a > b ? a : b);
    final maxFeatureCount = entries.isEmpty
        ? 1
        : entries.map((e) => e.value).fold<int>(0, (a, b) => a > b ? a : b);

    // Real balance from the backend — watched so a purchase made on the
    // Recharge Credits screen (which invalidates creditsProvider) is
    // reflected here immediately, without needing to reopen this screen.
    final backendTotal = ref.watch(creditsProvider).valueOrNull;
    final totalCredits = backendTotal ?? _credits!['total']!;
    final usedCredits = _credits!['used']!;
    final balance = (totalCredits - usedCredits).clamp(0, totalCredits);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: AppBar(
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.bar_chart_rounded, size: 20),
          SizedBox(width: 8),
          Text('Dashboard'),
        ]),
        actions: [
          IconButton(
            icon: _exporting
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_outlined),
            onPressed: _exporting ? null : _load,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: FadeTransition(
            opacity: _fadeIn,
            child: SlideTransition(
              position: _slideIn,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  // ── Hero: gradient card, greeting + credits ring ─────────
                  _HeroCreditsCard(
                    userName: userName,
                    balance: balance,
                    totalCredits: totalCredits,
                    usedCredits: usedCredits,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ── Export row ─────────────────────────────────────────
                  Row(children: [
                    Expanded(
                      child: Text('Last 7 days', style: theme.textTheme.titleSmall
                          ?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                    ),
                    _ExportButton(
                      icon: Icons.grid_on_rounded,
                      label: 'CSV',
                      color: AppColors.success,
                      onTap: _exporting ? null : () => _export('csv'),
                    ),
                    const SizedBox(width: 8),
                    _ExportButton(
                      icon: Icons.slideshow_rounded,
                      label: 'PPT',
                      color: AppColors.error,
                      onTap: _exporting ? null : () => _export('ppt'),
                    ),
                    const SizedBox(width: 8),
                    _ExportButton(
                      icon: Icons.description_rounded,
                      label: 'Word',
                      color: const Color(0xFF2563EB),
                      onTap: _exporting ? null : () => _export('word'),
                    ),
                  ]),
                  const SizedBox(height: AppSpacing.sm),

                  // ── Last 7 days chart ──────────────────────────────────
                  _GlassCard(
                    padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
                    child: SizedBox(
                      height: 200,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: ((maxDayTotal == 0 ? 5 : maxDayTotal) * 1.2).ceilToDouble(),
                          gridData: const FlGridData(show: true, drawVerticalLine: false),
                          borderData: FlBorderData(show: false),
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipColor: (_) => const Color(0xFF111827),
                              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                                '${rod.toY.toInt()} runs',
                                const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 32,
                                interval: 1,
                                getTitlesWidget: (value, meta) {
                                  if (value != value.roundToDouble()) return const SizedBox();
                                  return Text('${value.toInt()}',
                                      style: const TextStyle(fontSize: 11));
                                },
                              ),
                            ),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final i = value.toInt();
                                  if (i < 0 || i >= _last7Days!.length) return const SizedBox();
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(_dayLabel(_last7Days![i].key),
                                        style: const TextStyle(fontSize: 10)),
                                  );
                                },
                              ),
                            ),
                          ),
                          barGroups: [
                            for (int i = 0; i < _last7Days!.length; i++)
                              BarChartGroupData(x: i, barRods: [
                                BarChartRodData(
                                  toY: _last7Days![i].value.toDouble(),
                                  width: 18,
                                  borderRadius: BorderRadius.circular(6),
                                  gradient: const LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                                  ),
                                ),
                              ]),
                          ],
                        ),
                        swapAnimationDuration: const Duration(milliseconds: 500),
                        swapAnimationCurve: Curves.easeOutCubic,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ── Per-feature usage breakdown ─────────────────────────
                  Text('Credits by feature', style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: AppSpacing.sm),
                  if (entries.isEmpty)
                    _GlassCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Center(
                        child: Text('No AI features used yet.',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: AppColors.textSecondary)),
                      ),
                    )
                  else
                    _GlassCard(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: entries.map((e) {
                          final fraction = maxFeatureCount == 0 ? 0.0 : e.value / maxFeatureCount;
                          final color = _colorFor(e.key);
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(children: [
                              Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Icon(_iconFor(e.key), size: 15, color: color),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 78,
                                child: Text(_labelFor(e.key),
                                    style: theme.textTheme.bodyMedium,
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: fraction.clamp(0.02, 1.0)),
                                    duration: const Duration(milliseconds: 700),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, animatedFraction, _) => Stack(children: [
                                      Container(height: 14, color: AppColors.outlineVariant.withValues(alpha: 0.4)),
                                      FractionallySizedBox(
                                        widthFactor: animatedFraction,
                                        child: Container(
                                          height: 14,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(colors: [
                                              color.withValues(alpha: 0.7), color,
                                            ]),
                                          ),
                                        ),
                                      ),
                                    ]),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 28,
                                child: Text('${e.value}',
                                    textAlign: TextAlign.right,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(fontWeight: FontWeight.w700)),
                              ),
                            ]),
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hero card: gradient background, blurred depth orbs, credits ring ───────

class _HeroCreditsCard extends StatelessWidget {
  final String userName;
  final int balance, totalCredits, usedCredits;
  const _HeroCreditsCard({
    required this.userName, required this.balance,
    required this.totalCredits, required this.usedCredits,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF312E81), Color(0xFF4F46E5), Color(0xFF7C3AED)],
          ),
          boxShadow: [
            BoxShadow(color: Color(0x334F46E5), blurRadius: 24, offset: Offset(0, 12)),
          ],
        ),
        child: Stack(children: [
          // Decorative blurred "orbs" — the source of the 3D/premium depth.
          Positioned(top: -40, right: -30, child: _Orb(size: 140, color: Colors.white.withValues(alpha: 0.10))),
          Positioned(bottom: -50, left: -20, child: _Orb(size: 160, color: Colors.white.withValues(alpha: 0.08))),
          Positioned(top: 60, left: 30, child: _Orb(size: 60, color: Colors.white.withValues(alpha: 0.06))),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hi $userName!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('Here\'s your AI usage at a glance',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
              const SizedBox(height: 18),

              SizedBox(
                height: 176,
                child: Stack(alignment: Alignment.center, children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, _) => PieChart(
                      PieChartData(
                        sectionsSpace: 4,
                        centerSpaceRadius: 58,
                        startDegreeOffset: -90,
                        sections: [
                          PieChartSectionData(
                            value: math.max(balance, 0) * t + 0.0001,
                            color: Colors.white,
                            radius: 20,
                            showTitle: false,
                          ),
                          PieChartSectionData(
                            value: usedCredits * t + 0.0001,
                            color: Colors.white.withValues(alpha: 0.25),
                            radius: 20,
                            showTitle: false,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    _AnimatedCount(
                      value: balance,
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    Text('Balance',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
                  ]),
                ]),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _GlassStat(
                    icon: Icons.autorenew_rounded,
                    label: 'Total Credits',
                    value: totalCredits,
                  ),
                  _GlassStat(
                    icon: Icons.local_fire_department_rounded,
                    label: 'Used Credits',
                    value: usedCredits,
                  ),
                ],
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  const _Orb({required this.size, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

/// A frosted-glass-style stat pill sitting on the gradient hero card.
class _GlassStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  const _GlassStat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 84, height: 84,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
        ),
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(height: 2),
          _AnimatedCount(
            value: value,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ]),
      ),
      const SizedBox(height: 6),
      Text(label, style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
    ]);
  }
}

/// A number that counts up from 0 the first time it's built, instead of
/// just appearing — a small touch that reads as "designed" rather than a
/// static stat dump.
class _AnimatedCount extends StatelessWidget {
  final int value;
  final TextStyle? style;
  const _AnimatedCount({required this.value, required this.style});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<int>(
    tween: IntTween(begin: 0, end: value),
    duration: const Duration(milliseconds: 900),
    curve: Curves.easeOutCubic,
    builder: (context, v, _) => Text('$v', style: style),
  );
}

/// A soft-elevated white "glass" card — replaces the plain default [Card]
/// look with a subtle shadow and larger radius for a more premium feel.
class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _GlassCard({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, 6)),
      ],
    ),
    child: child,
  );
}

class _ExportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _ExportButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
    );
  }
}
