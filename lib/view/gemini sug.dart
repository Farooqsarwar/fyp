import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GeminiInsightsScreen extends StatefulWidget {
  final String imageUrl;
  final String title;
  final bool isArt;

  const GeminiInsightsScreen({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.isArt,
  });

  @override
  State<GeminiInsightsScreen> createState() => _GeminiInsightsScreenState();
}

class _GeminiInsightsScreenState extends State<GeminiInsightsScreen> {
  String? _geminiResponse;
  bool _isLoading = true;
  String? _validationError;
  bool _isRelevant = true;

  @override
  void initState() {
    super.initState();
    _validateAndFetch();
  }

  Future<void> _validateAndFetch() async {
    // First validate image exists
    if (!await _validateImageUrl()) {
      setState(() {
        _validationError = "Invalid image URL";
        _isLoading = false;
      });
      return;
    }

    // Then validate image content
    if (!await _validateImageContent()) {
      setState(() {
        _isRelevant = false;
        _isLoading = false;
      });
      return;
    }

    // If validations pass, fetch suggestions
    await _fetchGeminiSuggestions();
  }

  Future<bool> _validateImageUrl() async {
    try {
      final response = await http.head(Uri.parse(widget.imageUrl));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _validateImageContent() async {
    const apiKey = "AIzaSyCuUj8UFsH6GsWXxPcxzO4Koy8XUWjfjtA";
    final prompt = "Analyze this image and respond with ONLY 'art', 'furniture' or 'irrelevant'. "
        "Determine if this is clearly: "
        "1) An artwork (painting, sculpture, etc) "
        "2) A furniture item "
        "3) Neither (irrelevant)";

    try {
      final imageResponse = await http.get(Uri.parse(widget.imageUrl));
      final requestBody = {
        "contents": [{
          "parts": [
            {"text": prompt},
            {
              "inline_data": {
                "mime_type": "image/jpeg",
                "data": base64Encode(imageResponse.bodyBytes)
              }
            }
          ]
        }]
      };

      final uri = Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey");
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final text = decoded['candidates']?[0]?['content']?['parts']?[0]?['text']?.toLowerCase().trim();

        // Check if image matches our expected category
        if (widget.isArt) {
          return text == "art";
        } else {
          return text == "furniture";
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _fetchGeminiSuggestions() async {
    const apiKey = "AIzaSyCuUj8UFsH6GsWXxPcxzO4Koy8XUWjfjtA";
    final prompt = widget.isArt
        ? "Generate a realistic auction description for this artwork. Include:\n"
        "- Art style and period (be conservative in attribution)\n"
        "- Materials and condition (be objective)\n"
        "- Suggested FAIR MARKET price range in USD and PKR "
        "(be conservative, format: USD X-XX / PKR X,XXX-XX,XXX)\n"
        "- Three practical selling points"
        : "Generate a realistic furniture auction listing. Include:\n"
        "- Style and materials (avoid overstatement)\n"
        "- Suggested REASONABLE price range in USD and PKR "
        "(middle-market estimate, format: USD X-XX / PKR X,XXX-XX,XXX)\n"
        "- Three honest selling points";

    try {
      final imageResponse = await http.get(Uri.parse(widget.imageUrl));
      final requestBody = {
        "contents": [{
          "parts": [
            {"text": prompt},
            {
              "inline_data": {
                "mime_type": "image/jpeg",
                "data": base64Encode(imageResponse.bodyBytes)
              }
            }
          ]
        }]
      };

      final uri = Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey");
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final text = decoded['candidates']?[0]?['content']?['parts']?[0]?['text'];
        setState(() {
          _geminiResponse = _formatResponse(text ?? "No insights generated.");
          _isLoading = false;
        });
      } else {
        throw Exception('API request failed');
      }
    } catch (e) {
      setState(() {
        _geminiResponse = "Failed to generate insights: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  String _formatResponse(String response) {
    return response
        .replaceAllMapped(
        RegExp(r'USD\s[\d,]+-[\d,]+'),
            (match) => '💰 USD ${match.group(0)?.substring(4) ?? ''}')
        .replaceAllMapped(
        RegExp(r'PKR\s[\d,]+-[\d,]+'),
            (match) => '💰 PKR ${match.group(0)?.substring(4) ?? ''}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('AI Suggestions', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.yellow),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.yellow))
          : _validationError != null
          ? Center(
        child: Text(
          _validationError!,
          style: const TextStyle(color: Colors.red, fontSize: 18),
        ),
      )
          : !_isRelevant
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 50),
            const SizedBox(height: 20),
            Text(
              widget.isArt
                  ? "This doesn't appear to be valid artwork"
                  : "This doesn't appear to be furniture",
              style: const TextStyle(color: Colors.red, fontSize: 18),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Try Another Image'),
            ),
          ],
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Image.network(
                  widget.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.error, color: Colors.red, size: 50),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.title,
                style: const TextStyle(
                    color: Colors.yellow,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Text(
                'Gemini Suggestions:',
                style: TextStyle(
                    color: Colors.yellow,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                _geminiResponse ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}