import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/notifications/notification_service.dart';
import 'settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final settings = ref.watch(settingsControllerProvider);
    final notifier = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(loc.tr('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(loc.tr('language')),
                  trailing: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'en', label: Text('English')),
                      ButtonSegment(value: 'ar', label: Text('العربية')),
                    ],
                    selected: {settings.locale.languageCode},
                    onSelectionChanged: (s) => notifier.setLanguage(s.first),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: Text(loc.tr('dark_mode')),
                  value: settings.themeMode == ThemeMode.dark,
                  onChanged: (v) => notifier.toggleDarkMode(v),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${loc.tr('quran_font_size')}: ${settings.quranFontSize.toInt()} pt',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Slider(
                        value: settings.quranFontSize,
                        min: 18.0,
                        max: 40.0,
                        divisions: 11,
                        label: '${settings.quranFontSize.toInt()}',
                        onChanged: (v) => notifier.setQuranFontSize(v),
                      ),
                      Text(
                        'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(fontSize: settings.quranFontSize),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_outlined),
                  title: Text(loc.tr('adhan_notifications')),
                  subtitle: const Text(
                    'Android 13+ notification & exact alarm permissions',
                  ),
                  value: settings.adhanNotificationsEnabled,
                  onChanged: (v) async {
                    if (v) {
                      await NotificationService.instance
                          .requestAndroidPermissions();
                    } else {
                      await NotificationService.instance.cancelAll();
                    }
                    await notifier.setAdhanNotifications(v);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: Text(loc.tr('backup_bookmarks')),
                  subtitle: const Text('Export or restore Quran bookmarks JSON'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.ios_share),
                        tooltip: 'Export Backup',
                        onPressed: () async {
                          final jsonStr = await notifier.exportBookmarksJson();
                          await Clipboard.setData(ClipboardData(text: jsonStr));
                          await Share.share(jsonStr,
                              subject: 'Noor Quran Bookmarks Backup');
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.restore),
                        tooltip: 'Restore from Clipboard JSON',
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data?.text != null && data!.text!.isNotEmpty) {
                            try {
                              final count = await notifier
                                  .importBookmarksJson(data.text!);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text('Restored $count bookmarks!'),
                                  ),
                                );
                              }
                            } catch (_) {}
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
