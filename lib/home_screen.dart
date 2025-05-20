import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'chat_screen.dart';
import 'services/appwrite_service.dart';
import 'screens/chat_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  String _name = 'User';
  bool _isLoading = false; // Changed from true to false to avoid loading indicator

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final AppwriteService _appwriteService = AppwriteService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _appwriteService.initialize();
    _loadUserData();
    
    // Start animation immediately
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    // First try to get name from SharedPreferences (already loaded during splash)
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('name');
    if (name != null && name.isNotEmpty) {
      setState(() {
        _name = name;
      });
      return; // Return early if we have the name
    }

    // Only if not available in prefs, try to load from API
    try {
      final userProfile = await _appwriteService.getUserProfile();
      if (userProfile != null) {
        setState(() {
          _name = userProfile.name;
        });
        // Save to prefs for next time
        await prefs.setString('name', _name);
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _getJournalEntries() async {
    final chatHistory = await _appwriteService.getChatHistory();
    return chatHistory;
  }

  void _navigateToTherapistChat(BuildContext context) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChatScreen(),
      ),
    );
  }

  void _navigateToProfile(BuildContext context) {
    Navigator.pushNamed(context, '/profile');
  }

  void _navigateToChatHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChatHistoryScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header with Appwrite Ai logo - Fixed Row overflow
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Appwrite Ai logo and name with flexible constraints
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10A37F),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Flexible(
                          child: Text(
                            'Appwrite Ai',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Profile avatar
                  GestureDetector(
                    onTap: () => _navigateToProfile(context),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey.shade100,
                        border: Border.all(color: Colors.grey.shade300, width: 1),
                      ),
                      child: Center(
                        child: Text(
                          _name.isNotEmpty ? _name[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF10A37F),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const Divider(height: 1, thickness: 1, color: Color(0xFFE5E5E5)),
            
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Welcome title
                      Text(
                        'Hello, ${_name.split(' ')[0]}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
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
                      const SizedBox(height: 40),
                      
                      // Example prompts
                      _buildExamplePrompt(
                        'Tell me about mindfulness',
                        () => _startNewChatWithPrompt('Tell me about mindfulness'),
                      ),
                      _buildExamplePrompt(
                        'How can I reduce my stress levels?',
                        () => _startNewChatWithPrompt('How can I reduce my stress levels?'),
                      ),
                      _buildExamplePrompt(
                        'Recommend some meditation techniques',
                        () => _startNewChatWithPrompt('Recommend some meditation techniques'),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Action buttons - Fixed to prevent overflow
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: _buildActionButton(
                              'New Chat',
                              Icons.add,
                              () => _navigateToTherapistChat(context),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Flexible(
                            child: _buildActionButton(
                              'History',
                              Icons.history,
                              () => _navigateToChatHistory(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Appwrite Ai disclaimer
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Appwrite Ai can make mistakes. Verify important information.',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
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

  // Helper method to start a new chat with a specific prompt
  void _startNewChatWithPrompt(String prompt) async {
    final chatScreen = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(),
      ),
    );
    
    // Note: You'll need to implement a way to send the initial prompt
    // This is a placeholder for that functionality
  }

  Widget _buildExamplePrompt(String text, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 130,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF10A37F),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}