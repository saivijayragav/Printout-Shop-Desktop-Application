import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final isReturning = true; // Replace with SharedPreferences logic if needed
    final message = isReturning
        ? '😎 Welcome back, Admin!'
        : ' 😊 Welcome, Admin!';

    return AppBar(
      backgroundColor: Colors.blue,
      titleSpacing: 0,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 12.0, top: 10),
                child: CircleAvatar(
                  backgroundImage: AssetImage('assets/Xeroxshoplogo.png'),
                  radius: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  "RIT Xerox Shop",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
               
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(70);
}
