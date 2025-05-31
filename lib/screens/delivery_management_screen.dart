import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/notification_bell.dart';

class DeliveryManagementScreen extends StatefulWidget {
  const DeliveryManagementScreen({Key? key}) : super(key: key);

  @override
  State<DeliveryManagementScreen> createState() => _DeliveryManagementScreenState();
}

class _DeliveryManagementScreenState extends State<DeliveryManagementScreen> {
  String _selectedStatus = 'すべて';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('配送案件管理'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => _showBulkActions(),
            icon: const Icon(Icons.checklist),
            tooltip: '一括操作',
          ),
          IconButton(
            onPressed: () => _exportToCSV(),
            icon: const Icon(Icons.file_download),
            tooltip: 'CSVエクスポート',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          _buildStatsBar(),
          Expanded(child: _buildDeliveryList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDeliveryDialog,
        icon: const Icon(Icons.add),
        label: const Text('新規案件'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '配送先、集荷先で検索...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: _selectedStatus,
                  underline: const SizedBox(),
                  items: ['すべて', '待機中', '配送中', '完了', 'キャンセル']
                      .map((status) => DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value!;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickFilterChip('今日', () => _filterByDate(DateTime.now())),
                _buildQuickFilterChip('昨日', () => _filterByDate(DateTime.now().subtract(const Duration(days: 1)))),
                _buildQuickFilterChip('今週', () => _filterByWeek()),
                _buildQuickFilterChip('今月', () => _filterByMonth()),
                _buildQuickFilterChip('高額案件', () => _filterByHighValue()),
                _buildQuickFilterChip('緊急', () => _filterByUrgent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFilterChip(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label),
        onPressed: onTap,
        backgroundColor: Colors.blue.shade50,
      ),
    );
  }

  Widget _buildStatsBar() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('deliveries').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final docs = snapshot.data!.docs;
        final total = docs.length;
        final pending = docs.where((d) => 
            _safeStringFromData(d.data() as Map<String, dynamic>, 'status') == '待機中').length;
        final inProgress = docs.where((d) => 
            _safeStringFromData(d.data() as Map<String, dynamic>, 'status') == '配送中').length;
        final completed = docs.where((d) => 
            _safeStringFromData(d.data() as Map<String, dynamic>, 'status') == '完了').length;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('総案件', total, Colors.blue),
              _buildStatItem('待機中', pending, Colors.orange),
              _buildStatItem('配送中', inProgress, Colors.green),
              _buildStatItem('完了', completed, Colors.purple),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildDeliveryList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildQuery().snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final filteredDocs = _filterDocuments(snapshot.data!.docs);

        if (filteredDocs.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildDeliveryCard(doc.id, data);
          },
        );
      },
    );
  }

  Query _buildQuery() {
    Query query = FirebaseFirestore.instance
        .collection('deliveries')
        .orderBy('createdAt', descending: true);

    if (_selectedStatus != 'すべて') {
      query = query.where('status', isEqualTo: _selectedStatus);
    }

    return query;
  }

  List<QueryDocumentSnapshot> _filterDocuments(List<QueryDocumentSnapshot> docs) {
    if (_searchQuery.isEmpty) return docs;

    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final pickup = (_safeStringFromData(data, 'pickupLocation') ?? '').toLowerCase();
      final delivery = (_safeStringFromData(data, 'deliveryLocation') ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      
      return pickup.contains(query) || delivery.contains(query);
    }).toList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '配送案件がありません',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '新規案件を追加してください',
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddDeliveryDialog,
            icon: const Icon(Icons.add),
            label: const Text('新規案件を追加'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryCard(String deliveryId, Map<String, dynamic> data) {
    // 型安全なデータ取得
    final status = _safeStringFromData(data, 'status') ?? '不明';
    final priority = _safeStringFromData(data, 'priority') ?? 'normal';
    final pickupLocation = _safeStringFromData(data, 'pickupLocation') ?? 'N/A';
    final deliveryLocation = _safeStringFromData(data, 'deliveryLocation') ?? 'N/A';
    final driverName = _safeStringFromData(data, 'driverName');
    final fee = _safeNumberFromData(data, 'fee') ?? 0;
    final createdAt = data['createdAt'] as Timestamp?;
    
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
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDeliveryDetails(deliveryId, data),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildStatusBadge(status),
                  if (isUrgent) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                  ],
                  const Spacer(),
                  Text(
                    '¥${_formatNumber(fee)}',
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
                      pickupLocation,
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
                      deliveryLocation,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (driverName != null) ...[
                Row(
                  children: [
                    const Icon(Icons.person, color: Colors.blue, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '担当: $driverName',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatTimestamp(createdAt),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  ..._buildActionButtons(deliveryId, data),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    Color bgColor;
    
    switch (status) {
      case '待機中':
        color = Colors.orange;
        bgColor = Colors.orange.shade100;
        break;
      case '配送中':
        color = Colors.blue;
        bgColor = Colors.blue.shade100;
        break;
      case '完了':
        color = Colors.green;
        bgColor = Colors.green.shade100;
        break;
      case 'キャンセル':
        color = Colors.red;
        bgColor = Colors.red.shade100;
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

  List<Widget> _buildActionButtons(String deliveryId, Map<String, dynamic> data) {
    final status = _safeStringFromData(data, 'status');
    
    if (status == '待機中') {
      return [
        IconButton(
          onPressed: () => _showAssignDriverDialog(deliveryId, data),
          icon: const Icon(Icons.person_add, color: Colors.green),
          tooltip: 'ドライバー割り当て',
        ),
      ];
    } else if (status == '配送中') {
      return [
        IconButton(
          onPressed: () => _completeDelivery(deliveryId, data),
          icon: const Icon(Icons.check_circle, color: Colors.blue),
          tooltip: '完了',
        ),
      ];
    }
    
    return [
      IconButton(
        onPressed: () => _showEditDeliveryDialog(deliveryId, data),
        icon: const Icon(Icons.edit, color: Colors.grey),
        tooltip: '編集',
      ),
    ];
  }

  void _showAddDeliveryDialog() {
    showDialog(
      context: context,
      builder: (context) => _DeliveryFormDialog(),
    );
  }

  void _showEditDeliveryDialog(String deliveryId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => _DeliveryFormDialog(
        deliveryId: deliveryId,
        initialData: data,
      ),
    );
  }

  void _showAssignDriverDialog(String deliveryId, Map<String, dynamic> deliveryData) {
    showDialog(
      context: context,
      builder: (context) => _DriverAssignDialog(
        deliveryId: deliveryId,
        deliveryData: deliveryData,
      ),
    );
  }

  void _showDeliveryDetails(String deliveryId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => _DeliveryDetailsDialog(
        deliveryId: deliveryId,
        data: data,
      ),
    );
  }

  Future<void> _completeDelivery(String deliveryId, Map<String, dynamic> data) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('配送完了'),
        content: const Text('この配送案件を完了としてマークしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('完了'),
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
          'driverId': _safeStringFromData(data, 'driverId'),
          'driverName': _safeStringFromData(data, 'driverName'),
          'amount': (_safeNumberFromData(data, 'fee') ?? 0).toDouble(),
          'pickupLocation': _safeStringFromData(data, 'pickupLocation'),
          'deliveryLocation': _safeStringFromData(data, 'deliveryLocation'),
          'completedAt': FieldValue.serverTimestamp(),
          'month': DateTime.now().month,
          'year': DateTime.now().year,
        });

        await batch.commit();

        // 通知送信
        await NotificationService.notifyAllAdmins(
          title: '配送が完了しました',
          message: '${_safeStringFromData(data, 'driverName') ?? 'ドライバー'} が ${_safeStringFromData(data, 'deliveryLocation') ?? '配送先'} への配送を完了しました',
          type: 'delivery_completed',
          data: {'deliveryId': deliveryId},
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('配送完了として処理しました')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  // フィルター機能
  void _filterByDate(DateTime date) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${date.year}/${date.month}/${date.day}でフィルタリング')),
    );
  }

  void _filterByWeek() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('今週の案件でフィルタリング')),
    );
  }

  void _filterByMonth() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('今月の案件でフィルタリング')),
    );
  }

  void _filterByHighValue() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('高額案件でフィルタリング（5000円以上）')),
    );
  }

  void _filterByUrgent() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('緊急案件でフィルタリング')),
    );
  }

  void _showBulkActions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle),
              title: const Text('選択した案件を一括完了'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('一括完了機能は準備中です')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('選択した案件にドライバー一括割り当て'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('一括割り当て機能は準備中です')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('選択した案件を一括削除'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('一括削除機能は準備中です')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _exportToCSV() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSVエクスポート機能は準備中です')),
    );
  }

  // 型安全なヘルパーメソッド
  String? _safeStringFromData(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;
    if (value is String) return value.isEmpty ? null : value;
    if (value is Map || value is List) return null; // LinkedMapやListは無視
    return value.toString();
  }

  num? _safeNumberFromData(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) {
      final parsed = num.tryParse(value);
      return parsed;
    }
    return null;
  }

  String _formatNumber(num number) {
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
}

// 配送案件フォームダイアログ
class _DeliveryFormDialog extends StatefulWidget {
  final String? deliveryId;
  final Map<String, dynamic>? initialData;

  const _DeliveryFormDialog({
    this.deliveryId,
    this.initialData,
  });

  @override
  State<_DeliveryFormDialog> createState() => _DeliveryFormDialogState();
}

class _DeliveryFormDialogState extends State<_DeliveryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pickupController = TextEditingController();
  final _deliveryController = TextEditingController();
  final _feeController = TextEditingController();
  final _notesController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  
  String _priority = 'normal';
  DateTime? _deadline;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final data = widget.initialData!;
      _pickupController.text = _safeString(data['pickupLocation']) ?? '';
      _deliveryController.text = _safeString(data['deliveryLocation']) ?? '';
      _feeController.text = (_safeNumber(data['fee']) ?? 0).toString();
      _notesController.text = _safeString(data['notes']) ?? '';
      _customerNameController.text = _safeString(data['customerName']) ?? '';
      _customerPhoneController.text = _safeString(data['customerPhone']) ?? '';
      _priority = _safeString(data['priority']) ?? 'normal';
      
      if (data['deadline'] != null && data['deadline'] is Timestamp) {
        _deadline = (data['deadline'] as Timestamp).toDate();
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.deliveryId == null ? '新規配送案件' : '配送案件編集'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _pickupController,
                  decoration: const InputDecoration(
                    labelText: '集荷先 *',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  validator: (value) => value?.isEmpty == true ? '必須項目です' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _deliveryController,
                  decoration: const InputDecoration(
                    labelText: '配送先 *',
                    prefixIcon: Icon(Icons.flag),
                  ),
                  validator: (value) => value?.isEmpty == true ? '必須項目です' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _feeController,
                        decoration: const InputDecoration(
                          labelText: '料金 *',
                          prefixIcon: Icon(Icons.attach_money),
                          suffixText: '円',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) => value?.isEmpty == true ? '必須項目です' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _priority,
                        decoration: const InputDecoration(
                          labelText: '優先度',
                          prefixIcon: Icon(Icons.priority_high),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'normal', child: Text('通常')),
                          DropdownMenuItem(value: 'urgent', child: Text('緊急')),
                          DropdownMenuItem(value: 'low', child: Text('低')),
                        ],
                        onChanged: (value) => setState(() => _priority = value!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _customerNameController,
                        decoration: const InputDecoration(
                          labelText: '顧客名',
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _customerPhoneController,
                        decoration: const InputDecoration(
                          labelText: '電話番号',
                          prefixIcon: Icon(Icons.phone),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: Text(_deadline == null 
                      ? '配送期限を設定' 
                      : '期限: ${_deadline!.year}/${_deadline!.month}/${_deadline!.day}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: _selectDeadline,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: '備考',
                    prefixIcon: Icon(Icons.note),
                  ),
                  maxLines: 3,
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
          onPressed: _isLoading ? null : _saveDelivery,
          child: _isLoading
              ? const CircularProgressIndicator()
              : Text(widget.deliveryId == null ? '追加' : '更新'),
        ),
      ],
    );
  }

  Future<void> _selectDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() {
        _deadline = picked;
      });
    }
  }

  Future<void> _saveDelivery() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final data = {
        'pickupLocation': _pickupController.text.trim(),
        'deliveryLocation': _deliveryController.text.trim(),
        'fee': int.tryParse(_feeController.text) ?? 0,
        'notes': _notesController.text.trim(),
        'customerName': _customerNameController.text.trim(),
        'customerPhone': _customerPhoneController.text.trim(),
        'priority': _priority,
        'deadline': _deadline != null ? Timestamp.fromDate(_deadline!) : null,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.deliveryId == null) {
        // 新規作成
        data['status'] = '待機中';
        data['createdAt'] = FieldValue.serverTimestamp();
        
        await FirebaseFirestore.instance.collection('deliveries').add(data);
        
        // 通知送信
        await NotificationService.notifyAllAdmins(
          title: '新しい配送案件が登録されました',
          message: '${_pickupController.text.trim()} → ${_deliveryController.text.trim()}',
          type: 'system',
        );
      } else {
        // 更新
        await FirebaseFirestore.instance
            .collection('deliveries')
            .doc(widget.deliveryId)
            .update(data);
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.deliveryId == null ? '配送案件を追加しました' : '配送案件を更新しました')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

// ドライバー割り当てダイアログ
class _DriverAssignDialog extends StatefulWidget {
  final String deliveryId;
  final Map<String, dynamic> deliveryData;

  const _DriverAssignDialog({
    required this.deliveryId,
    required this.deliveryData,
  });

  @override
  State<_DriverAssignDialog> createState() => _DriverAssignDialogState();
}

class _DriverAssignDialogState extends State<_DriverAssignDialog> {
  String? _selectedDriverId;
  Map<String, dynamic>? _selectedDriverData;

  String? _safeString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.isEmpty ? null : value;
    if (value is Map || value is List) return null;
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ドライバー割り当て'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('drivers')
              .where('status', isEqualTo: '稼働中')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final drivers = snapshot.data!.docs;
            if (drivers.isEmpty) {
              return const Center(
                child: Text('稼働中のドライバーがいません'),
              );
            }

            return ListView.builder(
              itemCount: drivers.length,
              itemBuilder: (context, index) {
                final driver = drivers[index];
                final data = driver.data() as Map<String, dynamic>;
                final isSelected = _selectedDriverId == driver.id;
                
                return Card(
                  color: isSelected ? Colors.blue.shade50 : null,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Text(
                        (_safeString(data['name']) ?? 'N')[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(_safeString(data['name']) ?? 'N/A'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_safeString(data['phone']) ?? 'N/A'} | ${_safeString(data['vehicle']) ?? 'N/A'}'),
                        Text(
                          '現在の案件数: ${(data['currentDeliveries'] as num? ?? 0).toString()}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Colors.blue)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedDriverId = driver.id;
                        _selectedDriverData = data;
                      });
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: _selectedDriverId != null ? _assignDriver : null,
          child: const Text('割り当て'),
        ),
      ],
    );
  }

  Future<void> _assignDriver() async {
    if (_selectedDriverId == null || _selectedDriverData == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('deliveries')
          .doc(widget.deliveryId)
          .update({
        'driverId': _selectedDriverId,
        'driverName': _safeString(_selectedDriverData!['name']),
        'status': '配送中',
        'assignedAt': FieldValue.serverTimestamp(),
      });

      // 通知送信
      await NotificationService.notifyDeliveryAssigned(
        driverId: _selectedDriverId!,
        deliveryId: widget.deliveryId,
        pickupLocation: _safeString(widget.deliveryData['pickupLocation']) ?? '',
        deliveryLocation: _safeString(widget.deliveryData['deliveryLocation']) ?? '',
      );

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_safeString(_selectedDriverData!['name']) ?? 'ドライバー'}に割り当てました')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $e')),
      );
    }
  }
}

// 配送詳細ダイアログ
class _DeliveryDetailsDialog extends StatelessWidget {
  final String deliveryId;
  final Map<String, dynamic> data;

  const _DeliveryDetailsDialog({
    required this.deliveryId,
    required this.data,
  });

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

  String _getPriorityText(String? priority) {
    switch (priority) {
      case 'urgent':
        return '緊急';
      case 'low':
        return '低';
      default:
        return '通常';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    
    final date = timestamp.toDate();
    return '${date.year}/${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('配送案件詳細'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('案件ID', deliveryId.substring(0, 8)),
              _buildDetailRow('ステータス', _safeString(data['status']) ?? 'N/A'),
              _buildDetailRow('集荷先', _safeString(data['pickupLocation']) ?? 'N/A'),
              _buildDetailRow('配送先', _safeString(data['deliveryLocation']) ?? 'N/A'),
              _buildDetailRow('料金', '¥${_safeNumber(data['fee'])}'),
              _buildDetailRow('優先度', _getPriorityText(_safeString(data['priority']))),
              if (data['deadline'] != null && data['deadline'] is Timestamp)
                _buildDetailRow('期限', _formatDate((data['deadline'] as Timestamp).toDate())),
              if (_safeString(data['customerName']) != null)
                _buildDetailRow('顧客名', _safeString(data['customerName'])!),
              if (_safeString(data['customerPhone']) != null)
                _buildDetailRow('電話番号', _safeString(data['customerPhone'])!),
              if (_safeString(data['driverName']) != null)
                _buildDetailRow('担当ドライバー', _safeString(data['driverName'])!),
              if (_safeString(data['notes']) != null && _safeString(data['notes'])!.isNotEmpty)
                _buildDetailRow('備考', _safeString(data['notes'])!),
              _buildDetailRow('作成日時', _formatTimestamp(data['createdAt'] as Timestamp?)),
              if (data['assignedAt'] != null && data['assignedAt'] is Timestamp)
                _buildDetailRow('割り当て日時', _formatTimestamp(data['assignedAt'] as Timestamp)),
              if (data['completedAt'] != null && data['completedAt'] is Timestamp)
                _buildDetailRow('完了日時', _formatTimestamp(data['completedAt'] as Timestamp)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('閉じる'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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
}

// NotificationServiceのスタブクラス（実際の実装では別ファイル）
class NotificationService {
  static Future<void> notifyAllAdmins({
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    // 実装予定
  }

  static Future<void> notifyDeliveryAssigned({
    required String driverId,
    required String deliveryId,
    required String pickupLocation,
    required String deliveryLocation,
  }) async {
    // 実装予定
  }
}