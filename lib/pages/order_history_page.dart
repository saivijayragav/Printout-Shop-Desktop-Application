import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'orders_page.dart';
import '../pages/order_details_page.dart';
import 'package:intl/intl.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  String searchQuery = '';
  
  get refreshData => null;

  void moveToOrders(BuildContext context, DocumentSnapshot doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Move to Orders"),
        content: const Text("Do you want to move this order back to Orders?"),
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
        await FirebaseFirestore.instance.collection('orders').add(doc.data() as Map<String, dynamic>);
        await FirebaseFirestore.instance.collection('order_history').doc(doc.id).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Moved back to Orders')),
        );
      } catch (e) {
        debugPrint("Error moving order: $e");
      }
    }
  }

  void deleteOrder(BuildContext context, DocumentSnapshot doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Order"),
        content: const Text("Are you sure you want to delete this order permanently?"),
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
        await FirebaseFirestore.instance.collection('order_history').doc(doc.id).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order deleted')),
        );
      } catch (e) {
        debugPrint("Error deleting order: $e");
      }
    }
  }

  bool matchesSearch(Map<String, dynamic> data) {
    final query = searchQuery.toUpperCase();
    final orderId = data['orderID']?.toString().toUpperCase() ?? '';
    return orderId.contains(query);
  }

  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'No Timestamp';
    final dt = timestamp.toDate();
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.history, size: 26, color: Colors.black),
            SizedBox(width: 8),
            Text(
              "Order History",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const OrdersPage()),
          ),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
  padding: const EdgeInsets.fromLTRB(16, 16, 24, 4),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      ElevatedButton.icon(
        onPressed: () => setState(() {}), // refresh StreamBuilder
        icon: const Icon(Icons.refresh),
        label: const Text("Refresh"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange.shade700,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      SizedBox(
        width: 200,
        child: TextField(
          maxLength: 4,
          onChanged: (value) {
            if (RegExp(r'^[a-zA-Z0-9]{0,4}$').hasMatch(value)) {
              setState(() => searchQuery = value);
            }
          },
          decoration: InputDecoration(
            counterText: '',
            hintText: 'Search Order ID',
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(Icons.search),
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
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
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('order_history')
                      .orderBy('timestamp')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const CircularProgressIndicator();

                    final allDocs = snapshot.data!.docs;
                    final docs = allDocs.where((doc) => matchesSearch(doc.data() as Map<String, dynamic>)).toList();

                    if (docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text("No order history found."),
                      );
                    }

                    return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 800),
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
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Date/Time')),
                              DataColumn(label: Text('Restore')),
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
                                const DataCell(
                                  Text('Completed', style: TextStyle(color: Colors.green)),
                                ),
                                DataCell(Text(formatTimestamp(timestamp))),
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.restore, color: Colors.orange),
                                    onPressed: () => moveToOrders(context, doc),
                                  ),
                                ),
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => deleteOrder(context, doc),
                                  ),
                                ),
                              ]);
                            }),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
