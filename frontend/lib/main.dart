import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

void main() {
  runApp(const ZavrsniApp());
}

class ZavrsniApp extends StatelessWidget {
  const ZavrsniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Završni projekt',
      debugShowCheckedModeBanner: false,
      home: const BackendStatusPage(),
    );
  }
}

class BackendStatusPage extends StatefulWidget {
  const BackendStatusPage({super.key});

  @override
  State<BackendStatusPage> createState() => _BackendStatusPageState();
}

class _BackendStatusPageState extends State<BackendStatusPage> {
  String message = 'Povezivanje s backendom...';

  @override
  void initState() {
    super.initState();
    loadBackendStatus();
  }

  Future<void> loadBackendStatus() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/status/'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        setState(() {
          message = data['message']?.toString() ?? 'Backend radi';
        });
      } else {
        setState(() {
          message = 'Backend je vratio grešku: ${response.statusCode}';
        });
      }
    } catch (error) {
      setState(() {
        message = 'Nije moguće povezati se s backendom: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Završni projekt'),
      ),
      body: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}