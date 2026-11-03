class GeminiRequest {
  final String message;
  final List<ChatMessage>? history;

  GeminiRequest({required this.message, this.history});

  Map<String, dynamic> toJson() => {
        'message': message,
        if (history != null)
          'history': history!.map((message) => message.toJson()).toList(),
      };
}

class ChatMessage {
  final String role;
  final String text;

  ChatMessage({required this.role, required this.text});

  Map<String, dynamic> toJson() => {'role': role, 'text': text};
}

class GeminiResponse {
  final String reply;
  final int timestamp;

  GeminiResponse({required this.reply, required this.timestamp});

  factory GeminiResponse.fromJson(Map<String, dynamic> json) {
    return GeminiResponse(
      reply: json['reply'] as String,
      timestamp: json['timestamp'] as int,
    );
  }
}
