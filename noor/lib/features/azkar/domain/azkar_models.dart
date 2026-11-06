class DhikrItem {
  final String id;
  final String category;
  final String titleEn;
  final String titleAr;
  final String arabic;
  final String transliteration;
  final String translation;
  final String source;
  final int targetCount;

  const DhikrItem({
    required this.id,
    required this.category,
    required this.titleEn,
    required this.titleAr,
    required this.arabic,
    required this.transliteration,
    required this.translation,
    required this.source,
    required this.targetCount,
  });

  factory DhikrItem.fromJson(Map<String, dynamic> json) => DhikrItem(
        id: json['id'] as String,
        category: json['category'] as String,
        titleEn: json['titleEn'] as String,
        titleAr: json['titleAr'] as String,
        arabic: json['arabic'] as String,
        transliteration: json['transliteration'] as String,
        translation: json['translation'] as String,
        source: json['source'] as String,
        targetCount: json['targetCount'] as int? ?? 1,
      );
}
