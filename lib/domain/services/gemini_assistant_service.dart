import 'package:google_generative_ai/google_generative_ai.dart';

abstract interface class GeminiAssistantService {
  bool get isConfigured;
  Future<String> ask(String prompt);
}

class NoopGeminiAssistantService implements GeminiAssistantService {
  const NoopGeminiAssistantService();

  @override
  bool get isConfigured => false;

  @override
  Future<String> ask(String prompt) async {
    return 'La integración con Gemini no está configurada. Añade la variable de entorno GEMINI_API_KEY.';
  }
}

class GeminiAssistantServiceImpl implements GeminiAssistantService {
  GeminiAssistantServiceImpl({
    required String apiKey,
    String model = 'gemini-2.0-flash',
  }) : _model = GenerativeModel(model: model, apiKey: apiKey);

  final GenerativeModel _model;

  @override
  bool get isConfigured => true;

  @override
  Future<String> ask(String prompt) async {
    final response = await _model.generateContent(
      [Content.text(prompt)],
    );

    return response.text ?? 'No se obtuvo respuesta de Gemini.';
  }
}
