import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../auth/application/auth_service.dart';
import '../data/ai_data_repository.dart';

// ─── Message Model ─────────────────────────────────────────

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

// ─── System Instruction ────────────────────────────────────

const _systemInstruction = '''
أنت "مساعد بيفاين" - المساعد الذكي لنظام إدارة المخازن والمبيعات.
مهمتك هي مساعدة صاحب المتجر والموظفين بالإجابة على أسئلتهم حول بيانات المتجر.

قواعد مهمة:
1. أجب دائماً باللغة العربية ما لم يسألوك بلغة أخرى.
2. استخدم البيانات المقدمة لك في السياق للإجابة على أسئلة المستخدم.
3. لا تختلق بيانات. إذا لم تجد بيانات، أخبر المستخدم بذلك.
4. نسّق الأرقام بشكل واضح (استخدم الفواصل للآلاف والعلامات العشرية).
5. كن ودوداً ومحترفاً ومختصراً.
6. إذا سأل المستخدم عن شيء لا يتعلق بالتطبيق، اعتذر واخبره أنك متخصص في إدارة المخازن والمبيعات.
7. يمكنك تقديم نصائح واقتراحات بناءً على البيانات (مثل: "أنصحك بإعادة طلب هذا المنتج قريباً").
8. العملة المستخدمة هي الدينار (د).

أنت قادر على:
- عرض إحصائيات المبيعات (اليوم، الأسبوع، الشهر)
- تتبع المخزون والمنتجات قليلة الكمية
- البحث عن منتجات وعرض تفاصيلها
- عرض آخر العمليات والمعاملات
- عرض معلومات الموظفين والموردين
- عرض ملخص المهام
- تقديم نصائح لتحسين المبيعات وإدارة المخزون
''';

// ─── Gemini REST API Service ───────────────────────────────

class GeminiApiService {
  final String _apiKey;
  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1/models';
  static const _model = 'gemini-2.5-flash';

  GeminiApiService(this._apiKey);

  Future<String> sendMessage(List<ChatMessage> history, String userMessage, String contextData) async {
    final url = Uri.parse('$_baseUrl/$_model:generateContent?key=$_apiKey');

    final contents = [];
    
    // Add system instruction and context
    contents.add({
      'role': 'user',
      'parts': [{
        'text': '$_systemInstruction\n\n'
                'تعليمات هامة جداً:\n'
                '- أنت مساعد للقراءة والتحليل فقط (Read-Only).\n'
                '- لا تملك صلاحية إضافة أو تعديل أو حذف المنتجات، الموردين، الموظفين، أو أي بيانات.\n'
                '- إذا طلب منك المستخدم إضافة أو تعديل شيء، اعتذر بلباقة وأخبره أن دورك يقتصر على الاستعلام وقراءة البيانات الحالية فقط، وعليه استخدام واجهات التطبيق لإضافة البيانات.\n\n'
                'بيانات السياق المتوفرة حالياً:\n$contextData'
      }]
    });
    contents.add({
      'role': 'model',
      'parts': [{'text': 'حسناً، فهمت التعليمات والسياق وحدود صلاحياتي. أنا مستعد.'}]
    });

    // Add chat history (skip the first welcome message if we want)
    for (int i = 0; i < history.length; i++) {
      final msg = history[i];
      // Try to avoid passing errors as model responses to prevent API confusion, though it's fine.
      contents.add({
        'role': msg.isUser ? 'user' : 'model',
        'parts': [{'text': msg.text}]
      });
    }

    // Add the current user message
    contents.add({
      'role': 'user',
      'parts': [{'text': userMessage}]
    });

    final body = jsonEncode({
      'contents': contents,
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 2048,
      }
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final candidates = data['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final parts = candidates[0]['content']['parts'] as List?;
        if (parts != null && parts.isNotEmpty) {
          return parts[0]['text'] as String;
        }
      }
      return 'لم أستطع توليد إجابة. يرجى المحاولة مرة أخرى.';
    } else {
      debugPrint('Gemini API Error: ${response.statusCode} - ${response.body}');
      throw Exception('خطأ في الاتصال بالمساعد الذكي (${response.statusCode})');
    }
  }
}

// ─── AI Service (StateNotifier) ────────────────────────────

class AiAssistantState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;

  AiAssistantState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  AiAssistantState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
  }) {
    return AiAssistantState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AiAssistantNotifier extends StateNotifier<AiAssistantState> {
  final AiDataRepository _dataRepo;
  GeminiApiService? _gemini;
  bool _initialized = false;

  AiAssistantNotifier(this._dataRepo) : super(AiAssistantState()) {
    _initModel();
  }

  void _initModel() {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? const String.fromEnvironment('GEMINI_API_KEY');
      if (apiKey.isEmpty || apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
        state = state.copyWith(error: 'مفتاح Gemini API غير متوفر. يرجى إضافته في ملف .env');
        return;
      }

      _gemini = GeminiApiService(apiKey);
      _initialized = true;

      // Add welcome message
      state = state.copyWith(
        messages: [
          ChatMessage(
            text: 'مرحباً! أنا مساعد بيفاين الذكي 🤖\n\n'
                'يمكنني مساعدتك في:\n'
                '• الاستعلام عن المبيعات والإيرادات\n'
                '• تتبع المخزون والمنتجات\n'
                '• عرض آخر العمليات\n'
                '• معلومات الموظفين والموردين\n\n'
                'ماذا تريد أن تعرف؟',
            isUser: false,
          )
        ],
      );
    } catch (e) {
      debugPrint('AI Init Error: $e');
      state = state.copyWith(error: 'خطأ في تهيئة المساعد الذكي: $e');
    }
  }

  Future<void> sendMessage(String userMessage) async {
    if (!_initialized || _gemini == null) {
      state = state.copyWith(error: 'المساعد الذكي غير مُهيّأ بعد.');
      return;
    }
    if (userMessage.trim().isEmpty) return;

    final updatedMessages = [
      ...state.messages,
      ChatMessage(text: userMessage, isUser: true),
    ];
    state = state.copyWith(messages: updatedMessages, isLoading: true, error: null);

    try {
      // Gather context data from Supabase based on user's recent questions
      final contextData = await _gatherContextData(userMessage, state.messages);

      // Send to Gemini with history
      final responseText = await _gemini!.sendMessage(state.messages, userMessage, contextData);

      state = state.copyWith(
        messages: [
          ...state.messages, // Note: state.messages here already includes the new user message because of the copyWith above? No, state.messages was updated, so we need to use state.messages
          ChatMessage(text: responseText, isUser: false),
        ],
        isLoading: false,
      );
    } catch (e) {
      debugPrint('AI Send Error: $e');
      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(text: 'حدث خطأ أثناء المعالجة. يرجى المحاولة مرة أخرى.', isUser: false),
        ],
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Gathers relevant data from Supabase based on the user's question keywords
  Future<String> _gatherContextData(String question, List<ChatMessage> history) async {
    // Combine recent questions to maintain context across short follow-ups
    final recentQuestions = history.where((m) => m.isUser).map((m) => m.text).toList();
    final combinedQ = [...recentQuestions.reversed.take(2), question].join(' ').toLowerCase();
    
    final lowerQ = combinedQ;
    final buffer = StringBuffer();

    try {
      // Always get inventory summary as baseline
      final summary = await _dataRepo.getInventorySummary();
      buffer.writeln('ملخص المخزون: ${jsonEncode(summary)}');

      // Sales data
      if (lowerQ.contains('مبيع') || lowerQ.contains('بيع') || lowerQ.contains('ايراد') ||
          lowerQ.contains('إيراد') || lowerQ.contains('ربح') || lowerQ.contains('دخل') ||
          lowerQ.contains('sale') || lowerQ.contains('revenue')) {
        final sales = await _dataRepo.getTotalSales();
        buffer.writeln('المبيعات الإجمالية: ${jsonEncode(sales)}');

        final topProducts = await _dataRepo.getTopSellingProducts(limit: 5);
        buffer.writeln('أكثر المنتجات مبيعاً: ${jsonEncode(topProducts)}');
      }

      // Stores / Locations
      if (lowerQ.contains('فرع') || lowerQ.contains('موقع') || lowerQ.contains('متجر') || 
          lowerQ.contains('متاجر') || lowerQ.contains('فروع') || lowerQ.contains('مواقع') ||
          lowerQ.contains('store') || lowerQ.contains('location') || lowerQ.contains('مخزن') || lowerQ.contains('مخازن')) {
        final stores = await _dataRepo.getLocations();
        buffer.writeln('المتاجر (المخازن والمواقع): ${jsonEncode(stores)}');
      }

      // Stock / inventory
      if (lowerQ.contains('مخزون') || lowerQ.contains('مخزن') || lowerQ.contains('كمي') ||
          lowerQ.contains('نفاد') || lowerQ.contains('قليل') || lowerQ.contains('تفاصيل') ||
          lowerQ.contains('stock') || lowerQ.contains('inventory')) {
        final lowStock = await _dataRepo.getLowStockProducts(limit: 10);
        buffer.writeln('منتجات قليلة المخزون: ${jsonEncode(lowStock)}');
      }

      // Product search
      if (lowerQ.contains('منتج') || lowerQ.contains('سلع') || lowerQ.contains('بضاع') ||
          lowerQ.contains('product')) {
        final products = await _dataRepo.getProductInfo(question);
        buffer.writeln('بيانات المنتجات: ${jsonEncode(products)}');
      }

      // Transactions
      if (lowerQ.contains('عملي') || lowerQ.contains('معامل') || lowerQ.contains('حرك') ||
          lowerQ.contains('صادر') || lowerQ.contains('وارد') || lowerQ.contains('transaction')) {
        final transactions = await _dataRepo.getRecentTransactions(limit: 10);
        buffer.writeln('آخر العمليات: ${jsonEncode(transactions)}');
      }

      // Employees
      if (lowerQ.contains('موظف') || lowerQ.contains('عامل') || lowerQ.contains('فريق') ||
          lowerQ.contains('employee') || lowerQ.contains('staff')) {
        final employees = await _dataRepo.getEmployees();
        buffer.writeln('الموظفون: ${jsonEncode(employees)}');
      }

      // Categories
      if (lowerQ.contains('تصنيف') || lowerQ.contains('فئ') || lowerQ.contains('categor')) {
        final categories = await _dataRepo.getCategories();
        buffer.writeln('التصنيفات: ${jsonEncode(categories)}');
      }

      // Suppliers
      if (lowerQ.contains('مورد') || lowerQ.contains('توريد') || lowerQ.contains('supplier')) {
        final suppliers = await _dataRepo.getSuppliers();
        buffer.writeln('الموردون: ${jsonEncode(suppliers)}');
      }

      // Tasks
      if (lowerQ.contains('مهم') || lowerQ.contains('مهام') || lowerQ.contains('task')) {
        final tasks = await _dataRepo.getTasksSummary();
        buffer.writeln('ملخص المهام: ${jsonEncode(tasks)}');
      }
    } catch (e) {
      debugPrint('Context gathering error: $e');
      buffer.writeln('خطأ في جمع البيانات: $e');
    }

    return buffer.toString();
  }

  void clearChat() {
    state = AiAssistantState(
      messages: [
        ChatMessage(
          text: 'تمت إعادة تعيين المحادثة. كيف يمكنني مساعدتك؟',
          isUser: false,
        ),
      ],
    );
  }
}

// ─── Providers ─────────────────────────────────────────────

final aiDataRepositoryProvider = FutureProvider<AiDataRepository>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;
  if (user == null) throw Exception('المستخدم غير مسجل الدخول.');

  final profile = await supabase
      .from('profiles')
      .select('company_id')
      .eq('id', user.id)
      .single();
  final companyId = profile['company_id'] as String;
  return AiDataRepository(supabase, companyId);
});

final aiAssistantProvider =
    StateNotifierProvider<AiAssistantNotifier, AiAssistantState>((ref) {
  final dataRepoAsync = ref.watch(aiDataRepositoryProvider);
  return dataRepoAsync.when(
    data: (repo) => AiAssistantNotifier(repo),
    loading: () {
      // Return a placeholder notifier while loading
      final tempRepo = AiDataRepository(Supabase.instance.client, '');
      return AiAssistantNotifier(tempRepo);
    },
    error: (Object e, StackTrace s) {
      final tempRepo = AiDataRepository(Supabase.instance.client, '');
      return AiAssistantNotifier(tempRepo);
    },
  );
});
