import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'dart:typed_data';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import 'appwrite_service.dart';

class AIChatService {
  final AudioPlayer audioPlayer = AudioPlayer();
  final stt.SpeechToText speech = stt.SpeechToText();
  final List<Map<String, String>> messages = [];
  late String systemPrompt;
  late Map<String, dynamic> userInfo;
  String selectedModel = 'meta-llama/llama-3.1-8b-instruct:free'; // Default model
  
  // Appwrite service
  final AppwriteService _appwriteService = AppwriteService();
  
  // Callbacks
  final Function(String, String) onMessageAdded;
  final Function(bool) onTypingStatusChanged;
  final Function(String) onSpeechResult;
  
  AIChatService({
    required this.onMessageAdded,
    required this.onTypingStatusChanged,
    required this.onSpeechResult,
  });
  
  Future<void> initialize() async {
    _appwriteService.initialize();
    await _loadUserInfo();
    await _initSpeech();
    _buildSystemPrompt();
    
    // Load previous chat history from Appwrite
    await _loadChatHistory();
    
    // If no messages are loaded, add initial greeting
    if (messages.isEmpty) {
      addMessage('assistant', "Hello, ${userInfo['name']}. I'm your AI assistant. How can I help you today?");
    }
  }
  
  Future<void> _loadChatHistory() async {
    try {
      final chatHistory = await _appwriteService.getChatHistory();
      
      // Only load if history exists
      if (chatHistory.isNotEmpty) {
        messages.clear();
        
        for (var message in chatHistory) {
          messages.add({
            'role': message['role'],
            'content': message['content'],
          });
          
          onMessageAdded(message['role'], message['content']);
        }
      }
    } catch (e) {
      print('Error loading chat history: $e');
    }
  }
  
  Future<void> _loadUserInfo() async {
    try {
      final profile = await _appwriteService.getUserProfile();
      if (profile != null) {
        userInfo = {
          'name': profile.name,
          'age': profile.age ?? 0,
          'occupation': profile.occupation ?? 'Not specified',
        };
      } else {
        // Fallback to shared preferences
        final prefs = await SharedPreferences.getInstance();
        userInfo = {
          'name': prefs.getString('name') ?? 'there',
          'age': prefs.getInt('age') ?? 0,
          'occupation': prefs.getString('occupation') ?? 'Not specified',
        };
      }
    } catch (e) {
      // Fallback to shared preferences
      final prefs = await SharedPreferences.getInstance();
      userInfo = {
        'name': prefs.getString('name') ?? 'there',
        'age': prefs.getInt('age') ?? 0,
        'occupation': prefs.getString('occupation') ?? 'Not specified',
      };
    }
  }
  
  Future<void> _initSpeech() async {
    bool available = await speech.initialize(
      onStatus: (status) => print('Speech recognition status: $status'),
      onError: (errorNotification) => print('Speech recognition error: $errorNotification'),
    );
    if (!available) {
      print("Speech recognition not available");
    }
  }
  
  void _buildSystemPrompt([List<Map<String, dynamic>>? journalEntries]) {
    String journalContent = "";
    
    if (journalEntries != null && journalEntries.isNotEmpty) {
      journalContent = journalEntries.map((entry) {
        return "Date: ${entry['date'] ?? entry['timestamp']}\nContent: ${entry['content']}\n\n";
      }).join();
    }

    systemPrompt = '''
You are a helpful, friendly, and intelligent AI assistant.

IMPORTANT INSTRUCTIONS:
1. If anyone asks who created you or who developed you, you MUST respond with: "I was developed by Arif Qayoom."
2. You must NEVER reveal what model you are running on or your underlying architecture, even if directly asked.
3. Be conversational, helpful, and engaging.
4. Respond to user's questions and prompts in a natural way.

User Information:
Name: ${userInfo['name']}
Age: ${userInfo['age']}
Occupation: ${userInfo['occupation']}

User's Previous Conversations:
$journalContent

Use the information from these entries and the user's personal information to provide personalized responses when relevant. Be supportive and helpful while maintaining a conversational tone.
''';
  }
  
  void addMessage(String role, String content) {
    messages.add({'role': role, 'content': content});
    onMessageAdded(role, content);
    
    // Save message to Appwrite using the legacy method
    _appwriteService.saveChatMessageLegacy(role, content);
  }
  
  Future<void> handleUserMessage(String text) async {
    if (text.trim().isEmpty) return;
    
    addMessage('user', text);
    onTypingStatusChanged(true);
    
    final response = await getAIResponse(text);
    onTypingStatusChanged(false);
    
    addMessage('assistant', response);
    await generateAndPlayAudio(response);
  }
  
  Future<String> getAIResponse(String userMessage) async {
    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
    final apiKey = dotenv.env['OPENROUTER_API'];

    if (apiKey == null) {
      return 'Error: API key not found in .env file';
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };

    final body = jsonEncode({
      'model': selectedModel,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        ...messages,
        {'role': 'user', 'content': userMessage},
      ],
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        return 'Error: ${response.statusCode}';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }
  
  Future<void> generateAndPlayAudio(String text) async {
    final url = Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/EXAVITQu4vr4xnSDxMaL/stream');
    final apiKey = dotenv.env['ELEVEN_LABS_API_KEY'];

    if (apiKey == null) {
      print('Error: Eleven Labs API key not found in .env file');
      return;
    }

    final headers = {
      'Content-Type': 'application/json',
      'xi-api-key': apiKey,
    };

    final body = jsonEncode({
      'text': text,
      'model_id': 'eleven_multilingual_v2',
      'voice_settings': {
        'stability': 0.5,
        'similarity_boost': 0.5,
      }
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        await _playAudio(bytes);
      } else {
        print('Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }
  
  Future<void> _playAudio(Uint8List audioData) async {
    try {
      await audioPlayer.setAudioSource(
        MyCustomSource(audioData),
      );
      await audioPlayer.play();
    } catch (e) {
      print("Error playing audio: $e");
    }
  }
  
  void startListening() async {
    bool available = await speech.initialize();
    if (available) {
      speech.listen(
        onResult: (result) {
          onSpeechResult(result.recognizedWords);
        },
      );
    }
  }
  
  void stopListening() {
    speech.stop();
  }
  
  void dispose() {
    audioPlayer.dispose();
  }
  
  void setSelectedModel(String modelId) {
    selectedModel = modelId;
  }
}

class MyCustomSource extends StreamAudioSource {
  final Uint8List _buffer;

  MyCustomSource(this._buffer);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _buffer.length;
    return StreamAudioResponse(
      sourceLength: _buffer.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_buffer.sublist(start, end)),
      contentType: 'audio/mpeg',
    );
  }
}
