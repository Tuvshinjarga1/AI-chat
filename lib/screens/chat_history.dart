import 'package:flutter/material.dart';
import 'package:aichat/services/chat_service.dart';
import 'package:aichat/services/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:aichat/screens/chat_session.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({Key? key}) : super(key: key);

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;
  bool _isSelectionMode = false;
  Set<String> _selectedSessions = {};

  @override
  void initState() {
    super.initState();
    _loadChatSessions();
  }

  Future<void> _loadChatSessions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = AuthService.currentUser?.id;
      if (userId != null) {
        final sessions = await ChatService.getChatSessions(userId);
        setState(() {
          _sessions = sessions;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Алдаа гарлаа: $e')),
      );
      print('Error loading chat sessions: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteSession(String sessionId) async {
    try {
      await ChatService.deleteSession(sessionId);
      setState(() {
        _sessions.removeWhere((session) => session['sessionId'] == sessionId);
        _selectedSessions.remove(sessionId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Чат устгагдлаа')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Устгах үед алдаа гарлаа: $e')),
      );
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedSessions.clear();
    });
  }

  void _toggleSelection(String sessionId) {
    setState(() {
      if (_selectedSessions.contains(sessionId)) {
        _selectedSessions.remove(sessionId);
      } else {
        _selectedSessions.add(sessionId);
      }
    });
  }

  Future<void> _deleteSelectedSessions() async {
    if (_selectedSessions.isEmpty) return;

    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Сонгосон чатуудыг устгах'),
        content: Text(
            '${_selectedSessions.length} чатыг устгахдаа итгэлтэй байна уу?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Үгүй'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Тийм'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Delete each selected session one by one
        for (var sessionId in _selectedSessions) {
          await ChatService.deleteSession(sessionId);
        }

        // Update local state
        setState(() {
          _sessions.removeWhere(
              (session) => _selectedSessions.contains(session['sessionId']));
          _selectedSessions.clear();
          _isSelectionMode = false;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Сонгосон чатууд устгагдлаа')),
        );
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Устгах үед алдаа гарлаа: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Түүх',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Color(0xFF0e6655),
        leading: _isSelectionMode
            ? IconButton(
                icon: Icon(Icons.close, color: Colors.white),
                onPressed: _toggleSelectionMode,
              )
            : null,
        actions: [
          if (_sessions.isNotEmpty && !_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.select_all, color: Colors.white),
              tooltip: 'Сонгох',
              onPressed: _toggleSelectionMode,
            ),
          if (_isSelectionMode && _selectedSessions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              tooltip: 'Сонгосныг устгах',
              onPressed: _deleteSelectedSessions,
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 80, color: Colors.grey[400]),
                      SizedBox(height: 16),
                      Text(
                        'Чат түүх хоосон байна',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Шинэ чат эхлүүлэхийн тулд буцаагаад асуулт асууна уу',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadChatSessions,
                  child: ListView.builder(
                    itemCount: _sessions.length,
                    itemBuilder: (context, index) {
                      final session = _sessions[index];
                      final sessionId = session['sessionId'];
                      final title = session['title'];
                      final dateTime = session['lastMessageTime'] as DateTime;
                      final formattedDate =
                          DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
                      final isSelected = _selectedSessions.contains(sessionId);

                      return _isSelectionMode
                          ? Card(
                              margin: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              child: CheckboxListTile(
                                value: isSelected,
                                onChanged: (_) => _toggleSelection(sessionId),
                                title: Text(title),
                                subtitle: Text(formattedDate),
                                secondary: CircleAvatar(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  child: Icon(Icons.chat, color: Colors.white),
                                ),
                                controlAffinity:
                                    ListTileControlAffinity.trailing,
                              ),
                            )
                          : Dismissible(
                              key: Key(sessionId),
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: EdgeInsets.only(right: 20),
                                child: Icon(Icons.delete, color: Colors.white),
                              ),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (direction) async {
                                return await showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('Чат устгах'),
                                    content: Text(
                                        'Энэ чатыг устгахдаа итгэлтэй байна уу?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: Text('Үгүй'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: Text('Тийм'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              onDismissed: (direction) {
                                _deleteSession(sessionId);
                              },
                              child: Card(
                                margin: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
                                    child:
                                        Icon(Icons.chat, color: Colors.white),
                                  ),
                                  title: Text(title),
                                  subtitle: Text(formattedDate),
                                  trailing:
                                      Icon(Icons.arrow_forward_ios, size: 16),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ChatSessionScreen(
                                          sessionId: sessionId,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                    },
                  ),
                ),
    );
  }
}
