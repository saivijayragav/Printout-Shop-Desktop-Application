import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';


// Custom Imports
import '../widgets/customappbar.dart';
import '../widgets/custom_drawer.dart';
import 'order_details_page.dart';
import '../Service/notification_service.dart'; // Make sure this path is correct!

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  bool _liveOrdersEnabled = true;
  List<dynamic> _cachedOrders = [];
  bool _isLoading = false;

  // final String baseUrl = "http://172.15.18.61:8080/api/orders/summary";
  final String baseUrl =
    "http://${dotenv.env['API_IP']}/api/orders/summary";


  @override
  void initState() {
    super.initState();
    fetchOrdersFromApi();
  }

  void toggleLiveOrder(bool value) {
    setState(() => _liveOrdersEnabled = value);
    if (value) refreshData();
  }

  Future<void> fetchOrdersFromApi() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse(baseUrl));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        // Sort: Oldest first (Ascending)
        data.sort((a, b) {
           String tA = a['timestamp'] ?? '';
           String tB = b['timestamp'] ?? '';
           return tA.compareTo(tB); 
        });

        setState(() {
          _cachedOrders = data;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load orders: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Error fetching API: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("API Connection Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void refreshData() {
    fetchOrdersFromApi();
  }

  String formatTimestamp(String? timestampStr) {
    if (timestampStr == null || timestampStr.isEmpty) return 'No Timestamp';
    try {
      final DateTime dt = DateTime.parse(timestampStr);
      final DateTime now = DateTime.now();
      final bool isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
      final DateTime yesterday = now.subtract(const Duration(days: 1));
      final bool isYesterday = dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day;

      final String timePart = DateFormat('hh:mm a').format(dt);

      if (isToday) return "Today, $timePart";
      if (isYesterday) return "Yesterday, $timePart";
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (e) {
      return timestampStr; 
    }
  }

  // 🔥 UPDATED: Helper to get Token & Call your External Service
 Future<void> triggerNotificationSequence(
    String rawPhoneNumber, String orderId) async {
  try {
    // 🔹 Clean phone number
    String cleanPhone =
        rawPhoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanPhone.length > 10) {
      cleanPhone = cleanPhone.substring(cleanPhone.length - 10);
    }

    print("🔍 Looking up Firestore user: $cleanPhone");

    final docSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(cleanPhone)
        .get();

    if (!docSnapshot.exists) {
      print("⚠️ User document NOT found");
      return;
    }

    final data = docSnapshot.data();
    final String? token = data?['fcmToken'];

    if (token == null || token.isEmpty) {
      print("⚠️ FCM token missing or empty");
      return;
    }

    print("📲 FCM Token found: ${token.substring(0, 20)}...");

    await NotificationService.sendOrderReadyNotification(
      token: token,
      orderId: orderId,
    );

    print("✅ Notification SENT to mobile app");
  } catch (e) {
    print("❌ Notification error: $e");
  }
}


  void markAsPrinted(Map<String, dynamic> order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Mark as Printed"),
        content: const Text("Send notification to user and mark locally?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes", style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        String? phone = order['phoneNumber'];
        String orderId = order['orderId']?.toString() ?? 'N/A';

        // Send Notification if phone exists
        if (phone != null && phone.isNotEmpty) {
          await triggerNotificationSequence(phone, orderId);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("✅ Order marked & Notification sent to $phone")),
            );
          }
        }
        refreshData();
        print("📦 Mark as Printed clicked → OrderId: $orderId | Phone: $phone");

      } catch (e) {
        debugPrint("❌ markAsPrinted error: $e");
      }
    }
  }

  void deleteOrder(Map<String, dynamic> order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Order"),
        content: const Text("Are you sure you want to delete this order?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final orderId = order['orderId'];
        final response = await http.delete(Uri.parse("$baseUrl/$orderId"));

        if (response.statusCode == 200 || response.statusCode == 204) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Order deleted $orderId"),
                backgroundColor: Colors.red.shade400,
              ),
            );
          }
          refreshData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Delete Failed: $e")));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      drawer: const CustomDrawer(),
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 1.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: const [
                      Icon(Icons.assignment_turned_in, size: 26, color: Colors.black87),
                      SizedBox(width: 8),
                      Text("Orders", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: refreshData,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Refresh"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // Live Orders Toggle
          Padding(
            padding: const EdgeInsets.only(right: 24, bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text('Live Orders', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _liveOrdersEnabled ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Switch(value: _liveOrdersEnabled, onChanged: toggleLiveOrder),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : buildOrderTable(_cachedOrders),
          ),
        ],
      ),
    );
  }

  Widget buildOrderTable(List<dynamic> orders) {
    if (orders.isEmpty) {
      return const Center(child: Text("No orders found."));
    }

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1200),
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateColor.resolveWith((_) => Colors.blue.shade50),
              border: TableBorder.all(color: Colors.black54),
              columnSpacing: 20,
              headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              columns: const [
                DataColumn(label: Text('Index')),
                DataColumn(label: Text('Order ID')),
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Phone')),
                DataColumn(label: Text('Mark as Printed')),
                DataColumn(label: Text('Date/Time')),
                DataColumn(label: Text('Delete')),
              ],
              rows: List.generate(orders.length, (index) {
                final order = orders[index];

                final orderId = order['orderId'] ?? 'N/A';
                final userName = order['userName'] ?? '-';
                final phoneNumber = order['phoneNumber'] ?? '-';
                final timestamp = order['timestamp']; 

                return DataRow(cells: [
                  DataCell(Text('${index + 1}')),
                  DataCell(
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OrderDetailPage(orderData: order),
                          ),
                        ),
                        child: Text(
                          orderId.toString(),
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ),
                  DataCell(Text(userName)),
                  DataCell(Text(phoneNumber)),
                  DataCell(
                    ElevatedButton(
                      onPressed: () => markAsPrinted(order),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('Mark as Printed', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ),
                  DataCell(Text(
                    formatTimestamp(timestamp),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  )),
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => deleteOrder(order),
                    ),
                  ),
                ]);
              }),
            ),
          ),
        ),
      ),
    );
  }
}
// only fix the notification problem mainly dont change the ui content ,functions 