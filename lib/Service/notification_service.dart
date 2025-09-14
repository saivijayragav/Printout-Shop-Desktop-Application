import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';

class NotificationService {
  static Future<void> sendOrderReadyNotification({
    required String token,
    required String orderId,
  }) async {
    try {
      // Load service account JSON
      final file = File('config/service-account.json'); // Relative path
      final serviceAccountJson = await file.readAsString();
      final Map<String, dynamic> serviceAccount = jsonDecode(serviceAccountJson);

      final clientEmail = serviceAccount['client_email'];
      final privateKey = serviceAccount['private_key'];
      final projectId = serviceAccount['project_id'];

      final credentials = ServiceAccountCredentials(
        clientEmail,
        ClientId('', ''),
        privateKey,
      );

      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final client = await clientViaServiceAccount(credentials, scopes);

      final url = Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send');

     final message = {
  'message': {
    'token': token,
    'data': {
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
