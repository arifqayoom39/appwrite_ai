import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'models/chat_models.dart';
import 'models/chat_session_model.dart';
import 'models/chat_message_model.dart';
import 'services/ai_chat_service.dart';
import 'services/appwrite_service.dart';

class ChatScreen extends StatefulWidget {
  final ChatSessionModel? chatSession;
  final List<ChatMessageModel>? initialMessages;
  final List<Map<String, dynamic>>? journalEntries;

  const ChatScreen({
    Key? key, 
    this.chatSession,
    this.initialMessages,
    this.journalEntries,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Map<String, String>> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isListening = false;
  bool _isAssistantTyping = false;
  bool _isInitialized = false;
  bool _showSendButton = false;
  
  late AIChatService _chatService;
  final AppwriteService _appwriteService = AppwriteService();
  
  ChatSessionModel? _activeSession;
  String _selectedModel = 'meta-llama/llama-3.1-8b-instruct:free';
  String _chatTitle = 'New chat';

  @override
  void initState() {
    super.initState();
    _activeSession = widget.chatSession;
    
    if (widget.initialMessages != null && widget.initialMessages!.isNotEmpty) {
      // Load initial messages if provided
      for (var msg in widget.initialMessages!) {
        _messages.add({
          'role': msg.role,
          'content': msg.content,
        });
      }
      
      // Set the selected model from the session
      if (_activeSession != null) {
        _selectedModel = _activeSession!.modelId;
        _chatTitle = _activeSession!.title;
      }
    }
    
    _textController.addListener(() {
      setState(() {
        _showSendButton = _textController.text.isNotEmpty;
      });
    });
    
    _initChatService();
  }

  void _initChatService() {
    _chatService = AIChatService(
      onMessageAdded: _handleMessageAdded,
      onTypingStatusChanged: _handleTypingStatusChanged,
      onSpeechResult: _handleSpeechResult,
    );
    
    _chatService.initialize().then((_) {
      setState(() {
        _isInitialized = true;
      });
    });
  }

  void _handleMessageAdded(String role, String content) async {
    // Only add the message if it's not already in the list
    bool alreadyExists = _messages.any((msg) => 
      msg['role'] == role && msg['content'] == content);
      
    if (!alreadyExists) {
      setState(() {
        _messages.add({'role': role, 'content': content});
      });
      
      // Create a new chat session if this is the first message
      if (_activeSession == null) {
        try {
          _activeSession = await _appwriteService.createChatSession(
            _selectedModel, 
            content
          );
          setState(() {
            _chatTitle = _activeSession!.title;
          });
        } catch (e) {
          debugPrint('Error creating chat session: $e');
        }
      }
      
      // Save the message to Appwrite
      if (_activeSession != null) {
        try {
          await _appwriteService.saveChatMessage(
            _activeSession!.id, 
            role, 
            content
          );
        } catch (e) {
          debugPrint('Error saving message: $e');
        }
      }
    }
    
    _scrollToBottom();
  }

  void _handleTypingStatusChanged(bool isTyping) {
    setState(() {
      _isAssistantTyping = isTyping;
    });
    if (isTyping) {
      _scrollToBottom();
    }
  }

  void _handleSpeechResult(String text) {
    setState(() {
      _textController.text = text;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _chatService.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startListening() {
    setState(() => _isListening = true);
    _chatService.startListening();
  }

  void _stopListening() {
    setState(() => _isListening = false);
    _chatService.stopListening();
  }

  void _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;
    _textController.clear();
    
    // Add the user message locally first
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _showSendButton = false;
    });
    _scrollToBottom();
    
    // Create a new chat session if this is the first message
    if (_activeSession == null) {
      try {
        _activeSession = await _appwriteService.createChatSession(
          _selectedModel, 
          text
        );
        
        setState(() {
          _chatTitle = _activeSession!.title;
        });
        
        // Save the user message to Appwrite
        await _appwriteService.saveChatMessage(
          _activeSession!.id, 
          'user', 
          text
        );
        
        // Now get the AI response
        _getAIResponse(text);
      } catch (e) {
        debugPrint('Error starting new chat: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } else {
      // We have an active session, just save the message and get response
      try {
        await _appwriteService.saveChatMessage(
          _activeSession!.id, 
          'user', 
          text
        );
        
        _getAIResponse(text);
      } catch (e) {
        debugPrint('Error saving message: $e');
      }
    }
  }
  
  Future<void> _getAIResponse(String userMessage) async {
    setState(() => _isAssistantTyping = true);
    
    try {
      final response = await _chatService.getAIResponse(userMessage);
      
      setState(() => _isAssistantTyping = false);
      
      // Add the assistant message
      setState(() {
        _messages.add({'role': 'assistant', 'content': response});
      });
      _scrollToBottom();
      
      // Save the assistant message to Appwrite
      if (_activeSession != null) {
        await _appwriteService.saveChatMessage(
          _activeSession!.id, 
          'assistant', 
          response
        );
      }
      
      // Play audio if possible
      await _chatService.generateAndPlayAudio(response);
    } catch (e) {
      setState(() => _isAssistantTyping = false);
      debugPrint('Error getting AI response: $e');
    }
  }
  
  Future<void> _setSelectedModel(String modelId) async {
    _selectedModel = modelId;
    _chatService.setSelectedModel(modelId);
    
    // Update the session's model if it exists
    if (_activeSession != null) {
      try {
        await _appwriteService.updateSessionModel(_activeSession!.id, modelId);
      } catch (e) {
        debugPrint('Error updating session model: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20, color: Colors.black54),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            Expanded(
              child: Center(
                child: Text(
                  _chatTitle,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, size: 20, color: Colors.black54),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (context) => _buildModelSelector(),
                );
              },
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Divider(height: 1, thickness: 1, color: Colors.grey[200]),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Chat messages area
            Expanded(
              child: !_isInitialized
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10A37F)),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading...',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : _messages.isEmpty
                  ? _buildWelcomeView()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.zero,
                      itemCount: _messages.length + (_isAssistantTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_isAssistantTyping && index == _messages.length) {
                          return _buildAssistantMessage(isTyping: true);
                        }

                        final message = _messages[index];
                        final isUser = message['role'] == 'user';
                        
                        return isUser
                            ? _buildUserMessage(message['content']!)
                            : _buildAssistantMessage(content: message['content']!);
                      },
                    ),
            ),
            
            // Input area - Updated to match ChatGPT style
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.05),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey.shade50,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              focusNode: _focusNode,
                              minLines: 1,
                              maxLines: 5,
                              decoration: InputDecoration(
                                hintText: 'Message Appwrite Ai...',
                                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.4,
                              ),
                              textCapitalization: TextCapitalization.sentences,
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (Widget child, Animation<double> animation) {
                              return ScaleTransition(scale: animation, child: child);
                            },
                            child: _showSendButton
                                ? IconButton(
                                    key: const ValueKey('send'),
                                    icon: const Icon(Icons.send, size: 18, color: Color(0xFF10A37F)),
                                    onPressed: () => _handleSubmitted(_textController.text),
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  )
                                : IconButton(
                                    key: const ValueKey('mic'),
                                    icon: Icon(
                                      _isListening ? Icons.mic : Icons.mic_none,
                                      size: 18,
                                      color: _isListening ? const Color(0xFF10A37F) : Colors.grey[400],
                                    ),
                                    onPressed: _isListening ? _stopListening : _startListening,
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildWelcomeView() {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 24),
            const Text(
              'How can I help you today?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Ask me anything, from creative ideas to technical questions.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            
            // Example prompts - Updated to match ChatGPT style
            _buildExamplePrompt('Explain how mindfulness affects mental health'),
            _buildExamplePrompt('Write a guided meditation for anxiety relief'),
            _buildExamplePrompt('Recommend daily self-care practices'),
            _buildExamplePrompt('How can I improve my focus and concentration?'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildExamplePrompt(String prompt) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          _textController.text = prompt;
          _handleSubmitted(prompt);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            prompt,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserMessage(String content) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User avatar
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.person,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // User message
          Expanded(
            child: Text(
              content,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantMessage({String? content, bool isTyping = false}) {
    return Container(
      color: const Color(0xFFF7F7F8),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Assistant avatar
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Color(0xFF10A37F),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.auto_awesome,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Assistant message or typing indicator
          Expanded(
            child: isTyping
                ? _buildTypingIndicator()
                : _buildMarkdownContent(content!),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMarkdownContent(String content) {
    // Check if content appears to contain markdown elements
    bool hasMarkdown = content.contains('**') || 
                       content.contains('*') || 
                       content.contains('#') ||
                       content.contains('- ') ||
                       content.contains('1. ');
                       
    if (hasMarkdown) {
      return MarkdownBody(
        data: content,
        styleSheet: MarkdownStyleSheet(
          p: const TextStyle(
            fontSize: 15,
            height: 1.5,
            color: Colors.black87,
          ),
          h1: const TextStyle(
            fontSize: 20,
            height: 1.5,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          h2: const TextStyle(
            fontSize: 18,
            height: 1.5,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          h3: const TextStyle(
            fontSize: 16,
            height: 1.5,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          strong: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          em: TextStyle(
            fontStyle: FontStyle.italic,
            color: Colors.black87,
          ),
          listBullet: const TextStyle(
            fontSize: 15,
            height: 1.5,
            color: Colors.black87,
          ),
          listIndent: 20,
        ),
      );
    } else {
      // Fallback to regular text for simple messages
      return Text(
        content,
        style: const TextStyle(
          fontSize: 15,
          height: 1.5,
          color: Colors.black87,
        ),
      );
    }
  }

  Widget _buildTypingIndicator() {
    return Row(
      children: [
        _buildAnimatedDot(0),
        _buildAnimatedDot(0.2),
        _buildAnimatedDot(0.4),
      ],
    );
  }

  Widget _buildAnimatedDot(double delay) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: AnimatedDot(delay: delay),
    );
  }

  Widget _buildModelSelector() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Model',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ...ChatModels.allModels.map((model) {
            bool isSelected = model.id == _selectedModel;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? const Color(0xFF10A37F) : Colors.grey[400]!,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Container(
                        margin: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF10A37F),
                        ),
                      )
                    : null,
              ),
              title: Text(
                model.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                  color: Colors.black87,
                ),
              ),
              subtitle: model.description != null
                  ? Text(
                      model.description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    )
                  : null,
              onTap: () {
                _setSelectedModel(model.id);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ],
      ),
    );
  }
}

class AnimatedDot extends StatefulWidget {
  final double delay;

  const AnimatedDot({Key? key, this.delay = 0.0}) : super(key: key);

  @override
  _AnimatedDotState createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<AnimatedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
        reverseCurve: const Interval(0.5, 1.0, curve: Curves.easeIn),
      ),
    )..addListener(() {
        setState(() {});
      });

    Future.delayed(Duration(milliseconds: (widget.delay * 1000).toInt()), () {
      _controller.repeat();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8 + (4 * _animation.value),
          decoration: BoxDecoration(
            color: Colors.grey[400],
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }
    );
  }
}