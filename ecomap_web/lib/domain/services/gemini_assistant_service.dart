import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../core/api/gemini_contract.dart';

class GeminiAssistantService {
  GeminiAssistantService({
    required this.functionUrl,
    http.Client? httpClient,
    Future<String?> Function()? getIdToken,
  })  : httpClient = httpClient ?? http.Client(),
        _getIdToken = getIdToken;

  final String functionUrl;
  final http.Client httpClient;
  final Future<String?> Function()? _getIdToken;

  Future<String> sendMessage(
    String message, {
    List<ChatMessage>? history,
  }) async {
    final token = await _getToken();
    if (token == null) {
      throw const GeminiAssistantException(
        'No se pudo obtener el token de autenticación.',
      );
    }

    final request = GeminiRequest(message: message, history: history);
    final response = await httpClient
        .post(
          Uri.parse(functionUrl),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(request.toJson()),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode == 401) {
      throw const GeminiAssistantException(
        'Token de autenticación inválido.',
      );
    }
    if (response.statusCode == 400) {
      throw const GeminiAssistantException('Solicitud inválida.');
    }
    if (response.statusCode != 200) {
      throw const GeminiAssistantException(
        'El asistente no está disponible.',
      );
    }

    final data = _decodeResponse(response.body);
    try {
      return GeminiResponse.fromJson(data).reply;
    } on FormatException {
      throw const GeminiAssistantException(
        'El asistente devolvió una respuesta con formato inválido.',
      );
    } on TypeError {
      throw const GeminiAssistantException(
        'El asistente devolvió una respuesta incompleta.',
      );
    }
  }

  Map<String, dynamic> _decodeResponse(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } on FormatException {
      throw const GeminiAssistantException(
        'El servidor devolvió una respuesta con formato inválido.',
      );
    }

    throw const GeminiAssistantException(
      'El servidor devolvió una respuesta con formato inválido.',
    );
  }

  Future<String?> _getToken() async {
    if (_getIdToken != null) {
      return _getIdToken();
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const GeminiAssistantException('Usuario no autenticado.');
    }

    return user.getIdToken();
  }

  void dispose() => httpClient.close();
}

class GeminiAssistantException implements Exception {
  const GeminiAssistantException(this.message);

  final String message;

  @override
  String toString() => message;
}
