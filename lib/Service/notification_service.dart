import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  static Future<void> sendOrderReadyNotification({
    required String token,
    required String orderId,
  }) async {
    try {
      // Load service account json
      final serviceAccountString =
          await rootBundle.loadString('assets/config/service-account.json');

      final Map<String, dynamic> serviceAccount =
          jsonDecode(serviceAccountString);

      final String projectId = serviceAccount['project_id'];

      final credentials =
          ServiceAccountCredentials.fromJson(serviceAccount);

      final scopes = [
        'https://www.googleapis.com/auth/firebase.messaging'
      ];

      final authClient =
          await clientViaServiceAccount(credentials, scopes);

      final Uri url = Uri.parse(
        'https://fcm.googleapis.com/v1/projects/$projectId/messages:send',
      );

      final Map<String, dynamic> body = {
        "message": {
          "token": token,
          "notification": {
            "title": "Order Printed! ✅",
            "body":
                "Your order #$orderId is printed and ready for pickup."
          },
          "data": {
            "orderId": orderId,
            "type": "order_ready",
            "click_action": "FLUTTER_NOTIFICATION_CLICK"
          },
          "android": {
            "priority": "HIGH",
            "notification": {
              "channel_id": "high_importance_channel",
              "sound": "default"
            }
          }
        }
      };

      final response = await authClient.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        print("✅ FCM Sent Successfully");
      } else {
        print("❌ FCM Failed: ${response.statusCode}");
        print(response.body);
      }

      authClient.close();
    } catch (e) {
      print("🔥 Notification Error: $e");
    }
  }
}
