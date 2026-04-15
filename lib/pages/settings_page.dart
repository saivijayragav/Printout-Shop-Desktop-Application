
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'orders_page.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  final _formKey = GlobalKey<FormState>();

  // 🔁 CHANGE THIS IF NEEDED
  final String baseUrl = "http://${dotenv.env['API_IP']}";

  final ScrollController _scrollController = ScrollController();

  // UI variables (unchanged names)
  double? printPrice, colorPrice, softPrice, spiralPrice;
  double? doubleSide, fourSide;

  String adminName = "Arcade Shop";
  String adminEmail = "admin@example.com";
  String adminPhone = "+91-XXXXXXXXXX";

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _isEditing = {
    'printPrice': false,
    'colorPrice': false,
    'softBindingPrice': false,
    'spiralBindingPrice': false,
    'doubleSide': false,
    'fourSide': false
  };

  final Map<String, String> _labelMap = {
    'printPrice': 'Print Price',
    'colorPrice': 'Color Price',
    'softBindingPrice': 'Soft Binding Price',
    'spiralBindingPrice': 'Spiral Binding Price',
    'doubleSide': 'Double Side Price',
    'fourSide': 'Four Side price'
  };

  @override
  void initState() {
    super.initState();

    _controllers['printPrice'] = TextEditingController();
    _controllers['colorPrice'] = TextEditingController();
    _controllers['softBindingPrice'] = TextEditingController();
    _controllers['spiralBindingPrice'] = TextEditingController();
    _controllers['doubleSide'] = TextEditingController();
    _controllers['fourSide'] = TextEditingController();

    _loadPrices();
  }

  // =============================
  // GET FROM SPRING BOOT
  // =============================
  Future<void> _loadPrices() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/api/settings/pricing"));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          printPrice = (data['rateBw1'] ?? 0).toDouble();
          doubleSide = (data['rateBw2'] ?? 0).toDouble();
          fourSide = (data['rateBw4'] ?? 0).toDouble();

          colorPrice = (data['rateColor1'] ?? 0).toDouble();
          spiralPrice = (data['costSpiral'] ?? 0).toDouble();
          softPrice = (data['costSoft'] ?? 0).toDouble();

          _controllers['printPrice']!.text = printPrice!.toStringAsFixed(2);
          _controllers['doubleSide']!.text = doubleSide!.toStringAsFixed(2);
          _controllers['fourSide']!.text = fourSide!.toStringAsFixed(2);
          _controllers['colorPrice']!.text = colorPrice!.toStringAsFixed(2);
          _controllers['spiralBindingPrice']!.text = spiralPrice!.toStringAsFixed(2);
          _controllers['softBindingPrice']!.text = softPrice!.toStringAsFixed(2);
        });
      } else {
        throw Exception("Server error ${response.statusCode}");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load settings: $e")),
      );
    }
  }

  // =============================
  // CONFIRM EDIT (LOCAL)
  // =============================
  Future<void> _confirmPriceChange(String key) async {
    final controller = _controllers[key];

    if (controller == null || controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a value first")),
      );
      return;
    }

    final value = double.tryParse(controller.text.trim());
    if (value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid price entered")),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Price Change'),
        content: Text('Are you sure you want to change ${_labelMap[key]} to ₹${value.toStringAsFixed(2)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        switch (key) {
          case 'printPrice':
            printPrice = value;
            break;
          case 'colorPrice':
            colorPrice = value;
            break;
          case 'softBindingPrice':
            softPrice = value;
            break;
          case 'spiralBindingPrice':
            spiralPrice = value;
            break;
          case 'doubleSide':
            doubleSide = value;
            break;
          case 'fourSide':
            fourSide = value;
            break;
        }
        _isEditing[key] = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_labelMap[key]} updated locally')),
      );
    }
  }

  Widget priceRow(String label, String key, double? currentValue) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
          SizedBox(
            width: 130,
            child: TextFormField(
              controller: _controllers[key],
              readOnly: !_isEditing[key]!,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: '₹ ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                suffixIcon: IconButton(
                  icon: Icon(_isEditing[key]! ? Icons.check : Icons.edit),
                  onPressed: () {
                    if (_isEditing[key]!) {
                      _confirmPriceChange(key);
                    } else {
                      setState(() => _isEditing[key] = true);
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =============================
  // PUT TO SPRING BOOT
  // =============================
  Future<void> _saveAll() async {
    final body = {
      'rateBw1': printPrice ?? 0,
      'rateBw2': doubleSide ?? 0,
      'rateBw4': fourSide ?? 0,
      'rateColor1': colorPrice ?? 0,
      'rateColor2': 0,
      'rateColor4': 0,
      'costSpiral': spiralPrice ?? 0,
      'costSoft': softPrice ?? 0,
    };
   
    try {
      final response = await http.put(
        Uri.parse("$baseUrl/api/settings/savepricing"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.body)),
        );
      } else {
        throw Exception("Server error ${response.statusCode}");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save settings: $e")),
      );
    }
  }

  // =============================
  // UI (UNCHANGED)
  // =============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text('Admin Settings', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const OrdersPage()),
          ),
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
          ),
          child: Form(
            key: _formKey,
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Admin Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Name: $adminName'),
                    Text('Email: $adminEmail'),
                    Text('Phone: $adminPhone'),
                    const Divider(height: 32),
                    const Text('Pricing', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    priceRow('Print Price', 'printPrice', printPrice),
                    priceRow('Color Price', 'colorPrice', colorPrice),
                    priceRow('Soft Binding Price', 'softBindingPrice', softPrice),
                    priceRow('Spiral Binding Price', 'spiralBindingPrice', spiralPrice),
                    priceRow('Double Side Price', 'doubleSide', doubleSide),
                    priceRow('Four Side price', 'fourSide', fourSide),
                    const SizedBox(height: 24),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _saveAll,
                        icon: const Icon(Icons.save),
                        label: const Text('Save Settings'),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }
}
