import 'package:flutter/material.dart';

import '../../core/services/uno_q_credentials_service.dart';
import '../../core/services/uno_q_motor_service.dart';

class UnoQLampScreen extends StatefulWidget {
  const UnoQLampScreen({super.key});

  @override
  State<UnoQLampScreen> createState() => _UnoQLampScreenState();
}

class _UnoQLampScreenState extends State<UnoQLampScreen> {
  final _credentials = UnoQCredentialsService();
  final _motors = UnoQMotorService();
  final _urlController = TextEditingController();
  bool _working = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _motors.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final configuration = await _credentials.readConfiguration();
    if (!mounted) return;
    setState(() {
      _urlController.text = configuration.baseUrl.toString();
    });
  }

  Future<void> _save() async {
    await _run(() async {
      await _credentials.save(baseUrl: _urlController.text);
      _status = 'UNO Q connection saved.';
    });
  }

  Future<void> _health() => _run(() async {
    await _motors.checkHealth();
    _status = 'UNO Q is online.';
  });

  Future<void> _send(UnoQMotorAction action) => _run(() async {
    await _motors.send(action);
    _status = '${action.name.toUpperCase()} sent to the lamp.';
  });

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _working = true;
      _status = null;
    });
    try {
      await action();
      if (mounted) setState(() {});
    } on Object catch (error) {
      if (mounted) setState(() => _status = '$error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('UNO Q lamp')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'QNN-ECO sends only yes, no, or idle actions over your local Wi-Fi.',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _urlController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'UNO Q bridge URL',
              hintText: 'http://10.48.125.131:5000',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _working ? null : _save,
                  child: const Text('Save connection'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _working ? null : _health,
                child: const Text('Check'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'Manual motion test',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: _working ? null : () => _send(UnoQMotorAction.yes),
                  child: const Text('YES'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: _working ? null : () => _send(UnoQMotorAction.no),
                  child: const Text('NO'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _working
                      ? null
                      : () => _send(UnoQMotorAction.idle),
                  child: const Text('IDLE'),
                ),
              ),
            ],
          ),
          if (_status != null) ...[
            const SizedBox(height: 18),
            Text(_status!, style: TextStyle(color: colors.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}
