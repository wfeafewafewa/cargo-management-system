import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Map<String, int> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final futures = await Future.wait([
        FirebaseFirestore.instance.collection('deliveries').get(),
        FirebaseFirestore.instance.collection('drivers').get(),
        FirebaseFirestore.instance.collection('sales').get(),
      ]);

      final deliveries = futures[0];
      final drivers = futures[1];
      final sales = futures[2];

      // 今日の日付
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);

      // 統計計算
      final pendingDeliveries = deliveries.docs.where((d) => 
          (d.data() as Map<String, dynamic>)['status'] == '待機中').length;
      
      final inProgressDeliveries = deliveries.docs.where((d) => 
          (d.data() as Map<String, dynamic>)['status'] == '配送中').length;
      
      final completedDeliveries = deliveries.docs.where((d) => 
          (d.data() as Map<String, dynamic>)['status'] == '完了').length;

      final activeDrivers = drivers.docs.where((d) => 
          (d.data() as Map<String, dynamic>)['status'] == '稼働中').length;

      // 今日の売上
      double todaySales = 0;
      for (final sale in sales.docs) {
        final data = sale.data() as Map<String, dynamic>;
        final completedAt = (data['completedAt'] as Timestamp?)?.toDate();
        if (completedAt != null && completedAt.isAfter(todayStart)) {
          todaySales += (data['amount'] as num?)?.toDouble() ?? 0;
        }
      }

      // 今月の売上
      final monthStart = DateTime(today.year, today.month, 1);
      double monthSales = 0;
      for (final sale in sales.docs) {
        final data = sale.data() as Map<String, dynamic>;
        final completedAt = (data['completedAt'] as Timestamp?)?.toDate();
        if (completedAt != null && completedAt.isAfter(monthStart)) {
          monthSales += (data['amount'] as num?)?.toDouble() ?? 0;
        }
      }

      setState(() {
        _stats = {
          'totalDeliveries': deliveries.docs.length,
          'pendingDeliveries': pendingDeliveries,
          'inProgressDeliveries': inProgressDeliveries,
          'completedDeliveries': completedDeliveries,
          'totalDrivers': drivers.docs.length,
          'activeDrivers': activeDrivers,
          'todaySales': todaySales.round(),
          'monthSales': monthSales.round(),
          'completionRate': deliveries.docs.isEmpty ? 0 : 
              ((completedDeliveries / deliveries.docs.length) * 100).round(),
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('ダッシュボードデータ読み込みエラー: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理者ダッシュボード'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              } else if (value == 'settings') {
                _showComingSoon('設定');
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('設定'),
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text('ログアウト', style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeSection(),
              const SizedBox(height: 24),
              _buildStatsSection(),
              const SizedBox(height: 24),
              _buildQuickActions(),
              const SizedBox(height: 24),
              _buildRecentActivity(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.blue.shade100,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dashboard, color: Colors.blue.shade700, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '管理者ダッシュボード',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      Text(
                        '軽貨物業務管理システム',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '最終更新: ${DateTime.now().toString().substring(0, 16)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '今日の統計',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard(
                  '配送案件',
                  '${_stats['totalDeliveries'] ?? 0}',
                  Icons.local_shipping,
                  Colors.blue,
                  subtitle: '待機: ${_stats['pendingDeliveries'] ?? 0} | 進行: ${_stats['inProgressDeliveries'] ?? 0}',
                ),
                _buildStatCard(
                  'ドライバー',
                  '${_stats['activeDrivers'] ?? 0}/${_stats['totalDrivers'] ?? 0}',
                  Icons.people,
                  Colors.green,
                  subtitle: '稼働中/総数',
                ),
                _buildStatCard(
                  '今日の売上',
                  '¥${_formatNumber(_stats['todaySales'] ?? 0)}',
                  Icons.today,
                  Colors.orange,
                ),
                _buildStatCard(
                  '今月の売上',
                  '¥${_formatNumber(_stats['monthSales'] ?? 0)}',
                  Icons.calendar_month,
                  Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatCard(
              '完了率',
              '${_stats['completionRate'] ?? 0}%',
              Icons.check_circle,
              Colors.teal,
              isWide: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, 
      {String? subtitle, bool isWide = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: isWide ? 32 : 24),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: isWide ? 24 : 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'クイックアクション',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.5,
              children: [
                _buildActionButton(
                  '配送管理',
                  Icons.local_shipping,
                  Colors.blue,
                  () => Navigator.pushNamed(context, '/delivery-management'),
                ),
                _buildActionButton(
                  'ドライバー管理',
                  Icons.people,
                  Colors.green,
                  () => _showComingSoon('ドライバー管理'),
                ),
                _buildActionButton(
                  '売上管理',
                  Icons.attach_money,
                  Colors.orange,
                  () => _showComingSoon('売上管理'),
                ),
                _buildActionButton(
                  'パフォーマンス監視',
                  Icons.analytics,
                  Colors.purple,
                  () => Navigator.pushNamed(context, '/performance-monitor'),
                ),
                _buildActionButton(
                  'システム設定',
                  Icons.settings,
                  Colors.deepPurple,
                  () => Navigator.pushNamed(context, '/system-settings'),
                ),
                _buildActionButton(
                  'データ管理',
                  Icons.storage,
                  Colors.teal,
                  () => _showComingSoon('データ管理'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '最近のアクティビティ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showComingSoon('配送管理'),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('すべて見る'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('deliveries')
                  .orderBy('createdAt', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    child: const Column(
                      children: [
                        Icon(Icons.inbox, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text(
                          '最近のアクティビティはありません',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildActivityItem(data);
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          _buildStatusIcon(data['status']),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${data['pickupLocation'] ?? 'N/A'} → ${data['deliveryLocation'] ?? 'N/A'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${data['status'] ?? 'N/A'} - ¥${_formatNumber(data['fee'] ?? 0)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatTimestamp(data['createdAt']),
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(String? status) {
    IconData icon;
    Color color;
    
    switch (status) {
      case '待機中':
        icon = Icons.hourglass_empty;
        color = Colors.orange;
        break;
      case '配送中':
        icon = Icons.local_shipping;
        color = Colors.blue;
        break;
      case '完了':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      default:
        icon = Icons.help;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}時間前';
    } else {
      return '${difference.inDays}日前';
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature機能は準備中です'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ログアウト'),
        content: const Text('ログアウトしてもよろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacementNamed(context, '/login');
    }
  }
}