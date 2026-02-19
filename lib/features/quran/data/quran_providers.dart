import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ayah_model.dart';
import 'quran_api.dart';

// Provider for QuranApi
final quranApiProvider = Provider<QuranApi>((ref) {
  // Using a separate Dio instance for this API
  return QuranApi(Dio());
});

// Provider to fetch the verse of the day
final verseOfTheDayProvider = FutureProvider<Ayah>((ref) {
  final api = ref.watch(quranApiProvider);
  return api.getVerseOfTheDay();
});
