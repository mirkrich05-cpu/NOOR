import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../data/azkar_repository.dart';
import '../domain/azkar_models.dart';

class AzkarScreen extends ConsumerStatefulWidget {
  const AzkarScreen({super.key});

  @override
  ConsumerState<AzkarScreen> createState() => _AzkarScreenState();
}

class _AzkarScreenState extends ConsumerState<AzkarScreen> {
  String _selectedCategory = 'morning';
  final Map<String, int> _progressCounts = {};
  int _sessionTasbeeh = 0;
  int _dailyTotalTasbeeh = 0;
  int _tasbeehGoal = 33;

  static const Map<String, String> categories = {
    'morning': 'Morning (الصباح)',
    'evening': 'Evening (المساء)',
    'after_prayer': 'After Prayer (بعد الصلاة)',
    'sleep': 'Sleep (النوم)',
    'waking': 'Waking (الاستيقاظ)',
    'travel': 'Travel (السفر)',
  };

  @override
  void initState() {
    super.initState();
    _loadTasbeehStatsAndProgress();
  }

  String get _todayProgressKey =>
      'azkar_progress_${DateFormat('yyyy-MM-dd').format(DateTime.now())}';

  Future<void> _loadTasbeehStatsAndProgress() async {
    final count = await ref.read(azkarRepositoryProvider).getTodayTasbeehCount();
    final prefs = await SharedPreferences.getInstance();
    final rawProgress = prefs.getString(_todayProgressKey);
    final Map<String, int> loadedProgress = {};
    if (rawProgress != null && rawProgress.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawProgress) as Map<String, dynamic>;
        decoded.forEach((k, v) => loadedProgress[k] = (v as num).toInt());
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _dailyTotalTasbeeh = count;
        _progressCounts
          ..clear()
          ..addAll(loadedProgress);
      });
    }
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_todayProgressKey, jsonEncode(_progressCounts));
  }

  Future<void> _enableDailyReminder() async {
    await NotificationService.instance.scheduleDailyAzkarReminder();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Morning & Evening Azkar reminders enabled!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final repo = ref.watch(azkarRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.tr('azkar')),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Enable Daily Azkar Reminder',
            onPressed: _enableDailyReminder,
          ),
          IconButton(
            icon: const Icon(Icons.touch_app),
            tooltip: loc.tr('tasbeeh'),
            onPressed: _openTasbeehSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Category Chips
          SizedBox(
            height: 58,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: categories.entries.map((entry) {
                final selected = _selectedCategory == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: selected,
                    selectedColor: AppColors.accentGold,
                    onSelected: (_) =>
                        setState(() => _selectedCategory = entry.key),
                  ),
                );
              }).toList(),
            ),
          ),

          // Offline Azkar Cards
          Expanded(
            child: FutureBuilder<List<DhikrItem>>(
              future: repo.loadAllAzkar(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data!
                    .where((d) => d.category == _selectedCategory)
                    .toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final current = _progressCounts[item.id] ?? 0;
                    final done = current >= item.targetCount;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      color: done
                          ? AppColors.primaryGreen.withOpacity(0.1)
                          : null,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          if (current < item.targetCount) {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _progressCounts[item.id] = current + 1;
                            });
                            _saveProgress();
                          }
                        },
                        onLongPress: () {
                          HapticFeedback.mediumImpact();
                          setState(() {
                            _progressCounts[item.id] = 0;
                          });
                          _saveProgress();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item.titleEn} • ${item.titleAr}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryGreen,
                                      ),
                                    ),
                                  ),
                                  Chip(
                                    backgroundColor: done
                                        ? AppColors.primaryGreen
                                        : AppColors.accentGold,
                                    label: Text(
                                      '$current / ${item.targetCount}',
                                      style: TextStyle(
                                        color: done
                                            ? Colors.white
                                            : AppColors.deepEmerald,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (current > 0)
                                    IconButton(
                                      icon: const Icon(Icons.refresh, size: 18),
                                      tooltip: 'Reset Counter',
                                      onPressed: () {
                                        setState(() {
                                          _progressCounts[item.id] = 0;
                                        });
                                        _saveProgress();
                                      },
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                item.arabic,
                                textAlign: TextAlign.right,
                                textDirection: TextDirection.rtl,
                                style: const TextStyle(
                                  fontSize: 22,
                                  height: 1.8,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                item.transliteration,
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(item.translation),
                              const SizedBox(height: 8),
                              Text(
                                'Source: ${item.source} (Tap card to count)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openTasbeehSheet,
        icon: const Icon(Icons.fingerprint),
        label: Text('${loc.tr('tasbeeh')} ($_dailyTotalTasbeeh)'),
      ),
    );
  }

  void _openTasbeehSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Digital Tasbeeh • المسبحة الإلكترونية',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text("Today's Total Dhikr: $_dailyTotalTasbeeh"),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [33, 99, 100, 1000].map((goal) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text('Goal $goal'),
                        selected: _tasbeehGoal == goal,
                        onSelected: (_) =>
                            setModalState(() => _tasbeehGoal = goal),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    final newDaily = await ref
                        .read(azkarRepositoryProvider)
                        .incrementTasbeeh();
                    setModalState(() {
                      _sessionTasbeeh++;
                      _dailyTotalTasbeeh = newDaily;
                    });
                    setState(() {});
                  },
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryGreen,
                      border:
                          Border.all(color: AppColors.accentGold, width: 5),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$_sessionTasbeeh',
                            style: const TextStyle(
                              fontSize: 40,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '/ $_tasbeehGoal',
                            style: const TextStyle(
                              color: AppColors.accentGold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => setModalState(() => _sessionTasbeeh = 0),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset Session Counter'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
