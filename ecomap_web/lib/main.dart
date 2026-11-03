import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: EcomapWebApp()));
}

class EcomapWebApp extends ConsumerStatefulWidget {
  const EcomapWebApp({super.key});

  @override
  ConsumerState<EcomapWebApp> createState() => _EcomapWebAppState();
}

class _EcomapWebAppState extends ConsumerState<EcomapWebApp> {
  late Future<void> _firebaseInitialization;

  @override
  void initState() {
    super.initState();
    _firebaseInitialization = _initializeFirebase();
  }

  Future<void> _initializeFirebase() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Firebase Core',
          context: ErrorDescription(
            'No se pudo inicializar Firebase para ECOMAP Web.',
          ),
        ),
      );
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _firebaseInitialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            title: 'ECOMAP Web',
            theme: AppTheme.lightTheme,
            home: const LoadingScreen(),
          );
        }

        if (snapshot.hasError) {
          return MaterialApp(
            title: 'ECOMAP Web',
            theme: AppTheme.lightTheme,
            home: FirebaseInitializationErrorScreen(
              onRetry: () => setState(
                () => _firebaseInitialization = _initializeFirebase(),
              ),
            ),
          );
        }

        return MaterialApp.router(
          title: 'ECOMAP Web',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          routerConfig: ref.watch(appRouterProvider),
        );
      },
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.eco_rounded, size: 64),
            SizedBox(height: 20),
            Text('Cargando ECOMAP...'),
            SizedBox(height: 16),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class FirebaseInitializationErrorScreen extends StatelessWidget {
  const FirebaseInitializationErrorScreen({
    required this.onRetry,
    super.key,
  });

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48),
              const SizedBox(height: 16),
              const Text('No se pudo conectar con Firebase.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
