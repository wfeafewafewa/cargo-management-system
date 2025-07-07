import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:html' as html;
import 'dart:convert';
import 'dart:typed_data';

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

  String _currentDriverId = 'driver1'; // テスト用ID
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
          'driverName': '田中太郎',
          'phone': '090-1234-5678',
          'email': 'tanaka@example.com',
          'status': 'active',
          'vehicleType': '軽トラック',
          'createdAt': FieldValue.serverTimestamp(),
          'monthlyEarnings': 280000, // 月間売上（ドライバーに支払われる金額）
        });

        print('テスト用ドライバーを作成しました: $_currentDriverId');
      }
    } catch (e) {
      print('Test data creation error: $e');
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
        print('ドライバー情報取得成功: $_driverData');
      } else {
        print('ドライバー情報が見つかりません: $_currentDriverId');
      }

      // 今日の配送を取得（修正版）
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      print('ドライバーID: $_currentDriverId');
      print('検索範囲: $startOfDay ～ $endOfDay');

      // まず全体のクエリでデバッグ
      final allDeliveriesQuery =
          await FirebaseFirestore.instance.collection('deliveries').get();

      print('全配送案件数: ${allDeliveriesQuery.docs.length}');

      // ドライバーでフィルタリング（assignedDriverIdフィールドを使用）
      final driverDeliveriesQuery = await FirebaseFirestore.instance
          .collection('deliveries')
          .where('assignedDriverId', isEqualTo: _currentDriverId)
          .get();

      print('このドライバーの案件数: ${driverDeliveriesQuery.docs.length}');

      // 日付でもフィルタリング（より柔軟に）
      List<Map<String, dynamic>> filteredDeliveries = [];

      for (final doc in driverDeliveriesQuery.docs) {
        final data = doc.data();
        final scheduledTime = data['scheduledTime'] as Timestamp?;
        final createdAt = data['createdAt'] as Timestamp?;

        // 日付チェックを緩める（scheduledTimeがnullでも含める）
        bool includeDelivery = false;

        if (scheduledTime == null) {
          // scheduledTimeがない場合はcreatedAtで判定、それもなければ今日の案件として扱う
          if (createdAt != null) {
            final createDate = createdAt.toDate();
            includeDelivery =
                createDate.isAfter(startOfDay) && createDate.isBefore(endOfDay);
          } else {
            includeDelivery = true; // 作成日もない場合は含める
          }
        } else {
          final deliveryDate = scheduledTime.toDate();
          // 今日の案件かチェック
          includeDelivery = deliveryDate.isAfter(startOfDay) &&
              deliveryDate.isBefore(endOfDay);
        }

        if (includeDelivery) {
          filteredDeliveries.add({'id': doc.id, ...data});
        }
      }

      print('今日の案件数: ${filteredDeliveries.length}');
      if (filteredDeliveries.isNotEmpty) {
        print(
            '案件詳細: ${filteredDeliveries.map((d) => d['customerName'] ?? d['id']).toList()}');
      }

      _todayDeliveries = filteredDeliveries;

      setState(() => _isLoading = false);
      _animationController.forward();
    } catch (e) {
      print('データ読み込みエラー詳細: $e');
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
    final name = _driverData['driverName'] as String? ?? 'ドライバー';

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
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Icon(Icons.local_shipping,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        '今日の配送はありません',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '配送案件管理画面で案件を作成し、\nこのドライバーに割り当ててください',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                        textAlign: TextAlign.center,
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
    final status = delivery['status'] as String? ?? 'assigned';
    final priority = delivery['priority'] as String? ?? 'normal';
    final scheduledTime = (delivery['scheduledTime'] as Timestamp?)?.toDate();

    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case '完了':
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case '配送中':
      case 'in_progress':
        statusColor = Colors.blue;
        statusIcon = Icons.local_shipping;
        break;
      case '待機中':
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
      case 'urgent':
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
                  '${delivery['pickupLocation'] ?? 'N/A'} → ${delivery['deliveryLocation'] ?? 'N/A'}',
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
        'driverName': _driverData['driverName'] ?? _driverData['name'],
        'workDate': Timestamp.fromDate(DateTime.now()),
        'workStartTime':
            _workStartTime != null ? Timestamp.fromDate(_workStartTime!) : null,
        'workEndTime': Timestamp.fromDate(DateTime.now()),
        'selectedDelivery': reportData['selectedDelivery'],
        'feeType': reportData['feeType'],
        'totalAmount': reportData['totalAmount'],
        'itemCount': reportData['itemCount'],
        'expenseReceipt': reportData['expenseReceipt'],
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('レポート送信成功');
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
      case 'active':
        return Colors.green;
      case '休憩中':
        return Colors.orange;
      case 'オフライン':
      case 'inactive':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case '稼働中':
      case 'active':
        return Icons.work;
      case '休憩中':
        return Icons.pause;
      case 'オフライン':
      case 'inactive':
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

// 稼働終了レポートダイアログ（自賠責保険証書項目削除版）
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
  final _totalAmountController = TextEditingController();
  final _itemCountController = TextEditingController();

  String? _selectedDeliveryId;
  Map<String, dynamic>? _selectedDeliveryData;
  String _expenseReceipt = ''; // 立替費用の領収書画像
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.assignment_turned_in, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          const Text('稼働終了レポート'),
        ],
      ),
      content: SizedBox(
        width: 550,
        height: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 案件選択（必須）
                const Text(
                  '案件 *',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                if (widget.todayDeliveries.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning,
                                color: Colors.orange.shade700, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              '案件が見つかりません',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '配送案件管理画面で案件を作成し、このドライバーに割り当ててください。',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    value: _selectedDeliveryId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: '今日の配送案件から選択',
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('案件を選択してください',
                            style: TextStyle(color: Colors.grey)),
                      ),
                      ...widget.todayDeliveries.map((delivery) {
                        final customerName =
                            delivery['customerName'] as String? ?? '不明な顧客';
                        final pickupLocation =
                            delivery['pickupLocation'] as String? ?? '不明な場所';
                        final deliveryId = delivery['id'] as String;

                        return DropdownMenuItem<String>(
                          value: deliveryId,
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 48),
                            child: Text(
                              '$customerName ($pickupLocation)',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedDeliveryId = value;
                        if (value != null) {
                          _selectedDeliveryData = widget.todayDeliveries
                              .firstWhere(
                                  (delivery) => delivery['id'] == value);
                        } else {
                          _selectedDeliveryData = null;
                        }
                        // フォームをリセット
                        _totalAmountController.clear();
                        _itemCountController.clear();
                      });
                    },
                    validator: (value) => value == null ? '案件を選択してください' : null,
                  ),

                const SizedBox(height: 20),

                // 選択された案件の報酬形態に応じた入力フィールドを表示
                if (_selectedDeliveryData != null) ...[
                  _buildDynamicInputFields(),
                  const SizedBox(height: 20),
                ],

                // 画像アップロードセクション（立替費用の領収書のみ）
                _buildImageUploadSection(),
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

  Widget _buildDynamicInputFields() {
    final feeType = _selectedDeliveryData!['feeType'] as String? ?? 'daily';

    switch (feeType) {
      case 'per_item':
        return _buildItemOnlyFields();
      case 'daily':
      case 'hourly':
        return _buildAmountFields(feeType);
      default:
        return _buildAmountFields('daily');
    }
  }

  Widget _buildItemOnlyFields() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                '個数報酬案件',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '配達した荷物の個数のみ記録します',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _itemCountController,
            decoration: const InputDecoration(
              labelText: '配達した荷物の数 *',
              hintText: '例: 15',
              suffixText: '個',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value?.isEmpty == true) return '必須項目です';
              final count = int.tryParse(value!);
              if (count == null || count <= 0) return '正の数値を入力してください';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAmountFields(String feeType) {
    final feeTypeName = feeType == 'daily' ? '日当' : '時給';
    final hasItemTypes = _selectedDeliveryData!['itemTypes'] != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.attach_money, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                '$feeTypeName案件',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            hasItemTypes ? '支払われる総額と配達個数を記録します' : '支払われる総額を記録します',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),

          // 支払われる総額
          TextFormField(
            controller: _totalAmountController,
            decoration: InputDecoration(
              labelText: '支払われるべき総額 *',
              hintText: feeType == 'daily' ? '例: 8000' : '例: 1500',
              suffixText: '円',
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value?.isEmpty == true) return '必須項目です';
              final amount = int.tryParse(value!);
              if (amount == null || amount <= 0) return '正の数値を入力してください';
              return null;
            },
          ),

          // 個数フィールド（個数も含む案件の場合）
          if (hasItemTypes) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _itemCountController,
              decoration: const InputDecoration(
                labelText: '配達した荷物の数',
                hintText: '例: 10',
                suffixText: '個',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value?.isNotEmpty == true) {
                  final count = int.tryParse(value!);
                  if (count == null || count <= 0) return '正の数値を入力してください';
                }
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '画像アップロード（任意）',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        // 立替費用の領収書のみ
        _buildImageUploadCard(
          title: '立替費用の領収書',
          imageData: _expenseReceipt,
          color: Colors.green,
          onUpload: () => _selectImage('expense'),
          onDelete: () => setState(() => _expenseReceipt = ''),
          onView: () => _showImageViewer('立替費用の領収書', _expenseReceipt),
        ),
      ],
    );
  }

  Widget _buildImageUploadCard({
    required String title,
    required String imageData,
    required Color color,
    required VoidCallback onUpload,
    required VoidCallback onDelete,
    required VoidCallback onView,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onUpload,
                  icon: Icon(
                      imageData.isNotEmpty ? Icons.edit : Icons.file_upload),
                  label: Text(imageData.isNotEmpty ? '変更' : '選択'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              if (imageData.isNotEmpty) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onView,
                  icon: const Icon(Icons.visibility, color: Colors.blue),
                  tooltip: '閲覧',
                ),
                IconButton(
                  onPressed: () => _showDownloadDialog(title, imageData),
                  icon: const Icon(Icons.download, color: Colors.purple),
                  tooltip: 'ダウンロード',
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: '削除',
                ),
              ],
            ],
          ),
          if (imageData.isNotEmpty) _buildUploadedIndicator(),
        ],
      ),
    );
  }

  Widget _buildUploadedIndicator() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(Icons.check, color: Colors.green.shade700, size: 16),
          const SizedBox(width: 4),
          const Text(
            '画像がアップロードされました',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _selectImage(String type) async {
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
        if (type == 'expense') {
          _expenseReceipt = dataUrl;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('領収書画像をアップロードしました'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showImageViewer(String title, String imageData) {
    showDialog(
      context: context,
      builder: (context) => _ImageViewerDialog(
        title: title,
        imageData: imageData,
      ),
    );
  }

  void _showDownloadDialog(String title, String imageData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$title をダウンロード'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image, color: Colors.blue),
              title: const Text('画像ファイルとしてダウンロード'),
              subtitle: const Text('PNG形式'),
              onTap: () {
                Navigator.pop(context);
                _downloadAsImage(title, imageData);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('PDFとしてダウンロード'),
              subtitle: const Text('PDF形式'),
              onTap: () {
                Navigator.pop(context);
                _downloadAsPDF(title, imageData);
              },
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

  void _downloadAsImage(String title, String imageData) {
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final filename = '${title}_${dateStr}_$timeStr.png';

    final anchor = html.AnchorElement(href: imageData)
      ..download = filename
      ..click();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title を画像ファイルとしてダウンロードしました'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _downloadAsPDF(String title, String imageData) {
    // 簡易PDF生成（実際はpdf packageなどを使用することを推奨）
    final pdfContent = '''
%PDF-1.4
1 0 obj
<<
/Type /Catalog
/Pages 2 0 R
>>
endobj

2 0 obj
<<
/Type /Pages
/Kids [3 0 R]
/Count 1
>>
endobj

3 0 obj
<<
/Type /Page
/Parent 2 0 R
/MediaBox [0 0 612 792]
/Contents 4 0 R
>>
endobj

4 0 obj
<<
/Length 44
>>
stream
BT
/F1 12 Tf
100 700 Td
($title) Tj
ET
endstream
endobj

xref
0 5
0000000000 65535 f 
0000000010 00000 n 
0000000053 00000 n 
0000000125 00000 n 
0000000185 00000 n 
trailer
<<
/Size 5
/Root 1 0 R
>>
startxref
279
%%EOF
''';

    final bytes = Uint8List.fromList(utf8.encode(pdfContent));
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final filename = '${title}_${dateStr}_$timeStr.pdf';

    final anchor = html.AnchorElement(href: url)
      ..download = filename
      ..click();

    html.Url.revokeObjectUrl(url);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title をPDFとしてダウンロードしました'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _submitReport() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final feeType = _selectedDeliveryData!['feeType'] as String? ?? 'daily';

    final reportData = <String, dynamic>{
      'selectedDelivery': _selectedDeliveryId,
      'feeType': feeType,
      'expenseReceipt': _expenseReceipt,
    };

    // 報酬形態に応じてデータを追加
    if (feeType == 'per_item') {
      reportData['itemCount'] = int.tryParse(_itemCountController.text) ?? 0;
    } else {
      reportData['totalAmount'] =
          int.tryParse(_totalAmountController.text) ?? 0;

      final hasItemTypes = _selectedDeliveryData!['itemTypes'] != null;
      if (hasItemTypes && _itemCountController.text.isNotEmpty) {
        reportData['itemCount'] = int.tryParse(_itemCountController.text) ?? 0;
      }
    }

    Future.delayed(const Duration(seconds: 1), () {
      setState(() => _isLoading = false);
      Navigator.pop(context);
      widget.onSubmit(reportData);
    });
  }

  @override
  void dispose() {
    _totalAmountController.dispose();
    _itemCountController.dispose();
    super.dispose();
  }
}

// 画像閲覧ダイアログ
class _ImageViewerDialog extends StatelessWidget {
  final String title;
  final String imageData;

  const _ImageViewerDialog({
    required this.title,
    required this.imageData,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 800,
          maxHeight: 600,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ヘッダー
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.image, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // 画像表示エリア
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: InteractiveViewer(
                  panEnabled: true,
                  scaleEnabled: true,
                  minScale: 0.5,
                  maxScale: 3.0,
                  child: Image.network(
                    imageData,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error, size: 48, color: Colors.red),
                              SizedBox(height: 8),
                              Text('画像の読み込みに失敗しました'),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // フッター（操作ボタン）
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () =>
                        _downloadAsImage(title, imageData, context),
                    icon: const Icon(Icons.download),
                    label: const Text('画像ダウンロード'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _downloadAsPDF(title, imageData, context),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('PDF出力'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
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

  void _downloadAsImage(String title, String imageData, BuildContext context) {
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final filename = '${title}_${dateStr}_$timeStr.png';

    final anchor = html.AnchorElement(href: imageData)
      ..download = filename
      ..click();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title を画像ファイルとしてダウンロードしました'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _downloadAsPDF(String title, String imageData, BuildContext context) {
    // 簡易PDF生成
    final pdfContent = '''
%PDF-1.4
1 0 obj
<<
/Type /Catalog
/Pages 2 0 R
>>
endobj

2 0 obj
<<
/Type /Pages
/Kids [3 0 R]
/Count 1
>>
endobj

3 0 obj
<<
/Type /Page
/Parent 2 0 R
/MediaBox [0 0 612 792]
/Contents 4 0 R
>>
endobj

4 0 obj
<<
/Length 44
>>
stream
BT
/F1 12 Tf
100 700 Td
($title) Tj
ET
endstream
endobj

xref
0 5
0000000000 65535 f 
0000000010 00000 n 
0000000053 00000 n 
0000000125 00000 n 
0000000185 00000 n 
trailer
<<
/Size 5
/Root 1 0 R
>>
startxref
279
%%EOF
''';

    final bytes = Uint8List.fromList(utf8.encode(pdfContent));
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final filename = '${title}_${dateStr}_$timeStr.pdf';

    final anchor = html.AnchorElement(href: url)
      ..download = filename
      ..click();

    html.Url.revokeObjectUrl(url);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title をPDFとしてダウンロードしました'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
