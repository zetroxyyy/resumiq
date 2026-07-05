import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FcmService {
  static Future<void> initialize() async {
    final messaging = FirebaseMessaging.instance;
    
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    debugPrint('FCM permission: ${settings.authorizationStatus}');
    
    // Subscribe every user to the broadcast topic
    await messaging.subscribeToTopic('all_users');
    debugPrint('FCM: subscribed to all_users topic');
    
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('FCM message received: ${message.notification?.title}');
    });
  }
}
