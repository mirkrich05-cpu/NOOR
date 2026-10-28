class SurahSummary {
  final int number;
  final String nameArabic;
  final String nameEnglish;
  final String englishNameTranslation;
  final int numberOfAyahs;
  final String revelationType;

  const SurahSummary({
    required this.number,
    required this.nameArabic,
    required this.nameEnglish,
    required this.englishNameTranslation,
    required this.numberOfAyahs,
    required this.revelationType,
  });

  factory SurahSummary.fromJson(Map<String, dynamic> json) {
    return SurahSummary(
      number: json['number'] as int,
      nameArabic: json['name'] as String,
      nameEnglish: json['englishName'] as String,
      englishNameTranslation: json['englishNameTranslation'] as String? ?? '',
      numberOfAyahs: json['numberOfAyahs'] as int,
      revelationType: json['revelationType'] as String? ?? 'Meccan',
    );
  }
}

class AyahItem {
  final int numberInQuran;
  final int numberInSurah;
  final int surahNumber;
  final String surahNameArabic;
  final String surahNameEnglish;
  final String textUthmani;
  final String translationText;
  final String? tafsirText;
  final int juz;
  final int page;
  final String audioUrl;

  const AyahItem({
    required this.numberInQuran,
    required this.numberInSurah,
    required this.surahNumber,
    required this.surahNameArabic,
    required this.surahNameEnglish,
    required this.textUthmani,
    required this.translationText,
    this.tafsirText,
    required this.juz,
    required this.page,
    required this.audioUrl,
  });
}

class QuranBookmark {
  final String id;
  final int surahNumber;
  final String surahName;
  final int ayahNumber;
  final String ayahText;
  final int pageNumber;
  final DateTime createdAt;

  const QuranBookmark({
    required this.id,
    required this.surahNumber,
    required this.surahName,
    required this.ayahNumber,
    required this.ayahText,
    required this.pageNumber,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'surah_number': surahNumber,
        'surah_name': surahName,
        'ayah_number': ayahNumber,
        'ayah_text': ayahText,
        'page_number': pageNumber,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory QuranBookmark.fromMap(Map<String, dynamic> map) => QuranBookmark(
        id: map['id'] as String,
        surahNumber: map['surah_number'] as int,
        surahName: map['surah_name'] as String,
        ayahNumber: map['ayah_number'] as int,
        ayahText: map['ayah_text'] as String,
        pageNumber: map['page_number'] as int,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );
}

class ReciterOption {
  final String id;
  final String nameEn;
  final String nameAr;
  final String everyAyahSubfolder;

  const ReciterOption({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.everyAyahSubfolder,
  });

  static const List<ReciterOption> supportedReciters = [
    ReciterOption(
      id: 'ar.alafasy',
      nameEn: 'Mishary Rashid Alafasy',
      nameAr: 'مشاري راشد العفاسي',
      everyAyahSubfolder: 'Alafasy_128kbps',
    ),
    ReciterOption(
      id: 'ar.abdulbasitmurattal',
      nameEn: 'AbdulBaset AbdulSamad (Murattal)',
      nameAr: 'عبد الباسط عبد الصمد',
      everyAyahSubfolder: 'Abdul_Basit_Murattal_192kbps',
    ),
    ReciterOption(
      id: 'ar.husary',
      nameEn: 'Mahmoud Khalil Al-Husary',
      nameAr: 'محمود خليل الحصري',
      everyAyahSubfolder: 'Husary_128kbps',
    ),
    ReciterOption(
      id: 'ar.abdurrahmaansudais',
      nameEn: 'Abdurrahmaan As-Sudais',
      nameAr: 'عبد الرحمن السديس',
      everyAyahSubfolder: 'Abdurrahmaan_As-Sudais_192kbps',
    ),
  ];
}
