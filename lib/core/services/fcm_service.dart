import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FcmService {
  static Future<void> initialize() async {
    final messaging = FirebaseMessaging.instance;
    
    final settings = await messaging.requestPermission(
      alert: true, badge: true, sound: true,
    );
    
    debugPrint('FCM permission status: ${settings.authorizationStatus}');
    
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('FCM: Permission DENIED by user');
      return;
    }
    
    try {
      await messaging.subscribeToTopic('all_users');
      debugPrint('FCM: Successfully subscribed to all_users topic');
      
      final token = await messaging.getToken();
      debugPrint('FCM: Device token obtained: ${token?.substring(0, 20)}...');
    } catch (e) {
      debugPrint('FCM: Subscription FAILED: $e');
    }
    
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('FCM: Foreground message received - '
        '${message.notification?.title}');
    });
    
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('FCM: Notification tapped - '
        '${message.notification?.title}');
    });
  }
}
