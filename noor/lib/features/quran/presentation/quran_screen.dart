import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../settings/presentation/settings_controller.dart';
import '../data/quran_repository.dart';
import '../domain/quran_models.dart';

class QuranScreen extends ConsumerStatefulWidget {
  const QuranScreen({super.key});

  @override
  ConsumerState<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends ConsumerState<QuranScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _selectedTranslation = 'en.sahih';
  ReciterOption _selectedReciter = ReciterOption.supportedReciters.first;
  Map<String, dynamic>? _lastRead;
  List<QuranBookmark> _bookmarks = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadBookmarksAndLastRead();
  }

  Future<void> _loadBookmarksAndLastRead() async {
    final repo = ref.read(quranRepositoryProvider);
    final last = await repo.getLastRead();
    final marks = await repo.getBookmarks();
    if (mounted) {
      setState(() {
        _lastRead = last;
        _bookmarks = marks;
      });
    }
  }

  Future<void> _runSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results =
          await ref.read(quranRepositoryProvider).searchQuran(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final repo = ref.watch(quranRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.tr('quran')),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.translate),
            tooltip: 'Translation Edition',
            onSelected: (val) => setState(() => _selectedTranslation = val),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'en.sahih',
                child: Text('English - Saheeh International'),
              ),
              PopupMenuItem(
                value: 'en.yusufali',
                child: Text('English - Abdullah Yusuf Ali'),
              ),
              PopupMenuItem(
                value: 'ar.muyassar',
                child: Text('العربية - التفسير الميسر'),
              ),
              PopupMenuItem(
                value: 'fr.hamidullah',
                child: Text('Français - Muhammad Hamidullah'),
              ),
            ],
          ),
          PopupMenuButton<ReciterOption>(
            icon: const Icon(Icons.record_voice_over),
            tooltip: 'Select Reciter',
            onSelected: (r) => setState(() => _selectedReciter = r),
            itemBuilder: (_) => ReciterOption.supportedReciters
                .map(
                  (r) => PopupMenuItem(
                    value: r,
                    child: Text('${r.nameEn} (${r.nameAr})'),
                  ),
                )
                .toList(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accentGold,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppColors.accentGold,
          tabs: [
            Tab(text: loc.tr('surah')),
            Tab(text: loc.tr('juz')),
            Tab(text: loc.tr('page')),
            Tab(text: loc.tr('bookmarks')),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Bar & Last Read Banner
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchController,
              onSubmitted: _runSearch,
              decoration: InputDecoration(
                hintText: loc.tr('search_quran'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchResults = []);
                        },
                      )
                    : null,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_lastRead != null && _searchResults.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Card(
                color: AppColors.primaryGreen,
                child: ListTile(
                  leading:
                      const Icon(Icons.menu_book, color: AppColors.accentGold),
                  title: Text(
                    '${loc.tr('last_read')}: ${_lastRead!['surahName']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Ayah ${_lastRead!['ayahNumber']} • Page ${_lastRead!['pageNumber']}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    color: AppColors.accentGold,
                    size: 16,
                  ),
                  onTap: () => _openSurahReader(
                    surahNumber: _lastRead!['surahNumber'] as int,
                    surahTitle: _lastRead!['surahName'] as String,
                    initialAyah: _lastRead!['ayahNumber'] as int,
                  ),
                ),
              ),
            ),
          if (_isSearching) const LinearProgressIndicator(),
          if (_searchResults.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (ctx, i) {
                  final match = _searchResults[i];
                  final surah = match['surah'] as Map<String, dynamic>? ?? {};
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: ListTile(
                      title: Text(match['text'] as String? ?? ''),
                      subtitle: Text(
                        '${surah['englishName'] ?? ''} • Ayah ${match['numberInSurah']}',
                      ),
                      onTap: () => _openSurahReader(
                        surahNumber: surah['number'] as int? ?? 1,
                        surahTitle: surah['englishName'] as String? ?? 'Surah',
                        initialAyah: match['numberInSurah'] as int? ?? 1,
                      ),
                    ),
                  );
                },
              ),
            )
          else
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: All 114 Surahs
                  FutureBuilder<List<SurahSummary>>(
                    future: repo.getAllSurahs(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cloud_off, size: 48),
                              const SizedBox(height: 8),
                              Text('Error loading Surahs: ${snapshot.error}'),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () => setState(() {}),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        );
                      }
                      final surahs = snapshot.data ?? [];
                      return ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: surahs.length,
                        itemBuilder: (context, idx) {
                          final s = surahs[idx];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppColors.primaryGreen.withOpacity(0.12),
                                child: Text(
                                  '${s.number}',
                                  style: const TextStyle(
                                    color: AppColors.primaryGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                s.nameEnglish,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${s.englishNameTranslation} • ${s.numberOfAyahs} Ayahs • ${s.revelationType}',
                              ),
                              trailing: Text(
                                s.nameArabic,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                              onTap: () => _openSurahReader(
                                surahNumber: s.number,
                                surahTitle: '${s.nameEnglish} (${s.nameArabic})',
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),

                  // Tab 2: 30 Juz Grid
                  GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1.4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: 30,
                    itemBuilder: (context, idx) {
                      final juzNumber = idx + 1;
                      return InkWell(
                        onTap: () => _openJuzOrPageReader(
                          title: 'Juz $juzNumber (الجزء $juzNumber)',
                          loader: () => repo.getJuzAyahs(
                            juzNumber,
                            translationEdition: _selectedTranslation,
                          ),
                        ),
                        child: Card(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Juz $juzNumber',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'الجزء $juzNumber',
                                  style: const TextStyle(
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Tab 3: 604 Pages Selector
                  ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: 604,
                    itemBuilder: (context, idx) {
                      final pageNum = idx + 1;
                      return Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.auto_stories,
                            color: AppColors.primaryGreen,
                          ),
                          title: Text('Mushaf Page $pageNum (صفحة $pageNum)'),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => _openJuzOrPageReader(
                            title: 'Page $pageNum (صفحة $pageNum)',
                            loader: () => repo.getPageAyahs(
                              pageNum,
                              translationEdition: _selectedTranslation,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Tab 4: Saved Bookmarks
                  _bookmarks.isEmpty
                      ? const Center(
                          child: Text('No bookmarks yet. Tap the bookmark icon on any Ayah.'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _bookmarks.length,
                          itemBuilder: (context, idx) {
                            final b = _bookmarks[idx];
                            return Card(
                              child: ListTile(
                                title: Text(
                                  '${b.surahName} • Ayah ${b.ayahNumber}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  b.ayahText,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textDirection: TextDirection.rtl,
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    await repo.toggleBookmark(b);
                                    _loadBookmarksAndLastRead();
                                  },
                                ),
                                onTap: () => _openSurahReader(
                                  surahNumber: b.surahNumber,
                                  surahTitle: b.surahName,
                                  initialAyah: b.ayahNumber,
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openSurahReader({
    required int surahNumber,
    required String surahTitle,
    int initialAyah = 1,
  }) async {
    final repo = ref.read(quranRepositoryProvider);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuranReaderView(
          title: surahTitle,
          reciter: _selectedReciter,
          initialAyah: initialAyah,
          ayahsLoader: () => repo.getSurahAyahs(
            surahNumber: surahNumber,
            translationEdition: _selectedTranslation,
            reciter: _selectedReciter,
          ),
        ),
      ),
    );
    _loadBookmarksAndLastRead();
  }

  Future<void> _openJuzOrPageReader({
    required String title,
    required Future<List<AyahItem>> Function() loader,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuranReaderView(
          title: title,
          reciter: _selectedReciter,
          ayahsLoader: loader,
        ),
      ),
    );
    _loadBookmarksAndLastRead();
  }
}

class QuranReaderView extends ConsumerStatefulWidget {
  final String title;
  final ReciterOption reciter;
  final int initialAyah;
  final Future<List<AyahItem>> Function() ayahsLoader;

  const QuranReaderView({
    super.key,
    required this.title,
    required this.reciter,
    this.initialAyah = 1,
    required this.ayahsLoader,
  });

  @override
  ConsumerState<QuranReaderView> createState() => _QuranReaderViewState();
}

class _QuranReaderViewState extends ConsumerState<QuranReaderView> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  int? _playingAyahInQuran;
  bool _isDownloadingSurah = false;
  late Future<List<AyahItem>> _futureAyahs;

  @override
  void initState() {
    super.initState();
    _futureAyahs = widget.ayahsLoader();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playSingleAyah(AyahItem ayah) async {
    final repo = ref.read(quranRepositoryProvider);
    setState(() => _playingAyahInQuran = ayah.numberInQuran);
    try {
      final localPath = await repo.downloadOrGetCachedAudioPath(
        reciter: widget.reciter,
        surahNumber: ayah.surahNumber,
        ayahNumber: ayah.numberInSurah,
        remoteUrl: ayah.audioUrl,
      );
      await _audioPlayer.setFilePath(localPath);
      await _audioPlayer.play();
    } catch (_) {
      await _audioPlayer.setUrl(ayah.audioUrl);
      await _audioPlayer.play();
    }
  }

  Future<void> _playFullSurah(List<AyahItem> ayahs) async {
    final playlist = ConcatenatingAudioSource(
      children: ayahs
          .map((a) => AudioSource.uri(Uri.parse(a.audioUrl)))
          .toList(),
    );
    await _audioPlayer.setAudioSource(playlist);
    await _audioPlayer.play();
  }

  Future<void> _downloadEntireSurahForOffline(List<AyahItem> ayahs) async {
    setState(() => _isDownloadingSurah = true);
    final repo = ref.read(quranRepositoryProvider);
    try {
      for (final a in ayahs) {
        await repo.downloadOrGetCachedAudioPath(
          reciter: widget.reciter,
          surahNumber: a.surahNumber,
          ayahNumber: a.numberInSurah,
          remoteUrl: a.audioUrl,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Surah audio downloaded for offline playback!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Offline download error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloadingSurah = false);
    }
  }

  Future<void> _showTafsirModal(AyahItem ayah) async {
    final repo = ref.read(quranRepositoryProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: FutureBuilder<String>(
            future: repo.getAyahTafsir(
              surahNumber: ayah.surahNumber,
              ayahNumber: ayah.numberInSurah,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final tafsir = snapshot.data ??
                  'Tafsir unavailable offline until fetched once.';
              return ListView(
                controller: scrollController,
                children: [
                  Text(
                    'Tafsir Ibn Kathir • ${ayah.surahNameEnglish} ${ayah.surahNumber}:${ayah.numberInSurah}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    ayah.textUthmani,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontSize: 22,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const Divider(height: 24),
                  Text(
                    tafsir,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    final repo = ref.watch(quranRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.stop_circle_outlined),
            tooltip: 'Stop Audio',
            onPressed: () => _audioPlayer.stop(),
          ),
        ],
      ),
      body: FutureBuilder<List<AyahItem>>(
        future: _futureAyahs,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load Quran data: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () =>
                          setState(() => _futureAyahs = widget.ayahsLoader()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final ayahs = snapshot.data ?? [];
          return Column(
            children: [
              // Surah Audio Control Bar
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppColors.primaryGreen.withOpacity(0.08),
                child: Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _playFullSurah(ayahs),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Play All'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _isDownloadingSurah
                          ? null
                          : () => _downloadEntireSurahForOffline(ayahs),
                      icon: _isDownloadingSurah
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_for_offline_outlined),
                      label: const Text('Offline Audio'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: ayahs.length,
                  itemBuilder: (context, index) {
                    final ayah = ayahs[index];
                    final isPlaying =
                        _playingAyahInQuran == ayah.numberInQuran;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: isPlaying
                          ? AppColors.accentGold.withOpacity(0.15)
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Chip(
                                  label: Text(
                                    '${ayah.surahNumber}:${ayah.numberInSurah} • J${ayah.juz} • P${ayah.page}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.volume_up),
                                      color: AppColors.primaryGreen,
                                      tooltip: 'Play Ayah',
                                      onPressed: () => _playSingleAyah(ayah),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.menu_book_outlined),
                                      tooltip: 'Tafsir',
                                      onPressed: () => _showTafsirModal(ayah),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.bookmark_add_outlined),
                                      tooltip: 'Bookmark & Mark Last Read',
                                      onPressed: () async {
                                        await repo.saveLastRead(
                                          surahNumber: ayah.surahNumber,
                                          surahName: ayah.surahNameEnglish,
                                          ayahNumber: ayah.numberInSurah,
                                          pageNumber: ayah.page,
                                        );
                                        await repo.toggleBookmark(
                                          QuranBookmark(
                                            id: '${ayah.surahNumber}_${ayah.numberInSurah}',
                                            surahNumber: ayah.surahNumber,
                                            surahName: ayah.surahNameEnglish,
                                            ayahNumber: ayah.numberInSurah,
                                            ayahText: ayah.textUthmani,
                                            pageNumber: ayah.page,
                                            createdAt: DateTime.now(),
                                          ),
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Saved bookmark & updated last-read position!',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              ayah.textUthmani,
                              textAlign: TextAlign.right,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontSize: settings.quranFontSize,
                                height: 1.85,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              ayah.translationText,
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
