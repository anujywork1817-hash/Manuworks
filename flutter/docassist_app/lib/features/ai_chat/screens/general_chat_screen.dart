import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/widgets/fun_loading_word.dart';

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
class GeneralChatScreen extends StatefulWidget {
  const GeneralChatScreen({super.key});

  @override
  State<GeneralChatScreen> createState() => _GeneralChatScreenState();
}

class _GeneralChatScreenState extends State<GeneralChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_Msg> _messages = [];
  bool _isLoading = false;
  String? _error;

  String? _sessionId;
  List<_Session> _allSessions = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessions = await _GeneralChatStore.loadAll();
    if (!mounted) return;
    setState(() => _allSessions = sessions);
  }

  @override
  void dispose() {
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

    setState(() {
      _messages.add(_Msg(text, true));
      _isLoading = true;
      _error = null;
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
  }

  void _startNewChat() {
    setState(() {
      _messages.clear();
      _sessionId = null;
      _error = null;
    });
  }

  void _openSession(_Session session) {
    setState(() {
      _messages
        ..clear()
        ..addAll(session.messages);
      _sessionId = session.id;
      _error = null;
    });
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
              child: _messages.isEmpty
                  ? const _EmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        return _ChatBubble(msg: msg);
                      },
                    ),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.auto_awesome_rounded,
                  color: cs.onPrimaryContainer, size: 40),
            ),
            const SizedBox(height: 20),
            Text('Ask me anything legal',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                color: cs.onSurface)),
          ],
        ),
      ),
    );
  }
}
