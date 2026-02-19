import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/locations/presentation/country_page.dart';
import 'features/settings/data/prefs_repository.dart';
import 'features/settings/presentation/theme_controller.dart';
import 'features/times/presentation/times_page.dart';

class EzanApp extends ConsumerWidget {
  const EzanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get the list of recent locations
    final recentLocations = ref.watch(prefsRepositoryProvider).getRecentLocations();
    // Use the first location in the list as the last used one, if it exists.
    final lastLocation = recentLocations.isNotEmpty ? recentLocations.first : null;

    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ezan Vakti',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),

      themeMode: themeMode,
      home: lastLocation != null
          ? TimesPage(
              ulke: lastLocation.ulke,
              sehir: lastLocation.sehir,
              ilce: lastLocation.ilce,
            )
          : const CountryPage(),
    );
  }
}
