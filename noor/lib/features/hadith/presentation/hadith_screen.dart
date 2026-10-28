import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../data/hadith_repository.dart';
import '../domain/hadith_models.dart';

class HadithScreen extends ConsumerStatefulWidget {
  const HadithScreen({super.key});

  @override
  ConsumerState<HadithScreen> createState() => _HadithScreenState();
}

class _HadithScreenState extends ConsumerState<HadithScreen> {
  HadithCollectionMeta _selectedCollection =
      HadithCollectionMeta.collections.first;
  String _searchQuery = '';
  bool _showFavoritesOnly = false;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final repo = ref.watch(hadithRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.tr('hadith')),
        actions: [
          IconButton(
            icon: Icon(
              _showFavoritesOnly ? Icons.favorite : Icons.favorite_border,
              color: _showFavoritesOnly ? AppColors.accentGold : Colors.white,
            ),
            tooltip: 'Saved Favorite Hadiths',
            onPressed: () =>
                setState(() => _showFavoritesOnly = !_showFavoritesOnly),
          ),
        ],
      ),
      body: Column(
        children: [
          // Collection Selector
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: HadithCollectionMeta.collections.map((c) {
                final selected =
                    !_showFavoritesOnly && _selectedCollection.id == c.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('${c.nameEn} (${c.nameAr})'),
                    selected: selected,
                    selectedColor: AppColors.accentGold,
                    onSelected: (_) => setState(() {
                      _showFavoritesOnly = false;
                      _selectedCollection = c;
                    }),
                  ),
                );
              }).toList(),
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
              decoration: InputDecoration(
                hintText: 'Search Hadith in Arabic or English...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          Expanded(
            child: FutureBuilder<List<HadithEntry>>(
              future: _showFavoritesOnly
                  ? repo.getFavorites()
                  : repo.getCollectionHadiths(_selectedCollection),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snapshot.data ?? [];
                final filtered = all.where((h) {
                  if (_searchQuery.isEmpty) return true;
                  final q = _searchQuery.toLowerCase();
                  return h.arabic.contains(_searchQuery) ||
                      h.translation.toLowerCase().contains(q);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No matching Hadiths found.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    final h = filtered[idx];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Chip(label: Text(h.reference)),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.favorite_outline),
                                      color: AppColors.primaryGreen,
                                      onPressed: () async {
                                        await repo.toggleFavorite(h);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Updated Hadith favorites!'),
                                            ),
                                          );
                                        }
                                        if (_showFavoritesOnly) setState(() {});
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.share),
                                      onPressed: () => Share.share(
                                        '${h.arabic}

${h.translation}
— ${h.reference} (via Noor App)',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              h.arabic,
                              textAlign: TextAlign.right,
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(
                                fontSize: 20,
                                height: 1.75,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Divider(height: 20),
                            Text(
                              h.translation,
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
