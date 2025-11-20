import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Main App Screen'),
        backgroundColor: Colors.blue, // Ya koi aur color
      ),
      body: Center(
        child: Text(
          'Welcome to NearBuy',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}