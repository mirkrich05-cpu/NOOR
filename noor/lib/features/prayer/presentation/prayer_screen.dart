import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../data/prayer_repository.dart';
import '../domain/prayer_models.dart';

class PrayerScreen extends ConsumerStatefulWidget {
  const PrayerScreen({super.key});

  @override
  ConsumerState<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends ConsumerState<PrayerScreen> {
  CityPreset? _selectedManualCity;
  int _calculationMethod = 4; // Umm al-Qura default
  int _madhhabSchool = 0; // Shafi default
  String _selectedAdhanSound = 'Makkah Adhan';
  Timer? _countdownTimer;
  DateTime _now = DateTime.now();
  Future<DailyPrayerTimes>? _prayerFuture;
  double _currentLat = 31.7683;
  double _currentLng = 35.2137;

  @override
  void initState() {
    super.initState();
    _initPreferencesAndLoad();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  Future<void> _initPreferencesAndLoad() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _calculationMethod = prefs.getInt('prayer_calc_method') ?? 4;
        _madhhabSchool = prefs.getInt('prayer_madhhab') ?? 0;
        _selectedAdhanSound =
            prefs.getString('adhan_sound') ?? 'Makkah Adhan';
      });
    }
    await _loadPrayerTimes();
  }

  Future<void> _loadPrayerTimes() async {
    final repo = ref.read(prayerRepositoryProvider);
    final coords =
        await repo.resolveCoordinates(manualCity: _selectedManualCity);
    _currentLat = coords.lat;
    _currentLng = coords.lng;
    if (mounted) {
      setState(() {
        _prayerFuture = repo.getTodayPrayerTimes(
          latitude: coords.lat,
          longitude: coords.lng,
          locationLabel: coords.label,
          method: _calculationMethod,
          school: _madhhabSchool,
          adhanSoundName: _selectedAdhanSound,
        );
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final timeFmt = DateFormat('hh:mm a');
    final repo = ref.watch(prayerRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.tr('prayer')),
        actions: [
          IconButton(
            icon: const Icon(Icons.explore),
            tooltip: loc.tr('qibla_compass'),
            onPressed: () => _openQiblaCompassDialog(
              repo.calculateQiblaBearing(_currentLat, _currentLng),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Detect GPS Location',
            onPressed: () {
              setState(() => _selectedManualCity = null);
              _loadPrayerTimes();
            },
          ),
        ],
      ),
      body: FutureBuilder<DailyPrayerTimes>(
        future: _prayerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: ElevatedButton(
                onPressed: _loadPrayerTimes,
                child: const Text('Retry Prayer Calculation'),
              ),
            );
          }

          final times = snapshot.data!;
          final next = times.nextPrayer(_now);
          final remaining = next.value.difference(_now);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Next Prayer Countdown Banner
              Card(
                color: AppColors.primaryGreen,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        times.locationLabel,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${loc.tr('next_prayer')}: ${next.key}',
                        style: const TextStyle(
                          color: AppColors.accentGold,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatDuration(remaining),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${times.hijriFormatted} (${times.hijriMonthNameAr})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                      if (times.holidays.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Chip(
                          backgroundColor: AppColors.accentGold,
                          label: Text(
                            'Islamic Event: ${times.holidays.join(', ')}',
                            style: const TextStyle(
                              color: AppColors.deepEmerald,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // City Fallback, Calculation Method, Madhhab & Adhan Sound Controls
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      DropdownButtonFormField<CityPreset>(
                        value: _selectedManualCity,
                        decoration: const InputDecoration(
                          labelText: 'Location (GPS or Manual City Fallback)',
                          prefixIcon: Icon(Icons.location_city),
                        ),
                        items: CityPreset.presets
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.name),
                              ),
                            )
                            .toList(),
                        onChanged: (c) {
                          setState(() => _selectedManualCity = c);
                          _loadPrayerTimes();
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _calculationMethod,
                              decoration: const InputDecoration(
                                labelText: 'Calculation Method',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 4,
                                  child: Text('Umm al-Qura'),
                                ),
                                DropdownMenuItem(
                                  value: 3,
                                  child: Text('Muslim World League'),
                                ),
                                DropdownMenuItem(
                                  value: 5,
                                  child: Text('Egyptian General Authority'),
                                ),
                                DropdownMenuItem(
                                  value: 2,
                                  child: Text('ISNA (North America)'),
                                ),
                              ],
                              onChanged: (val) async {
                                if (val != null) {
                                  setState(() => _calculationMethod = val);
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.setInt('prayer_calc_method', val);
                                  _loadPrayerTimes();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _madhhabSchool,
                              decoration: const InputDecoration(
                                labelText: 'Madhhab (Asr)',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 0,
                                  child: Text('Standard (Shafi/Maliki/Hanbali)'),
                                ),
                                DropdownMenuItem(
                                  value: 1,
                                  child: Text('Hanafi'),
                                ),
                              ],
                              onChanged: (val) async {
                                if (val != null) {
                                  setState(() => _madhhabSchool = val);
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.setInt('prayer_madhhab', val);
                                  _loadPrayerTimes();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedAdhanSound,
                        decoration: const InputDecoration(
                          labelText: 'Adhan Notification Sound',
                          prefixIcon: Icon(Icons.notifications_active),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Makkah Adhan',
                            child: Text('Makkah Al-Mukarramah Adhan'),
                          ),
                          DropdownMenuItem(
                            value: 'Madinah Adhan',
                            child: Text('Al-Masjid An-Nabawi Adhan'),
                          ),
                          DropdownMenuItem(
                            value: 'Al-Aqsa Adhan',
                            child: Text('Al-Masjid Al-Aqsa Adhan'),
                          ),
                        ],
                        onChanged: (val) async {
                          if (val != null) {
                            setState(() => _selectedAdhanSound = val);
                            final prefs =
                                await SharedPreferences.getInstance();
                            await prefs.setString('adhan_sound', val);
                            _loadPrayerTimes();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 5 Daily Prayers + Sunrise List
              ...times.fivePrayersAndSunrise.entries.map((entry) {
                final isNext = entry.key == next.key;
                return Card(
                  color:
                      isNext ? AppColors.accentGold.withOpacity(0.18) : null,
                  child: ListTile(
                    leading: Icon(
                      entry.key == 'Sunrise'
                          ? Icons.wb_sunny_outlined
                          : Icons.access_time_filled,
                      color: isNext
                          ? AppColors.primaryGreen
                          : Colors.grey.shade600,
                    ),
                    title: Text(
                      entry.key,
                      style: TextStyle(
                        fontWeight:
                            isNext ? FontWeight.bold : FontWeight.normal,
                        fontSize: 17,
                      ),
                    ),
                    trailing: Text(
                      timeFmt.format(entry.value),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: isNext ? AppColors.primaryGreen : null,
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  void _openQiblaCompassDialog(double qiblaBearing) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Qibla Compass • اتجاه القبلة'),
        content: SizedBox(
          height: 260,
          width: 260,
          child: StreamBuilder<CompassEvent>(
            stream: FlutterCompass.events,
            builder: (context, snapshot) {
              final heading = snapshot.data?.heading ?? 0.0;
              final angleRad = (qiblaBearing - heading) * (math.pi / 180.0);

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Qibla Bearing: ${qiblaBearing.toStringAsFixed(1)}° N',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Transform.rotate(
                    angle: angleRad,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.accentGold,
                          width: 4,
                        ),
                        color: AppColors.primaryGreen.withOpacity(0.1),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.navigation,
                            size: 64,
                            color: AppColors.primaryGreen,
                          ),
                          Text(
                            'KAABA 🕋',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Heading: ${heading.toStringAsFixed(0)}°',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
