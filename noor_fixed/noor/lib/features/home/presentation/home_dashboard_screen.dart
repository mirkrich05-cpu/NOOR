import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../prayer/data/prayer_repository.dart';
import '../../prayer/domain/prayer_models.dart';
import '../../settings/presentation/settings_screen.dart';

class HomeDashboardScreen extends ConsumerStatefulWidget {
  final ValueChanged<int> onNavigateTab;
  const HomeDashboardScreen({super.key, required this.onNavigateTab});

  @override
  ConsumerState<HomeDashboardScreen> createState() =>
      _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  Future<DailyPrayerTimes>? _todayPrayerFuture;
  Set<int> _completedKhatmaJuz = {};

  static const List<Map<String, String>> _dailyVerses = [
    {
      'arabic': 'فَاذْكُرُونِي أَذْكُرْكُمْ وَاشْكُرُوا لِي وَلَا تَكْفُرُونِ',
      'translation':
          'So remember Me; I will remember you. And be grateful to Me and do not deny Me.',
      'ref': 'Surah Al-Baqarah 2:152',
    },
    {
      'arabic': 'فَإِنَّ مَعَ الْعُسْرِ يُسْرًا • إِنَّ مَعَ الْعُسْرِ يُسْرًا',
      'translation':
          'For indeed, with hardship [will be] ease. Indeed, with hardship [will be] ease.',
      'ref': 'Surah Ash-Sharh 94:5-6',
    },
    {
      'arabic': 'أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ',
      'translation':
          'Unquestionably, by the remembrance of Allah hearts are assured.',
      'ref': "Surah Ar-Ra'd 13:28",
    },
  ];

  static const List<Map<String, String>> _dailyHadiths = [
    {
      'arabic': 'خَيْرُكُمْ مَنْ تَعَلَّمَ الْقُرْآنَ وَعَلَّمَهُ',
      'translation':
          'The best among you are those who learn the Quran and teach it.',
      'ref': 'Sahih al-Bukhari 5027',
    },
    {
      'arabic': 'الدُّعَاءُ هُوَ الْعِبَادَةُ',
      'translation': 'Supplication (Dua) is the essence of worship.',
      'ref': 'Jami` at-Tirmidhi 2969',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initDashboard();
  }

  Future<void> _initDashboard() async {
    final prayerRepo = ref.read(prayerRepositoryProvider);
    final coords = await prayerRepo.resolveCoordinates();
    final prefs = await SharedPreferences.getInstance();
    final savedKhatma = prefs.getStringList('khatma_completed_juz') ?? [];

    if (mounted) {
      setState(() {
        _completedKhatmaJuz = savedKhatma.map(int.parse).toSet();
        _todayPrayerFuture = prayerRepo.getTodayPrayerTimes(
          latitude: coords.lat,
          longitude: coords.lng,
          locationLabel: coords.label,
        );
      });
    }
  }

  Future<void> _toggleKhatmaJuz(int juz) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_completedKhatmaJuz.contains(juz)) {
        _completedKhatmaJuz.remove(juz);
      } else {
        _completedKhatmaJuz.add(juz);
      }
    });
    await prefs.setStringList(
      'khatma_completed_juz',
      _completedKhatmaJuz.map((e) => e.toString()).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final dayOfYear = int.parse(DateFormat('D').format(DateTime.now()));
    final verse = _dailyVerses[dayOfYear % _dailyVerses.length];
    final hadith = _dailyHadiths[dayOfYear % _dailyHadiths.length];
    final timeFmt = DateFormat('hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mosque, color: AppColors.accentGold),
            const SizedBox(width: 8),
            Text('${loc.tr('app_name')} • نور'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Top Next Prayer & Hijri Banner
          FutureBuilder<DailyPrayerTimes>(
            future: _todayPrayerFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              final times = snapshot.data!;
              final next = times.nextPrayer(DateTime.now());
              return Card(
                color: AppColors.primaryGreen,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            times.hijriFormatted,
                            style: const TextStyle(
                              color: AppColors.accentGold,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            times.locationLabel,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${loc.tr('next_prayer')}: ${next.key} at ${timeFmt.format(next.value)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Suhoor (Fajr): ${timeFmt.format(times.fajr)}  •  Iftar (Maghrib): ${timeFmt.format(times.maghrib)}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // Quick Access Grid
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.25,
            children: [
              _quickCard(Icons.menu_book, loc.tr('quran'), () => widget.onNavigateTab(1)),
              _quickCard(Icons.access_time, loc.tr('prayer'), () => widget.onNavigateTab(2)),
              _quickCard(Icons.volunteer_activism, loc.tr('azkar'), () => widget.onNavigateTab(3)),
              _quickCard(Icons.library_books, loc.tr('hadith'), () => widget.onNavigateTab(4)),
              _quickCard(Icons.calculate, loc.tr('zakat'), () => widget.onNavigateTab(5)),
              _quickCard(Icons.nights_stay, 'Ramadan Hub', _openRamadanPlannerModal),
            ],
          ),
          const SizedBox(height: 12),

          // Verse of the Day Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: AppColors.accentGold),
                      const SizedBox(width: 8),
                      Text(
                        loc.tr('verse_of_the_day'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    verse['arabic']!,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(verse['translation']!),
                  const SizedBox(height: 6),
                  Text(
                    verse['ref']!,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Hadith of the Day Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.format_quote, color: AppColors.primaryGreen),
                      const SizedBox(width: 8),
                      Text(
                        loc.tr('hadith_of_the_day'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    hadith['arabic']!,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(hadith['translation']!),
                  const SizedBox(height: 6),
                  Text(
                    hadith['ref']!,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickCard(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primaryGreen, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  void _openRamadanPlannerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          final progress = _completedKhatmaJuz.length / 30.0;
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            builder: (_, controller) => Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ramadan Mode & 30-Day Quran Khatma Planner',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade300,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Completed ${_completedKhatmaJuz.length} of 30 Juz (${(progress * 100).toStringAsFixed(0)}%)',
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: GridView.builder(
                      controller: controller,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: 30,
                      itemBuilder: (ctx, i) {
                        final dayJuz = i + 1;
                        final done = _completedKhatmaJuz.contains(dayJuz);
                        return InkWell(
                          onTap: () async {
                            await _toggleKhatmaJuz(dayJuz);
                            setModalState(() {});
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: done
                                  ? AppColors.primaryGreen
                                  : AppColors.accentGold.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                'Day $dayJuz\nJuz $dayJuz',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: done ? Colors.white : null,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
