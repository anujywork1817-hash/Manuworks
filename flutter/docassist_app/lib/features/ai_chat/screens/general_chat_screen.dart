import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/widgets/fun_loading_word.dart';
import '../../auth/providers/auth_provider.dart';

/// Suggested opening questions shown in the hero card — a mix general
/// enough to be useful to most users of a legal-document assistant.
const _suggestedQuestions = [
  'Explain what a legal notice is',
  'What are my rights as a tenant?',
  'Draft a simple rent agreement clause',
  'Difference between civil and criminal law',
  'What documents do I need for a will?',
  'Summarize consumer protection basics',
];

class _Msg {
  final String text;
  final bool isUser;
  _Msg(this.text, this.isUser);

  Map<String, dynamic> toJson() => {'text': text, 'isUser': isUser};
  factory _Msg.fromJson(Map<String, dynamic> j) =>
      _Msg(j['text'] ?? '', j['isUser'] ?? false);
}

/// One saved general-chat conversation, persisted locally on-device
/// (this endpoint is stateless server-side, so history lives client-side).
class _Session {
  final String id;
  String title;
  final List<_Msg> messages;
  DateTime updatedAt;

  _Session({required this.id, required this.title, required this.messages, required this.updatedAt});

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'messages': messages.map((m) => m.toJson()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
      };
  factory _Session.fromJson(Map<String, dynamic> j) => _Session(
        id: j['id'] ?? '',
        title: j['title'] ?? 'New chat',
        messages: ((j['messages'] as List?) ?? [])
            .map((m) => _Msg.fromJson(m as Map<String, dynamic>))
            .toList(),
        updatedAt: DateTime.tryParse(j['updatedAt'] ?? '') ?? DateTime.now(),
      );
}

/// Local storage for general-chat conversation history (SharedPreferences,
/// JSON-encoded). The `/ai/help` backend endpoint is stateless, so this
/// keeps "history" and "continue chat from where you left off" working
/// entirely on-device.
class _GeneralChatStore {
  static const _key = 'general_chat_sessions_v1';

  static Future<List<_Session>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      final sessions = list.map((e) => _Session.fromJson(e as Map<String, dynamic>)).toList();
      sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return sessions;
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<_Session> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(sessions.map((s) => s.toJson()).toList()));
  }
}

/// A general-purpose AI chat that does NOT require an uploaded document.
/// Reachable directly from the "AI Chat" bottom nav tab. Conversation
/// history is persisted locally so the user can revisit and continue any
/// past conversation.
class GeneralChatScreen extends ConsumerStatefulWidget {
  const GeneralChatScreen({super.key});

  @override
  ConsumerState<GeneralChatScreen> createState() => _GeneralChatScreenState();
}

class _GeneralChatScreenState extends ConsumerState<GeneralChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_Msg> _messages = [];
  bool _isLoading = false;
  String? _error;

  String? _sessionId;
  List<_Session> _allSessions = [];

  // ── Hero suggestion card visibility ──────────────────────────────────
  // Shown on first open; hidden the moment the user types; reappears after
  // a period of inactivity so it keeps offering suggestions rather than
  // vanishing for good after the first message.
  bool _showHero = true;
  Timer? _inactivityTimer;

  @override
  void initState() {
    super.initState();
    _loadSessions();
    _controller.addListener(_onTextChanged);
  }

  Future<void> _loadSessions() async {
    final sessions = await _GeneralChatStore.loadAll();
    if (!mounted) return;
    setState(() => _allSessions = sessions);
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText && _showHero) {
      _inactivityTimer?.cancel();
      setState(() => _showHero = false);
    } else if (!hasText && !_isLoading) {
      _scheduleHeroReappear();
    }
  }

  void _scheduleHeroReappear({Duration delay = const Duration(seconds: 18)}) {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(delay, () {
      if (!mounted) return;
      if (_controller.text.trim().isEmpty && !_isLoading) {
        setState(() => _showHero = true);
      }
    });
  }

  void _useSuggestion(String question) {
    _inactivityTimer?.cancel();
    setState(() => _showHero = false);
    _controller.text = question;
    _send();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _friendlyError(String raw) {
    if (raw.contains('Daily AI token limit') ||
        raw.contains('tokens per day') ||
        raw.contains('TPD')) {
      final match = RegExp(r'try again in ([^.]+)').firstMatch(raw);
      final wait = match?.group(1);
      return 'Daily AI limit reached.${wait != null ? ' Try again in $wait.' : ' Please try again later.'}';
    }
    if (raw.contains('Rate limit') || raw.contains('rate limit') || raw.contains('TPM')) {
      return 'AI is busy right now. Please wait a moment and try again.';
    }
    return raw;
  }

  Future<void> _persist() async {
    final id = _sessionId ??= DateTime.now().microsecondsSinceEpoch.toString();
    final title = _messages.isNotEmpty
        ? (_messages.first.text.length > 40
            ? '${_messages.first.text.substring(0, 40)}…'
            : _messages.first.text)
        : 'New chat';

    final existingIndex = _allSessions.indexWhere((s) => s.id == id);
    final session = _Session(
      id: id,
      title: title,
      messages: List.of(_messages),
      updatedAt: DateTime.now(),
    );
    if (existingIndex >= 0) {
      _allSessions[existingIndex] = session;
    } else {
      _allSessions.insert(0, session);
    }
    _allSessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _GeneralChatStore.saveAll(_allSessions);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;
    _controller.clear();
    _inactivityTimer?.cancel();

    setState(() {
      _messages.add(_Msg(text, true));
      _isLoading = true;
      _error = null;
      _showHero = false;
    });
    _scrollToBottom();

    try {
      // Send prior turns as history so the assistant has conversation
      // context, not just the latest message.
      final history = _messages
          .sublist(0, _messages.length - 1)
          .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
          .toList();
      final response = await DioClient.post('/ai/help', data: {
        'message': text,
        'history': history,
      });
      final data = response is Map ? response['data'] : response;

      String answer;
      if (data is Map) {
        answer = (data['reply'] ?? data['message'] ?? data.toString()).toString();
      } else {
        answer = data.toString();
      }

      setState(() {
        _messages.add(_Msg(answer, false));
        _isLoading = false;
      });
      await _persist();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = _friendlyError(e.toString());
      });
    }
    _scrollToBottom();
    // Went quiet again — bring the suggestion card back after a while so
    // it keeps offering follow-up ideas instead of disappearing for good.
    _scheduleHeroReappear();
  }

  void _startNewChat() {
    _inactivityTimer?.cancel();
    setState(() {
      _messages.clear();
      _sessionId = null;
      _error = null;
      _showHero = true;
    });
  }

  void _openSession(_Session session) {
    setState(() {
      _messages
        ..clear()
        ..addAll(session.messages);
      _sessionId = session.id;
      _error = null;
      _showHero = false;
    });
    _scheduleHeroReappear();
    Navigator.pop(context);
    _scrollToBottom();
  }

  Future<void> _deleteSession(_Session session) async {
    setState(() {
      _allSessions.removeWhere((s) => s.id == session.id);
      if (_sessionId == session.id) {
        _messages.clear();
        _sessionId = null;
      }
    });
    await _GeneralChatStore.saveAll(_allSessions);
  }

  Future<void> _openHistory() async {
    await _loadSessions();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _GeneralChatHistorySheet(
        sessions: _allSessions,
        onSelect: _openSession,
        onDelete: (s) async {
          await _deleteSession(s);
          if (ctx.mounted) Navigator.pop(ctx);
          if (mounted) await _openHistory();
        },
      ),
    );
  }

  String _userName(WidgetRef ref) => ref.watch(currentUserProvider).maybeWhen(
        data: (u) {
          final email = (u['email'] ?? '').toString();
          final name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
          if (name.isNotEmpty) return name.split(' ').first;
          if (email.isNotEmpty) {
            final handle = email.split('@').first.replaceAll(RegExp(r'[._]'), ' ');
            final first = handle.split(' ').firstWhere((w) => w.isNotEmpty, orElse: () => '');
            if (first.isNotEmpty) return first[0].toUpperCase() + first.substring(1);
          }
          return 'there';
        },
        orElse: () => 'there',
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final userName = _userName(ref);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Container(
              color: cs.surface,
              padding: const EdgeInsets.fromLTRB(4, 10, 20, 10),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.auto_awesome_rounded,
                      color: cs.onPrimaryContainer, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('AI Chat',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                        color: cs.onSurface)),
                    Text('Ask me anything legal',
                      style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6))),
                  ]),
                ),
                IconButton(
                  icon: const Icon(Icons.history_rounded),
                  tooltip: 'History',
                  onPressed: _openHistory,
                ),
                IconButton(
                  icon: const Icon(Icons.add_comment_outlined),
                  tooltip: 'New chat',
                  onPressed: _isLoading ? null : _startNewChat,
                ),
              ]),
            ),
            const Divider(height: 1),

            // ── Body ────────────────────────────────────────────────────────
            Expanded(
              child: Stack(children: [
                _messages.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: _HeroSuggestionCard(
                            userName: userName,
                            floating: false,
                            onSuggestion: _useSuggestion,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          return _ChatBubble(msg: msg);
                        },
                      ),
                if (_messages.isNotEmpty)
                  Positioned(
                    left: 16, right: 16, bottom: 10,
                    child: IgnorePointer(
                      ignoring: !_showHero,
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOutCubic,
                        offset: _showHero ? Offset.zero : const Offset(0, 0.35),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 350),
                          opacity: _showHero ? 1 : 0,
                          child: _HeroSuggestionCard(
                            userName: userName,
                            floating: true,
                            onSuggestion: _useSuggestion,
                            onDismiss: () {
                              _inactivityTimer?.cancel();
                              setState(() => _showHero = false);
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: FunLoadingWord(),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Ask a legal question...',
                        filled: true,
                        fillColor: AppColors.accentContainer,
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.full,
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isLoading ? null : _send,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GeneralChatHistorySheet extends StatelessWidget {
  final List<_Session> sessions;
  final void Function(_Session) onSelect;
  final void Function(_Session) onDelete;
  const _GeneralChatHistorySheet({
    required this.sessions,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(children: [
            Icon(Icons.history_rounded, color: cs.onSurface),
            const SizedBox(width: 8),
            Text('Chat History',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: sessions.isEmpty
              ? Center(
                  child: Text('No past conversations yet',
                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6))))
              : ListView.builder(
                  controller: scrollController,
                  itemCount: sessions.length,
                  itemBuilder: (context, i) {
                    final s = sessions[i];
                    return Dismissible(
                      key: ValueKey(s.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: AppColors.error,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete_outline, color: Colors.white),
                      ),
                      onDismissed: (_) => onDelete(s),
                      child: ListTile(
                        leading: const Icon(Icons.chat_bubble_outline_rounded),
                        title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '${s.messages.length} message${s.messages.length == 1 ? '' : 's'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onTap: () => onSelect(s),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final _Msg msg;
  const _ChatBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: msg.isUser ? AppColors.accentContainer : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(msg.text),
      ),
    );
  }
}

/// Greets the user and suggests questions to ask. Shown full-size as the
/// empty state on first open, and as a smaller floating card above the
/// input mid-conversation whenever the user has gone quiet for a while.
class _HeroSuggestionCard extends StatefulWidget {
  final String userName;
  final bool floating;
  final void Function(String question) onSuggestion;
  final VoidCallback? onDismiss;
  const _HeroSuggestionCard({
    required this.userName,
    required this.floating,
    required this.onSuggestion,
    this.onDismiss,
  });

  @override
  State<_HeroSuggestionCard> createState() => _HeroSuggestionCardState();
}

class _HeroSuggestionCardState extends State<_HeroSuggestionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this, duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.floating
        ? _suggestedQuestions.take(3).toList()
        : _suggestedQuestions;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(maxWidth: widget.floating ? 520 : 460),
        padding: EdgeInsets.fromLTRB(20, widget.floating ? 16 : 26, 20, widget.floating ? 14 : 22),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF312E81), Color(0xFF4F46E5), Color(0xFF7C3AED)],
          ),
          boxShadow: [
            BoxShadow(color: Color(0x334F46E5), blurRadius: 20, offset: Offset(0, 10)),
          ],
        ),
        child: Stack(children: [
          Positioned(top: -30, right: -20,
              child: _Orb(size: 100, color: Colors.white.withValues(alpha: 0.10))),
          Positioned(bottom: -30, left: -20,
              child: _Orb(size: 90, color: Colors.white.withValues(alpha: 0.08))),

          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              AnimatedBuilder(
                animation: _float,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, -4 * math.sin(_float.value * math.pi)),
                  child: child,
                ),
                child: Container(
                  width: widget.floating ? 34 : 46,
                  height: widget.floating ? 34 : 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(widget.floating ? 10 : 14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: widget.floating ? 18 : 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Hello, ${widget.userName}!',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800,
                          fontSize: widget.floating ? 15 : 19)),
                  Text(
                    widget.floating
                        ? 'Need another idea? Try one of these:'
                        : 'What legal question can I help with today?',
                    style: TextStyle(color: Colors.white70, fontSize: widget.floating ? 11.5 : 13),
                  ),
                ]),
              ),
              if (widget.onDismiss != null)
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                  tooltip: 'Dismiss',
                  onPressed: widget.onDismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
            ]),
            SizedBox(height: widget.floating ? 12 : 18),
            Wrap(spacing: 8, runSpacing: 8, children: questions.map((q) => _SuggestionChip(
              text: q,
              compact: widget.floating,
              onTap: () => widget.onSuggestion(q),
            )).toList()),
          ]),
        ]),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String text;
  final bool compact;
  final VoidCallback onTap;
  const _SuggestionChip({required this.text, required this.compact, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14, vertical: compact ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Text(text,
          style: TextStyle(color: Colors.white, fontSize: compact ? 11.5 : 12.5,
              fontWeight: FontWeight.w600)),
    ),
  );
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
