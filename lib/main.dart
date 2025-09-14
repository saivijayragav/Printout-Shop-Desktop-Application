import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'pages/orders_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyD0oDjc489B4AmTYfmJfarpaFoX1rbVRt0",
      authDomain: "adminpanel-c5c41.firebaseapp.com",
      projectId: "adminpanel-c5c41",
      storageBucket: "adminpanel-c5c41.appspot.com",
      messagingSenderId: "254208556943",
      appId: "1:254208556943:web:3810247665b3af1347d5fa",
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OrdersPage(),
    );
  }
}
