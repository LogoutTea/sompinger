import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/device_provider.dart';
import 'screens/scan_screen.dart';
import 'services/ping_service.dart';
import 'package:dart_ping_ios/dart_ping_ios.dart';

void main() {
  DartPingIOS.register(); 
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DeviceProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key}); // Исправлено с super-параметрами

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Network Monitor',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key}); // Исправлено с super-параметрами

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late PingService _pingService;

  @override
  void initState() {
    super.initState();
    _pingService = PingService(Provider.of<DeviceProvider>(context, listen: false));
    _pingService.startMonitoring();
  }

  @override
  void dispose() {
    _pingService.stopMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Монитор сети')),
      body: const ScanScreen(),
    );
  }
}
