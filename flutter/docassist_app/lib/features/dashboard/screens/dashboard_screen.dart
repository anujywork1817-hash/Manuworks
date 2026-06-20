import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_theme.dart';
import '../../../core/router/router.dart';
import '../../../core/network/dio_client.dart';
import '../../documents/providers/document_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../notifications/providers/notifications_provider.dart';

final dashboardStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final res = await DioClient.get('/documents', queryParams: {'limit': 5});
    return {
      'recent_documents': res['data']['documents'] ?? [],
      'total_documents': res['data']['total'] ?? 0,
    };
  } catch (_) {
    return {'recent_documents': [], 'total_documents': 0};
  }
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync  = ref.watch(dashboardStatsProvider);
    final userAsync   = ref.watch(currentUserProvider);
    final unreadCount = ref.watch(notificationsProvider.select((s) => s.unreadCount));
    final cs          = Theme.of(context).colorScheme;
    final tt          = Theme.of(context).textTheme;

    final userName = userAsync.maybeWhen(
      data: (u) {
        final email = (u['email'] ?? '').toString();
        final name  = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
        return name.isNotEmpty ? name : email.split('@').first;
      },
      orElse: () => '',
    );

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: cs.primary,
          onRefresh: () => ref.refresh(dashboardStatsProvider.future),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [

              // ── Header ─────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(children: [
                    // Logo mark
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.balance_rounded,
                          color: cs.onPrimary, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Text('LexDocs',
                      style: tt.titleLarge?.copyWith(
                        letterSpacing: -0.5, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    _NotificationBell(unreadCount: unreadCount, cs: cs),
                  ]),
                ),
              ),

              // ── Greeting ───────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      userName.isNotEmpty ? 'Good day, $userName.' : 'Good day.',
                      style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 4),
                    Text('Your legal workspace is ready.',
                      style: tt.bodyMedium),
                  ]),
                ),
              ),

              // ── AI Chat banner ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: GestureDetector(
                    onTap: () => context.go(AppRoutes.aiChat),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(18),
                      child: Row(children: [
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('AI Legal Assistant',
                              style: tt.titleSmall?.copyWith(
                                color: cs.onPrimary,
                                fontWeight: FontWeight.w700,
                              )),
                            const SizedBox(height: 4),
                            Text('Ask anything about your documents,\ncases, or legal queries.',
                              style: tt.bodySmall?.copyWith(
                                color: cs.onPrimary.withValues(alpha: 0.72),
                                height: 1.5,
                              )),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: cs.onPrimary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('Start Chatting',
                                style: tt.labelMedium?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w700,
                                )),
                            ),
                          ],
                        )),
                        const SizedBox(width: 16),
                        Icon(Icons.auto_awesome_rounded,
                            color: cs.onPrimary.withValues(alpha: 0.3), size: 56),
                      ]),
                    ),
                  ),
                ),
              ),

              // ── Feature shortcuts ──────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(children: [
                    _FeatureChip(icon: Icons.upload_file_outlined, label: 'Upload',
                        onTap: () => context.go(AppRoutes.documents), cs: cs, tt: tt),
                    const SizedBox(width: 10),
                    _FeatureChip(icon: Icons.draw_outlined, label: 'Draft',
                        onTap: () => context.push(AppRoutes.draft), cs: cs, tt: tt),
                    const SizedBox(width: 10),
                    _FeatureChip(icon: Icons.document_scanner_outlined, label: 'Scan',
                        onTap: () => context.push(AppRoutes.ocrScan), cs: cs, tt: tt),
                    const SizedBox(width: 10),
                    _FeatureChip(icon: Icons.compare_arrows_rounded, label: 'Compare',
                        onTap: () => context.push(AppRoutes.compare), cs: cs, tt: tt),
                  ]),
                ),
              ),

              // ── Quick Access ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Quick Access', style: tt.titleMedium),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: _QuickCard(
                        icon: Icons.folder_outlined,
                        title: 'Documents',
                        subtitle: 'View & manage',
                        onTap: () => context.go(AppRoutes.documents),
                        cs: cs, tt: tt,
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _QuickCard(
                        icon: Icons.cases_outlined,
                        title: 'Matters',
                        subtitle: 'Case folders',
                        onTap: () => context.go(AppRoutes.matters),
                        cs: cs, tt: tt,
                      )),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _QuickCard(
                        icon: Icons.search_outlined,
                        title: 'Search',
                        subtitle: 'Full-text search',
                        onTap: () => context.push(AppRoutes.search),
                        cs: cs, tt: tt,
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _QuickCard(
                        icon: Icons.star_outline_rounded,
                        title: 'Favourites',
                        subtitle: 'Saved documents',
                        onTap: () => context.push(AppRoutes.favourites),
                        cs: cs, tt: tt,
                      )),
                    ]),
                  ]),
                ),
              ),

              // ── Recent Documents ───────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 4, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recent Documents', style: tt.titleMedium),
                      TextButton(
                        onPressed: () => context.go(AppRoutes.documents),
                        child: const Text('See all'),
                      ),
                    ],
                  ),
                ),
              ),

              statsAsync.when(
                data: (stats) {
                  final docs = stats['recent_documents'] as List;
                  if (docs.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(children: [
                            Icon(Icons.folder_open_outlined,
                                size: 40, color: cs.outline),
                            const SizedBox(height: 8),
                            Text('No documents yet',
                                style: tt.bodyMedium),
                            const SizedBox(height: 14),
                            ElevatedButton(
                              onPressed: () => context.go(AppRoutes.documents),
                              child: const Text('Upload Document'),
                            ),
                          ]),
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final doc = Document.fromJson(docs[i] as Map<String, dynamic>);
                          return _RecentDocRow(doc: doc, cs: cs, tt: tt,
                              onTap: () => context.push('/documents/${doc.id}'));
                        },
                        childCount: docs.length,
                      ),
                    ),
                  );
                },
                loading: () => SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, __) => _SkeletonRow(cs: cs),
                      childCount: 3,
                    ),
                  ),
                ),
                error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Notification bell ─────────────────────────────────────────────────────────

class _NotificationBell extends StatelessWidget {
  final int unreadCount;
  final ColorScheme cs;
  const _NotificationBell({required this.unreadCount, required this.cs});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => context.push(AppRoutes.notifications),
    child: Stack(clipBehavior: Clip.none, children: [
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          shape: BoxShape.circle,
          border: Border.all(color: cs.outline),
        ),
        child: Icon(Icons.notifications_outlined, color: cs.onSurface, size: 20),
      ),
      if (unreadCount > 0)
        Positioned(
          right: -2, top: -2,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Text(
              unreadCount > 99 ? '99+' : '$unreadCount',
              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ),
    ]),
  );
}

// ── Feature chip ──────────────────────────────────────────────────────────────

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme cs;
  final TextTheme tt;

  const _FeatureChip({
    required this.icon, required this.label,
    required this.onTap, required this.cs, required this.tt,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline),
        ),
        child: Column(children: [
          Icon(icon, color: cs.onSurface, size: 22),
          const SizedBox(height: 6),
          Text(label,
            style: tt.labelSmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            )),
        ]),
      ),
    ),
  );
}

// ── Quick access card ─────────────────────────────────────────────────────────

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  final ColorScheme cs;
  final TextTheme tt;

  const _QuickCard({
    required this.icon, required this.title, required this.subtitle,
    required this.onTap, required this.cs, required this.tt,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: cs.primary, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
            style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          Text(subtitle,
            style: tt.bodySmall),
        ])),
      ]),
    ),
  );
}

// ── Recent doc row ────────────────────────────────────────────────────────────

class _RecentDocRow extends StatelessWidget {
  final Document doc;
  final VoidCallback onTap;
  final ColorScheme cs;
  final TextTheme tt;
  const _RecentDocRow({required this.doc, required this.onTap,
      required this.cs, required this.tt});

  Color get _typeColor {
    switch (doc.fileType.toLowerCase()) {
      case 'pdf':  return AppColors.pdfColor;
      case 'docx': case 'doc': return AppColors.docxColor;
      default: return AppColors.txtColor;
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: _typeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(child: Text(doc.fileType.toUpperCase(),
              style: TextStyle(color: _typeColor,
                  fontWeight: FontWeight.w800, fontSize: 10))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(doc.title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: tt.labelLarge),
          const SizedBox(height: 2),
          Text('${doc.fileSizeHuman} · ${timeago.format(doc.createdAt)}',
              style: tt.bodySmall),
        ])),
        Icon(Icons.chevron_right_rounded, color: cs.outline, size: 20),
      ]),
    ),
  );
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

class _SkeletonRow extends StatelessWidget {
  final ColorScheme cs;
  const _SkeletonRow({required this.cs});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    height: 64,
    decoration: BoxDecoration(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
    ),
  );
}
