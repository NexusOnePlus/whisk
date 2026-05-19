import 'package:flutter/material.dart';
import 'package:whisk/data/services/app_window_service.dart';
import 'package:whisk/ui/core/app_frame.dart';
import 'package:whisk/ui/core/whisk_theme.dart';
import 'package:whisk/ui/features/app_shell/views/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await const AppWindowService().initialize();
  runApp(const WhiskApp());
}

class WhiskApp extends StatelessWidget {
  const WhiskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Whisk',
      debugShowCheckedModeBanner: false,
      theme: buildWhiskTheme(),
      home: const AppFrame(child: AppShell()),
    );
  }
}
