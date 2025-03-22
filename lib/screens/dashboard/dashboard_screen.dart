import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text(
            'Dashboard',
            style: TextStyle(fontSize: 24),
          ),
          SizedBox(height: 20),
          Text('Welcome to the Sports App Dashboard'),
          SizedBox(height: 20),
          Text('Use the navigation drawer to explore the app'),
        ],
      ),
    );
  }
}