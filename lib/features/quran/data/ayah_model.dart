class Ayah {
  final String text;
  final String translation;
  final String surahName;
  final int numberInSurah;

  Ayah({
    required this.text,
    required this.translation,
    required this.surahName,
    required this.numberInSurah,
  });

  factory Ayah.fromApiResponse(Map<String, dynamic> json) {
    final editions = json['data'] as List<dynamic>?;
    if (editions == null || editions.length < 2) {
      throw Exception("API response is missing required editions (Uthmani and Turkish)");
    }

    final uthmaniData = editions[0];
    final translationData = editions[1];

    return Ayah(
      text: uthmaniData['text'] as String,
      translation: translationData['text'] as String,
      surahName: uthmaniData['surah']?['englishName'] as String? ?? 'N/A',
      numberInSurah: uthmaniData['numberInSurah'] as int,
    );
  }
}
