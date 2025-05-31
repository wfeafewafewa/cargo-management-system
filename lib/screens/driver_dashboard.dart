import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/notification_bell.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({Key? key}) : super(key: key);

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _driverName = '';
  String _driverId = '';
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDriverData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDriverData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // ユーザー情報を取得
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (userData.exists) {
        setState(() {
          _driverName = userData.data()?['name'] ?? 'ドライバー';
          _driverId = user.uid;
        });
      }

      // 統計データを取得
      await _loadStats();
    } catch (e) {
      print('ドライバーデータ読み込みエラー: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStats() async {
    try {
      final futures = await Future.wait([
        // 自分の配送案件
        FirebaseFirestore.instance
            .collection('deliveries')
            .where('driverId', isEqualTo: _driverId)
            .get(),
        // 今月の売上
        FirebaseFirestore.instance
            .collection('sales')
            .where('driverId', isEqualTo: _driverId)
            .where('year', isEqualTo: DateTime.now().year)
            .where('month', isEqualTo: DateTime.now().month)
            .get(),
      ]);

      final deliveries = futures[0].docs;
      final sales = futures[1].docs;

      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);

      // 統計計算
      final totalDeliveries = deliveries.length;
      final pendingDeliveries = deliveries.where((d) => 
          (d.data() as Map<String, dynamic>)['status'] == '配送中').length;
      final completedDeliveries = deliveries.where((d) => 
          (d.data() as Map<String, dynamic>)['status'] == '完了').length;

      // 今日の売上
      double todaySales = 0;
      double monthSales = 0;
      
      for (final sale in sales) {
        final data = sale.data() as Map<String, dynamic>;
        final amount = (data['amount'] as num?)?.toDouble() ?? 0;
        monthSales += amount;
        
        final completedAt = (data['completedAt'] as Timestamp?)?.toDate();
        if (completedAt != null && completedAt.isAfter(todayStart)) {
          todaySales += amount;
        }
      }

      setState(() {
        _stats = {
          'totalDeliveries': totalDeliveries,
          'pendingDeliveries': pendingDeliveries,
          'completedDeliveries': completedDeliveries,
          'todaySales': todaySales.toInt(),
          'monthSales': monthSales.toInt(),
          'completionRate': totalDeliveries > 0 
              ? ((completedDeliveries / totalDeliveries) * 100).round()
              : 0,
        };
      });
    } catch (e) {
      print('統計データ読み込みエラー: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$_driverName さん'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadDriverData,
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              } else if (value == 'profile') {
                _showProfile();
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'ダッシュボード'),
            Tab(icon: Icon(Icons.local_shipping), text: '配送案件'),
            Tab(icon: Icon(Icons.attach_money), text: '売上'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(),
          _buildDeliveriesTab(),
          _buildSalesTab(),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadDriverData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(),
            const SizedBox(height: 16),
            _buildStatsGrid(),
            const SizedBox(height: 16),
            _buildQuickActions(),
            const SizedBox(height: 16),
            _buildTodayDeliveries(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
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
              Colors.green.shade50,
              Colors.green.shade100,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.green,
                  child: Text(
                    _driverName.isNotEmpty ? _driverName[0].toUpperCase() : 'D',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'おつかれさまです！',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.green.shade700,
                        ),
                      ),
                      Text(
                        '$_driverName さん',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
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

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          '総配送件数',
          '${_stats['totalDeliveries'] ?? 0}',
          Icons.local_shipping,
          Colors.blue,
        ),
        _buildStatCard(
          '配送中',
          '${_stats['pendingDeliveries'] ?? 0}',
          Icons.timer,
          Colors.orange,
        ),
        _buildStatCard(
          '今日の売上',
          '¥${_formatNumber(_stats['todaySales'] ?? 0)}',
          Icons.today,
          Colors.green,
        ),
        _buildStatCard(
          '今月の売上',
          '¥${_formatNumber(_stats['monthSales'] ?? 0)}',
          Icons.calendar_month,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _tabController.animateTo(1),
                    icon: const Icon(Icons.list),
                    label: const Text('配送案件確認'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _tabController.animateTo(2),
                    icon: const Icon(Icons.attach_money),
                    label: const Text('売上確認'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayDeliveries() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '今日の配送案件',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('deliveries')
                  .where('driverId', isEqualTo: _driverId)
                  .where('status', isEqualTo: '配送中')
                  .orderBy('assignedAt', descending: true)
                  .limit(3)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Text('今日の配送案件はありません');
                }

                return Column(
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildDeliveryListItem(doc.id, data);
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveriesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('deliveries')
          .where('driverId', isEqualTo: _driverId)
          .orderBy('assignedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text('担当する配送案件はありません'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildDeliveryCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildSalesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sales')
          .where('driverId', isEqualTo: _driverId)
          .orderBy('completedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.attach_money, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text('売上データがありません'),
              ],
            ),
          );
        }

        // 月別集計
        final salesByMonth = <String, double>{};
        double totalSales = 0;

        for (final doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final amount = (data['amount'] as num?)?.toDouble() ?? 0;
          final year = data['year'] ?? 0;
          final month = data['month'] ?? 0;
          
          totalSales += amount;
          final key = '$year年${month}月';
          salesByMonth[key] = (salesByMonth[key] ?? 0) + amount;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            const Text(
                              '総売上',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                            Text(
                              '¥${_formatNumber(totalSales.toInt())}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            const Text(
                              '配送件数',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                            Text(
                              '${snapshot.data!.docs.length}件',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '月別売上',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...salesByMonth.entries.map((entry) => Card(
                child: ListTile(
                  leading: const Icon(Icons.calendar_month, color: Colors.blue),
                  title: Text(entry.key),
                  trailing: Text(
                    '¥${_formatNumber(entry.value.toInt())}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeliveryListItem(String deliveryId, Map<String, dynamic> data) {
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
          _buildStatusIcon(data['status'] as String?),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${data['pickupLocation'] as String? ?? 'N/A'} → ${data['deliveryLocation'] as String? ?? 'N/A'}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '¥${_formatNumber((data['fee'] as num? ?? 0).toInt())}',
                  style: const TextStyle(color: Colors.green),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryCard(String deliveryId, Map<String, dynamic> data) {
    final status = data['status'] as String? ?? '不明';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatusBadge(status),
                const Spacer(),
                Text(
                  '¥${_formatNumber((data['fee'] as num? ?? 0).toInt())}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    data['pickupLocation'] as String? ?? 'N/A',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.flag, color: Colors.green, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    data['deliveryLocation'] as String? ?? 'N/A',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            if (data['notes'] != null && (data['notes'] as String).isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.note, color: Colors.blue, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      data['notes'] as String,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatTimestamp(data['assignedAt'] as Timestamp?),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                if (status == '配送中')
                  ElevatedButton(
                    onPressed: () => _completeDelivery(deliveryId, data),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('完了報告'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(String? status) {
    IconData icon;
    Color color;
    
    switch (status) {
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
      child: Icon(icon, color: color, size: 16),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    Color bgColor;
    
    switch (status) {
      case '配送中':
        color = Colors.blue;
        bgColor = Colors.blue.shade100;
        break;
      case '完了':
        color = Colors.green;
        bgColor = Colors.green.shade100;
        break;
      default:
        color = Colors.grey;
        bgColor = Colors.grey.shade100;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _completeDelivery(String deliveryId, Map<String, dynamic> data) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('配送完了報告'),
        content: const Text('この配送を完了として報告しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('完了報告'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final batch = FirebaseFirestore.instance.batch();

        // 配送を完了状態に更新
        final deliveryRef = FirebaseFirestore.instance.collection('deliveries').doc(deliveryId);
        batch.update(deliveryRef, {
          'status': '完了',
          'completedAt': FieldValue.serverTimestamp(),
        });

        // 売上を自動生成
        final salesRef = FirebaseFirestore.instance.collection('sales').doc();
        batch.set(salesRef, {
          'deliveryId': deliveryId,
          'driverId': _driverId,
          'driverName': _driverName,
          'amount': (data['fee'] as num?)?.toDouble() ?? 0.0,
          'pickupLocation': data['pickupLocation'] as String?,
          'deliveryLocation': data['deliveryLocation'] as String?,
          'completedAt': FieldValue.serverTimestamp(),
          'month': DateTime.now().month,
          'year': DateTime.now().year,
        });

        await batch.commit();

        // 通知送信
        await NotificationService.notifyAllAdmins(
          title: '配送が完了しました',
          message: '$_driverName が ${data['deliveryLocation'] as String? ?? '配送先'} への配送を完了しました',
          type: 'delivery_completed',
          data: {'deliveryId': deliveryId},
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('配送完了を報告しました')),
        );

        // 統計を更新
        _loadStats();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
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
      return '${difference.inMinutes}分前に割り当て';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}時間前に割り当て';
    } else {
      return '${difference.inDays}日前に割り当て';
    }
  }

  void _showProfile() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('プロフィール'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('名前: $_driverName'),
            Text('メール: ${FirebaseAuth.instance.currentUser?.email ?? ''}'),
            Text('役割: ドライバー'),
            Text('総配送件数: ${_stats['totalDeliveries'] ?? 0}件'),
            Text('完了率: ${_stats['completionRate'] ?? 0}%'),
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
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacementNamed(context, '/login');
    }
  }
}