import 'package:flutter/material.dart';
import 'package:aichat/admin/admin_ui.dart';
import 'package:aichat/admin/dashboard.dart';
import 'package:aichat/services/auth_service.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({Key? key}) : super(key: key);

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.animateToPage(
        index,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
    // Close drawer on small screens after selection
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  String _getPageTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Дашборд';
      case 1:
        return 'Асуулт/Хариулт';
      case 2:
        return 'Тохиргоо';
      default:
        return 'Админ панел';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 900;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(_getPageTitle()),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        leading: isSmallScreen
            ? IconButton(
                icon: Icon(Icons.menu),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              )
            : null,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                AuthService.currentUser?.displayName?.substring(0, 1) ?? 'A',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: isSmallScreen ? _buildDrawer() : null,
      body: Row(
        children: [
          // Зүүн талын сайдбар (том дэлгэцэнд харагдана)
          if (!isSmallScreen) _buildSidebar(),

          // Баруун талын контент
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              children: [
                AdminDashboard(),
                AdminQAEntryPage(),
                _buildSettingsPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 260,
      color: Theme.of(context).colorScheme.primary,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 24),
            color: Theme.of(context).colorScheme.primary,
            child: Center(
              child: Text(
                'Админ удирдлага',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Divider(color: Colors.white30, height: 1),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: _buildMenuItems(),
            ),
          ),
          Divider(color: Colors.white30, height: 1),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.white70),
            title: Text(
              'Гарах',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () async {
              await AuthService.logout();
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/',
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: Theme.of(context).colorScheme.primary,
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 40,
                    child: Text(
                      AuthService.currentUser?.displayName?.substring(0, 1) ??
                          'A',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    AuthService.currentUser?.displayName ?? 'Админ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: _buildMenuItems(),
              ),
            ),
            Divider(color: Colors.white30, height: 1),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.white70),
              title: Text(
                'Гарах',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                await AuthService.logout();
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/',
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMenuItems() {
    return [
      ListTile(
        leading: Icon(Icons.dashboard,
            color: _selectedIndex == 0 ? Colors.white : Colors.white70),
        title: Text(
          'Дашборд',
          style: TextStyle(
            color: _selectedIndex == 0 ? Colors.white : Colors.white70,
            fontWeight:
                _selectedIndex == 0 ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: _selectedIndex == 0,
        selectedTileColor: Colors.white.withOpacity(0.1),
        onTap: () => _onItemTapped(0),
      ),
      ListTile(
        leading: Icon(Icons.question_answer,
            color: _selectedIndex == 1 ? Colors.white : Colors.white70),
        title: Text(
          'Асуулт/Хариулт',
          style: TextStyle(
            color: _selectedIndex == 1 ? Colors.white : Colors.white70,
            fontWeight:
                _selectedIndex == 1 ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: _selectedIndex == 1,
        selectedTileColor: Colors.white.withOpacity(0.1),
        onTap: () => _onItemTapped(1),
      ),
      ListTile(
        leading: Icon(Icons.settings,
            color: _selectedIndex == 2 ? Colors.white : Colors.white70),
        title: Text(
          'Тохиргоо',
          style: TextStyle(
            color: _selectedIndex == 2 ? Colors.white : Colors.white70,
            fontWeight:
                _selectedIndex == 2 ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: _selectedIndex == 2,
        selectedTileColor: Colors.white.withOpacity(0.1),
        onTap: () => _onItemTapped(2),
      ),
    ];
  }

  Widget _buildSettingsPage() {
    return Scaffold(
      appBar: null, // Remove AppBar since we already have one in the parent
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Админ профайл',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text('И-мэйл: ${AuthService.currentUser?.email ?? ""}'),
                    Text('Нэр: ${AuthService.currentUser?.displayName ?? ""}'),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        await AuthService.logout();
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/',
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Гарах'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
