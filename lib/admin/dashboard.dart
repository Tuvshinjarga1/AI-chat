import 'package:flutter/material.dart';
import 'package:aichat/services/chat_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aichat/models/user_model.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  List<Map<String, dynamic>> _recentUsers = [];
  List<Map<String, dynamic>> _popularQuestions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final stats = await ChatService.getStats();

      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      final recentUsers = usersSnapshot.docs.map((doc) {
        final user = UserModel.fromFirestore(doc);
        return {
          'id': user.id,
          'name': user.displayName,
          'email': user.email,
          'joinDate': user.createdAt,
        };
      }).toList();

      final questionsSnapshot = await FirebaseFirestore.instance
          .collection('questions')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      final popularQuestions = questionsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'question': data['question'],
          'answer': data['answer'],
          'date': (data['createdAt'] as Timestamp).toDate(),
        };
      }).toList();

      setState(() {
        _stats = stats;
        _recentUsers = recentUsers;
        _popularQuestions = popularQuestions;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Column(
      children: [
        Container(
          color: Theme.of(context).colorScheme.primary,
          child: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            indicatorWeight: 3,
            labelPadding: EdgeInsets.symmetric(vertical: 8),
            tabs: const [
              Tab(text: 'Ерөнхий'),
              Tab(text: 'Хэрэглэгчид'),
              Tab(text: 'Асуултууд'),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(isSmallScreen),
                    _buildUsersTab(),
                    _buildQuestionsTab(),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab(bool isSmallScreen) {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ерөнхий статистик',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildStatCards(isSmallScreen),
            const SizedBox(height: 16),
            const Text(
              'Асуултын төрлүүд',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: isSmallScreen ? 180 : 220,
              child: _buildQuestionTypesPieChart(),
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCards(bool isSmallScreen) {
    return GridView.count(
      crossAxisCount: isSmallScreen ? 2 : 2,
      crossAxisSpacing: isSmallScreen ? 8 : 16,
      mainAxisSpacing: isSmallScreen ? 8 : 16,
      childAspectRatio: isSmallScreen ? 1.1 : 1.3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard(
          title: 'Хэрэглэгч',
          value: _stats['totalUsers']?.toString() ?? '0',
          icon: Icons.people,
          color: Colors.blue,
          isSmallScreen: isSmallScreen,
        ),
        _buildStatCard(
          title: 'Нийт асуулт',
          value: _stats['totalQuestions']?.toString() ?? '0',
          icon: Icons.question_answer,
          color: Colors.green,
          isSmallScreen: isSmallScreen,
        ),
        _buildStatCard(
          title: 'Нийт чатнууд',
          value: _stats['totalMessages']?.toString() ?? '0',
          icon: Icons.chat,
          color: Colors.orange,
          isSmallScreen: isSmallScreen,
        ),
        _buildStatCard(
          title: '7 хоног чат',
          value: _stats['recentMessages']?.toString() ?? '0',
          icon: Icons.trending_up,
          color: Colors.purple,
          isSmallScreen: isSmallScreen,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isSmallScreen,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 8.0 : 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: isSmallScreen ? 24 : 30, color: color),
            SizedBox(height: isSmallScreen ? 4 : 8),
            Text(
              value,
              style: TextStyle(
                  fontSize: isSmallScreen ? 16 : 20,
                  fontWeight: FontWeight.bold,
                  color: color),
            ),
            SizedBox(height: isSmallScreen ? 2 : 4),
            Text(
              title,
              style: TextStyle(
                fontSize: isSmallScreen ? 12 : 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionTypesPieChart() {
    final manualQuestions = _stats['manualQuestions'] ?? 0;
    final aiGenerated = _stats['aiGeneratedQuestions'] ?? 0;

    return manualQuestions == 0 && aiGenerated == 0
        ? const Center(child: Text('Асуултын мэдээлэл байхгүй байна'))
        : PieChart(
            PieChartData(
              sections: [
                PieChartSectionData(
                  value: manualQuestions.toDouble(),
                  title: 'Гараар',
                  color: Colors.blue,
                  radius: 80,
                  titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                PieChartSectionData(
                  value: aiGenerated.toDouble(),
                  title: 'AI',
                  color: Colors.orange,
                  radius: 80,
                  titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ],
              centerSpaceRadius: 30,
              sectionsSpace: 2,
            ),
          );
  }

  Widget _buildUsersTab() {
    return _recentUsers.isEmpty
        ? const Center(child: Text('Хэрэглэгчдийн мэдээлэл байхгүй байна'))
        : ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: _recentUsers.length,
            itemBuilder: (context, index) {
              final user = _recentUsers[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(child: Text(user['name'][0])),
                  title: Text(user['name'],
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(user['email'],
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text(
                    DateFormat('yyyy-MM-dd').format(user['joinDate']),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              );
            },
          );
  }

  Widget _buildQuestionsTab() {
    return _popularQuestions.isEmpty
        ? const Center(child: Text('Асуултын мэдээлэл байхгүй байна'))
        : ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: _popularQuestions.length,
            itemBuilder: (context, index) {
              final question = _popularQuestions[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ExpansionTile(
                  title: Text(
                    question['question'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    DateFormat('yyyy-MM-dd').format(question['date']),
                    style: const TextStyle(fontSize: 12),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(question['answer']),
                    ),
                  ],
                ),
              );
            },
          );
  }
}
