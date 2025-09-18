import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter/services.dart' show rootBundle;

class NotificationService {
  static Future<void> sendOrderReadyNotification({
    required String token,
    required String orderId,
  }) async {
    try {
      // Load service account JSON
      final serviceAccountJson = await rootBundle.loadString('assets/config/service-account.json');
      final serviceAccount = jsonDecode(serviceAccountJson);
      final credentials = ServiceAccountCredentials.fromJson(serviceAccount);
      final projectId = serviceAccount['project_id'];

      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final client = await clientViaServiceAccount(credentials, scopes);

      final url = Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send');

     final message = {
  'message': {
    'token': token,
    'notification': {
      'title': 'Order Ready 🎉',
      'body': 'Your order $orderId has been printed and is ready for pickup!',
    },
    'android': {
      'priority': 'high',
      'notification': {
        'sound': 'default',
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        'channel_id': 'channel_id'
      },
    },
  },
};


      final response = await client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(message),
      );

      if (response.statusCode == 200) {
        print('✅ Notification sent successfully.');
      } else {
        print('❌ Failed to send notification: ${response.statusCode} - ${response.body}');
      }

      client.close();
    } catch (e) {
      print('🔥 Error sending FCM notification: $e');
    }
  }
}
