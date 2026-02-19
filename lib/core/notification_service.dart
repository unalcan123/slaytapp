import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../features/locations/data/models.dart';
import '../features/settings/data/alert_settings.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  final AudioPlayer _audioPlayer = AudioPlayer();

  NotificationService(this._notificationsPlugin);

  Future<void> init() async {
    tz.initializeTimeZones();
    const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification click if needed
      },
    );

    _createNotificationChannels();
  }

  Future<void> _createNotificationChannels() async {
    final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      // Ezan Kanalı
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'ezan_vakti_v5', 
          'Ezan Vakti Uyarıları',
          description: 'Namaz vakitlerinde ezan okur.',
          importance: Importance.max, 
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );
      // Hatırlatıcı Kanalı
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'pre_prayer_v5', 
          'Vakit Yaklaşıyor',
          description: 'Vaktin çıkmasına az kaldığını bildirir.',
          importance: Importance.max, 
          playSound: true,
        ),
      );
    }
  }

  Future<void> showPrayerTimeNotification(String prayerName) async {
    const androidDetails = AndroidNotificationDetails(
      'ezan_vakti_v5', 'Ezan Vakti Uyarıları',
      importance: Importance.max, priority: Priority.high,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
    );
    await _notificationsPlugin.show(0, 'Vakit Girdi', '$prayerName vakti girdi.', const NotificationDetails(android: androidDetails));
  }

  Future<void> showPrePrayerNotification(String prayerName, int minute, String? assetPath) async {
    // Uygulama içindeyken ses çal
    if (assetPath != null) {
      try {
        await _audioPlayer.setAsset(assetPath);
        _audioPlayer.play();
      } catch (e) {
        debugPrint("Pre-notification audio error: $e");
      }
    }

    const androidDetails = AndroidNotificationDetails(
      'pre_prayer_v5', 'Vakit Yaklaşıyor',
      importance: Importance.max, priority: Priority.high,
      visibility: NotificationVisibility.public,
    );
    await _notificationsPlugin.show(minute, 'Vakit Yaklaşıyor', '$prayerName vaktine $minute dk kaldı.', const NotificationDetails(android: androidDetails));
  }

  Future<void> scheduleAlarms(List<Vakit> vakitler, AlertSettings settings) async {
    await _notificationsPlugin.cancelAll();
    int id = 100;
    final now = DateTime.now();

    for (final vakit in vakitler) {
      final prayers = [
        MapEntry('İmsak', vakit.imsak),
        MapEntry('Öğle', vakit.ogle),
        MapEntry('İkindi', vakit.ikindi),
        MapEntry('Akşam', vakit.aksam),
        MapEntry('Yatsı', vakit.yatsi),
      ];

      for (final prayer in prayers) {
        if (!settings.isPrayerEnabled(prayer.key)) continue;

        final prayerTime = _parseDateTime(vakit.miladiTarihKisaIso8601, prayer.value);
        if (prayerTime.isBefore(now)) continue;

        // RAW resource kontrolü ve uzantı temizliği
        final soundFileName = _getSoundFileName(prayer.key, settings.alertType);
        final soundResource = (soundFileName != null && settings.alertType == AlertType.ezan) 
            ? RawResourceAndroidNotificationSound(soundFileName) 
            : null;

        final androidDetails = AndroidNotificationDetails(
          'ezan_vakti_v5',
          'Ezan Vakti Uyarıları',
          importance: Importance.max,
          priority: Priority.high,
          sound: soundResource,
          playSound: soundResource != null,
          fullScreenIntent: true, 
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
        );

        await _notificationsPlugin.zonedSchedule(
          id++,
          'Vakit Girdi: ${prayer.key}',
          'Ezan okunuyor...',
          tz.TZDateTime.from(prayerTime, tz.local),
          NotificationDetails(android: androidDetails),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }
  }

  String? _getSoundFileName(String prayerName, AlertType type) {
    if (type == AlertType.ezan) {
      switch (prayerName) {
        // Not: Android RAW resource isimlerinde dosya uzantısı (.mp3) OLMAZ.
        case 'İmsak': return 'sabah_ezan'; 
        case 'Öğle': return 'ogle_ezan';
        case 'İkindi': return 'ikindi_ezan';
        case 'Akşam': return 'aksam_ezan';
        case 'Yatsı': return 'yatsi_ezan';
      }
    }
    return null;
  }

  DateTime _parseDateTime(String dateStr, String timeStr) {
    final d = dateStr.split('.');
    final t = timeStr.split(':');
    return DateTime(int.parse(d[2]), int.parse(d[1]), int.parse(d[0]), int.parse(t[0]), int.parse(t[1]));
  }
}

final flutterLocalNotificationsProvider = Provider<FlutterLocalNotificationsPlugin>((ref) => FlutterLocalNotificationsPlugin());
final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService(ref.watch(flutterLocalNotificationsProvider)));
