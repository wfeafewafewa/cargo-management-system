import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';

class DriverDashboardScreen extends StatefulWidget {
  final String? driverId; // 実際のアプリでは認証から取得

  const DriverDashboardScreen({
    Key? key,
    this.driverId,
  }) : super(key: key);

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  String _currentDriverId = 'test_driver_001'; // テスト用ID
  Map<String, dynamic> _driverData = {};
  List<Map<String, dynamic>> _todayDeliveries = [];
  List<Map<String, dynamic>> _todaySchedule = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.driverId != null) {
      _currentDriverId = widget.driverId!;
    }

    _setupAnimations();
    _loadDriverData();
    _createTestDriverIfNeeded();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
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

  Future<void> _createTestDriverIfNeeded() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(_currentDriverId)
          .get();

      if (!doc.exists) {
        // テスト用ドライバーデータを作成
        await FirebaseFirestore.instance
            .collection('drivers')
            .doc(_currentDriverId)
            .set({
          'name': '田中太郎',
          'phone': '090-1234-5678',
          'email': 'tanaka@example.com',
          'vehicle': 'トヨタ ハイエース',
          'license': 'AB123456789',
          'status': '稼働中',
          'rating': 4.5,
          'currentDeliveries': 3,
          'createdAt': FieldValue.serverTimestamp(),
          'statusUpdatedAt': FieldValue.serverTimestamp(),
        });

        // テスト用配送データを作成
        await _createTestDeliveries();
        await _createTestSchedule();
      }
    } catch (e) {
      print('Test data creation error: $e');
    }
  }

  Future<void> _createTestDeliveries() async {
    final today = DateTime.now();
    final deliveries = [
      {
        'id': 'delivery_001',
        'pickupLocation': '東京都渋谷区渋谷1-1-1',
        'deliveryLocation': '東京都新宿区新宿2-2-2',
        'status': 'assigned',
        'priority': 'high',
        'customerName': '山田商事',
        'customerPhone': '03-1234-5678',
        'scheduledTime':
            Timestamp.fromDate(today.add(const Duration(hours: 2))),
        'estimatedDuration': 45,
        'driverId': _currentDriverId,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'id': 'delivery_002',
        'pickupLocation': '東京都品川区品川3-3-3',
        'deliveryLocation': '東京都目黒区目黒4-4-4',
        'status': 'in_progress',
        'priority': 'medium',
        'customerName': '佐藤物流',
        'customerPhone': '03-2345-6789',
        'scheduledTime':
            Timestamp.fromDate(today.add(const Duration(hours: 4))),
        'estimatedDuration': 30,
        'driverId': _currentDriverId,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'id': 'delivery_003',
        'pickupLocation': '東京都港区港5-5-5',
        'deliveryLocation': '東京都千代田区千代田6-6-6',
        'status': 'pending',
        'priority': 'low',
        'customerName': '鈴木貿易',
        'customerPhone': '03-3456-7890',
        'scheduledTime':
            Timestamp.fromDate(today.add(const Duration(hours: 6))),
        'estimatedDuration': 60,
        'driverId': _currentDriverId,
        'createdAt': FieldValue.serverTimestamp(),
      },
    ];

    for (final delivery in deliveries) {
      await FirebaseFirestore.instance
          .collection('deliveries')
          .doc(delivery['id'] as String)
          .set(delivery);
    }
  }

  Future<void> _createTestSchedule() async {
    final today = DateTime.now();
    final scheduleEvents = [
      {
        'title': '車両点検',
        'description': '月次定期点検',
        'type': 'maintenance',
        'driverId': _currentDriverId,
        'date': Timestamp.fromDate(today),
        'startTime': Timestamp.fromDate(
            DateTime(today.year, today.month, today.day, 9, 0)),
        'endTime': Timestamp.fromDate(
            DateTime(today.year, today.month, today.day, 9, 30)),
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'title': '安全講習',
        'description': 'オンライン安全講習受講',
        'type': 'training',
        'driverId': _currentDriverId,
        'date': Timestamp.fromDate(today),
        'startTime': Timestamp.fromDate(
            DateTime(today.year, today.month, today.day, 13, 0)),
        'endTime': Timestamp.fromDate(
            DateTime(today.year, today.month, today.day, 14, 0)),
        'createdAt': FieldValue.serverTimestamp(),
      },
    ];

    for (final event in scheduleEvents) {
      await FirebaseFirestore.instance.collection('schedule_events').add(event);
    }
  }

  Future<void> _loadDriverData() async {
    setState(() => _isLoading = true);
    try {
      // ドライバー情報を取得
      final driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(_currentDriverId)
          .get();

      if (driverDoc.exists) {
        _driverData = driverDoc.data() ?? {};
      }

      // 今日の配送を取得
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final deliveriesQuery = await FirebaseFirestore.instance
          .collection('deliveries')
          .where('driverId', isEqualTo: _currentDriverId)
          .where('scheduledTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('scheduledTime', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('scheduledTime')
          .get();

      _todayDeliveries = deliveriesQuery.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      // 今日のスケジュールを取得
      final scheduleQuery = await FirebaseFirestore.instance
          .collection('schedule_events')
          .where('driverId', isEqualTo: _currentDriverId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('date')
          .orderBy('startTime')
          .get();

      _todaySchedule = scheduleQuery.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      setState(() => _isLoading = false);
      _animationController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('データ読み込みエラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: CustomScrollView(
                slivers: [
                  _buildSliverAppBar(),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildQuickActions(),
                        const SizedBox(height: 20),
                        _buildTodayStats(),
                        const SizedBox(height: 20),
                        _buildTodayDeliveries(),
                        const SizedBox(height: 20),
                        _buildTodaySchedule(),
                        const SizedBox(height: 20),
                        _buildPerformanceCard(),
                        const SizedBox(height: 100),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showStatusChangeDialog,
        icon: Icon(_getStatusIcon(_driverData['status'] as String? ?? 'オフライン')),
        label:
            Text(_getStatusText(_driverData['status'] as String? ?? 'オフライン')),
        backgroundColor:
            _getStatusColor(_driverData['status'] as String? ?? 'オフライン'),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    final status = _driverData['status'] as String? ?? 'オフライン';
    final name = _driverData['name'] as String? ?? 'ドライバー';

    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: _getStatusColor(status),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          '$name さん',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _getStatusColor(status),
                _getStatusColor(status).withOpacity(0.8),
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                _buildStatusBadge(status),
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.home),
          tooltip: 'ホームに戻る',
        ),
        IconButton(
          onPressed: _loadDriverData,
          icon: const Icon(Icons.refresh),
          tooltip: '更新',
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(status),
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            status,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'クイックアクション',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    '配送開始',
                    Icons.play_arrow,
                    Colors.green,
                    () => _startDelivery(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    '休憩開始',
                    Icons.pause,
                    Colors.orange,
                    () => _changeStatus('休憩中'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    '緊急連絡',
                    Icons.emergency,
                    Colors.red,
                    () => _emergencyContact(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    'ナビ開始',
                    Icons.navigation,
                    Colors.blue,
                    () => _startNavigation(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayStats() {
    final completedDeliveries =
        _todayDeliveries.where((d) => d['status'] == 'completed').length;
    final pendingDeliveries =
        _todayDeliveries.where((d) => d['status'] != 'completed').length;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '今日の実績',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    '完了',
                    '$completedDeliveries件',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    '残り',
                    '$pendingDeliveries件',
                    Icons.pending,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    '評価',
                    '${(_driverData['rating'] as num? ?? 0).toStringAsFixed(1)}★',
                    Icons.star,
                    Colors.amber,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayDeliveries() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '今日の配送',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_todayDeliveries.length}件',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_todayDeliveries.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.local_shipping, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        '今日の配送はありません',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._todayDeliveries
                  .map((delivery) => _buildDeliveryItem(delivery)),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryItem(Map<String, dynamic> delivery) {
    final status = delivery['status'] as String;
    final priority = delivery['priority'] as String? ?? 'medium';
    final scheduledTime = (delivery['scheduledTime'] as Timestamp?)?.toDate();

    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'in_progress':
        statusColor = Colors.blue;
        statusIcon = Icons.local_shipping;
        break;
      case 'assigned':
        statusColor = Colors.orange;
        statusIcon = Icons.assignment;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.pending;
    }

    Color priorityColor;
    switch (priority) {
      case 'high':
        priorityColor = Colors.red;
        break;
      case 'medium':
        priorityColor = Colors.orange;
        break;
      default:
        priorityColor = Colors.green;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(statusIcon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  delivery['customerName'] as String? ?? 'お客様',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  priority.toUpperCase(),
                  style: TextStyle(
                    color: priorityColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${delivery['pickupLocation']} → ${delivery['deliveryLocation']}',
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (scheduledTime != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')} 予定',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const Spacer(),
                Text(
                  '${delivery['estimatedDuration'] ?? 30}分',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showDeliveryDetails(delivery),
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('詳細'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: statusColor,
                    side: BorderSide(color: statusColor),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (status != 'completed')
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateDeliveryStatus(delivery),
                    icon: Icon(_getNextStatusIcon(status), size: 16),
                    label: Text(_getNextStatusText(status)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: statusColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodaySchedule() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '今日のスケジュール',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_todaySchedule.length}件',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_todaySchedule.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.event_available, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        '今日の予定はありません',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._todaySchedule.map((schedule) => _buildScheduleItem(schedule)),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleItem(Map<String, dynamic> schedule) {
    final type = schedule['type'] as String? ?? 'general';
    final title = schedule['title'] as String? ?? 'タイトルなし';
    final description = schedule['description'] as String? ?? '';
    final startTime = (schedule['startTime'] as Timestamp?)?.toDate();
    final endTime = (schedule['endTime'] as Timestamp?)?.toDate();

    Color typeColor;
    IconData typeIcon;

    switch (type) {
      case 'delivery':
        typeColor = Colors.green;
        typeIcon = Icons.local_shipping;
        break;
      case 'maintenance':
        typeColor = Colors.orange;
        typeIcon = Icons.build;
        break;
      case 'break':
        typeColor = Colors.grey;
        typeIcon = Icons.pause;
        break;
      case 'training':
        typeColor = Colors.purple;
        typeIcon = Icons.school;
        break;
      default:
        typeColor = Colors.blue;
        typeIcon = Icons.event;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: typeColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: typeColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: typeColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(typeIcon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
                if (startTime != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        _formatScheduleTime(startTime, endTime),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard() {
    final rating = (_driverData['rating'] as num? ?? 0).toDouble();
    final currentDeliveries = _driverData['currentDeliveries'] as num? ?? 0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '今月のパフォーマンス',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildPerformanceItem(
                    '総配送',
                    '${currentDeliveries.round()}件',
                    Icons.local_shipping,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildPerformanceItem(
                    '平均評価',
                    '${rating.toStringAsFixed(1)}★',
                    Icons.star,
                    Colors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildPerformanceItem(
                    '完了率',
                    '95%',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildPerformanceItem(
                    '稼働時間',
                    '8.2h',
                    Icons.timer,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceItem(
      String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // アクションメソッド
  void _showStatusChangeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ステータス変更'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.work, color: Colors.green),
              title: const Text('稼働中'),
              onTap: () => _changeStatus('稼働中'),
            ),
            ListTile(
              leading: const Icon(Icons.pause, color: Colors.orange),
              title: const Text('休憩中'),
              onTap: () => _changeStatus('休憩中'),
            ),
            ListTile(
              leading: const Icon(Icons.offline_bolt, color: Colors.grey),
              title: const Text('オフライン'),
              onTap: () => _changeStatus('オフライン'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeStatus(String newStatus) async {
    Navigator.pop(context);

    try {
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(_currentDriverId)
          .update({
        'status': newStatus,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _driverData['status'] = newStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ステータスを「$newStatus」に変更しました'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('エラー: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startDelivery() {
    final pendingDelivery = _todayDeliveries
        .where((d) => d['status'] == 'assigned' || d['status'] == 'pending')
        .isNotEmpty;

    if (!pendingDelivery) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('開始可能な配送がありません'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _changeStatus('稼働中');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('配送を開始しました'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _emergencyContact() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('緊急連絡'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.phone, color: Colors.red),
              title: Text('事故・緊急時'),
              subtitle: Text('110 / 119'),
            ),
            ListTile(
              leading: Icon(Icons.business, color: Colors.blue),
              title: Text('運行管理者'),
              subtitle: Text('090-0000-0000'),
            ),
            ListTile(
              leading: Icon(Icons.support_agent, color: Colors.green),
              title: Text('サポートセンター'),
              subtitle: Text('0120-000-000'),
            ),
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

  void _startNavigation() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ナビゲーションアプリを起動中...'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showDeliveryDetails(Map<String, dynamic> delivery) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(delivery['customerName'] as String? ?? 'お客様'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('集荷先', delivery['pickupLocation'] as String? ?? ''),
            _buildDetailRow(
                '配送先', delivery['deliveryLocation'] as String? ?? ''),
            _buildDetailRow(
                'お客様電話', delivery['customerPhone'] as String? ?? ''),
            _buildDetailRow('ステータス', delivery['status'] as String? ?? ''),
            _buildDetailRow('優先度', delivery['priority'] as String? ?? ''),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
          if (delivery['status'] != 'completed')
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _updateDeliveryStatus(delivery);
              },
              child: Text(_getNextStatusText(delivery['status'] as String)),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _updateDeliveryStatus(Map<String, dynamic> delivery) async {
    final currentStatus = delivery['status'] as String;
    String nextStatus;

    switch (currentStatus) {
      case 'assigned':
      case 'pending':
        nextStatus = 'in_progress';
        break;
      case 'in_progress':
        nextStatus = 'completed';
        break;
      default:
        return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('deliveries')
          .doc(delivery['id'] as String)
          .update({
        'status': nextStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        if (nextStatus == 'completed')
          'completedAt': FieldValue.serverTimestamp(),
      });

      _loadDriverData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('配送ステータスを「${_getStatusDisplayName(nextStatus)}」に更新しました'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('エラー: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ヘルパーメソッド
  Color _getStatusColor(String status) {
    switch (status) {
      case '稼働中':
        return Colors.green;
      case '休憩中':
        return Colors.orange;
      case 'オフライン':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case '稼働中':
        return Icons.work;
      case '休憩中':
        return Icons.pause;
      case 'オフライン':
        return Icons.offline_bolt;
      default:
        return Icons.help;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case '稼働中':
        return '稼働中';
      case '休憩中':
        return '休憩中';
      case 'オフライン':
        return 'オフライン';
      default:
        return 'ステータス変更';
    }
  }

  IconData _getNextStatusIcon(String currentStatus) {
    switch (currentStatus) {
      case 'assigned':
      case 'pending':
        return Icons.play_arrow;
      case 'in_progress':
        return Icons.check;
      default:
        return Icons.update;
    }
  }

  String _getNextStatusText(String currentStatus) {
    switch (currentStatus) {
      case 'assigned':
      case 'pending':
        return '開始';
      case 'in_progress':
        return '完了';
      default:
        return '更新';
    }
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'assigned':
        return '割り当て済み';
      case 'pending':
        return '待機中';
      case 'in_progress':
        return '配送中';
      case 'completed':
        return '完了';
      default:
        return status;
    }
  }

  String _formatScheduleTime(DateTime? startTime, DateTime? endTime) {
    if (startTime == null) return '';

    final start =
        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    if (endTime == null) return start;

    final end =
        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
    return '$start - $end';
  }
}
