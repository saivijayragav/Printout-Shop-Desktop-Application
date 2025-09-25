// Add this import at the top if not present
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
  bool _liveOrdersEnabled = true;
  List<DocumentSnapshot> _cachedOrders = [];

  @override
  void initState() {
    super.initState();
    fetchLiveOrderToggle();
  }

  void fetchLiveOrderToggle() async {
    final doc = await FirebaseFirestore.instance.collection('settings').doc('config').get();
    if (doc.exists) {
      final data = doc.data();
      if (data != null && data['liveOrdersEnabled'] != null) {
        setState(() {
          _liveOrdersEnabled = data['liveOrdersEnabled'] as bool;
        });
      }
    }
  }

  void toggleLiveOrder(bool value) async {
    setState(() => _liveOrdersEnabled = value);
    await FirebaseFirestore.instance
        .collection('settings')
        .doc('config')
        .set({'liveOrdersEnabled': value}, SetOptions(merge: true));
  }

  void refreshData() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .orderBy('timestamp')
          .get();

      setState(() {
        _cachedOrders = snapshot.docs;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _liveOrdersEnabled = false; // turn off live updates
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "An error occurred while fetching orders. Live orders disabled."),
          ),
        );
      }
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
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
      final data = snapshot.data();

      if (data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Order data not found.")),
        );
        return;
      }

      final orderId = data['orderID'] ?? 'Unknown';
      final userId = data['userId'];

      await docRef.update({'printed': true});

      String? fcmToken;
      if (userId != null && userId.toString().isNotEmpty) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId.toString()).get();
        if (userDoc.exists) {
          fcmToken = userDoc.data()?['fcmToken'];
        }
      }

      if (fcmToken != null && fcmToken.isNotEmpty) {
        try {
          await NotificationService.sendOrderReadyNotification(token: fcmToken, orderId: orderId);
        } catch (_) {}
      }

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

  List<DocumentSnapshot> filterAndSortOrders(List<DocumentSnapshot> allDocs) {
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

    return uniqueDocs;
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
            child: _liveOrdersEnabled
                ? StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('orders').orderBy('timestamp').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                      // Turn off live orders
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            _liveOrdersEnabled = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Firestore limits exceeded. Live orders turned off.",
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      });

                      return buildOrderTable(_cachedOrders);
                        }
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final docs = snapshot.data!.docs;
                      _cachedOrders = docs; // cache latest data
                      return buildOrderTable(docs);
                    },
                  )
                : buildOrderTable(_cachedOrders),
          ),
        ],
      ),
    );
  }

  Widget buildOrderTable(List<DocumentSnapshot> docs) {
    return Center(
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
              headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              columns: const [
                DataColumn(label: Text('Index')),
                DataColumn(label: Text('Order ID')),
                DataColumn(label: Text('Mark as Printed')),
                DataColumn(label: Text('Date/Time')),
                DataColumn(label: Text('Delete')),
              ],
              rows: List.generate(docs.length, (index) {
                final doc = docs[index];
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
    );
  }
}
