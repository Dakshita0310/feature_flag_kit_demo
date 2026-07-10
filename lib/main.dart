import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/bootstrap.dart';
import 'src/providers/config_providers.dart';
import 'src/ui/home_screen.dart';

Future<void> main() async {
  final deps = await bootstrap();
  runApp(
    ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWithValue(deps.controller),
        mockRepositoryProvider.overrideWithValue(deps.repository),
      ],
      child: const DemoApp(),
    ),
  );
}

/// Root widget of the demo client.
class DemoApp extends StatelessWidget {
  /// Creates the app.
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Feature Flag Kit Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const HomeScreen(),
    );
  }
}
