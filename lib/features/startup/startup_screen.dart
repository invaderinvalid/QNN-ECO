import 'package:flutter/material.dart';

import '../../core/models/model_spec.dart';
import '../../core/services/geniex_bridge.dart';
import '../model_setup/model_setup_screen.dart';
import '../voice_chat/voice_chat_screen.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  final _bridge = GenieXBridge();

  @override
  void initState() {
    super.initState();
    _routeFromModelState();
  }

  Future<void> _routeFromModelState() async {
    ModelSpec? brain;
    try {
      for (final candidate in ModelCatalog.brainModels) {
        final isDownloaded = await _bridge
            .isModelDownloaded(candidate)
            .timeout(const Duration(seconds: 2), onTimeout: () => false);
        if (isDownloaded) {
          brain = candidate;
          break;
        }
      }
    } catch (_) {
      // The setup screen surfaces bridge errors and offers a retry path.
    }
    if (!mounted) return;
    final destination = brain != null
        ? VoiceChatScreen(bridge: _bridge, model: brain)
        : ModelSetupScreen(
            bridge: _bridge,
            onBrainReady: () => _openVoiceChat(),
          );
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute<void>(builder: (_) => destination));
  }

  void _openVoiceChat() {
    // ModelSetupScreen only enables its chat action after confirming the brain
    // model. Do not repeat a GenieX cache lookup here: it can be held by an
    // unrelated pull and would route back to the same setup screen.
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            VoiceChatScreen(bridge: _bridge, model: ModelCatalog.gemma4E2b),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
