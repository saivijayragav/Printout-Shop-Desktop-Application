import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:cloudflare_r2/cloudflare_r2.dart';

// 🔌 Services & Config Page Import
import '../Service/printer_check.dart'; 
import 'printer_setup_page.dart'; // Ensure the path points to your Setup UI

class OrderDetailPage extends StatefulWidget {
  final Map<String, dynamic> orderData;
  const OrderDetailPage({super.key, required this.orderData});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  bool isLoading = true;
  bool hasError = false;
  late Map<String, dynamic> _orderDetails;

  // 🔐 Environment Variables
  static final accountId = dotenv.env['CLOUDFLARE_ACCOUNT_ID']!;
  static final accessKeyId = dotenv.env['CLOUDFLARE_ACCESS_KEY']!;
  static final secretAccessKey = dotenv.env['CLOUDFLARE_SECRET_KEY']!;
  static final bucket = dotenv.env['CLOUDFLARE_BUCKET']!;

  final String baseUrl = "http://${dotenv.env['API_IP']}/api/orders";

  @override
  void initState() {
    super.initState();
    _orderDetails = widget.orderData;
    _initCloudflare();
    _fetchOrderDetailsFromApi();
  }

  Future<void> _fetchOrderDetailsFromApi() async {
    final orderId = widget.orderData['orderId'] ?? widget.orderData['orderID'];
    if (orderId == null) return;

    try {
      final response = await http.get(Uri.parse('$baseUrl/$orderId'));
      if (response.statusCode == 200) {
        if (mounted) setState(() => _orderDetails = json.decode(response.body));
      }
    } catch (e) {
      debugPrint("❌ API Error: $e");
    }
  }

  Future<void> _initCloudflare() async {
    try {
      await CloudFlareR2.init(accountId: accountId, accessKeyId: accessKeyId, secretAccessKey: secretAccessKey);
    } catch (e) {
      setState(() => hasError = true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  String _formatTs(dynamic ts) {
    if (ts == null) return 'N/A';
    if (ts is String) {
      try {
        final dt = DateTime.parse(ts);
        return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
      } catch (e) {
        return ts;
      }
    }
    return 'N/A';
  }

  Future<Directory> _getCustomDownloadFolder() async {
    Directory? downloadsDir;
    try {
      if (Platform.isWindows) {
        downloadsDir = await getDownloadsDirectory();
      } else {
        downloadsDir = await getApplicationDocumentsDirectory();
      }
    } catch (e) {
      downloadsDir = await getApplicationDocumentsDirectory();
    }
    downloadsDir ??= await getApplicationDocumentsDirectory();

    final folder = Directory('${downloadsDir.path}\\RIT_XeroxShop');
    if (!await folder.exists()) await folder.create(recursive: true);
    return folder;
  }

  // 🧠 NEW: Fetch directly into memory from the Server (Bypass Local Folder)
  Future<Uint8List?> _fetchFileBytesFromR2(String rawName) async {
    final orderId = _orderDetails['orderId']?.toString() ?? _orderDetails['orderID']?.toString() ?? "";
    final variants = {"$orderId${rawName.trim()}", rawName.trim(), Uri.decodeFull(rawName.trim())};

    for (final name in variants) {
      try {
        debugPrint("☁️ Fetching fresh file from server: $name");
        final bytes = await CloudFlareR2.getObject(bucket: bucket, objectName: name);
        if (bytes.isNotEmpty) {
          return Uint8List.fromList(bytes); // Return directly to RAM
        }
      } catch (e) { 
        debugPrint("⚠️ Failed key: $name"); 
      }
    }
    return null;
  }

  // 🔥 UPDATED MAIN FUNCTION: Prints strictly from downloaded memory bytes
  Future<void> _downloadAndSilentPrint(List<dynamic> files) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 10),
            Text("Fetching & Routing Smart Job...", style: TextStyle(color: Colors.white, decoration: TextDecoration.none, fontSize: 14))
          ],
        ),
      ),
    );

    try {
      int totalJobsSent = 0;

      for (var fileData in files) {
        if (fileData is! Map) continue;
        
        final rawName = fileData['name']?.toString() ?? '';
        final int copies = int.tryParse(fileData['copies']?.toString() ?? '1') ?? 1;
        
        // 🧠 Extract Requirements
        final String reqColor = fileData['color']?.toString().toLowerCase() ?? '';
        final bool isColorJob = reqColor.contains('color') || reqColor.contains('colour');
        
        final String sides = fileData['sides']?.toString().toLowerCase() ?? '';
        final bool isDuplexJob = sides.contains('double') || sides.contains('back') || sides.contains('two');

        final String pagesStr = fileData['pages']?.toString() ?? fileData['pageCount']?.toString() ?? '1';
        final int documentPages = int.tryParse(pagesStr) ?? 1;

        // 1. FETCH EXACT FILE DIRECTLY INTO MEMORY (No Folder Checks)
        final bytes = await _fetchFileBytesFromR2(rawName);

        // 2. SEND TO SMART ROUTER
        if (bytes != null && bytes.isNotEmpty) {
          int sent = await PrinterChecker.printJobAutomated(
            bytes: bytes,
            isColor: isColorJob,
            isDuplex: isDuplexJob,
            copies: copies,
            documentPages: documentPages,
            jobNamePrefix: 'Job_${_orderDetails['orderId']}',
          );
          totalJobsSent += sent;
        } else {
          debugPrint("❌ Failed to fetch bytes from server for: $rawName");
        }
      }

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ Complete! Routed $totalJobsSent jobs directly from server."), backgroundColor: Colors.green));
      }

    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.of(context).pop();
      String errorMessage = e.toString().replaceAll("Exception:", "").trim();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ $errorMessage"), backgroundColor: Colors.redAccent, duration: const Duration(seconds: 5)));
      }
    }
  }

  // 💾 "Download Only" Button - Explicitly writes the fetched memory to disk
  Future<void> _downloadFileOnly(String rawName) async {
    try {
      final bytes = await _fetchFileBytesFromR2(rawName);
      if (bytes == null || bytes.isEmpty) throw Exception("Failed to fetch file from server.");

      final folder = await _getCustomDownloadFolder();
      String cleanNameLocal = rawName.split('/').last; 
      cleanNameLocal = Uri.decodeFull(cleanNameLocal.trim()).replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      
      final file = File('${folder.path}\\$cleanNameLocal');
      await file.writeAsBytes(bytes, flush: true);

      if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ Saved to: ${file.path}")));
          // Highlight the specific file in Windows Explorer
          if (Platform.isWindows) Process.run('explorer.exe', ['/select,', file.path]);
      }
    } catch (e) { 
      debugPrint("Download Error: $e"); 
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Download failed: $e"), backgroundColor: Colors.red));
    }
  }

  Widget buildDetailBox(String label, String? value) {
    if (value == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8), color: Colors.white),
      child: RichText(text: TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 16), children: [TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black))])),
    );
  }

  Widget buildFileSummary(Map<String, dynamic> fileData, int index) {
    final rawName = fileData['name']?.toString() ?? '';
    final fileName = Uri.decodeFull(rawName.trim()).replaceAll('%20', ' ');
    final String pages = fileData['pages']?.toString() ?? fileData['pageCount']?.toString() ?? 'N/A';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border.all(color: Colors.blueGrey.shade300, width: 1.5), borderRadius: BorderRadius.circular(12), color: const Color(0xFFF8F9FB), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(1, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("📄 File ${index + 1}: $fileName", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 10),
          buildDetailBox("Color", fileData['color']),
          buildDetailBox("Side", fileData['sides']),
          buildDetailBox("Pages", pages),
          buildDetailBox("Binding", fileData['binding']),
          buildDetailBox("Copies", fileData['copies']?.toString()),
          const SizedBox(height: 8),
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.download), label: const Text("Download Only"), onPressed: () => _downloadFileOnly(rawName), style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple.shade100, foregroundColor: Colors.deepPurple),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _orderDetails;
    final files = data['files'] as List<dynamic>? ?? [];
    final seen = <String>{};
    final uniqueFiles = files.where((file) {
      final name = file['name']?.toString() ?? '';
      if (seen.contains(name)) return false;
      seen.add(name); return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'), backgroundColor: Colors.blue, foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configure Printers',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const PrinterSetupPage()));
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : hasError
              ? const Center(child: Text("Error loading configuration."))
              : Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 80),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("🧾 Order Summary", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 20),
                            buildDetailBox("Order ID", data['orderId']?.toString()),
                            buildDetailBox("Date/Time", _formatTs(data['timestamp'])),
                            buildDetailBox("Name", data['userName']),
                            buildDetailBox("Phone", data['phoneNumber']),
                            const SizedBox(height: 16),
                            const Divider(thickness: 1),
                            ...List.generate(uniqueFiles.length, (i) => buildFileSummary(uniqueFiles[i] as Map<String, dynamic>, i)),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 20, left: 0, right: 0,
                      child: Center(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.print, color: Colors.black),
                          label: const Text("Smart Route & Print", style: TextStyle(color: Colors.black)),
                          onPressed: () => _downloadAndSilentPrint(uniqueFiles),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber, 
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}