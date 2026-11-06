import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/localization/app_localizations.dart';
import 'core/notifications/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/azkar/presentation/azkar_screen.dart';
import 'features/hadith/presentation/hadith_screen.dart';
import 'features/home/presentation/home_dashboard_screen.dart';
import 'features/prayer/presentation/prayer_screen.dart';
import 'features/quran/presentation/quran_screen.dart';
import 'features/settings/presentation/settings_controller.dart';
import 'features/zakat/presentation/zakat_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();

  runApp(const ProviderScope(child: NoorApp()));
}

class NoorApp extends ConsumerWidget {
  const NoorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);

    return MaterialApp(
      title: 'Noor - نور',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const NoorMainShell(),
    );
  }
}

class NoorMainShell extends StatefulWidget {
  const NoorMainShell({super.key});

  @override
  State<NoorMainShell> createState() => _NoorMainShellState();
}

class _NoorMainShellState extends State<NoorMainShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    final screens = [
      HomeDashboardScreen(
        onNavigateTab: (idx) => setState(() => _currentIndex = idx),
      ),
      const QuranScreen(),
      const PrayerScreen(),
      const AzkarScreen(),
      const HadithScreen(),
      const ZakatScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: loc.tr('home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book),
            label: loc.tr('quran'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.access_time),
            selectedIcon: const Icon(Icons.access_time_filled),
            label: loc.tr('prayer'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.volunteer_activism_outlined),
            selectedIcon: const Icon(Icons.volunteer_activism),
            label: loc.tr('azkar'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.library_books_outlined),
            selectedIcon: const Icon(Icons.library_books),
            label: loc.tr('hadith'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.calculate_outlined),
            selectedIcon: const Icon(Icons.calculate),
            label: loc.tr('zakat'),
          ),
        ],
      ),
    );
  }
}
