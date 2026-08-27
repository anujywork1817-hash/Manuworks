import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_theme.dart';
import '../providers/ai_provider.dart';

/// Slides in from the left showing every past chat session for this
/// document — title (from the first message), a preview of the last
/// message, and when it was last active. Tap one to resume it exactly
/// where it was left off; swipe to delete.
///
/// Mirrors the visual pattern of [showFeatureHistorySheet] used by the
/// other AI feature screens, but backed by real server-persisted sessions
/// (chat_sessions / chat_messages) instead of local-only history, since a
/// chat needs to actually continue — not just redisplay a static result.
Future<String?> showChatHistorySheet(
  BuildContext context, {
  required String documentId,
}) {
  return Navigator.of(context).push<String>(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black54,
      barrierDismissible: true,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => _ChatHistoryPanel(documentId: documentId),
      transitionsBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
  );
}

class _ChatHistoryPanel extends ConsumerWidget {
  final String documentId;
  const _ChatHistoryPanel({required this.documentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width * 0.84;
    final sessionsAsync = ref.watch(chatSessionsProvider(documentId));
    final cs = Theme.of(context).colorScheme;

    return Row(children: [
      Material(
        color: cs.surface,
        elevation: 8,
        child: SizedBox(
          width: width,
          height: double.infinity,
          child: SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(children: [
                  Icon(Icons.history_rounded, color: cs.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Chat History',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ]),
              ),
              const Divider(height: 1),
              Expanded(
                child: sessionsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const Center(child: Text('Could not load history')),
                  data: (sessions) {
                    if (sessions.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.chat_bubble_outline_rounded,
                                size: 40, color: cs.onSurface.withValues(alpha: 0.3)),
                            const SizedBox(height: 12),
                            Text('No past conversations yet',
                                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6))),
                          ]),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: sessions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final s = sessions[i];
                        return Dismissible(
                          key: ValueKey(s.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                          ),
                          confirmDismiss: (_) async {
                            await ref.read(chatProvider(documentId).notifier).deleteSession(s.id);
                            return true;
                          },
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.of(context).pop(s.id),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: cs.outlineVariant),
                              ),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Expanded(
                                    child: Text(
                                      s.title.isEmpty ? 'Chat' : s.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(timeago.format(s.updatedAt),
                                      style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
                                ]),
                                if (s.lastMessage.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    s.lastMessage,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12.5, color: cs.onSurface.withValues(alpha: 0.65)),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Text('${s.messageCount} message${s.messageCount == 1 ? '' : 's'}',
                                    style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45))),
                              ]),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ]),
          ),
        ),
      ),
      const Expanded(child: SizedBox()),
    ]);
  }
}
