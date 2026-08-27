import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';

// ─── AI feature notifier (Summarize, KeyPoints, Timeline, Actions, Analyze) ───

class AIState {
  final bool isLoading;
  final String? error;
  const AIState({this.isLoading = false, this.error});
  AIState copyWith({bool? isLoading, String? error}) =>
      AIState(isLoading: isLoading ?? this.isLoading, error: error);
}

class AINotifier extends StateNotifier<AIState> {
  AINotifier() : super(const AIState());

  Future<String> processDocument(String docId) async {
    final response = await DioClient.post('/documents/$docId/process');
    return response['message'] ?? 'Document processed successfully';
  }

  Future<String> summarize(String docId) async {
    final response = await DioClient.post('/documents/$docId/summarize');
    final data = response['data'];
    return data['summary'] ?? data.toString();
  }

  Future<String> extractKeyPoints(String docId) async {
    final response = await DioClient.post('/documents/$docId/keypoints');
    final data = response['data'];
    if (data is List) return data.map((e) => '• $e').join('\n');
    if (data is Map && data['key_points'] is List) {
      return (data['key_points'] as List).map((e) => '• $e').join('\n');
    }
    return data.toString();
  }

  Future<String> extractTimeline(String docId) async {
    final response = await DioClient.post('/documents/$docId/timeline');
    final data = response['data'];
    if (data is Map && data['events'] is List) {
      return (data['events'] as List)
          .map((e) => '${e['date']}: ${e['event']}')
          .join('\n');
    }
    return data.toString();
  }

  Future<String> extractActionItems(String docId) async {
    final response = await DioClient.post('/documents/$docId/actions');
    final data = response['data'];
    if (data is List) return data.map((e) => '☑ $e').join('\n');
    if (data is Map && data['action_items'] is List) {
      return (data['action_items'] as List)
          .map((e) => '☑ ${e['action']} (${e['priority'] ?? ''})')
          .join('\n');
    }
    return data.toString();
  }

  Future<String> analyzeDocument(String docId) async {
    final response = await DioClient.post('/documents/$docId/analyze');
    final data = response['data'];
    if (data is Map) {
      final buffer = StringBuffer();
      if (data['document_type'] != null) {
        buffer.writeln('Type: ${data['document_type']}');
      }
      if (data['sentiment'] != null) buffer.writeln('Sentiment: ${data['sentiment']}');
      if (data['risk_level'] != null) buffer.writeln('Risk: ${data['risk_level']}');
      if (data['insights'] is List) {
        buffer.writeln('\nInsights:');
        for (final i in (data['insights'] as List)) {
          buffer.writeln('• $i');
        }
      }
      return buffer.toString();
    }
    return data.toString();
  }

  Future<String> translateDocument(String docId, String targetLanguage) async {
    final response = await DioClient.post('/documents/$docId/translate',
        data: {'target_language': targetLanguage});
    final data = response['data'];
    if (data is Map) return data['translated_text'] ?? data.toString();
    return data.toString();
  }

  Future<String> checkGrammar(String docId) async {
    final response = await DioClient.post('/documents/$docId/grammar');
    final data = response['data'];
    if (data is! Map) return data.toString();

    final score = data['score'] ?? 0;
    final issueCount = data['issue_count'] ?? 0;
    final summary = data['summary'] ?? '';
    final issues = data['issues'];

    final scoreIcon = score >= 90 ? '✅' : score >= 70 ? '🟡' : '🔴';
    final buf = StringBuffer();
    buf.writeln('$scoreIcon GRAMMAR CHECK — Score: $score/100');
    buf.writeln();

    if (issueCount == 0) {
      buf.writeln('✅ No grammatical errors found.');
      buf.writeln();
      buf.writeln(summary);
      return buf.toString().trim();
    }

    buf.writeln('Found $issueCount issue${issueCount == 1 ? '' : 's'}\n');

    if (issues is List) {
      for (final issue in issues) {
        if (issue is! Map) continue;
        final type = (issue['type'] ?? '').toString();
        final typeIcon = _grammarTypeIcon(type);
        buf.writeln('$typeIcon ${_grammarTypeLabel(type)}');
        buf.writeln('  ✗ "${issue['original'] ?? ''}"');
        buf.writeln('  ✓ "${issue['correction'] ?? ''}"');
        if ((issue['explanation'] ?? '').toString().isNotEmpty) {
          buf.writeln('  → ${issue['explanation']}');
        }
        buf.writeln();
      }
    }

    buf.writeln('─────────────────────');
    buf.writeln(summary);
    return buf.toString().trim();
  }

  String _grammarTypeIcon(String type) {
    switch (type) {
      case 'spelling': return '🔤';
      case 'punctuation': return '⚡';
      case 'tense': return '⏰';
      case 'subject-verb': return '🔗';
      case 'article': return '📌';
      case 'preposition': return '📍';
      case 'sentence-structure': return '🏗️';
      default: return '❌';
    }
  }

  String _grammarTypeLabel(String type) {
    switch (type) {
      case 'subject-verb': return 'Subject-Verb Agreement';
      case 'sentence-structure': return 'Sentence Structure';
      default: return type[0].toUpperCase() + type.substring(1);
    }
  }

  Future<String> autoTag(String docId) async {
    final response = await DioClient.post('/documents/$docId/autotag');
    final data = response['data'];
    if (data is! Map) return data.toString();

    final buf = StringBuffer();
    buf.writeln('🏷️ AUTO-TAGS\n');

    final type = data['document_type'] ?? '';
    final area = data['practice_area'] ?? '';
    final complexity = (data['complexity'] ?? '').toString();

    if (type.isNotEmpty) buf.writeln('📄 Type: $type');
    if (area.isNotEmpty) buf.writeln('⚖️ Practice Area: $area');
    if (complexity.isNotEmpty) {
      final icon = complexity == 'complex' ? '🔴' : complexity == 'moderate' ? '🟡' : '🟢';
      buf.writeln('$icon Complexity: ${complexity[0].toUpperCase()}${complexity.substring(1)}');
    }

    final tags = data['tags'];
    if (tags is List && tags.isNotEmpty) {
      buf.writeln('\n🔖 Tags:');
      buf.writeln(tags.map((t) => '#$t').join('  '));
    }

    return buf.toString().trim();
  }

  Future<String> extractDeadlines(String docId) async {
    final response = await DioClient.post('/documents/$docId/deadlines');
    final data = response['data'];
    if (data is! Map) return data.toString();

    final deadlines = data['deadlines'];
    if (deadlines is! List || deadlines.isEmpty) {
      return '📅 No time-bound obligations or deadlines found in this document.';
    }

    final high = <dynamic>[];
    final medium = <dynamic>[];
    final low = <dynamic>[];
    for (final d in deadlines) {
      if (d is! Map) continue;
      final p = (d['priority'] ?? '').toString().toLowerCase();
      if (p == 'high') { high.add(d); }
      else if (p == 'medium') { medium.add(d); }
      else { low.add(d); }
    }

    final buf = StringBuffer();
    buf.writeln('📅 DEADLINES & TIME LIMITS (${deadlines.length} found)\n');

    void writeGroup(String header, String icon, List<dynamic> items) {
      if (items.isEmpty) return;
      buf.writeln('$icon $header');
      for (final d in items) {
        buf.writeln('  ⏰ ${d['title'] ?? 'Deadline'}');
        buf.writeln('     Date: ${d['date'] ?? 'See document'}');
        if (d['party'] != null && (d['party'] as String).isNotEmpty) {
          buf.writeln('     Party: ${d['party']}');
        }
        buf.writeln('     Action: ${d['obligation'] ?? ''}');
        buf.writeln();
      }
    }

    writeGroup('HIGH PRIORITY', '🔴', high);
    writeGroup('MEDIUM PRIORITY', '🟡', medium);
    writeGroup('LOW PRIORITY', '🟢', low);

    return buf.toString().trim();
  }

  Future<String> scanRisks(String docId) async {
    final response = await DioClient.post('/documents/$docId/risks');
    final data = response['data'];
    if (data is! Map) return data.toString();

    final overall = (data['overall_risk'] ?? 'unknown').toString().toUpperCase();
    final clauses = data['clauses'];
    if (clauses is! List || clauses.isEmpty) {
      return '✅ Overall Risk: $overall\n\nNo significant risk clauses found.';
    }

    final buf = StringBuffer();
    buf.writeln('⚠️ Overall Risk: $overall\n');

    for (final c in clauses) {
      if (c is! Map) continue;
      final level = (c['risk_level'] ?? '').toString().toUpperCase();
      final icon = level == 'HIGH' ? '🔴' : level == 'MEDIUM' ? '🟡' : '🟢';
      buf.writeln('$icon ${c['title'] ?? 'Clause'} [$level]');
      if (c['clause_text'] != null && (c['clause_text'] as String).isNotEmpty) {
        buf.writeln('  "${c['clause_text']}"');
      }
      buf.writeln('  ⚡ ${c['concern'] ?? ''}');
      buf.writeln('  💡 ${c['recommendation'] ?? ''}');
      buf.writeln();
    }

    return buf.toString().trim();
  }

  Future<String> extractCitations(String docId) async {
    final response = await DioClient.post('/documents/$docId/citations');
    final data = response['data'];
    if (data is! Map) return data.toString();

    final buf = StringBuffer();

    void writeSection(String header, String icon, dynamic list) {
      if (list is List && list.isNotEmpty) {
        buf.writeln('$icon $header (${list.length})');
        for (final item in list) { buf.writeln('  • $item'); }
        buf.writeln();
      }
    }

    writeSection('CASES', '⚖️', data['cases']);
    writeSection('STATUTORY SECTIONS', '§', data['sections']);
    writeSection('ACTS & STATUTES', '📜', data['acts']);
    writeSection('CONSTITUTIONAL ARTICLES', '🏛️', data['articles']);
    writeSection('RULES & ORDERS', '📋', data['rules']);

    final result = buf.toString().trim();
    return result.isEmpty ? 'No legal citations found in this document.' : result;
  }
}

final aiProvider = StateNotifierProvider<AINotifier, AIState>(
  (ref) => AINotifier(),
);

// ─── Chat (Q&A, with real persisted history) ──────────────────────────────────
//
// Backend persists every conversation as a chat_session + its chat_messages
// (see internal/chat). Starting a session (first message) returns a
// session_id; every later message in the same conversation goes to
// /chat/:session_id/message. History is fetched from the backend, not kept
// only in memory, so a session survives navigating away and reopening the
// app — the whole point of "continue chat from where they left off".

class ChatMessage {
  final String id;
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  bool get isUser => role == 'user';

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: (json['id'] ?? '').toString(),
        role: (json['role'] ?? 'assistant').toString(),
        content: (json['content'] ?? '').toString(),
        createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
            DateTime.now(),
      );
}

/// One row in the History panel — a past conversation about this document.
class ChatSessionSummary {
  final String id;
  final String documentId;
  final String title;
  final String lastMessage;
  final int messageCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatSessionSummary({
    required this.id,
    required this.documentId,
    required this.title,
    required this.lastMessage,
    required this.messageCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatSessionSummary.fromJson(Map<String, dynamic> json) =>
      ChatSessionSummary(
        id: (json['id'] ?? '').toString(),
        documentId: (json['document_id'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        lastMessage: (json['last_message'] ?? '').toString(),
        messageCount: (json['message_count'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
            DateTime.now(),
        updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()) ??
            DateTime.now(),
      );
}

/// Lists this document's past chat sessions, newest-continued first —
/// backs the History panel. `.family` keyed by documentId; invalidate after
/// sending a message / deleting a session so the list stays current.
final chatSessionsProvider =
    FutureProvider.family<List<ChatSessionSummary>, String>((ref, documentId) async {
  try {
    final res = await DioClient.get('/documents/$documentId/chat/sessions');
    final list = res['data'] as List? ?? [];
    return list
        .map((e) => ChatSessionSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
});

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isLoadingHistory;
  final String? error;
  final String? sessionId; // null until the first message starts a session

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isLoadingHistory = false,
    this.error,
    this.sessionId,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isLoadingHistory,
    String? error,
    String? sessionId,
    bool clearSessionId = false,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
        error: error,
        sessionId: clearSessionId ? null : (sessionId ?? this.sessionId),
      );
}

class ChatNotifier extends StateNotifier<ChatState> {
  final String documentId;
  final Ref ref;
  ChatNotifier(this.documentId, this.ref) : super(const ChatState());

  /// Called once when the chat screen opens. With no [sessionId], this is a
  /// blank "New Chat" — the first message you send creates the session.
  /// With a [sessionId] (resuming from History), loads that session's full
  /// message log from the backend so the conversation continues exactly
  /// where it left off.
  Future<void> startSession({String? sessionId}) async {
    if (sessionId == null) {
      state = const ChatState();
      return;
    }
    state = state.copyWith(isLoadingHistory: true, error: null);
    try {
      final res = await DioClient.get('/chat/$sessionId/history');
      final list = res['data'] as List? ?? [];
      final messages = list
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      state = ChatState(messages: messages, sessionId: sessionId);
    } catch (e) {
      state = state.copyWith(
        isLoadingHistory: false,
        error: 'Could not load that conversation: $e',
      );
    }
  }

  /// Clears the current conversation on-screen so the next message starts a
  /// brand-new session, without losing the old one (it stays in History).
  void startNewChat() {
    state = const ChatState();
  }

  Future<void> sendMessage(String message) async {
    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      content: message,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      error: null,
    );

    try {
      final Map<String, dynamic> data;
      if (state.sessionId == null) {
        final response = await DioClient.post(
          '/documents/$documentId/chat',
          data: {'message': message},
        );
        data = response['data'] as Map<String, dynamic>;
      } else {
        final response = await DioClient.post(
          '/chat/${state.sessionId}/message',
          data: {'message': message},
        );
        data = response['data'] as Map<String, dynamic>;
      }

      final answer = (data['answer'] ?? '').toString();
      final newSessionId = (data['session_id'] as String?) ?? state.sessionId;

      final assistantMsg = ChatMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}_ai',
        role: 'assistant',
        content: answer,
        createdAt: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, assistantMsg],
        isLoading: false,
        sessionId: newSessionId,
      );

      // Refresh the History list so this session (new, or just-updated)
      // shows up with its latest message right away.
      ref.invalidate(chatSessionsProvider(documentId));
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendlyError(e.toString()));
    }
  }

  Future<void> deleteSession(String sessionId) async {
    try {
      await DioClient.delete('/chat/$sessionId');
      ref.invalidate(chatSessionsProvider(documentId));
      if (state.sessionId == sessionId) {
        state = const ChatState();
      }
    } catch (_) {}
  }

  String _friendlyError(String raw) {
    if (raw.contains('Daily AI token limit') || raw.contains('tokens per day') || raw.contains('TPD')) {
      final match = RegExp(r'try again in ([^.]+)').firstMatch(raw);
      final wait = match?.group(1);
      return 'Daily AI limit reached.${wait != null ? ' Try again in $wait.' : ' Please try again later.'}';
    }
    if (raw.contains('Rate limit') || raw.contains('rate limit') || raw.contains('TPM')) {
      return 'AI is busy right now. Please wait a moment and try again.';
    }
    return raw;
  }
}

final chatProvider =
    StateNotifierProvider.family<ChatNotifier, ChatState, String>(
  (ref, documentId) => ChatNotifier(documentId, ref),
);