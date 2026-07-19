import 'package:flutter/material.dart';

import '../../core/services/geniex_bridge.dart';

class NotificationTriageScreen extends StatefulWidget {
  const NotificationTriageScreen({super.key, required this.bridge});

  final GenieXBridge bridge;

  @override
  State<NotificationTriageScreen> createState() =>
      _NotificationTriageScreenState();
}

class _NotificationTriageScreenState extends State<NotificationTriageScreen>
    with WidgetsBindingObserver {
  NotificationTriageStatus? _status;
  String? _error;
  bool _openingSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final status = await widget.bridge.getNotificationTriageStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  Future<void> _openSettings() async {
    setState(() => _openingSettings = true);
    try {
      await widget.bridge.openNotificationListenerSettings();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _openingSettings = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = _status?.listenerEnabled == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Notification triage')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Icon(
            enabled
                ? Icons.notifications_active
                : Icons.notifications_off_outlined,
            color: enabled ? colors.primary : colors.onSurfaceVariant,
            size: 38,
          ),
          const SizedBox(height: 12),
          Text(
            'Always-on local notification triage',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'When enabled, QNN-ECO reads new notification text locally with the installed brain model. Promotional messages are ignored. Other messages are classified, announced aloud, and sent as an IR alert.',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          _StatusTile(
            icon: enabled ? Icons.check_circle_outline : Icons.lock_outline,
            title: 'Notification access',
            detail: enabled
                ? 'Enabled — new notifications can be triaged.'
                : 'Required. Android will ask you to grant this in system settings.',
            active: enabled,
          ),
          const SizedBox(height: 10),
          _StatusTile(
            icon: Icons.settings_remote_outlined,
            title: 'IR transmitter',
            detail: _status == null
                ? 'Checking hardware…'
                : _status!.irAvailable
                ? 'Available — NEC commands will be blasted.'
                : 'Unavailable — spoken triage still works, but no IR command is sent.',
            active: _status?.irAvailable == true,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _openingSettings ? null : _openSettings,
            icon: const Icon(Icons.open_in_new),
            label: Text(
              enabled
                  ? 'Review notification access'
                  : 'Enable notification access',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: colors.error)),
          ],
          const SizedBox(height: 28),
          Text('Alert mapping', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          const _AlertMapping(
            label: 'Crisis',
            color: Color(0xFFF720DF),
            action: 'Red + flash',
          ),
          const _AlertMapping(
            label: 'Distressed',
            color: Color(0xFFF728D7),
            action: 'Yellow',
          ),
          const _AlertMapping(
            label: 'Mild negative',
            color: Color(0xFFF750AF),
            action: 'Soft blue',
          ),
          const _AlertMapping(
            label: 'Neutral',
            color: Color(0xFFF7E01F),
            action: 'White',
          ),
          const _AlertMapping(
            label: 'Positive',
            color: Color(0xFFF7A05F),
            action: 'Green',
          ),
        ],
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.icon,
    required this.title,
    required this.detail,
    required this.active,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(
          icon,
          color: active ? colors.primary : colors.onSurfaceVariant,
        ),
        title: Text(title),
        subtitle: Text(detail),
      ),
    );
  }
}

class _AlertMapping extends StatelessWidget {
  const _AlertMapping({
    required this.label,
    required this.color,
    required this.action,
  });

  final String label;
  final Color color;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(
            action,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
