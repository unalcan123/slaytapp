import 'package:dio/dio.dart';
import 'ayah_model.dart';

class QuranApi {
  final Dio _dio;

  QuranApi(this._dio);

  Future<Ayah> getVerseOfTheDay() async {
    // There are 6236 verses in the Quran. We'll pick one based on the day of the year.
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    final ayahNumber = (dayOfYear * 31) % 6236 + 1;

    // Fetch both Uthmani text and Turkish translation in one call
    try {
      final response = await _dio.get('http://api.alquran.cloud/v1/ayah/$ayahNumber/editions/quran-uthmani,tr.diyanet');
      return Ayah.fromApiResponse(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception("Günün ayeti alınamadı: ${e.message}");
    }
  }
}
