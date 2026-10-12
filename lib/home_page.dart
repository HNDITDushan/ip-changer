import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'data_toggler.dart';
import 'ip_service.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  String? _currentIp;
  bool _loadingIp = true;
  bool _onWifi = false;
  bool _serviceEnabled = true;
  bool _busy = false;
  String _status = '';
  String? _error;
  IpChange? _lastChange;
  late List<IpChange> _history = widget.settings.history;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Completer<void>? _returnedFromShortcut;
  bool _leftApp = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      _onConnectivity,
    );
    Connectivity().checkConnectivity().then(_onConnectivity);
    _refreshService();
    _refreshIp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _leftApp = true;
      return;
    }
    _refreshService();
    final returned = _returnedFromShortcut;
    if (returned != null && _leftApp && !returned.isCompleted) {
      returned.complete();
    }
    if (!_busy) _refreshIp();
  }

  void _onConnectivity(List<ConnectivityResult> results) {
    if (!mounted) return;
    setState(() => _onWifi = results.contains(ConnectivityResult.wifi));
    if (!_busy) _refreshIp();
  }

  Future<void> _refreshService() async {
    if (!isAndroid) return;
    final enabled = await isAndroidServiceEnabled();
    if (mounted) setState(() => _serviceEnabled = enabled);
  }

  Future<void> _refreshIp() async {
    setState(() => _loadingIp = true);
    final ip = await fetchPublicIp();
    if (!mounted) return;
    setState(() {
      _currentIp = ip;
      _loadingIp = false;
    });
  }

  Future<void> _changeIp() async {
    setState(() {
      _busy = true;
      _error = null;
      _lastChange = null;
      _status = 'Checking current IP...';
    });
    final previous = await fetchPublicIp();
    if (!mounted) return;
    setState(() {
      _currentIp = previous;
      _status = isAndroid
          ? 'Switching mobile data off and on...'
          : 'Running the shortcut...';
    });

    try {
      if (isAndroid) {
        await cycleMobileDataAndroid(widget.settings);
      } else {
        await _runShortcutAndWait();
      }
    } on ToggleException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
      _refreshIp();
      return;
    }

    if (!mounted) return;
    setState(() => _status = 'Waiting for the connection to come back...');
    final newIp = await waitForPublicIp();
    if (!mounted) return;

    final change = IpChange(
      time: DateTime.now(),
      previousIp: previous,
      newIp: newIp,
    );
    widget.settings.addHistory(change);
    setState(() {
      _busy = false;
      _currentIp = newIp;
      _loadingIp = false;
      _lastChange = change;
      _history = [change, ..._history];
    });
  }

  Future<void> _runShortcutAndWait() async {
    _leftApp = false;
    final returned = _returnedFromShortcut = Completer<void>();
    await runIosShortcut(widget.settings.shortcutName);
    await returned.future.timeout(
      const Duration(minutes: 3),
      onTimeout: () =>
          throw ToggleException('The shortcut did not return to the app.'),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(settings: widget.settings),
      ),
    );
    if (mounted) setState(() => _history = widget.settings.history);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final change = _lastChange;
    final canChange = !_busy && (!isAndroid || _serviceEnabled);

    return Scaffold(
      appBar: AppBar(
        title: const Text('IP Changer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: _busy ? null : _openSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isAndroid && !_serviceEnabled)
            _Notice(
              icon: Icons.accessibility_new,
              text:
                  'Turn on the IP Changer accessibility service so the app '
                  'can switch mobile data for you.',
              actionLabel: 'Open settings',
              onAction: openAccessibilitySettings,
            ),
          if (isIos)
            _Notice(
              icon: Icons.info_outline,
              text:
                  'iPhone needs a one-time shortcut named '
                  '"${widget.settings.shortcutName}".',
              actionLabel: 'How to set up',
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      IosSetupPage(shortcutName: widget.settings.shortcutName),
                ),
              ),
            ),
          if (_onWifi)
            const _Notice(
              icon: Icons.wifi,
              text:
                  'Wi-Fi is on, so this is your Wi-Fi IP. Turn Wi-Fi off to '
                  'see and change your mobile data IP.',
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text('Current IP', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  if (_loadingIp && !_busy)
                    const SizedBox(
                      height: 40,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    SelectableText(
                      _currentIp ?? 'No connection',
                      style: theme.textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                  TextButton.icon(
                    onPressed: _busy ? null : _refreshIp,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: canChange ? _changeIp : null,
            icon: const Icon(Icons.swap_horiz),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Change IP'),
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(_status, textAlign: TextAlign.center),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
          if (change != null) ...[
            const SizedBox(height: 16),
            _ResultCard(change: change),
          ],
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('History', style: theme.textTheme.titleMedium),
            for (final entry in _history)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  entry.changed ? Icons.check_circle : Icons.remove_circle,
                  color: entry.changed ? Colors.green : Colors.orange,
                ),
                title: Text(
                  '${entry.previousIp ?? 'unknown'}  ->  '
                  '${entry.newIp ?? 'no connection'}',
                ),
                subtitle: Text(_formatTime(entry.time)),
              ),
          ],
        ],
      ),
    );
  }
}

String _formatTime(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.change});

  final IpChange change;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String verdict;
    if (change.newIp == null) {
      verdict = 'The connection did not come back. Check mobile data.';
    } else if (change.changed) {
      verdict = 'IP changed';
    } else {
      verdict = 'Same IP. Try again, or use a longer wait.';
    }
    return Card(
      color: change.changed
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(verdict, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _IpRow(label: 'Previous IP', ip: change.previousIp ?? 'unknown'),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Icon(Icons.arrow_downward),
            ),
            _IpRow(label: 'New IP', ip: change.newIp ?? 'no connection'),
          ],
        ),
      ),
    );
  }
}

class _IpRow extends StatelessWidget {
  const _IpRow({required this.label, required this.ip});

  final String label;
  final String ip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        SelectableText(ip, style: theme.textTheme.titleLarge),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: ListTile(
        leading: Icon(icon),
        title: Text(text),
        trailing: actionLabel == null
            ? null
            : TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ),
    );
  }
}
