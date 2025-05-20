import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/chat_session_model.dart';
import '../services/appwrite_service.dart';
import '../chat_screen.dart';

class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({Key? key}) : super(key: key);

  @override
  _ChatHistoryScreenState createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  final AppwriteService _appwriteService = AppwriteService();
  bool _isLoading = true;
  List<ChatSessionModel> _chatSessions = [];
  
  @override
  void initState() {
    super.initState();
    _loadChatSessions();
  }
  
  Future<void> _loadChatSessions() async {
    setState(() => _isLoading = true);
    
    try {
      final sessions = await _appwriteService.getChatSessions();
      setState(() {
        _chatSessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading chat history: $e')),
      );
    }
  }
  
  Future<void> _deleteSession(ChatSessionModel session) async {
    try {
      await _appwriteService.deleteChatSession(session.id);
      
      setState(() {
        _chatSessions.removeWhere((s) => s.id == session.id);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting chat: $e')),
      );
    }
  }
  
  Future<void> _clearAllChats() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Clear conversations',
          style: TextStyle(
            fontSize: 16, 
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        content: const Text(
          'This will permanently delete all your conversations. Are you sure?',
          style: TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.black87,
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              
              try {
                await _appwriteService.clearChatHistory();
                
                setState(() {
                  _chatSessions = [];
                  _isLoading = false;
                });
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All conversations cleared'),
                    backgroundColor: Color(0xFF10A37F),
                  ),
                );
              } catch (e) {
                setState(() => _isLoading = false);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error clearing chats: $e')),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF10A37F),
            ),
            child: const Text(
              'Clear',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _navigateToChat(ChatSessionModel session) async {
    final messages = await _appwriteService.getChatMessages(session.id);
    
    if (!mounted) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatSession: session,
          initialMessages: messages,
        ),
      ),
    ).then((_) => _loadChatSessions());
  }
  
  void _startNewChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChatScreen(),
      ),
    ).then((_) => _loadChatSessions());
  }
  
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      
      if (date.year == now.year && date.month == now.month && date.day == now.day) {
        return DateFormat.jm().format(date);
      } else if (date.year == now.year) {
        return DateFormat('MMM d').format(date);
      } else {
        return DateFormat('MMM d, y').format(date);
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Appwrite Ai', 
          style: TextStyle(
            color: Colors.black87, 
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20, color: Colors.black54),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_chatSessions.isNotEmpty)
            TextButton(
              onPressed: _clearAllChats,
              child: const Text(
                'Clear all',
                style: TextStyle(
                  color: Color(0xFF10A37F),
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Divider(height: 1, thickness: 1, color: Colors.grey[200]),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16.0),
            child: InkWell(
              onTap: _startNewChat,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add, color: Color(0xFF10A37F), size: 20),
                    const SizedBox(width: 12),
                    const Text(
                      'New chat',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Today',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ),
          _isLoading
            ? const Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10A37F)),
                  ),
                ),
              )
            : _chatSessions.isEmpty
              ? Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No conversations yet',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 0),
                    itemCount: _chatSessions.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 0),
                    itemBuilder: (context, index) {
                      final session = _chatSessions[index];
                      return _buildChatSessionTile(session);
                    },
                  ),
                ),
        ],
      ),
    );
  }
  
  Widget _buildChatSessionTile(ChatSessionModel session) {
    return InkWell(
      onTap: () => _navigateToChat(session),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0),
        child: Row(
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 18,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  if (session.updatedAt.isNotEmpty)
                    Text(
                      _formatDate(session.updatedAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 18,
                color: Colors.grey[400],
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
              onPressed: () => _deleteSession(session),
            ),
          ],
        ),
      ),
    );
  }
}
