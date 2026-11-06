class HadithCollectionMeta {
  final String id;
  final String nameEn;
  final String nameAr;
  final String araEdition;
  final String engEdition;

  const HadithCollectionMeta({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.araEdition,
    required this.engEdition,
  });

  static const List<HadithCollectionMeta> collections = [
    HadithCollectionMeta(
      id: 'nawawi40',
      nameEn: "Nawawi's 40 Hadith",
      nameAr: 'الأربعون النووية',
      araEdition: 'ara-nawawi',
      engEdition: 'eng-nawawi',
    ),
    HadithCollectionMeta(
      id: 'bukhari',
      nameEn: 'Sahih al-Bukhari',
      nameAr: 'صحيح البخاري',
      araEdition: 'ara-bukhari',
      engEdition: 'eng-bukhari',
    ),
    HadithCollectionMeta(
      id: 'muslim',
      nameEn: 'Sahih Muslim',
      nameAr: 'صحيح مسلم',
      araEdition: 'ara-muslim',
      engEdition: 'eng-muslim',
    ),
    HadithCollectionMeta(
      id: 'abudawud',
      nameEn: 'Sunan Abu Dawud',
      nameAr: 'سنن أبي داود',
      araEdition: 'ara-abudawud',
      engEdition: 'eng-abudawud',
    ),
    HadithCollectionMeta(
      id: 'tirmidhi',
      nameEn: 'Jami` at-Tirmidhi',
      nameAr: 'جامع الترمذي',
      araEdition: 'ara-tirmidhi',
      engEdition: 'eng-tirmidhi',
    ),
    HadithCollectionMeta(
      id: 'nasai',
      nameEn: "Sunan an-Nasa'i",
      nameAr: 'سنن النسائي',
      araEdition: 'ara-nasai',
      engEdition: 'eng-nasai',
    ),
    HadithCollectionMeta(
      id: 'ibnmajah',
      nameEn: 'Sunan Ibn Majah',
      nameAr: 'سنن ابن ماجه',
      araEdition: 'ara-ibnmajah',
      engEdition: 'eng-ibnmajah',
    ),
    HadithCollectionMeta(
      id: 'riyadussalihin',
      nameEn: 'Riyad as-Salihin',
      nameAr: 'رياض الصالحين',
      araEdition: 'ara-riyadussalihin',
      engEdition: 'eng-riyadussalihin',
    ),
  ];
}

class HadithEntry {
  final int number;
  final String collectionId;
  final String arabic;
  final String translation;
  final String reference;

  const HadithEntry({
    required this.number,
    required this.collectionId,
    required this.arabic,
    required this.translation,
    required this.reference,
  });
}
