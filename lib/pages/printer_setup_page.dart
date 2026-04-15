import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../Service/printer_check.dart'; // Ensure this path matches your project structure

class PrinterSetupPage extends StatefulWidget {
  const PrinterSetupPage({super.key});

  @override
  State<PrinterSetupPage> createState() => _PrinterSetupPageState();
}

class _PrinterSetupPageState extends State<PrinterSetupPage> {
  List<Printer> _systemPrinters = [];
  List<PrinterConfig> _savedConfigs = [];
  bool _isLoading = true;

  Printer? _selectedPrinter;
  bool _isColor = false;
  bool _supportsDuplex = false;
  final TextEditingController _ppmController = TextEditingController(text: "20");

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    try {
      final allPrinters = await Printing.listPrinters();
      _systemPrinters = allPrinters.where((p) {
        final lower = p.name.toLowerCase();
        return !lower.contains("pdf") && !lower.contains("fax") && !lower.contains("onenote");
      }).toList();
      _savedConfigs = await PrinterChecker.loadConfigs();
    } catch (e) {
      debugPrint("Error loading printers: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePrinter() async {
    if (_selectedPrinter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Please select a physical printer first!")),
      );
      return;
    }
    final config = PrinterConfig(
      osPrinterName: _selectedPrinter!.name,
      isColor: _isColor,
      supportsDuplex: _supportsDuplex,
      speedPpm: int.tryParse(_ppmController.text) ?? 20,
    );

    await PrinterChecker.saveConfig(config);
    await _initData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Printer configured successfully!"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    setState(() {
      _selectedPrinter = null;
      _isColor = false;
      _supportsDuplex = false;
      _ppmController.text = "20";
    });
  }

  Future<void> _deletePrinter(String name) async {
    await PrinterChecker.deleteConfig(name);
    await _initData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🗑️ Printer removed."),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9), // Modern subtle background
      appBar: AppBar(
        title: const Text(
          "Printer Configuration",
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.indigo.shade600),
                  const SizedBox(height: 16),
                  const Text("Scanning for hardware...", style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(20.0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // 🟢 ADD NEW PRINTER FORM
                        const Text(
                          "Add Hardware Route",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87),
                        ),
                        const SizedBox(height: 12),
                        _buildConfigurationForm(),

                        const SizedBox(height: 32),

                        // 🔵 ACTIVE ROUTES SECTION
                        Row(
                          children: [
                            const Text(
                              "Active Routing Network",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.indigo.shade100, borderRadius: BorderRadius.circular(20)),
                              child: Text(
                                "${_savedConfigs.length} Configured",
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo.shade800),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 16),
                        _savedConfigs.isEmpty
                            ? _buildEmptyState()
                            : _buildActiveRoutesList(),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ==========================================
  // UI WIDGET BUILDERS
  // ==========================================

  Widget _buildConfigurationForm() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🖨️ Printer Selection Dropdown
          DropdownButtonFormField<Printer>(
            decoration: InputDecoration(
              labelText: "Select Physical Printer",
              labelStyle: TextStyle(color: Colors.indigo.shade300),
              prefixIcon: Icon(Icons.print_rounded, color: Colors.indigo.shade400),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.indigo.shade400, width: 2)),
            ),
            value: _selectedPrinter,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            items: _systemPrinters.map((p) => DropdownMenuItem(value: p, child: Text(p.name, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (val) => setState(() => _selectedPrinter = val),
            isExpanded: true,
          ),
          const SizedBox(height: 20),

          // ⚙️ Features Row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text("Supports Color", style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: const Text("Can print in CMYK/RGB", style: TextStyle(fontSize: 12)),
                  secondary: Icon(Icons.color_lens_rounded, color: _isColor ? Colors.pink : Colors.grey),
                  activeColor: Colors.pink,
                  value: _isColor,
                  onChanged: (val) => setState(() => _isColor = val),
                ),
                const Divider(height: 1, indent: 20, endIndent: 20),
                SwitchListTile(
                  title: const Text("Supports Duplex", style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: const Text("Can print on both sides", style: TextStyle(fontSize: 12)),
                  secondary: Icon(Icons.file_copy_rounded, color: _supportsDuplex ? Colors.teal : Colors.grey),
                  activeColor: Colors.teal,
                  value: _supportsDuplex,
                  onChanged: (val) => setState(() => _supportsDuplex = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ⚡ Speed Input
          TextFormField(
            controller: _ppmController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: "Print Speed (Pages Per Minute)",
              prefixIcon: Icon(Icons.speed_rounded, color: Colors.amber.shade700),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.indigo.shade400, width: 2)),
            ),
          ),
          const SizedBox(height: 24),

          // 💾 Save Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_circle_outline_rounded, size: 24),
              label: const Text("Register Printer", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              onPressed: _savePrinter,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade600,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRoutesList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _savedConfigs.length,
      itemBuilder: (context, index) {
        final config = _savedConfigs[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: config.isColor ? Colors.pink.shade50 : Colors.indigo.shade50, 
                shape: BoxShape.circle,
              ),
              child: Icon(
                config.isColor ? Icons.color_lens_rounded : Icons.print_rounded,
                color: config.isColor ? Colors.pink : Colors.indigo,
                size: 26,
              ),
            ),
            title: Text(config.osPrinterName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Row(
                children: [
                  _buildBadge(Icons.speed, "${config.speedPpm} PPM", Colors.orange),
                  const SizedBox(width: 8),
                  if (config.supportsDuplex) _buildBadge(Icons.layers_rounded, "Duplex", Colors.teal),
                ],
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              tooltip: "Remove Printer",
              onPressed: () => _deletePrinter(config.osPrinterName),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBadge(IconData icon, String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade50, 
        borderRadius: BorderRadius.circular(6), 
        border: Border.all(color: color.shade100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.shade700),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color.shade700)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(Icons.print_disabled_rounded, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("No Printers Configured", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 8),
          const Text("Add a printer above to enable smart automated job routing.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}