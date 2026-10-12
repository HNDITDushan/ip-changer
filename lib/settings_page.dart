import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'data_toggler.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  AppSettings get _settings => widget.settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isAndroid) ...[
            Text(
              'Keep mobile data off for ${_settings.waitSeconds} seconds',
              style: theme.textTheme.titleMedium,
            ),
            Slider(
              value: _settings.waitSeconds.toDouble(),
              min: 2,
              max: 60,
              divisions: 58,
              label: '${_settings.waitSeconds}s',
              onChanged: (v) =>
                  setState(() => _settings.waitSeconds = v.round()),
            ),
            const Text('If the IP stays the same, try a longer wait.'),
            const SizedBox(height: 24),
            Text(
              'Screen used to switch data',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            DropdownMenu<String>(
              initialSelection: _settings.androidScreen,
              expandedInsets: EdgeInsets.zero,
              onSelected: (v) {
                if (v != null) setState(() => _settings.androidScreen = v);
              },
              dropdownMenuEntries: const [
                DropdownMenuEntry(
                  value: 'panel',
                  label: 'Internet panel (default)',
                ),
                DropdownMenuEntry(
                  value: 'data_usage',
                  label: 'Data usage settings',
                ),
                DropdownMenuEntry(
                  value: 'mobile_network',
                  label: 'Mobile network settings',
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'If the app cannot find the mobile data switch on your phone, '
              'try another screen.',
            ),
            const SizedBox(height: 24),
            TextFormField(
              initialValue: _settings.customLabel,
              decoration: const InputDecoration(
                labelText: 'Mobile data switch label (optional)',
                helperText:
                    'Only needed if your phone is not in English. Type the '
                    'label exactly as your phone shows it.',
                helperMaxLines: 3,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _settings.customLabel = v,
            ),
          ],
          if (isIos) ...[
            TextFormField(
              initialValue: _settings.shortcutName,
              decoration: const InputDecoration(
                labelText: 'Shortcut name',
                helperText: 'Must match the shortcut in the Shortcuts app.',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _settings.shortcutName = v.trim(),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      IosSetupPage(shortcutName: _settings.shortcutName),
                ),
              ),
              child: const Text('How to set up the shortcut'),
            ),
          ],
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () {
              _settings.clearHistory();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('History cleared')));
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Clear history'),
          ),
        ],
      ),
    );
  }
}

/// iOS cannot switch mobile data from an app, so the user builds this shortcut once.
class IosSetupPage extends StatelessWidget {
  const IosSetupPage({super.key, required this.shortcutName});

  final String shortcutName;

  @override
  Widget build(BuildContext context) {
    final steps = [
      'Open the Shortcuts app and tap + to create a new shortcut.',
      'Add the action "Set Mobile Data" (called "Set Cellular Data" in some '
          'regions) and set it to Off.',
      'Add the action "Wait" and set it to 5 seconds.',
      'Add "Set Mobile Data" again and set it to On.',
      'Rename the shortcut to exactly "$shortcutName" and tap Done.',
      'Come back here and tap Change IP. The first time, allow the shortcut '
          'to run.',
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('iPhone setup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Apple does not let apps switch mobile data, but the Shortcuts app '
            'can. Create this shortcut once and IP Changer will run it for you.',
          ),
          const SizedBox(height: 16),
          for (final (i, step) in steps.indexed)
            ListTile(
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text(step),
            ),
          const SizedBox(height: 16),
          const Text(
            'If the IP stays the same, increase the Wait time, or use '
            '"Set Airplane Mode" On/Off instead of Mobile Data.',
          ),
        ],
      ),
    );
  }
}
