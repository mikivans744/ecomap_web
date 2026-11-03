import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/services/gemini_assistant_service.dart';

part 'gemini_assistant_provider.g.dart';

@riverpod
// ignore: deprecated_member_use_from_same_package
String geminiFunctionUrl(GeminiFunctionUrlRef ref) {
  return const String.fromEnvironment(
    'GEMINI_FUNCTION_URL',
    defaultValue:
        'https://us-central1-ecomap-ae07e.cloudfunctions.net/geminiChat',
  );
}

@riverpod
// ignore: deprecated_member_use_from_same_package
GeminiAssistantService geminiAssistant(GeminiAssistantRef ref) {
  final service = GeminiAssistantService(
    functionUrl: ref.watch(geminiFunctionUrlProvider),
  );
  ref.onDispose(service.dispose);
  return service;
}
