import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/customappbar.dart';
import '../widgets/custom_drawer.dart';
import '../Service/notification_service.dart';
import 'order_details_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  late Future<void> _futureOrders;
  String _estimatedQueueTime = "Loading...";

  @override
  void initState() {
    super.initState();
    _futureOrders = Future.value();
    loadQueueEstimate();
  }

  void refreshData() {
    setState(() {
      _futureOrders = Future.value();
      loadQueueEstimate();
    });
  }

  // ✅ Accurate Time Estimation
 Future<void> loadQueueEstimate() async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('orders')
        .get(const GetOptions(source: Source.server)); // ✅ Force server to avoid cache

    final uniqueOrderIds = <String>{};
    int totalPages = 0;
    int totalCopies = 0;
    int specialBindingCount = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final orderId = data['orderID'];
      final pages = int.tryParse(data['pages']?.toString() ?? '0') ?? 0;
      final binding = (data['bindingType'] ?? '').toString().toLowerCase();

      // 🆕 Extract copies from 'files' array
      int copies = 0;
      if (data['files'] is List) {
        final files = List<Map<String, dynamic>>.from(data['files']);
        for (final file in files) {
          copies += int.tryParse(file['copies']?.toString() ?? '1') ?? 1;
        }
      }

      if (orderId != null && !uniqueOrderIds.contains(orderId)) {
        uniqueOrderIds.add(orderId);
        totalPages += pages;
        totalCopies += copies;

        if (binding.contains('spiral') || binding.contains('soft')) {
          specialBindingCount++;
        }
      }
    }

    final totalOrders = uniqueOrderIds.length;

    final totalSeconds = (totalOrders * 60) +
        (totalPages * 1) +
        (totalCopies * 15) +
        (specialBindingCount * 15 * 60);

    String formatted;
    if (totalSeconds >= 3600) {
      final hours = totalSeconds ~/ 3600;
      final minutes = (totalSeconds % 3600) ~/ 60;
      final seconds = totalSeconds % 60;
      formatted =
          "$hours hr${minutes > 0 ? ' $minutes min' : ''}${seconds > 0 ? ' $seconds sec' : ''}";
    } else if (totalSeconds >= 60) {
      final minutes = totalSeconds ~/ 60;
      final seconds = totalSeconds % 60;
      formatted = "$minutes min${seconds > 0 ? ' $seconds sec' : ''}";
    } else {
      formatted = "$totalSeconds sec";
    }

    setState(() {
      _estimatedQueueTime = formatted;
    });
  } catch (e) {
    setState(() {
      _estimatedQueueTime = "Error";
    });
    debugPrint("Error estimating queue time: $e");
  }
}

String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'No Timestamp';
    final dt = timestamp.toDate();
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }
void markAsPrinted(DocumentSnapshot order) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Mark as Printed"),
      content: const Text("Are you sure you want to mark this order as printed?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text("Yes", style: TextStyle(color: Colors.green)),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  try {
    final docRef = FirebaseFirestore.instance.collection('orders').doc(order.id);
    final snapshot = await docRef.get();
    final data = snapshot.data() as Map<String, dynamic>?;

    if (data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Order data not found.")),
      );
      return;
    }

    // Prevent re-marking
    final orderId = data['orderID'] ?? 'Unknown';
    final userId = data['userId'];

    debugPrint("🆔 userId from order: $userId");

    // ✅ Mark the order as printed in current doc
    await docRef.update({'printed': true});

    // ✅ Fetch the FCM token from users/<userId>
    String? fcmToken;
    if (userId != null && userId.toString().isNotEmpty) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId.toString())
          .get();

      if (userDoc.exists) {
        fcmToken = userDoc.data()?['fcmToken'];
        debugPrint("📲 fcmToken fetched: $fcmToken");
      } else {
        debugPrint("⚠️ User document not found for $userId");
      }
    }

    // ✅ Send the FCM push notification
    if (fcmToken != null && fcmToken.isNotEmpty) {
      try {
        await NotificationService.sendOrderReadyNotification(
          token: fcmToken,
          orderId: orderId,
        );
        debugPrint("✅ Notification sent to $fcmToken");
      } catch (e, stack) {
        debugPrint("❌ Notification sending failed: $e");
        debugPrint("📄 Stack trace: $stack");
      }
    } else {
      debugPrint("⚠️ No FCM token found for user: $userId");
    }

    // ✅ Move to 'order_history'
    final updatedData = Map<String, dynamic>.from(data);

    if (updatedData.containsKey('timestamp')) {
      updatedData['originalTimestamp'] = updatedData['timestamp'];
    }

    updatedData['timestamp'] = FieldValue.serverTimestamp();
    updatedData['printed'] = true;

    await FirebaseFirestore.instance.collection('order_history').add(updatedData);
    await docRef.delete();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Order $orderId marked as printed and moved.")),
    );

    refreshData();
  } catch (e, stack) {
    debugPrint("❌ markAsPrinted error: $e");
    debugPrint("📄 Stack trace: $stack");
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error: ${e.toString()}")),
    );
  }
}

 void deleteOrder(DocumentSnapshot order) async {
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
      final data = order.data() as Map<String, dynamic>;
      final orderId = data['orderID'] ?? 'Unknown';

      await FirebaseFirestore.instance.collection('orders').doc(order.id).delete();
     ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Row(
      children: [
        const Icon(Icons.delete, color: Colors.white),
        const SizedBox(width: 12),
        Text("Order deleted $orderId"),
      ],
    ),
    backgroundColor: Colors.red.shade400,
  ),
);

      refreshData();
    } catch (e) {
      debugPrint("Error deleting order: $e");
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      drawer: const CustomDrawer(),
      backgroundColor: const Color(0xFFF5F7FA),
      body: FutureBuilder(
        future: _futureOrders,
        builder: (context, _) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('orders').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final allDocs = snapshot.data!.docs;
              final uniqueMap = <String, DocumentSnapshot>{};

              for (var doc in allDocs) {
                final data = doc.data() as Map<String, dynamic>;
                final orderId = data['orderID'];
                if (orderId != null && !uniqueMap.containsKey(orderId)) {
                  uniqueMap[orderId] = doc;
                }
              }

              final uniqueDocs = uniqueMap.values.toList();
              uniqueDocs.sort((a, b) {
                final t1 = (a.data() as Map<String, dynamic>)['timestamp'];
                final t2 = (b.data() as Map<String, dynamic>)['timestamp'];
                final d1 = t1 is Timestamp ? t1.toDate() : DateTime(2100);
                final d2 = t2 is Timestamp ? t2.toDate() : DateTime(2100);
                return d1.compareTo(d2);
              });

              return Column(
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
                        Text(
                          "Estimate Time in Queue: ",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _estimatedQueueTime,
                          style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black, // Changed to black as per your request
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 16),
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
                  Expanded(
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 1000),
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
                              columnSpacing: 30,
                              headingTextStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              columns: const [
                                DataColumn(label: Text('Index')),
                                DataColumn(label: Text('Order ID')),
                                DataColumn(label: Text('Mark as Printed')),
                                DataColumn(label: Text('Date/Time')),
                                DataColumn(label: Text('Delete')),
                              ],
                              rows: List.generate(uniqueDocs.length, (index) {
                                final doc = uniqueDocs[index];
                                final data = doc.data() as Map<String, dynamic>;
                                final orderId = data['orderID'] ?? 'N/A';
                                final timestamp = data['timestamp'];

                                return DataRow(cells: [
                                  DataCell(Text('${index + 1}')),
                                  DataCell(
                                    MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: GestureDetector(
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => OrderDetailPage(orderData: data),
                                          ),
                                        ),
                                        child: Text(
                                          orderId,
                                          style: const TextStyle(
                                            color: Colors.blue,
                                            fontWeight: FontWeight.bold,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    ElevatedButton(
                                      onPressed: () => markAsPrinted(doc),
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
                                    style: const TextStyle(fontSize: 14),
                                  )),
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => deleteOrder(doc),
                                    ),
                                  ),
                                ]);
                              }),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
