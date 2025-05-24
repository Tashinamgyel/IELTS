// lib/widgets/interactive_text.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../language_setting.dart';

/// Helper function to clean text by removing extra whitespace, newlines, and tabs.
String cleanText(String input) {
  return input.replaceAll(RegExp(r'[\n\r\t]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Fetches the definition in English and the translation (in the target language)
/// for [word] using the ChatGPT API. The target language is read from LanguageSettings.
Future<Map<String, String>> fetchDefinitionAndTranslation(String word) async {
  final String targetLanguage = LanguageSettings.selectedLanguage;
  final String prompt =
      "Define the word \"$word\" in a concise manner in English, then on a new line, provide only its plain $targetLanguage translation preceded by '$targetLanguage:'.";
  final String apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
  const String apiUrl = 'https://api.openai.com/v1/chat/completions';

  final Map<String, dynamic> body = {
    'model': 'gpt-3.5-turbo',
    'messages': [
      {
        'role': 'system',
        'content': 'You are a helpful dictionary assistant.'
      },
      {
        'role': 'user',
        'content': prompt,
      }
    ],
    'temperature': 0.0,
    'max_tokens': 150,
  };

  final response = await http.post(
    Uri.parse(apiUrl),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    },
    body: jsonEncode(body),
  );

  if (response.statusCode == 200) {
    final decodedResponse = utf8.decode(response.bodyBytes);
    final data = jsonDecode(decodedResponse);
    final String rawResponse = data['choices'][0]['message']['content'] ?? "";
    final String marker = "$targetLanguage:";
    final int index = rawResponse.indexOf(marker);
    if (index >= 0) {
      final String definition = cleanText(rawResponse.substring(0, index));
      final String translation = cleanText(rawResponse.substring(index + marker.length));
      return {
        "definition": definition.isNotEmpty ? definition : "Definition not found.",
        "translation": translation.isNotEmpty ? translation : "Translation not found."
      };
    } else {
      return {
        "definition": cleanText(rawResponse).isNotEmpty ? cleanText(rawResponse) : "Definition not found.",
        "translation": "Translation not found."
      };
    }
  } else {
    return {
      "definition": "Definition not found.",
      "translation": "Translation not found."
    };
  }
}

class InteractiveText extends StatefulWidget {
  final String text;
  const InteractiveText({super.key, required this.text});

  @override
  _InteractiveTextState createState() => _InteractiveTextState();
}

class _InteractiveTextState extends State<InteractiveText> {
  /// Displays a frosted glass dialog showing the [word] along with its English definition
  /// and its translation in the target language.
  void showWordMeaning(String word) async {
    final Map<String, String> result = await fetchDefinitionAndTranslation(word);
    final String definition = result["definition"] ?? "Definition not found.";
    final String translation = result["translation"] ?? "Translation not found.";

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3), // Dim background.
      builder: (context) {
        return Center(
          child: IntrinsicWidth(
            child: Dialog(
              backgroundColor: Colors.white.withOpacity(0.95),
              insetPadding: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header row: word and translation separated by '|'
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          word,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '|',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          translation,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // English definition below.
                    Text(
                      definition,
                      style: const TextStyle(fontSize: 16, color: Colors.black),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close', style: TextStyle(color: Colors.blue),),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Split the provided text into individual words.
    final List<String> words = widget.text.split(' ');
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: words.map((word) {
        return GestureDetector(
          onLongPress: () => showWordMeaning(word),
          child: Text(
            "$word ",
            style: const TextStyle(color: Colors.black),
          ),
        );
      }).toList(),
    );
  }
}
