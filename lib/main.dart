import 'package:aichat/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:aichat/admin/admin_ui.dart';
import 'package:aichat/services/auth_service.dart';
import 'package:aichat/services/chat_service.dart';
import 'package:aichat/admin/admin_panel.dart';
import 'package:aichat/screens/chat_history.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:aichat/auth/login_bottom_sheet.dart';
import 'package:aichat/screens/chat_session.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await AuthService.initialize();
  await AuthService.setupInitialAdmins();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Chat App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const MyHomePage(title: 'AI Chat'),
        '/admin': (context) => const AdminPanel(),
        '/history': (context) => const ChatHistoryScreen(),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _ChatPageState();
}

class _ChatPageState extends State<MyHomePage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;
  String _sessionId = Uuid().v4();
  bool _isLoggedIn = false;
  int _messageCountBeforeLogin = 0;
  final int _maxMessagesBeforeLogin = 7;
  bool _showSidebar = false;
  List<Map<String, dynamic>> _chatSessions = [];
  bool _isLoading = false;
  late AnimationController _dotAnimationController;

  // Check if State is mounted to avoid "setState() called after dispose()" error
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dotAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _checkLoginStatus();
    _addWelcomeMessage();
    _loadChatSessions();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Жишээ нь, app inactive болоход эсвэл background-д орох үед
    // _mounted = false; гэж тохируулж болно
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _mounted = false;
    } else if (state == AppLifecycleState.resumed) {
      _mounted = true;
      // App дахин идэвхтэй болох үед хэрэглэгчийн мэдээллийг дахин шалгах
      _checkLoginStatus();
      if (_isLoggedIn) {
        _loadChatSessions();
      }
    }
  }

  @override
  void dispose() {
    _mounted = false;
    _controller.dispose();
    _dotAnimationController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Safely call setState to avoid unmounted widget errors
  void safeSetState(VoidCallback fn) {
    if (_mounted) {
      setState(fn);
    }
  }

  Future<void> _checkLoginStatus() async {
    safeSetState(() {
      _isLoggedIn = AuthService.currentUser != null;
      _showSidebar = _isLoggedIn;
    });
  }

  Future<void> _loadChatSessions() async {
    if (!_isLoggedIn) return;

    safeSetState(() {
      _isLoading = true;
    });

    try {
      final userId = AuthService.currentUser?.id;
      if (userId != null) {
        final sessions = await ChatService.getChatSessions(userId);
        safeSetState(() {
          _chatSessions = sessions;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading chat sessions: $e');
      safeSetState(() {
        _isLoading = false;
      });
    }
  }

  void _addWelcomeMessage() {
    safeSetState(() {
      _messages.add({
        "from": "bot",
        "text":
            "Сайн байна уу! Би танд туслахад бэлэн байна. Асуултаа бичнэ үү.",
      });
    });
  }

  void _handleSubmit(String input) async {
    if (input.trim().isEmpty) return;

    // Increment message counter if not logged in
    if (!_isLoggedIn) {
      _messageCountBeforeLogin++;
    }

    // Save user message locally
    safeSetState(() {
      _messages.add({"from": "user", "text": input});
      _isTyping = true;
    });

    _controller.clear();

    // Check if user reached message limit
    if (!_isLoggedIn && _messageCountBeforeLogin >= _maxMessagesBeforeLogin) {
      safeSetState(() {
        _messages.add({
          "from": "bot",
          "text":
              "Таны мессеж бичих эрх дууссан байна. Цааш үргэлжлүүлэхийн тулд нэвтэрнэ үү.",
          "requireLogin": true,
        });
        _isTyping = false;
      });
      return;
    }

    // "Бичиж байна..." статусыг харуулах
    safeSetState(() {
      _messages.add({
        "from": "bot",
        "text": "...",
        "isTyping": true,
      });
    });

    // If logged in, save message to Firestore
    if (_isLoggedIn) {
      await ChatService.saveMessage(
        userId: AuthService.currentUser!.id,
        text: input,
        sender: "user",
        sessionId: _sessionId,
      );
    }

    // Search for answer in the database
    final localAnswer = await ChatService.searchInFirestore(input);

    // Remove typing indicator
    if (_mounted) {
      safeSetState(() {
        _messages.removeLast();
        _isTyping = false;
      });
    }

    if (localAnswer != null) {
      // Show database answer
      safeSetState(() {
        _messages.add({"from": "bot", "text": localAnswer});
      });

      // Save bot response if logged in
      if (_isLoggedIn) {
        await ChatService.saveMessage(
          userId: AuthService.currentUser!.id,
          text: localAnswer,
          sender: "bot",
          sessionId: _sessionId,
        );
      }
    } else {
      // Ask if user wants to search with Gemini
      safeSetState(() {
        _messages.add({
          "from": "bot",
          "text": "Манай мэдээллийн санд олдсонгүй. Дэлгэрэнгүй хайх уу?",
          "action": true
        });
      });

      // Save bot response if logged in
      if (_isLoggedIn) {
        await ChatService.saveMessage(
          userId: AuthService.currentUser!.id,
          text: "Манай мэдээллийн санд олдсонгүй. Дэлгэрэнгүй хайх уу?",
          sender: "bot",
          sessionId: _sessionId,
        );
      }
    }
  }

  void _handleGeminiSearch(String input) async {
    // Show typing indicator
    safeSetState(() {
      _messages.add({
        "from": "bot",
        "text": "...",
        "isTyping": true,
      });
    });

    // Get answer from Gemini
    final geminiAnswer = await ChatService.askGemini(input);

    // Remove typing indicator and show answer
    safeSetState(() {
      _messages.removeLast();
      _messages.add({"from": "bot", "text": geminiAnswer});
    });

    // Save answer to database
    await ChatService.saveQuestionAnswer(
      question: input,
      answer: geminiAnswer,
    );

    // Save bot response if logged in
    if (_isLoggedIn) {
      await ChatService.saveMessage(
        userId: AuthService.currentUser!.id,
        text: geminiAnswer,
        sender: "bot",
        sessionId: _sessionId,
      );
    }
  }

  void _startNewChat() {
    safeSetState(() {
      _sessionId = Uuid().v4();
      _messages.clear();
      _addWelcomeMessage();
    });
  }

  void _openChatSession(String sessionId) async {
    safeSetState(() {
      _isLoading = true;
    });

    try {
      final messages = await ChatService.getSessionMessagesAsList(sessionId);
      safeSetState(() {
        _sessionId = sessionId;
        _messages = messages
            .map((msg) => {
                  "from": msg.sender,
                  "text": msg.text,
                })
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading chat session: $e');
      safeSetState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showLoginModal(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: LoginBottomSheet(),
        ),
      ),
    );

    if (result == true) {
      await _checkLoginStatus();
      await _loadChatSessions();
    }
  }

  void _showUserMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (AuthService.currentUser?.isAdmin == true)
                ListTile(
                  leading: Icon(Icons.admin_panel_settings),
                  title: Text('Админ панел'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/admin');
                  },
                ),
              ListTile(
                leading: Icon(Icons.history),
                title: Text('Чатын түүх'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/history');
                },
              ),
              ListTile(
                leading: Icon(Icons.logout),
                title: Text('Гарах'),
                onTap: () async {
                  Navigator.pop(context);
                  await AuthService.logout();
                  safeSetState(() {
                    _isLoggedIn = false;
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String lastUserMessage = _messages
            .lastWhere((m) => m['from'] == 'user',
                orElse: () => {'text': ''})['text']
            ?.toString() ??
        '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        leading: _isLoggedIn
            ? IconButton(
                icon: Icon(_showSidebar ? Icons.menu_open : Icons.menu),
                onPressed: () {
                  safeSetState(() {
                    _showSidebar = !_showSidebar;
                  });
                },
              )
            : null,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.smart_toy,
                  color: Theme.of(context).colorScheme.primary),
            ),
            SizedBox(width: 10),
            Text(widget.title),
          ],
        ),
        actions: [
          if (_isLoggedIn)
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: () {
                Navigator.pushNamed(context, '/history');
              },
            ),
          IconButton(
            icon: _isLoggedIn
                ? const Icon(Icons.account_circle)
                : const Icon(Icons.login),
            onPressed: () {
              if (_isLoggedIn) {
                _showUserMenu(context);
              } else {
                _showLoginModal(context);
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main chat area (always visible)
          Container(
            color: Colors.grey[100],
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final bool isUser = msg['from'] == 'user';
                      final bool isTyping = msg['isTyping'] == true;
                      final bool requireLogin = msg['requireLogin'] == true;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: isUser
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          children: [
                            if (!isUser)
                              CircleAvatar(
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                                radius: 16,
                                child: Icon(Icons.smart_toy,
                                    size: 18, color: Colors.white),
                              ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isUser
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 2,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    isTyping
                                        ? _buildTypingIndicator()
                                        : SelectableText(
                                            msg['text'],
                                            style: TextStyle(
                                              color: isUser
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                    if (msg['action'] == true)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 8.0),
                                        child: ElevatedButton(
                                          onPressed: () {
                                            if (lastUserMessage.isNotEmpty) {
                                              _handleGeminiSearch(
                                                  lastUserMessage);
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Theme.of(context)
                                                .colorScheme
                                                .primaryContainer,
                                            foregroundColor: Theme.of(context)
                                                .colorScheme
                                                .onPrimaryContainer,
                                          ),
                                          child:
                                              const Text("Тийм, Gemini-р хайх"),
                                        ),
                                      ),
                                    if (requireLogin)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 8.0),
                                        child: ElevatedButton(
                                          onPressed: () {
                                            _showLoginModal(context);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Theme.of(context)
                                                .colorScheme
                                                .primaryContainer,
                                            foregroundColor: Theme.of(context)
                                                .colorScheme
                                                .onPrimaryContainer,
                                          ),
                                          child: const Text("Нэвтрэх"),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isUser)
                              CircleAvatar(
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                                radius: 16,
                                child: Icon(Icons.person,
                                    size: 18, color: Colors.white),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: Offset(0, -1),
                      ),
                    ],
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          onSubmitted: _handleSubmit,
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          decoration: InputDecoration(
                            hintText: 'Асуултаа бичнэ үү...',
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.send),
                          color: Colors.white,
                          onPressed: () => _handleSubmit(_controller.text),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Sidebar overlay (visible when toggled)
          if (_isLoggedIn && _showSidebar)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onHorizontalDragUpdate: (details) {
                  if (details.delta.dx < -5) {
                    safeSetState(() {
                      _showSidebar = false;
                    });
                  }
                },
                child: Container(
                  width: 280,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 5,
                        offset: Offset(2, 0),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Чатын түүх',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close),
                              onPressed: () {
                                safeSetState(() {
                                  _showSidebar = false;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _startNewChat();
                            safeSetState(() {
                              _showSidebar = false;
                            });
                          },
                          icon: Icon(Icons.add),
                          label: Text('Шинэ чат'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            minimumSize: Size(double.infinity, 48),
                          ),
                        ),
                      ),
                      Divider(),
                      Expanded(
                        child: _isLoading
                            ? Center(child: CircularProgressIndicator())
                            : _chatSessions.isEmpty
                                ? Center(
                                    child: Text('Чатын түүх хоосон байна'),
                                  )
                                : ListView.builder(
                                    itemCount: _chatSessions.length,
                                    itemBuilder: (context, index) {
                                      final session = _chatSessions[index];
                                      return ListTile(
                                        leading:
                                            Icon(Icons.chat_bubble_outline),
                                        title: Text(
                                          session['title'].toString(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        selected:
                                            session['sessionId'] == _sessionId,
                                        selectedTileColor: Colors.grey[300],
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  ChatSessionScreen(
                                                sessionId: session['sessionId']
                                                    .toString(),
                                              ),
                                            ),
                                          ).then((_) {
                                            // Reload chat sessions when returning
                                            _loadChatSessions();
                                          });
                                          safeSetState(() {
                                            _showSidebar = false;
                                          });
                                        },
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Semi-transparent overlay when sidebar is open
          if (_isLoggedIn && _showSidebar)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  safeSetState(() {
                    _showSidebar = false;
                  });
                },
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                  margin: EdgeInsets.only(left: 280),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Row(
      children: [
        _buildDot(0),
        _buildDot(1),
        _buildDot(2),
      ],
    );
  }

  Widget _buildDot(int index) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 2),
      height: 8,
      width: 8,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.6),
        shape: BoxShape.circle,
      ),
    );
  }
}
