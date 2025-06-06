import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:html' as html;

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
  bool _isLoading = true;
  bool _isWorking = false; // 稼働状態
  DateTime? _workStartTime; // 稼働開始時間

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
          'status': '稼働中',
          'createdAt': FieldValue.serverTimestamp(),
          'statusUpdatedAt': FieldValue.serverTimestamp(),
          'monthlyEarnings': 280000, // 月間売上（ドライバーに支払われる金額）
        });

        // テスト用配送データを作成
        await _createTestDeliveries();
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
        // 注意: 受注金額（fee）は意図的に除外
      },
      {
        'id': 'delivery_002',
        'pickupLocation': '東京都品川区品川3-3-3',
        'deliveryLocation': '東京都目黒区目黒4-4-4',
        'status': 'assigned',
        'priority': 'normal',
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
        'status': 'assigned',
        'priority': 'normal',
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

      // 今日の配送を取得（自身がアサインされたもののみ）
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
                        _buildTodayDeliveries(),
                        const SizedBox(height: 20),
                        _buildMonthlyPerformance(),
                        const SizedBox(height: 100),
                      ]),
                    ),
                  ),
                ],
              ),
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
                  child: const Icon(
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

  // 修正: クイックアクションを要件に合わせて変更
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
                    _isWorking ? '稼働終了' : '稼働開始',
                    _isWorking ? Icons.stop : Icons.play_arrow,
                    _isWorking ? Colors.red : Colors.green,
                    () => _isWorking ? _endWork() : _startWork(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    '緊急連絡',
                    Icons.emergency,
                    Colors.red,
                    () => _emergencyContact(),
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

  // 修正: 今日の配送（管理者画面でアサインされたもののみ表示）
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
            const SizedBox(height: 8),
            const Text(
              '自身が本日対応するべき配送案件を表示',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
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
    final priority = delivery['priority'] as String? ?? 'normal';
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
      case 'normal':
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
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showDeliveryDetails(delivery),
              icon: const Icon(Icons.info_outline, size: 16),
              label: const Text('詳細確認'),
              style: OutlinedButton.styleFrom(
                foregroundColor: statusColor,
                side: BorderSide(color: statusColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 修正: 今月のパフォーマンスを総売上額のみに簡素化
  Widget _buildMonthlyPerformance() {
    final monthlyEarnings = _driverData['monthlyEarnings'] as num? ?? 0;

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
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.green,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '今月の総売上額',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '¥${_formatNumber(monthlyEarnings.round())}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
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

  // 稼働開始機能
  void _startWork() {
    setState(() {
      _isWorking = true;
      _workStartTime = DateTime.now();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('稼働を開始しました'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // 稼働終了機能（レポート付き）
  void _endWork() {
    showDialog(
      context: context,
      builder: (context) => _WorkReportDialog(
        workStartTime: _workStartTime,
        todayDeliveries: _todayDeliveries,
        onSubmit: (reportData) {
          _submitWorkReport(reportData);
        },
      ),
    );
  }

  void _submitWorkReport(Map<String, dynamic> reportData) {
    setState(() {
      _isWorking = false;
      _workStartTime = null;
    });

    // レポートデータを管理者画面に送信
    _sendReportToAdmin(reportData);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('稼働終了レポートを送信しました'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _sendReportToAdmin(Map<String, dynamic> reportData) async {
    try {
      await FirebaseFirestore.instance.collection('work_reports').add({
        'driverId': _currentDriverId,
        'driverName': _driverData['name'],
        'workDate': Timestamp.fromDate(DateTime.now()),
        'workStartTime':
            _workStartTime != null ? Timestamp.fromDate(_workStartTime!) : null,
        'workEndTime': Timestamp.fromDate(DateTime.now()),
        'selectedDelivery': reportData['selectedDelivery'],
        'unitPrice': reportData['unitPrice'],
        'totalAmount': reportData['totalAmount'],
        'expenseReceipt': reportData['expenseReceipt'],
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('レポート送信エラー: $e');
    }
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
            // 注意: 受注金額は表示しない
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

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}

// 稼働終了レポートダイアログ
class _WorkReportDialog extends StatefulWidget {
  final DateTime? workStartTime;
  final List<Map<String, dynamic>> todayDeliveries;
  final Function(Map<String, dynamic>) onSubmit;

  const _WorkReportDialog({
    required this.workStartTime,
    required this.todayDeliveries,
    required this.onSubmit,
  });

  @override
  State<_WorkReportDialog> createState() => _WorkReportDialogState();
}

class _WorkReportDialogState extends State<_WorkReportDialog> {
  final _formKey = GlobalKey<FormState>();
  final _unitPriceController = TextEditingController();
  final _totalAmountController = TextEditingController();

  String? _selectedDeliveryId;
  String _expenseReceipt = ''; // 立替費用の領収書画像
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final workDuration = widget.workStartTime != null
        ? DateTime.now().difference(widget.workStartTime!)
        : Duration.zero;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.assignment_turned_in, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          const Text('稼働終了レポート'),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 稼働時間表示
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '稼働時間',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${workDuration.inHours}時間${workDuration.inMinutes % 60}分',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      if (widget.workStartTime != null)
                        Text(
                          '${widget.workStartTime!.hour.toString().padLeft(2, '0')}:${widget.workStartTime!.minute.toString().padLeft(2, '0')} ～ ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 必須: 案件選択
                const Text(
                  '案件 *',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedDeliveryId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '今日の配送案件から選択',
                  ),
                  items: widget.todayDeliveries.map((delivery) {
                    return DropdownMenuItem<String>(
                      value: delivery['id'] as String,
                      child: Text(
                        '${delivery['customerName']} (${delivery['pickupLocation']})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedDeliveryId = value;
                    });
                  },
                  validator: (value) => value == null ? '案件を選択してください' : null,
                ),

                const SizedBox(height: 20),

                // 必須: 支払われるべき単価
                const Text(
                  '支払われるべき単価 *',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _unitPriceController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '例: 5000',
                    suffixText: '円',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) =>
                      value?.isEmpty == true ? '必須項目です' : null,
                  onChanged: (value) {
                    _updateTotalAmount();
                  },
                ),

                const SizedBox(height: 20),

                // 必須: 支払われるべき総額
                const Text(
                  '支払われるべき総額 *',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _totalAmountController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '例: 5000',
                    suffixText: '円',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) =>
                      value?.isEmpty == true ? '必須項目です' : null,
                ),

                const SizedBox(height: 20),

                // 任意: 画像アップロード（立替費用の領収書）
                const Text(
                  '画像アップロード（任意）',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '立替費用の領収書',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _selectExpenseReceipt,
                              icon: Icon(_expenseReceipt.isNotEmpty
                                  ? Icons.edit
                                  : Icons.file_upload),
                              label: Text(
                                  _expenseReceipt.isNotEmpty ? '変更' : '選択'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          if (_expenseReceipt.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _expenseReceipt = '';
                                });
                              },
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: '削除',
                            ),
                          ],
                        ],
                      ),
                      if (_expenseReceipt.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check,
                                  color: Colors.green.shade700, size: 16),
                              const SizedBox(width: 4),
                              const Text(
                                '画像がアップロードされました',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitReport,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('送信'),
        ),
      ],
    );
  }

  void _updateTotalAmount() {
    final unitPrice = int.tryParse(_unitPriceController.text) ?? 0;
    _totalAmountController.text = unitPrice.toString();
  }

  void _selectExpenseReceipt() async {
    final input = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..click();

    await input.onChange.first;
    if (input.files!.isNotEmpty) {
      final file = input.files![0];
      final reader = html.FileReader();
      reader.readAsDataUrl(file);

      await reader.onLoad.first;
      final dataUrl = reader.result as String;

      setState(() {
        _expenseReceipt = dataUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('領収書画像をアップロードしました'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _submitReport() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final reportData = {
      'selectedDelivery': _selectedDeliveryId,
      'unitPrice': int.tryParse(_unitPriceController.text) ?? 0,
      'totalAmount': int.tryParse(_totalAmountController.text) ?? 0,
      'expenseReceipt': _expenseReceipt,
    };

    // 少し遅延を入れてリアルな感じを演出
    Future.delayed(const Duration(seconds: 1), () {
      setState(() => _isLoading = false);
      Navigator.pop(context);
      widget.onSubmit(reportData);
    });
  }

  @override
  void dispose() {
    _unitPriceController.dispose();
    _totalAmountController.dispose();
    super.dispose();
  }
}
