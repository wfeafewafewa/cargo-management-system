import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with TickerProviderStateMixin {
  Map<String, int> _stats = {};
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

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

      // 統計計算（安全な型変換）
      final pendingDeliveries = deliveries.docs.where((d) {
        final data = d.data() as Map<String, dynamic>?;
        return data?['status'] == '待機中';
      }).length;

      final inProgressDeliveries = deliveries.docs.where((d) {
        final data = d.data() as Map<String, dynamic>?;
        return data?['status'] == '配送中';
      }).length;

      final completedDeliveries = deliveries.docs.where((d) {
        final data = d.data() as Map<String, dynamic>?;
        return data?['status'] == '完了';
      }).length;

      final activeDrivers = drivers.docs.where((d) {
        final data = d.data() as Map<String, dynamic>?;
        return data?['status'] == '稼働中';
      }).length;

      final restingDrivers = drivers.docs.where((d) {
        final data = d.data() as Map<String, dynamic>?;
        return data?['status'] == '休憩中';
      }).length;

      // 今日の売上
      double todaySales = 0;
      int todayCompletedCount = 0;

      // 今月の売上
      final monthStart = DateTime(today.year, today.month, 1);
      double monthSales = 0;
      int monthCompletedCount = 0;

      for (final sale in sales.docs) {
        final data = sale.data() as Map<String, dynamic>?;
        final completedAt = (data?['completedAt'] as Timestamp?)?.toDate();
        final amount = (data?['amount'] as num?)?.toDouble() ?? 0;

        if (completedAt != null && completedAt.isAfter(todayStart)) {
          todaySales += amount;
          todayCompletedCount++;
        }
        if (completedAt != null && completedAt.isAfter(monthStart)) {
          monthSales += amount;
          monthCompletedCount++;
        }
      }

      // 平均単価計算
      final avgOrderValue =
          monthCompletedCount > 0 ? monthSales / monthCompletedCount : 0;

      setState(() {
        _stats = {
          'totalDeliveries': deliveries.docs.length,
          'pendingDeliveries': pendingDeliveries,
          'inProgressDeliveries': inProgressDeliveries,
          'completedDeliveries': completedDeliveries,
          'totalDrivers': drivers.docs.length,
          'activeDrivers': activeDrivers,
          'restingDrivers': restingDrivers,
          'todaySales': todaySales.round(),
          'monthSales': monthSales.round(),
          'todayCompletedCount': todayCompletedCount,
          'monthCompletedCount': monthCompletedCount,
          'avgOrderValue': avgOrderValue.round(),
          'completionRate': deliveries.docs.isEmpty
              ? 0
              : ((completedDeliveries / deliveries.docs.length) * 100).round(),
          'driverUtilization': drivers.docs.isEmpty
              ? 0
              : ((activeDrivers / drivers.docs.length) * 100).round(),
        };
        _isLoading = false;
      });

      _animationController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('データ読み込みエラー: ${e.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: '再試行',
              onPressed: _loadDashboardData,
              textColor: Colors.white,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理者ダッシュボード'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
          ),
          IconButton(
            onPressed: () => _showNotifications(),
            icon: Stack(
              children: [
                const Icon(Icons.notifications),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 12,
                      minHeight: 12,
                    ),
                    child: Text(
                      '${_stats['pendingDeliveries'] ?? 0}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
            tooltip: '通知',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  _showUserProfile();
                  break;
                case 'logout':
                  _logout();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: ListTile(
                  leading: Icon(Icons.person),
                  title: Text('プロフィール'),
                ),
              ),
              const PopupMenuDivider(),
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
          child: FadeTransition(
            opacity: _fadeAnimation,
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
                const SizedBox(height: 24),
                _buildSystemHealth(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    final user = FirebaseAuth.instance.currentUser;
    final currentHour = DateTime.now().hour;
    String greeting = currentHour < 12
        ? 'おはようございます'
        : currentHour < 18
            ? 'こんにちは'
            : 'お疲れさまです';

    return Card(
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.dashboard,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$greeting！',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      Text(
                        user?.email?.split('@')[0] ?? '管理者',
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
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade700.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.update,
                    size: 16,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '最終更新: ${DateTime.now().toString().substring(0, 16)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
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

  Widget _buildStatsSection() {
    if (_isLoading) {
      return Card(
        child: Container(
          height: 200,
          padding: const EdgeInsets.all(40),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('データを読み込み中...'),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text(
                  '今日の統計',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.3,
              children: [
                _buildStatCard(
                  '配送案件',
                  '${_stats['totalDeliveries'] ?? 0}',
                  Icons.local_shipping,
                  Colors.blue,
                  subtitle:
                      '待機: ${_stats['pendingDeliveries'] ?? 0} | 進行: ${_stats['inProgressDeliveries'] ?? 0}',
                ),
                _buildStatCard(
                  'ドライバー',
                  '${_stats['activeDrivers'] ?? 0}/${_stats['totalDrivers'] ?? 0}',
                  Icons.people,
                  Colors.green,
                  subtitle: '稼働率: ${_stats['driverUtilization'] ?? 0}%',
                ),
                _buildStatCard(
                  '今日の売上',
                  '¥${_formatNumber(_stats['todaySales'] ?? 0)}',
                  Icons.today,
                  Colors.orange,
                  subtitle: '${_stats['todayCompletedCount'] ?? 0}件完了',
                ),
                _buildStatCard(
                  '今月の売上',
                  '¥${_formatNumber(_stats['monthSales'] ?? 0)}',
                  Icons.calendar_month,
                  Colors.purple,
                  subtitle:
                      '平均: ¥${_formatNumber(_stats['avgOrderValue'] ?? 0)}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color,
      {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
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
              fontSize: 20,
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
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flash_on, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                const Text(
                  'クイックアクション',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.2,
              children: [
                _buildActionButton(
                  '配送管理',
                  Icons.local_shipping,
                  Colors.blue,
                  () {
                    print('配送管理がタップされました');
                    Navigator.pushNamed(context, '/delivery-management');
                  },
                ),
                _buildActionButton(
                  'ドライバー管理',
                  Icons.people,
                  Colors.green,
                  () {
                    print('ドライバー管理がタップされました');
                    Navigator.pushNamed(context, '/driver-management');
                  },
                ),
                _buildActionButton(
                  '売上管理',
                  Icons.attach_money,
                  Colors.orange,
                  () {
                    print('売上管理がタップされました');
                    Navigator.pushNamed(context, '/sales-management');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
      String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: () {
        print('$labelボタンがタップされました');
        try {
          onPressed();
        } catch (e) {
          print('エラー: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('画面遷移エラー: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: Colors.indigo.shade700),
                const SizedBox(width: 8),
                const Text(
                  '最近のアクティビティ',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/delivery-management'),
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
                  return Container(
                    height: 100,
                    child: const Center(child: CircularProgressIndicator()),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(40),
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

  Widget _buildSystemHealth() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.health_and_safety, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Text(
                  'システムヘルス',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildHealthIndicator(
                    'データベース',
                    true,
                    'オンライン',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildHealthIndicator(
                    'Firebase Auth',
                    true,
                    '正常',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildHealthIndicator(
                    'PDF生成',
                    true,
                    '動作中',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthIndicator(String service, bool isHealthy, String status) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHealthy
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHealthy
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            isHealthy ? Icons.check_circle : Icons.error,
            color: isHealthy ? Colors.green : Colors.red,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            service,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            status,
            style: TextStyle(
              fontSize: 10,
              color: isHealthy ? Colors.green : Colors.red,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
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
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStatusColor(data['status'])
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        data['status'] ?? 'N/A',
                        style: TextStyle(
                          fontSize: 10,
                          color: _getStatusColor(data['status']),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '¥${_formatNumber(data['fee'] ?? 0)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
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
    Color color = _getStatusColor(status);

    switch (status) {
      case '待機中':
        icon = Icons.hourglass_empty;
        break;
      case '配送中':
        icon = Icons.local_shipping;
        break;
      case '完了':
        icon = Icons.check_circle;
        break;
      default:
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case '待機中':
        return Colors.orange;
      case '配送中':
        return Colors.blue;
      case '完了':
        return Colors.green;
      default:
        return Colors.grey;
    }
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

  void _showNotifications() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('通知'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.warning, color: Colors.orange),
              title: Text('待機中の配送案件: ${_stats['pendingDeliveries'] ?? 0}件'),
            ),
            ListTile(
              leading: const Icon(Icons.info, color: Colors.blue),
              title: Text('進行中の配送案件: ${_stats['inProgressDeliveries'] ?? 0}件'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/delivery-management');
            },
            child: const Text('配送管理へ'),
          ),
        ],
      ),
    );
  }

  void _showUserProfile() {
    final user = FirebaseAuth.instance.currentUser;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ユーザープロフィール'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('メール: ${user?.email ?? 'N/A'}'),
            Text('UID: ${user?.uid ?? 'N/A'}'),
            Text(
                '作成日: ${user?.metadata.creationTime?.toString().substring(0, 10) ?? 'N/A'}'),
            Text(
                '最終ログイン: ${user?.metadata.lastSignInTime?.toString().substring(0, 16) ?? 'N/A'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
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
      try {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ログアウトエラー: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
