import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'orders_page.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});
  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  final _formKey = GlobalKey<FormState>();

  double? printPrice, colorPrice, softPrice, spiralPrice;
  double? singleSide, doubleSide, fourSide;
  bool _liveOrdersEnabled = true;

  String adminName = "Arcade Shop";
  String adminEmail = "admin@example.com";
  String adminPhone = "+91-XXXXXXXXXX";

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _isEditing = {
    'printPrice': false,
    'colorPrice': false,
    'softBindingPrice': false,
    'spiralBindingPrice': false,
    'singleSide': false,
    'doubleSide': false,
    'fourSide': false
  };

  final Map<String, String> _labelMap = {
    'printPrice': 'Print Price',
    'colorPrice': 'Color Price',
    'softBindingPrice': 'Soft Binding Price',
    'spiralBindingPrice': 'Spiral Binding Price',
    'singleSide': 'Single side Price',
    'doubleSide': 'Double Side Price',
    'fourSide': 'Four Side price'
  };

  @override
  void initState() {
    super.initState();
    _loadPrices();
  }

  void _loadPrices() async {
    final snapshot = await FirebaseFirestore.instance.collection('settings').doc('pricing').get();
    final data = snapshot.data();

    if (data != null) {
      setState(() {
        printPrice = (data['printPrice'] ?? 0).toDouble();
        colorPrice = (data['colorPrice'] ?? 0).toDouble();
        softPrice = (data['softBindingPrice'] ?? 0).toDouble();
        spiralPrice = (data['spiralBindingPrice'] ?? 0).toDouble();
        
        doubleSide = (data['doubleSide'] ?? 0).toDouble();
        fourSide = (data['fourSide'] ?? 0).toDouble();
        _liveOrdersEnabled = (data['liveOrdersEnabled'] ?? true);

        _controllers['printPrice'] = TextEditingController(text: printPrice!.toStringAsFixed(2));
        _controllers['colorPrice'] = TextEditingController(text: colorPrice!.toStringAsFixed(2));
        _controllers['softBindingPrice'] = TextEditingController(text: softPrice!.toStringAsFixed(2));
        _controllers['spiralBindingPrice'] = TextEditingController(text: spiralPrice!.toStringAsFixed(2));
        // _controllers['singleSide'] = TextEditingController(text: singleSide!.toStringAsFixed(2));
        _controllers['doubleSide'] = TextEditingController(text: doubleSide!.toStringAsFixed(2));
        _controllers['fourSide'] = TextEditingController(text: fourSide!.toStringAsFixed(2));
      });
    }
  }

  Future<void> _confirmPriceChange(String key) async {
    final value = double.tryParse(_controllers[key]!.text.trim());
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
          case 'printPrice': printPrice = value; break;
          case 'colorPrice': colorPrice = value; break;
          case 'softBindingPrice': softPrice = value; break;
          case 'spiralBindingPrice': spiralPrice = value; break;
          // case 'singleSide': singleSide = value; break;
          case 'doubleSide': doubleSide = value; break;
          case 'fourSide': fourSide = value; break;
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
              validator: (v) {
                if (double.tryParse(v ?? '') == null) return 'Invalid';
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAll() async {
    await FirebaseFirestore.instance.collection('settings').doc('pricing').set({
      'printPrice': printPrice ?? 0,
      'colorPrice': colorPrice ?? 0,
      'softBindingPrice': softPrice ?? 0,
      'spiralBindingPrice': spiralPrice ?? 0,
      // 'singleSide': singleSide ?? 0,
      'doubleSide': doubleSide ?? 0,
      'fourSide': fourSide ?? 0,
      'liveOrdersEnabled': _liveOrdersEnabled, // Save toggle state
    }, SetOptions(merge: true));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("All settings saved to Firebase")),
    );
  }

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
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Admin Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Name: $adminName', style: const TextStyle(color: Colors.black87)),
                  Text('Email: $adminEmail', style: const TextStyle(color: Colors.black87)),
                  Text('Phone: $adminPhone', style: const TextStyle(color: Colors.black87)),
                  const Divider(height: 32),
                  const Text('Pricing', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  priceRow('Print Price', 'printPrice', printPrice),
                  priceRow('Color Price', 'colorPrice', colorPrice),
                  priceRow('Soft Binding Price', 'softBindingPrice', softPrice),
                  priceRow('Spiral Binding Price', 'spiralBindingPrice', spiralPrice),
                  // priceRow('Single side Price', 'singleSide', singleSide),
                  priceRow('Double Side Price', 'doubleSide', doubleSide),
                  priceRow('Four Side price', 'fourSide', fourSide),
                  const SizedBox(height: 24),
                 
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _saveAll,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Settings'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
