import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/models/chat_entry.dart';
import '../core/models/model_spec.dart';
import '../core/services/geniex_bridge.dart';
import 'temporary_conversation_memory_store.dart';
import 'uno_q_gesture_service.dart';

enum _GenerationTarget { reply, consolidation }

/// Holds the persistent local chat thread and streams a GenieX reply into it.
class BrainService {
  BrainService({
    required GenieXBridge bridge,
    required this.model,
    TemporaryConversationMemoryStore? memoryStore,
    UnoQGestureService? gestureService,
  }) : _bridge = bridge,
       _memoryStore = memoryStore ?? TemporaryConversationMemoryStore(),
       _gestureService = gestureService ?? UnoQGestureService() {
    _chatSubscription = GenieXBridge.chat.receiveBroadcastStream().listen(
      _onChatEvent,
      onError: (Object error) => _finishWithError('$error'),
    );
  }

  final GenieXBridge _bridge;
  final ModelSpec model;
  final TemporaryConversationMemoryStore _memoryStore;
  final UnoQGestureService _gestureService;
  final ChatThread thread = ChatThread();
  late final StreamSubscription<dynamic> _chatSubscription;
  Completer<String>? _replyCompleter;
  _GenerationTarget? _generationTarget;
  StringBuffer? _consolidationBuffer;
  String _memoryContext = '';
  bool _disposed = false;

  bool get isThinking => _replyCompleter != null;

  Future<void> initialize() async {
    _memoryContext = await _memoryStore.load() ?? '';
  }

  Future<String> ask(String text) async {
    if (_replyCompleter != null) {
      throw StateError('The brain is already generating a reply.');
    }

    thread.addUser(text);
    try {
      final isNotificationRequest = _requestsNotificationStatus(text);
      var reply = isNotificationRequest
          ? await _answerNotificationRequest()
          : await _generateReply();
      if (!isNotificationRequest && _isToolRequest(reply)) {
        thread.removeLastAssistant();
        reply = await _answerNotificationRequest();
      }
      // The command is restricted to an unambiguous leading yes/no and is sent
      // independently, so a slow lamp cannot delay a spoken/local response.
      unawaited(_gestureService.mirrorAnswer(reply));
      await _consolidateThreadIfNeeded();
      return reply;
    } on Object catch (error) {
      if (_replyCompleter != null) _finishWithError('$error');
      rethrow;
    }
  }

  /// The bridge emulates a tool call because the installed local runtime does
  /// not expose structured function calls to Dart. Every notification request
  /// follows the same availability → read → summarize path.
  Future<String> _answerNotificationRequest() async {
    try {
      final capability = await _bridge.getNotificationTriageStatus();
      if (!capability.listenerEnabled) return _toolUnavailableReply();

      final result = await _bridge.getRecentNotificationStatus();
      try {
        final reply = await _generateReply(notificationStatus: result);
        if (!_isToolRequest(reply)) return reply;
        thread.removeLastAssistant();
        return _recordAssistant(_toolResultReply(result));
      } on Object {
        thread.removeLastResponse();
        return _recordAssistant(_toolResultReply(result));
      }
    } on Object {
      return _toolUnavailableReply();
    }
  }

  String _toolUnavailableReply() => _recordAssistant(
    "I can't access the notification tool yet. Enable notification access in QNN-ECO, then try again.",
  );

  String _toolResultReply(String result) =>
      'Here is what the notification tool returned: $result';

  String _recordAssistant(String text) {
    thread.addAssistant(text);
    return text;
  }

  Future<String> _generateReply({String? notificationStatus}) async {
    thread.addAssistantDraft();
    return _runGeneration(
      _prompt(notificationStatus: notificationStatus),
      _GenerationTarget.reply,
    );
  }

  Future<void> _consolidateThreadIfNeeded() async {
    if (thread.entries.length < 20) return;
    final transcript = thread.entries
        .map((entry) => '${entry.role}: ${entry.content}')
        .join('\n');
    try {
      final summary = await _runGeneration(<ChatEntry>[
        const ChatEntry(
          role: 'system',
          content:
              'Consolidate this completed conversation into compact memory for a new thread. Keep enduring preferences, names, commitments, decisions, important context, and unresolved questions. Do not invent facts. Return only the memory, under 550 characters.',
        ),
        ChatEntry(role: 'user', content: transcript),
      ], _GenerationTarget.consolidation);
      _memoryContext = summary.trim().isEmpty
          ? _compactFallbackMemory()
          : summary.trim();
    } on Object catch (_) {
      _memoryContext = _compactFallbackMemory();
    }
    await _memoryStore.save(_memoryContext);
    thread.startNewThread();
  }

  Future<String> _runGeneration(
    List<ChatEntry> prompt,
    _GenerationTarget target,
  ) async {
    if (_replyCompleter != null) {
      throw StateError('The brain is already generating a reply.');
    }
    _generationTarget = target;
    _consolidationBuffer = target == _GenerationTarget.consolidation
        ? StringBuffer()
        : null;
    final completer = Completer<String>();
    _replyCompleter = completer;
    try {
      await _bridge.generateReply(model.name, prompt);
      return await completer.future;
    } on Object {
      rethrow;
    }
  }

  List<ChatEntry> _prompt({String? notificationStatus}) => <ChatEntry>[
    ChatEntry(role: 'system', content: _systemPrompt()),
    if (_memoryContext.isNotEmpty)
      ChatEntry(
        role: 'system',
        content:
            'Private rolling memory from an earlier thread. Use it only as context: $_memoryContext',
      ),
    if (notificationStatus != null)
      ChatEntry(
        role: 'system',
        content:
            'Trusted local tool result for notification_status. Use it to answer the user directly; do not claim to have seen anything else:\n$notificationStatus',
      ),
    ...thread.entries,
  ];

  String _systemPrompt() {
    final now = DateTime.now();
    const weekdays = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final date =
        '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
    return '''
You are QNN-ECO: a gentle, thoughtful companion. Be warm, practical, and concise. A little kind humour is welcome when it fits, never at someone’s expense or during distress. Speak sparingly and thoughtfully; each word carries weight. Do not use Markdown or emoji. Today is $date. The local timestamp is ${now.toIso8601String()} (${now.timeZoneName}).
You are an on-device assistant. Do not claim access to notifications, files, the internet, or device controls unless a trusted local tool result is provided in this conversation.
The available tool is notification_status. For every request about notifications, notification status, recent notifications, or a notification summary: if a Trusted local tool result for notification_status is present, respond by summarizing only that result. If no result is present, return exactly [[tool:notification_status]] and nothing else. Never request the tool again after a trusted result is present.
''';
  }

  bool _isToolRequest(String reply) =>
      reply.trim().toLowerCase() == '[[tool:notification_status]]';

  bool _requestsNotificationStatus(String text) => RegExp(
    r'\b(notifications?|notifs?|alerts?)\b',
    caseSensitive: false,
  ).hasMatch(text);

  String _compactFallbackMemory() {
    final recent = thread.entries
        .skip(thread.entries.length > 8 ? thread.entries.length - 8 : 0)
        .map((entry) => '${entry.role}: ${entry.content}')
        .join('\n');
    return recent.length <= 550 ? recent : recent.substring(0, 550);
  }

  Future<void> stop() async {
    if (_replyCompleter == null) return;
    await _bridge.stopGeneration();
    if (!_replyCompleter!.isCompleted) {
      _replyCompleter!.complete(
        _generationTarget == _GenerationTarget.reply
            ? thread.lastAssistantText
            : _consolidationBuffer.toString(),
      );
    }
    _replyCompleter = null;
    _generationTarget = null;
    _consolidationBuffer = null;
  }

  void _onChatEvent(dynamic value) {
    if (_disposed || value is! Map || value['modelName'] != model.name) return;
    final type = value['type'] as String?;
    final text = value['text'] as String? ?? '';
    switch (type) {
      case 'token':
        if (_generationTarget == _GenerationTarget.reply) {
          thread.appendAssistant(text);
        } else {
          _consolidationBuffer?.write(text);
        }
        break;
      case 'completed':
        final reply = _generationTarget == _GenerationTarget.reply
            ? thread.lastAssistantText
            : _consolidationBuffer.toString();
        _replyCompleter?.complete(reply);
        _replyCompleter = null;
        _generationTarget = null;
        _consolidationBuffer = null;
        break;
      case 'error':
        _finishWithError(
          text.isEmpty ? 'The local model could not reply.' : text,
        );
        break;
      default:
        break;
    }
  }

  void _finishWithError(String error) {
    if (_generationTarget == _GenerationTarget.reply) {
      thread.replaceAssistantWithError(error);
    }
    _replyCompleter?.completeError(StateError(error));
    _replyCompleter = null;
    _generationTarget = null;
    _consolidationBuffer = null;
  }

  Future<void> dispose() async {
    _disposed = true;
    await stop();
    await _chatSubscription.cancel();
    thread.dispose();
  }
}

class ChatThread extends ChangeNotifier {
  final List<ChatEntry> _entries = <ChatEntry>[];

  List<ChatEntry> get entries => List<ChatEntry>.unmodifiable(_entries);
  String get lastAssistantText {
    for (final entry in _entries.reversed) {
      if (entry.role == 'assistant') return entry.content;
    }
    return '';
  }

  void addUser(String text) {
    _entries.add(ChatEntry(role: 'user', content: text));
    notifyListeners();
  }

  void addAssistantDraft() {
    _entries.add(const ChatEntry(role: 'assistant', content: ''));
    notifyListeners();
  }

  void appendAssistant(String text) {
    if (_entries.isEmpty || _entries.last.role != 'assistant') return;
    final previous = _entries.removeLast();
    _entries.add(previous.copyWith(content: previous.content + text));
    notifyListeners();
  }

  void replaceAssistantWithError(String error) {
    if (_entries.isNotEmpty && _entries.last.role == 'assistant') {
      _entries.removeLast();
    }
    _entries.add(ChatEntry(role: 'error', content: error));
    notifyListeners();
  }

  void removeLastAssistant() {
    if (_entries.isNotEmpty && _entries.last.role == 'assistant') {
      _entries.removeLast();
      notifyListeners();
    }
  }

  void removeLastResponse() {
    if (_entries.isNotEmpty &&
        (_entries.last.role == 'assistant' || _entries.last.role == 'error')) {
      _entries.removeLast();
      notifyListeners();
    }
  }

  void addAssistant(String text) {
    _entries.add(ChatEntry(role: 'assistant', content: text));
    notifyListeners();
  }

  void startNewThread() {
    _entries.clear();
    notifyListeners();
  }
}
