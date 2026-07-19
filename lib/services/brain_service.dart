import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/models/chat_entry.dart';
import '../core/models/model_spec.dart';
import '../core/services/geniex_bridge.dart';

/// Holds the persistent local chat thread and streams a GenieX reply into it.
class BrainService {
  BrainService({required GenieXBridge bridge, required this.model})
    : _bridge = bridge {
    _chatSubscription = GenieXBridge.chat.receiveBroadcastStream().listen(
      _onChatEvent,
      onError: (Object error) => _finishWithError('$error'),
    );
  }

  final GenieXBridge _bridge;
  final ModelSpec model;
  final ChatThread thread = ChatThread();
  late final StreamSubscription<dynamic> _chatSubscription;
  Completer<String>? _replyCompleter;
  bool _disposed = false;

  bool get isThinking => _replyCompleter != null;

  Future<String> ask(String text) async {
    if (_replyCompleter != null) {
      throw StateError('The brain is already generating a reply.');
    }

    thread.addUser(text);
    final prompt = List<ChatEntry>.of(thread.entries);
    thread.addAssistantDraft();
    final completer = Completer<String>();
    _replyCompleter = completer;

    try {
      await _bridge.generateReply(model.name, prompt);
      return await completer.future;
    } on Object catch (error) {
      _finishWithError('$error');
      rethrow;
    }
  }

  Future<void> stop() async {
    if (_replyCompleter == null) return;
    await _bridge.stopGeneration();
    if (!_replyCompleter!.isCompleted) {
      _replyCompleter!.complete(thread.lastAssistantText);
    }
    _replyCompleter = null;
  }

  void _onChatEvent(dynamic value) {
    if (_disposed || value is! Map || value['modelName'] != model.name) return;
    final type = value['type'] as String?;
    final text = value['text'] as String? ?? '';
    switch (type) {
      case 'token':
        thread.appendAssistant(text);
        break;
      case 'completed':
        final reply = thread.lastAssistantText;
        _replyCompleter?.complete(reply);
        _replyCompleter = null;
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
    thread.replaceAssistantWithError(error);
    _replyCompleter?.completeError(StateError(error));
    _replyCompleter = null;
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
}
