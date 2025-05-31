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
  String _driverId = '';
  String _driverName = '';
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDriverInfo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDriverInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // ユーザー情報を取得
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          _driverId = user.uid;
          _driverName = userData['name'] ?? 'ドライバー';
        }

        await _loadDashboardStats();
      }
    } catch (e) {
      print('ドライバー情報読み込みエラー: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDashboardStats() async {
    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final todayStart = DateTime(now.year, now.month, now.day);

      // 担当案件を取得
      final deliveriesQuery = await FirebaseFirestore.instance
          .collection('deliveries')
          .where('driverId', isEqualTo: _driverId)
          .get();

      // 売上データを取得
      final salesQuery = await FirebaseFirestore.instance
          .collection('sales')
          .where('driverId', isEqualTo: _driverId)
          .get();

      final deliveries = deliveriesQuery.docs;
      final sales = salesQuery.docs;

      // 統計計算
      final pendingDeliveries = deliveries
          .where((d) => (d.data()['status'] as String?) == '配送中')
          .length;

      final completedDeliveries = deliveries
          .where((d) => (d.data()['status'] as String?) == '完了')
          .length;

      // 今日の売上
      double todaySales = 0;
      for (final sale in sales) {
        final data = sale.data();
        final completedAt = (data['completedAt'] as Timestamp?)?.toDate();
        if (completedAt != null && completedAt.isAfter(todayStart)) {
          todaySales += (data['amount'] as num?)?.toDouble() ?? 0;
        }
      }

      // 今月の売上
      double monthSales = 0;
      int monthDeliveries = 0;
      for (final sale in sales) {
        final data = sale.data();
        final completedAt = (data['completedAt'] as Timestamp?)?.toDate();
        if (completedAt != null && completedAt.isAfter(monthStart)) {
          monthSales += (data['amount'] as num?)?.toDouble() ?? 0;
          monthDeliveries++;
        }
      }

      setState(() {
        _stats = {
          'totalAssigned': deliveries.length,
          'pendingDeliveries': pendingDeliveries,
          'completedDeliveries': completedDeliveries,
          'todaySales': todaySales.round(),
          'monthSales': monthSales.round(),
          'monthDeliveries': monthDeliveries,
          'averagePerDelivery':
              monthDeliveries > 0 ? (monthSales / monthDeliveries).round() : 0,
        };
      });
    } catch (e) {
      print('統計データ読み込みエラー: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ドライバーダッシュボード'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: _loadDashboardStats,
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'ダッシュボード'),
            Tab(icon: Icon(Icons.local_shipping), text: '担当案件'),
            Tab(icon: Icon(Icons.attach_money), text: '売上確認'),
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
    return RefreshIndicator(
      onRefresh: _loadDashboardStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
            _buildRecentActivity(),
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
              Colors.orange.shade50,
              Colors.orange.shade100,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Text(
                    _driverName.isNotEmpty ? _driverName[0].toUpperCase() : 'D',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'おかえりなさい、$_driverName さん',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                      Text(
                        '今日も安全運転でお疲れ様です',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange.shade600,
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
      childAspectRatio: 1.3,
      children: [
        _buildStatCard(
          '担当案件',
          '${_stats['pendingDeliveries'] ?? 0}',
          Icons.local_shipping,
          Colors.blue,
          subtitle: '配送待ち',
        ),
        _buildStatCard(
          '完了案件',
          '${_stats['completedDeliveries'] ?? 0}',
          Icons.check_circle,
          Colors.green,
          subtitle: '今月完了',
        ),
        _buildStatCard(
          '今日の売上',
          '¥${_formatNumber(_stats['todaySales'] ?? 0)}',
          Icons.today,
          Colors.purple,
        ),
        _buildStatCard(
          '今月の売上',
          '¥${_formatNumber(_stats['monthSales'] ?? 0)}',
          Icons.calendar_month,
          Colors.orange,
          subtitle: '${_stats['monthDeliveries'] ?? 0}件完了',
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color,
      {String? subtitle}) {
    return Card(
      child: Container(
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
                Icon(icon, color: color, size: 24),
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
                fontSize: 18,
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
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _tabController.animateTo(1),
                    icon: const Icon(Icons.local_shipping),
                    label: const Text('担当案件確認'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
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
                      padding: const EdgeInsets.all(16),
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

  Widget _buildRecentActivity() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '最近の活動',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('deliveries')
                  .where('driverId', isEqualTo: _driverId)
                  .orderBy('createdAt', descending: true)
                  .limit(3)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      children: [
                        Icon(Icons.inbox, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('最近の活動はありません'),
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
      margin: const EdgeInsets.only(bottom: 12),
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
                  '${_safeString(data['pickupLocation']) ?? 'N/A'} → ${_safeString(data['deliveryLocation']) ?? 'N/A'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_safeString(data['status']) ?? 'N/A'} - ¥${_formatNumber((_safeNumber(data['fee']) ?? 0).round())}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatTimestamp(data['createdAt'] as Timestamp?),
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveriesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('deliveries')
          .where('driverId', isEqualTo: _driverId)
          .where('status', isEqualTo: '配送中')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyDeliveries();
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

  Widget _buildEmptyDeliveries() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '現在担当中の案件はありません',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '新しい案件が割り当てられるまでお待ちください',
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryCard(String deliveryId, Map<String, dynamic> data) {
    final priority = _safeString(data['priority']) ?? 'normal';
    final isUrgent = priority == 'urgent';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isUrgent ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isUrgent
            ? const BorderSide(color: Colors.red, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isUrgent) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '緊急',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                const Spacer(),
                Text(
                  '¥${_formatNumber((_safeNumber(data['fee']) ?? 0).round())}',
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
                    _safeString(data['pickupLocation']) ?? 'N/A',
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
                    _safeString(data['deliveryLocation']) ?? 'N/A',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            if (_safeString(data['notes']) != null &&
                _safeString(data['notes'])!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.note, color: Colors.blue.shade600, size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _safeString(data['notes'])!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '割り当て: ${_formatTimestamp(data['assignedAt'] as Timestamp?)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _completeDelivery(deliveryId, data),
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('完了報告'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
          return _buildEmptySales();
        }

        final sales = snapshot.data!.docs;
        final monthlySales = _groupSalesByMonth(sales);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSalesOverview(sales),
            const SizedBox(height: 16),
            ...monthlySales.entries
                .map((entry) => _buildMonthlySalesCard(entry.key, entry.value)),
          ],
        );
      },
    );
  }

  Widget _buildEmptySales() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.attach_money_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '売上データがありません',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '配送を完了すると売上が記録されます',
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesOverview(List<QueryDocumentSnapshot> sales) {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 1);
    final thisMonthSales = sales.where((s) {
      final data = s.data() as Map<String, dynamic>;
      final completedAt = (data['completedAt'] as Timestamp?)?.toDate();
      return completedAt != null && completedAt.isAfter(thisMonth);
    }).toList();

    final thisMonthAmount = thisMonthSales.fold<double>(0, (sum, s) {
      final data = s.data() as Map<String, dynamic>;
      return sum + ((data['amount'] as num?)?.toDouble() ?? 0);
    });

    final thisMonthCount = thisMonthSales.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '今月の売上サマリー',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    '売上金額',
                    '¥${_formatNumber(thisMonthAmount.round())}',
                    Colors.green,
                    Icons.attach_money,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryItem(
                    '完了件数',
                    '$thisMonthCount件',
                    Colors.blue,
                    Icons.local_shipping,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    '平均単価',
                    thisMonthCount > 0
                        ? '¥${_formatNumber((thisMonthAmount / thisMonthCount).round())}'
                        : '¥0',
                    Colors.orange,
                    Icons.trending_up,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryItem(
                    '総売上',
                    '¥${_formatNumber(_calculateTotalSales(sales))}',
                    Colors.purple,
                    Icons.account_balance_wallet,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
      String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlySalesCard(
      String monthKey, List<QueryDocumentSnapshot> sales) {
    final totalAmount = sales.fold<double>(0, (sum, s) {
      final data = s.data() as Map<String, dynamic>;
      return sum + ((data['amount'] as num?)?.toDouble() ?? 0);
    });

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  monthKey,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '¥${_formatNumber(totalAmount.round())}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${sales.length}件の配送完了',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: sales.length,
                itemBuilder: (context, index) {
                  final data = sales[index].data() as Map<String, dynamic>;
                  return Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(
                              (data['completedAt'] as Timestamp).toDate()),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '¥${_formatNumber((_safeNumber(data['amount']) ?? 0).round())}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Text(
                            '${_safeString(data['pickupLocation']) ?? ''} → ${_safeString(data['deliveryLocation']) ?? ''}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _completeDelivery(
      String deliveryId, Map<String, dynamic> data) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('配送完了報告'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('この配送案件を完了としてマークしますか？'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('集荷先: ${_safeString(data['pickupLocation']) ?? 'N/A'}'),
                  Text(
                      '配送先: ${_safeString(data['deliveryLocation']) ?? 'N/A'}'),
                  Text(
                      '料金: ¥${_formatNumber((_safeNumber(data['fee']) ?? 0).round())}'),
                ],
              ),
            ),
          ],
        ),
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
        final deliveryRef =
            FirebaseFirestore.instance.collection('deliveries').doc(deliveryId);
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
          'amount': (_safeNumber(data['fee']) ?? 0).toDouble(),
          'pickupLocation': _safeString(data['pickupLocation']),
          'deliveryLocation': _safeString(data['deliveryLocation']),
          'completedAt': FieldValue.serverTimestamp(),
          'month': DateTime.now().month,
          'year': DateTime.now().year,
        });

        await batch.commit();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('配送完了報告を送信しました'),
            backgroundColor: Colors.green,
          ),
        );

        // 統計を更新
        await _loadDashboardStats();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
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
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }

  Map<String, List<QueryDocumentSnapshot>> _groupSalesByMonth(
      List<QueryDocumentSnapshot> sales) {
    final Map<String, List<QueryDocumentSnapshot>> grouped = {};

    for (final sale in sales) {
      final data = sale.data() as Map<String, dynamic>;
      final completedAt = (data['completedAt'] as Timestamp?)?.toDate();
      if (completedAt != null) {
        final monthKey = '${completedAt.year}年${completedAt.month}月';
        grouped.putIfAbsent(monthKey, () => []).add(sale);
      }
    }

    return grouped;
  }

  int _calculateTotalSales(List<QueryDocumentSnapshot> sales) {
    return sales.fold<double>(0, (sum, s) {
      final data = s.data() as Map<String, dynamic>;
      return sum + ((data['amount'] as num?)?.toDouble() ?? 0);
    }).round();
  }

  String? _safeString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.isEmpty ? null : value;
    if (value is Map || value is List) return null;
    return value.toString();
  }

  num _safeNumber(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    if (value is String) {
      final parsed = num.tryParse(value);
      return parsed ?? 0;
    }
    return 0;
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

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }
}
