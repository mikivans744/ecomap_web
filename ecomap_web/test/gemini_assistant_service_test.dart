import 'dart:convert';

import 'package:ecomap_web/core/api/gemini_contract.dart';
import 'package:ecomap_web/domain/services/gemini_assistant_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('GeminiAssistantService', () {
    test('sends Firebase token and returns the proxy reply', () async {
      Map<String, String>? requestHeaders;
      Map<String, dynamic>? requestBody;
      final client = MockClient((request) async {
        requestHeaders = request.headers;
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'reply': 'Respuesta de prueba', 'timestamp': 123}),
          200,
        );
      });
      final service = GeminiAssistantService(
        functionUrl: Uri.https('example.test', '/geminiChat').toString(),
        getIdToken: () async => 'firebase-id-token',
        httpClient: client,
      );

      final reply = await service.sendMessage('¿Qué hago con papel?');

      expect(reply, 'Respuesta de prueba');
      expect(requestHeaders?['authorization'], 'Bearer firebase-id-token');
      expect(requestHeaders?['content-type'], contains('application/json'));
      expect(requestBody, {'message': '¿Qué hago con papel?'});
      service.dispose();
    });

    test('sends prior turns as proxy-compatible history', () async {
      final requestBodies = <Map<String, dynamic>>[];
      final service = GeminiAssistantService(
        functionUrl: Uri.https('example.test', '/geminiChat').toString(),
        getIdToken: () async => 'firebase-id-token',
        httpClient: MockClient((request) async {
          requestBodies.add(
            jsonDecode(request.body) as Map<String, dynamic>,
          );
          return http.Response(
            jsonEncode({
              'reply': 'Respuesta ${requestBodies.length}',
              'timestamp': requestBodies.length,
            }),
            200,
          );
        }),
      );

      await service.sendMessage('Primera pregunta');
      await service.sendMessage('Seguimiento', history: [
        ChatMessage(role: 'user', text: 'Primera pregunta'),
        ChatMessage(role: 'model', text: 'Respuesta anterior'),
      ]);

      expect(requestBodies[1]['history'], [
        {'role': 'user', 'text': 'Primera pregunta'},
        {'role': 'model', 'text': 'Respuesta anterior'},
      ]);
      service.dispose();
    });

    test('does not send a request without an ID token', () async {
      var requestSent = false;
      final service = GeminiAssistantService(
        functionUrl: Uri.https('example.test', '/geminiChat').toString(),
        getIdToken: () async => null,
        httpClient: MockClient((_) async {
          requestSent = true;
          return http.Response('', 200);
        }),
      );

      await expectLater(
        service.sendMessage('Pregunta'),
        throwsA(isA<GeminiAssistantException>()),
      );
      expect(requestSent, isFalse);
      service.dispose();
    });

    test('surfaces proxy error responses', () async {
      final service = GeminiAssistantService(
        functionUrl: Uri.https('example.test', '/geminiChat').toString(),
        getIdToken: () async => 'firebase-id-token',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({'error': 'Administrator access is required.'}),
            403,
          ),
        ),
      );

      await expectLater(
        service.sendMessage('Pregunta'),
        throwsA(
          isA<GeminiAssistantException>().having(
            (error) => error.message,
            'message',
            'El asistente no está disponible.',
          ),
        ),
      );
      service.dispose();
    });
  });
}
