import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive/hive.dart';

import 'firebase_options.dart';
import 'core/routing/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  developer.log('Inicializando Firebase Web...', name: 'ecomap_web');

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  developer.log('Firebase Web inicializado', name: 'ecomap_web');
  developer.log(
    'Project ID: ${Firebase.app().options.projectId}',
    name: 'ecomap_web',
  );

  Hive.init(null);
  await Hive.openBox<dynamic>('admin_cache');
  await Hive.openBox<dynamic>('audit_logs');
  await Hive.openBox<dynamic>('admin_panel_config');

  runApp(
    const ProviderScope(
      child: EcomapWebApp(),
    ),
  );
}

class EcomapWebApp extends ConsumerWidget {
  const EcomapWebApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'ECOMAP Web',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        primaryColor: const Color(0xFF2E7D32),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
