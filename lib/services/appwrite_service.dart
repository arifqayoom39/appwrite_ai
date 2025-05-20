import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/chat_session_model.dart';
import '../models/chat_message_model.dart';

class AppwriteService {
  static final AppwriteService _instance = AppwriteService._internal();
  factory AppwriteService() => _instance;

  AppwriteService._internal();

  // Appwrite SDK clients
  late final Client client;
  late final Account account;
  late final Databases databases;
  late final Storage storage;

  // Appwrite constants
  final String endpoint = 'https://cloud.appwrite.io/v1';
  final String projectId = '-'; // Replace with your Appwrite project ID
  final String databaseId = '-';
  final String userCollectionId = '-';
  final String chatSessionsCollectionId = '-';
  final String chatMessagesCollectionId = '-';

  bool _initialized = false;

  // Initialize Appwrite clients
  void initialize() {
    if (_initialized) return;
    
    client = Client()
      .setEndpoint(endpoint)
      .setProject(projectId)
      .setSelfSigned(status: true); // Use only during development
    
    account = Account(client);
    databases = Databases(client);
    storage = Storage(client);
    
    _initialized = true;
  }

  // Authentication methods
  Future<models.User> createAccount(String email, String password, String name) async {
    try {
      final user = await account.create(
        userId: ID.unique(),
        email: email,
        password: password,
        name: name,
      );
      
      await _createUserProfile(user.$id, name, email);
      
      return user;
    } catch (e) {
      rethrow;
    }
  }

  Future<models.Session> login(String email, String password) async {
    try {
      return await account.createEmailPasswordSession(email: email, password: password);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await account.deleteSession(sessionId: 'current');
    } catch (e) {
      rethrow;
    }
  }

  Future<models.User?> getCurrentUser() async {
    try {
      return await account.get();
    } catch (e) {
      return null;
    }
  }

  // User Profile methods
  Future<void> _createUserProfile(String userId, String name, String email) async {
    try {
      final userModel = UserModel(
        id: userId,
        name: name,
        email: email,
        createdAt: DateTime.now().toIso8601String(),
      );
      
      await databases.createDocument(
        databaseId: databaseId,
        collectionId: userCollectionId,
        documentId: userId,
        data: userModel.toMap(),
      );
    } catch (e) {
      debugPrint('Error creating profile: $e');
    }
  }

  Future<UserModel?> getUserProfile() async {
    try {
      final user = await account.get();
      final profile = await databases.getDocument(
        databaseId: databaseId,
        collectionId: userCollectionId,
        documentId: user.$id,
      );
      return UserModel.fromMap(profile.data);
    } catch (e) {
      debugPrint('Error getting profile: $e');
      return null;
    }
  }

  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    try {
      final user = await account.get();
      await databases.updateDocument(
        databaseId: databaseId,
        collectionId: userCollectionId,
        documentId: user.$id,
        data: data,
      );
    } catch (e) {
      debugPrint('Error updating profile: $e');
      rethrow;
    }
  }

  // Chat Session methods
  Future<ChatSessionModel> createChatSession(String modelId, String initialMessage) async {
    try {
      final user = await account.get();
      final title = ChatSessionModel.generateTitleFromContent(initialMessage);
      
      final now = DateTime.now().toIso8601String();
      final sessionData = {
        'userId': user.$id,
        'title': title,
        'createdAt': now,
        'updatedAt': now,
        'modelId': modelId,
      };
      
      final result = await databases.createDocument(
        databaseId: databaseId,
        collectionId: chatSessionsCollectionId,
        documentId: ID.unique(),
        data: sessionData,
      );
      
      return ChatSessionModel.fromMap(result.data);
    } catch (e) {
      debugPrint('Error creating chat session: $e');
      rethrow;
    }
  }

  Future<List<ChatSessionModel>> getChatSessions() async {
    try {
      final user = await account.get();
      final result = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: chatSessionsCollectionId,
        queries: [
          Query.equal('userId', user.$id),
          Query.orderDesc('updatedAt'),
        ],
      );
      
      return result.documents.map((doc) => ChatSessionModel.fromMap(doc.data)).toList();
    } catch (e) {
      debugPrint('Error getting chat sessions: $e');
      return [];
    }
  }

  Future<void> updateChatSessionTitle(String sessionId, String newTitle) async {
    try {
      await databases.updateDocument(
        databaseId: databaseId,
        collectionId: chatSessionsCollectionId,
        documentId: sessionId,
        data: {
          'title': newTitle,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('Error updating chat session title: $e');
      rethrow;
    }
  }

  Future<void> deleteChatSession(String sessionId) async {
    try {
      // First delete all messages in this session
      final messages = await getChatMessages(sessionId);
      for (var message in messages) {
        await databases.deleteDocument(
          databaseId: databaseId,
          collectionId: chatMessagesCollectionId,
          documentId: message.id,
        );
      }
      
      // Then delete the session
      await databases.deleteDocument(
        databaseId: databaseId,
        collectionId: chatSessionsCollectionId,
        documentId: sessionId,
      );
    } catch (e) {
      debugPrint('Error deleting chat session: $e');
      rethrow;
    }
  }

  Future<void> updateSessionModel(String sessionId, String modelId) async {
    try {
      await databases.updateDocument(
        databaseId: databaseId,
        collectionId: chatSessionsCollectionId,
        documentId: sessionId,
        data: {
          'modelId': modelId,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('Error updating session model: $e');
      rethrow;
    }
  }

  // Chat Messages methods
  Future<ChatMessageModel> saveChatMessage(String chatId, String role, String content) async {
    try {
      final now = DateTime.now().toIso8601String();
      
      final messageData = {
        'chatId': chatId,
        'role': role,
        'content': content,
        'timestamp': now,
      };
      
      final result = await databases.createDocument(
        databaseId: databaseId,
        collectionId: chatMessagesCollectionId,
        documentId: ID.unique(),
        data: messageData,
      );
      
      // Update the chat session's updatedAt timestamp
      await databases.updateDocument(
        databaseId: databaseId,
        collectionId: chatSessionsCollectionId,
        documentId: chatId,
        data: {'updatedAt': now},
      );
      
      return ChatMessageModel.fromMap(result.data);
    } catch (e) {
      debugPrint('Error saving chat message: $e');
      rethrow;
    }
  }

  Future<List<ChatMessageModel>> getChatMessages(String chatId) async {
    try {
      final result = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: chatMessagesCollectionId,
        queries: [
          Query.equal('chatId', chatId),
          Query.orderAsc('timestamp'),
        ],
      );
      
      return result.documents.map((doc) => ChatMessageModel.fromMap(doc.data)).toList();
    } catch (e) {
      debugPrint('Error getting chat messages: $e');
      return [];
    }
  }

  // Legacy methods for backward compatibility
  Future<void> saveChatMessageLegacy(String role, String content) async {
    try {
      final user = await account.get();
      
      // Check if there's an active session, or create one
      final sessions = await getChatSessions();
      
      String chatId;
      if (sessions.isEmpty) {
        final newSession = await createChatSession('meta-llama/llama-3.1-8b-instruct:free', content);
        chatId = newSession.id;
      } else {
        chatId = sessions.first.id;
      }
      
      await saveChatMessage(chatId, role, content);
    } catch (e) {
      debugPrint('Error saving chat message (legacy): $e');
      // Just log the error but don't rethrow - this prevents app crashes
      // on message saving failures
    }
  }

  Future<List<Map<String, dynamic>>> getChatHistory() async {
    try {
      final sessions = await getChatSessions();
      
      if (sessions.isEmpty) {
        return [];
      }
      
      // Get messages from the latest session
      final messages = await getChatMessages(sessions.first.id);
      
      return messages.map((msg) => {
        'role': msg.role,
        'content': msg.content,
        'timestamp': msg.timestamp,
      }).toList();
    } catch (e) {
      debugPrint('Error getting chat history (legacy): $e');
      return [];
    }
  }

  Future<void> clearChatHistory() async {
    try {
      final sessions = await getChatSessions();
      
      for (var session in sessions) {
        await deleteChatSession(session.id);
      }
    } catch (e) {
      debugPrint('Error clearing chat history: $e');
      rethrow;
    }
  }
}
