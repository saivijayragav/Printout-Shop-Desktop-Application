import 'package:flutter/material.dart';
import '../pages/orders_page.dart';
import '../pages/order_history_page.dart';
import '../pages/settings_page.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.white),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/ritlogo.jpg',
                  height: 60,
                ),
                const SizedBox(height: 10),
                const Text(
                  "Admin Menu",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            title: const Text(
              "Orders",
              style: TextStyle(fontWeight: FontWeight.bold,color: Colors.black),
            ),
            leading: const Icon(Icons.assignment),
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const OrdersPage()),
            ),
          ),
          ListTile(
            title: const Text(
              "Orders History",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            leading: const Icon(Icons.history),
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const OrderHistoryPage()),
            ),
          ),
          ListTile(
            title: const Text(
              "Settings",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            leading: const Icon(Icons.settings),
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AdminSettingsPage()),
            ),
          ),
        ],
      ),
    );
  }
}
