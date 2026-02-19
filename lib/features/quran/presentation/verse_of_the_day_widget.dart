import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/quran_providers.dart';

class VerseOfTheDayWidget extends ConsumerWidget {
  const VerseOfTheDayWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verseAsync = ref.watch(verseOfTheDayProvider);
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Card(
        elevation: 0,
        color: Colors.black.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: verseAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            error: (err, stack) => Center(
              child: Text(
                'Günün ayeti yüklenemedi.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            data: (ayah) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Günün Ayeti',
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                Text(
                  ayah.text,
                  textAlign: TextAlign.center,
                  style: textTheme.headlineMedium?.copyWith(fontSize: 40,
                    fontFamily: 'Hasenat', // Use the custom font
                    color: Colors.white,
                    height: 1.6, // Adjust line height for Arabic font
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '"${ayah.translation}"',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${ayah.surahName}, ${ayah.numberInSurah}',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
