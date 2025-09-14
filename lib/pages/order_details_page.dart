import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudflare_r2/cloudflare_r2.dart';
import 'package:printing/printing.dart';
import '../Service/printer_check.dart'; // ✅ Import the printer check

class OrderDetailPage extends StatefulWidget {
  final Map<String, dynamic> orderData;
  const OrderDetailPage({super.key, required this.orderData});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  bool isLoading = true;
  bool hasError = false;

  static const accountId = "c066124110c7d4aa00b8e423e288d1c6";
  static const accessKeyId = "170f089e4646d57ca32a729ddf9eab14";
  static const secretAccessKey = "d9757111f8ab64edf2d81468c06e8845714df24dcaad17e59da93dffa588aad8";
  static const bucket = "testfiles";

  @override
  void initState() {
    super.initState();
    _initCloudflare();
  }

  Future<void> _initCloudflare() async {
    try {
      CloudFlareR2.init(
        accountId: accountId,
        accessKeyId: accessKeyId,
        secretAccessKey: secretAccessKey,
      );
    } catch (e) {
      debugPrint("Cloudflare init failed: $e");
      setState(() => hasError = true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  String _formatTs(Timestamp? ts) {
    if (ts == null) return 'N/A';
    return DateFormat('dd MMM yyyy, hh:mm a').format(ts.toDate());
  }

  Future<Directory> _getCustomDownloadFolder() async {
    final downloadsDir = await getDownloadsDirectory();
    final folder = Directory('${downloadsDir!.path}/RIT_XeroxShop');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return folder;
  }

  Future<Uint8List?> _fetchFileBytes(String rawName) async {
    final fileName = Uri.decodeFull(rawName.trim()).replaceAll('%20', ' ');
    final folder = await _getCustomDownloadFolder();
    final file = File('${folder.path}/$fileName');

    if (await file.exists()) {
      debugPrint("✅ Loaded from local cache: $fileName");
      return await file.readAsBytes();
    }

    final variants = {
      rawName.trim(),
      rawName.trim().replaceAll('%20', ' '),
      Uri.decodeFull(rawName.trim()),
    };

    for (final name in variants) {
      try {
        final bytes = await CloudFlareR2.getObject(bucket: bucket, objectName: name);
        if (bytes.isNotEmpty) {
          debugPrint("📡 Downloaded from Cloudflare: $name");
          await file.writeAsBytes(bytes); // Cache locally
          return Uint8List.fromList(bytes);
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> _downloadFile(String rawName) async {
    final fileName = Uri.decodeFull(rawName.trim()).replaceAll('%20', ' ');
    final folder = await _getCustomDownloadFolder();
    final file = File('${folder.path}/$fileName');

    if (await file.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Already downloaded: ${file.path}")),
      );
      return;
    }

    final bytes = await _fetchFileBytes(rawName);
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Download failed for $rawName")),
      );
      return;
    }

    try {
      await file.writeAsBytes(bytes);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Downloaded to: ${file.path}")),
      );
    } catch (e) {
      debugPrint("❌ Save failed: $e");
    }
  }

  Future<void> _downloadAndPrintAll(List<dynamic> files) async {
    try {
      final folder = await _getCustomDownloadFolder();

      final tasks = files.map((file) async {
        if (file is! Map || !file.containsKey('name')) {
          debugPrint("⚠️ Skipping invalid file data: $file");
          return;
        }

        final rawName = file['name']?.toString() ?? '';
        final fileName = Uri.decodeFull(rawName.trim()).replaceAll('%20', ' ');
        final filePath = '${folder.path}/$fileName';
        final fileToSave = File(filePath);

        Uint8List? bytes;

        if (await fileToSave.exists()) {
          debugPrint("✅ File cached locally: $fileName");
          bytes = await fileToSave.readAsBytes();
        } else {
          bytes = await _fetchFileBytes(rawName);
          if (bytes == null || bytes.isEmpty) {
            debugPrint("❌ Could not download: $rawName");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("❌ Could not print: $rawName")),
            );
            return;
          }

          await fileToSave.writeAsBytes(bytes);
          debugPrint("📦 Downloaded and saved: $fileName");
        }

        await Printing.layoutPdf(onLayout: (_) async => bytes!);
      }).toList();

      await Future.wait(tasks); // ⏱️ Parallel execution
    } catch (e) {
      debugPrint("❌ Print error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ USB not connected or failed to print")),
      );
    }
  }

  Widget buildDetailBox(String label, String? value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: RichText(
        text: TextSpan(
          text: '$label: ',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 16),
          children: [
            TextSpan(
              text: value ?? 'N/A',
              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildFileSummary(Map<String, dynamic> fileData, int index) {
    final rawName = fileData['name']?.toString() ?? '';
    final fileName = Uri.decodeFull(rawName.trim()).replaceAll('%20', ' ');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blueGrey.shade300, width: 1.5),
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFF8F9FB),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(1, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("📄 File ${index + 1}: $fileName", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 10),
          buildDetailBox("Color", fileData['color']),
          buildDetailBox("Side", fileData['sides']),
          buildDetailBox("Binding", fileData['binding']),
          buildDetailBox("Pages", fileData['pages']?.toString()),
          buildDetailBox("Copies", fileData['copies']?.toString()),
          const SizedBox(height: 8),
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text("Download PDF"),
              onPressed: () => _downloadFile(rawName),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple.shade100,
                foregroundColor: Colors.deepPurple,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.orderData;
    final files = data['files'] as List<dynamic>? ?? [];

    // ✅ Remove duplicate PDFs (based on 'name')
    final seen = <String>{};
    final uniqueFiles = files.where((file) {
      final name = file['name']?.toString() ?? '';
      if (seen.contains(name)) return false;
      seen.add(name);
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : hasError
              ? const Center(child: Text("Something went wrong while loading files."))
              : Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 80),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("🧾 Order Summary", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 20),
                                buildDetailBox("Order ID", data['orderID']),
                                buildDetailBox("Date/Time", _formatTs(data['originalTimestamp'] ?? data['timestamp'])),
                                const SizedBox(height: 16),
                                const Divider(thickness: 1),
                                const SizedBox(height: 8),
                                ...List.generate(uniqueFiles.length, (i) {
                                  return buildFileSummary(uniqueFiles[i] as Map<String, dynamic>, i);
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 20,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.print, color: Colors.black),
                          label: const Text("Print", style: TextStyle(color: Colors.black)),
                          onPressed: () {
                            final connected = isPrinterAvailable();
                            final message = connected
                                ? "✅ Printer is connected. Starting print..."
                                : "❌ Printer is not connected.";

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(message)),
                            );

                            if (connected) {
                              _downloadAndPrintAll(uniqueFiles);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
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
