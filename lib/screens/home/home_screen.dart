import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/route_names.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Home"), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.home, size: 90, color: Colors.blue),

            const SizedBox(height: 20),

            const Text(
              "Login Successful!",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            const Text(
              "Welcome to the Home Screen",
              style: TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 40),

            ElevatedButton.icon(
              onPressed: () {
                context.go(RouteNames.login);
              },
              icon: const Icon(Icons.logout),
              label: const Text("Logout"),
            ),
          ],
        ),
      ),
    );
  }
}
