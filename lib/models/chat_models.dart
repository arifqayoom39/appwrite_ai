class ChatModel {
  final String id;
  final String name;
  final String description;
  
  const ChatModel({
    required this.id,
    required this.name,
    required this.description,
  });
}

class ChatModels {
  static const ChatModel llama = ChatModel(
    id: 'meta-llama/llama-3.1-8b-instruct:free',
    name: 'Llama 3',
    description: 'A lightweight and efficient AI assistant.',
  );
  
  static const ChatModel gpt = ChatModel(
    id: 'deepseek/deepseek-v3-base:free',
    name: 'DeepSeek',
    description: 'A well-balanced AI assistant for everyday use.',
  );
  
  static const ChatModel claude = ChatModel(
    id: 'mistralai/mistral-7b-instruct:free',
    name: 'Mistral',
    description: 'A more sophisticated AI assistant for complex tasks.',
  );
  
  static const ChatModel mistral = ChatModel(
    id: 'qwen/qwen3-30b-a3b:free',
    name: 'QWEN',
    description: 'Our most capable AI assistant for demanding needs.',
  );

  static const ChatModel gemini = ChatModel(
    id: 'microsoft/phi-4-reasoning:free',
    name: 'GMicrosoft',
    description: 'A well-balanced AI assistant for Reasoning',
  );
  
  static const List<ChatModel> allModels = [llama, gpt, claude, mistral, gemini];
}
