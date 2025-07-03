// notification_service.dart
// import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: android, iOS: ios);

    await _notifications.initialize(initSettings);
    tz.initializeTimeZones();
  }

  static Future<void> checkAndNotify() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final carsSnapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('cars')
            .get();

    for (var doc in carsSnapshot.docs) {
      final data = doc.data();

      final double mileage = (data['mileage'] ?? 0).toDouble();
      final double initialMileage =
          (data['initialMileage'] ?? mileage).toDouble();
      final Timestamp? lastServiceTs = data['lastServiceDate'];
      final String carName = '${data['make']} ${data['model']}';

      // 1. Mileage check
      if ((mileage - initialMileage) >= 10000) {
        await _showNotification(
          title: 'Service Reminder',
          body: '$carName has driven over 10,000 miles since last check.',
          id: doc.id.hashCode,
        );
      }

      // 2. Last service > 1 year ago
      if (lastServiceTs != null) {
        final lastService = lastServiceTs.toDate();
        final now = DateTime.now();
        if (now.difference(lastService).inDays > 365) {
          await _showNotification(
            title: 'Service Due',
            body: 'It\'s been over a year since you serviced $carName.',
            id: doc.id.hashCode + 1,
          );
        }
      }

      // 3. Scan reminder (example: if last scan date field exists)
      final Timestamp? lastScanTs = data['lastScan'];
      if (lastScanTs != null) {
        final lastScan = lastScanTs.toDate();
        if (DateTime.now().difference(lastScan).inDays > 14) {
          await _showNotification(
            title: 'Scan Reminder',
            body: 'You haven\'t scanned $carName in a while. Do it now!',
            id: doc.id.hashCode + 2,
          );
        }
      }
    }
  }

  static Future<void> _showNotification({
    required String title,
    required String body,
    required int id,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'maintenance_channel',
      'Maintenance Alerts',
      channelDescription: 'Reminders for car maintenance',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();
    const platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.now(
        tz.local,
      ).add(const Duration(seconds: 2)), // show after short delay
      platformDetails,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
