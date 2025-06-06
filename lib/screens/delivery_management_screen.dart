import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'dart:html' as html;

class DeliveryManagementScreen extends StatefulWidget {
  const DeliveryManagementScreen({Key? key}) : super(key: key);

  @override
  State<DeliveryManagementScreen> createState() =>
      _DeliveryManagementScreenState();
}

class _DeliveryManagementScreenState extends State<DeliveryManagementScreen>
    with TickerProviderStateMixin {
  String _selectedStatus = 'すべて';
  String _searchQuery = '';
  String _selectedPriority = 'すべて';
  bool _showOnlyUrgent = false;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _highValueFilter = false;
  final TextEditingController _searchController = TextEditingController();
  List<String> _selectedDeliveryIds = [];

  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('配送案件管理'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () => _showFilterDialog(),
            icon: Stack(
              children: [
                const Icon(Icons.filter_list),
                if (_hasActiveFilters())
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 12,
                        minHeight: 12,
                      ),
                      child: const Text(
                        '!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'フィルター',
          ),
          IconButton(
            onPressed: () => _showBulkActions(),
            icon: const Icon(Icons.checklist),
            tooltip: '一括操作',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'export_csv':
                  _exportToCSV();
                  break;
                case 'import_csv':
                  _importFromCSV();
                  break;
                case 'archive':
                  _archiveCompleted();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export_csv',
                child: ListTile(
                  leading: Icon(Icons.file_download),
                  title: Text('CSV出力'),
                ),
              ),
              const PopupMenuItem(
                value: 'import_csv',
                child: ListTile(
                  leading: Icon(Icons.file_upload),
                  title: Text('CSV一括入稿'),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'archive',
                child: ListTile(
                  leading: Icon(Icons.archive),
                  title: Text('完了案件をアーカイブ'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          _buildStatsBar(),
          Expanded(
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(_slideAnimation),
              child: FadeTransition(
                opacity: _slideAnimation,
                child: _buildDeliveryList(),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDeliveryDialog,
        heroTag: "add_delivery",
        icon: const Icon(Icons.add),
        label: const Text('新規案件'),
        backgroundColor: Colors.green,
      ),
    );
  }

  bool _hasActiveFilters() {
    return _selectedStatus != 'すべて' ||
        _selectedPriority != 'すべて' ||
        _searchQuery.isNotEmpty;
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '配送先、集荷先、顧客名で検索...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              borderRadius: BorderRadius.circular(12),
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
    );
  }

  Widget _buildStatsBar() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('deliveries').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final docs = snapshot.data!.docs;
        final total = docs.length;
        final pending = docs
            .where((d) =>
                _safeStringFromData(
                    d.data() as Map<String, dynamic>, 'status') ==
                '待機中')
            .length;
        final inProgress = docs
            .where((d) =>
                _safeStringFromData(
                    d.data() as Map<String, dynamic>, 'status') ==
                '配送中')
            .length;
        final completed = docs
            .where((d) =>
                _safeStringFromData(
                    d.data() as Map<String, dynamic>, 'status') ==
                '完了')
            .length;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('総案件', total, Colors.blue, Icons.assignment),
              _buildStatItem(
                  '待機中', pending, Colors.orange, Icons.hourglass_empty),
              _buildStatItem(
                  '配送中', inProgress, Colors.green, Icons.local_shipping),
              _buildStatItem(
                  '完了', completed, Colors.purple, Icons.check_circle),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, int count, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildDeliveryList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildQuery().snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('読み込み中...'),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final filteredDocs = _filterDocuments(snapshot.data!.docs);

        if (filteredDocs.isEmpty) {
          return _buildEmptyState(isFiltered: true);
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              final doc = filteredDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _buildDeliveryCard(doc.id, data);
            },
          ),
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

  List<QueryDocumentSnapshot> _filterDocuments(
      List<QueryDocumentSnapshot> docs) {
    var filtered = docs;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final pickup =
            (_safeStringFromData(data, 'pickupLocation') ?? '').toLowerCase();
        final delivery =
            (_safeStringFromData(data, 'deliveryLocation') ?? '').toLowerCase();
        final customer =
            (_safeStringFromData(data, 'customerName') ?? '').toLowerCase();
        final query = _searchQuery.toLowerCase();

        return pickup.contains(query) ||
            delivery.contains(query) ||
            customer.contains(query);
      }).toList();
    }

    return filtered;
  }

  Widget _buildEmptyState({bool isFiltered = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isFiltered ? Icons.search_off : Icons.inbox_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            isFiltered ? '該当する案件がありません' : '配送案件がありません',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isFiltered ? 'フィルター条件を変更してください' : '新規案件を追加してください',
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: isFiltered ? _clearAllFilters : _showAddDeliveryDialog,
            icon: Icon(isFiltered ? Icons.clear : Icons.add),
            label: Text(isFiltered ? 'フィルターをクリア' : '新規案件を追加'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isFiltered ? Colors.blue : Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryCard(String deliveryId, Map<String, dynamic> data) {
    final status = _safeStringFromData(data, 'status') ?? '不明';
    final pickupLocation = _safeStringFromData(data, 'pickupLocation') ?? 'N/A';
    final deliveryLocation =
        _safeStringFromData(data, 'deliveryLocation') ?? 'N/A';
    final customerName = _safeStringFromData(data, 'customerName');
    final createdAt = data['createdAt'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDeliveryDetails(deliveryId, data),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildStatusBadge(status),
                  const Spacer(),
                  if (customerName != null)
                    Text(
                      customerName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.red),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Text(pickupLocation,
                          style: const TextStyle(fontSize: 14))),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.flag, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Text(deliveryLocation,
                          style: const TextStyle(fontSize: 14))),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _formatTimestamp(createdAt),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case '待機中':
        color = Colors.orange;
        break;
      case '配送中':
        color = Colors.blue;
        break;
      case '完了':
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
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

  void _showFilterDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('フィルター機能は準備中です'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showBulkActions() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('一括操作機能は準備中です'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _exportToCSV() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('CSV出力機能は準備中です'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _importFromCSV() {
    showDialog(
      context: context,
      builder: (context) => const _MonthlyBulkImportDialog(),
    );
  }

  void _archiveCompleted() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('アーカイブ機能は準備中です'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _clearAllFilters() {
    setState(() {
      _selectedStatus = 'すべて';
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _showAddDeliveryDialog() {
    showDialog(
      context: context,
      builder: (context) => const _DeliveryFormDialog(),
    );
  }

  void _showDeliveryDetails(String deliveryId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('配送案件詳細'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('案件ID', deliveryId.substring(0, 8)),
            _buildDetailRow('集荷先', data['pickupLocation'] ?? 'N/A'),
            _buildDetailRow('配送先', data['deliveryLocation'] ?? 'N/A'),
            _buildDetailRow('顧客名', data['customerName'] ?? 'N/A'),
            _buildDetailRow('ステータス', data['status'] ?? 'N/A'),
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
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String? _safeStringFromData(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;
    if (value is String) return value.isEmpty ? null : value;
    return value.toString();
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

// 配送案件フォームダイアログ - 個数料金対応版
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
  final _projectNameController = TextEditingController();
  final _pickupController = TextEditingController();
  final _deliveryController = TextEditingController();
  final _customerController = TextEditingController();
  final _notesController = TextEditingController();
  final _unitPriceController = TextEditingController();

  String _priority = 'normal';
  String _feeType = 'daily';
  DateTime? _deadline;
  bool _isLoading = false;

  // 個数料金の詳細設定用
  List<Map<String, dynamic>> _itemTypes = [];
  final _itemTypeNameController = TextEditingController();
  final _itemTypePriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final data = widget.initialData!;
      _projectNameController.text = data['projectName'] ?? '';
      _pickupController.text = data['pickupLocation'] ?? '';
      _deliveryController.text = data['deliveryLocation'] ?? '';
      _customerController.text = data['customerName'] ?? '';
      _notesController.text = data['notes'] ?? '';
      _unitPriceController.text = (data['unitPrice'] ?? 0).toString();
      _priority = data['priority'] ?? 'normal';
      _feeType = data['feeType'] ?? 'daily';

      if (data['itemTypes'] != null) {
        _itemTypes = List<Map<String, dynamic>>.from(data['itemTypes']);
      }

      if (data['deadline'] != null) {
        _deadline = (data['deadline'] as Timestamp).toDate();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            widget.deliveryId == null ? Icons.add_circle : Icons.edit,
            color: Colors.green.shade700,
          ),
          const SizedBox(width: 8),
          Text(widget.deliveryId == null ? '新規配送案件' : '配送案件編集'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _projectNameController,
                  decoration: const InputDecoration(
                    labelText: '案件名',
                    hintText: '例: 東京→千葉配送案件',
                    prefixIcon: Icon(Icons.assignment),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _pickupController,
                  decoration: const InputDecoration(
                    labelText: '集荷先',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  validator: (value) => value?.isEmpty == true ? '必須' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _deliveryController,
                  decoration: const InputDecoration(
                    labelText: '配送先',
                    prefixIcon: Icon(Icons.flag),
                  ),
                  validator: (value) => value?.isEmpty == true ? '必須' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _customerController,
                  decoration: const InputDecoration(
                    labelText: '顧客名',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _feeType,
                  decoration: const InputDecoration(
                    labelText: '報酬形態',
                    prefixIcon: Icon(Icons.payment),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'daily', child: Text('日当')),
                    DropdownMenuItem(value: 'hourly', child: Text('時給')),
                    DropdownMenuItem(value: 'per_item', child: Text('個数')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _feeType = value!;
                      if (_feeType != 'per_item') {
                        _itemTypes.clear();
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (_feeType != 'per_item')
                  TextFormField(
                    controller: _unitPriceController,
                    decoration: InputDecoration(
                      labelText: '単価',
                      hintText: _getFeeTypeHint(),
                      prefixIcon: const Icon(Icons.attach_money),
                      suffixText: _getFeeTypeSuffix(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) => value?.isEmpty == true ? '必須' : null,
                  ),
                if (_feeType == 'per_item') _buildItemTypesSection(),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _priority,
                  decoration: const InputDecoration(
                    labelText: '優先度',
                    prefixIcon: Icon(Icons.priority_high),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('低')),
                    DropdownMenuItem(value: 'normal', child: Text('通常')),
                    DropdownMenuItem(value: 'urgent', child: Text('緊急')),
                  ],
                  onChanged: (value) => setState(() => _priority = value!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: '期限',
                    prefixIcon: const Icon(Icons.calendar_today),
                    suffixIcon: _deadline != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _deadline = null),
                          )
                        : null,
                  ),
                  readOnly: true,
                  controller: TextEditingController(
                    text: _deadline != null
                        ? '${_deadline!.year}/${_deadline!.month}/${_deadline!.day}'
                        : '',
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _deadline ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() => _deadline = date);
                    }
                  },
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
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.deliveryId == null ? '追加' : '更新'),
        ),
      ],
    );
  }

  Widget _buildItemTypesSection() {
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
              Icon(Icons.category, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                '個数料金の詳細設定',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '荷物種類ごとに異なる単価を設定\n例: 大型荷物 ¥300/個、小型荷物 ¥100/個',
              style: TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _itemTypeNameController,
                  decoration: const InputDecoration(
                    labelText: '荷物種類',
                    hintText: '大型荷物',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _itemTypePriceController,
                  decoration: const InputDecoration(
                    labelText: '単価',
                    hintText: '300',
                    border: OutlineInputBorder(),
                    suffixText: '円/個',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addItemType,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(12),
                ),
                child: const Icon(Icons.add, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_itemTypes.isNotEmpty) ...[
            Text(
              '設定済み荷物種類',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(height: 8),
            ..._itemTypes.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'],
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '¥${_formatNumber(item['price'])}/個',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _removeItemType(index),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                    ),
                  ],
                ),
              );
            }).toList(),
            const SizedBox(height: 12),
            if (_itemTypes.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calculate,
                        color: Colors.green.shade700, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '平均単価: ¥${_calculateAveragePrice()}/個',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (_feeType == 'per_item' && _itemTypes.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '個数料金を選択した場合、最低1つの荷物種類を設定してください',
                      style: TextStyle(
                          color: Colors.orange.shade800, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _addItemType() {
    final name = _itemTypeNameController.text.trim();
    final priceText = _itemTypePriceController.text.trim();

    if (name.isEmpty || priceText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('荷物種類と単価を入力してください')),
      );
      return;
    }

    final price = int.tryParse(priceText);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('単価は正の数値で入力してください')),
      );
      return;
    }

    if (_itemTypes
        .any((item) => item['name'].toLowerCase() == name.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('同じ名前の荷物種類が既に存在します')),
      );
      return;
    }

    setState(() {
      _itemTypes.add({'name': name, 'price': price});
      _itemTypeNameController.clear();
      _itemTypePriceController.clear();
    });
  }

  void _removeItemType(int index) {
    setState(() {
      _itemTypes.removeAt(index);
    });
  }

  int _calculateAveragePrice() {
    if (_itemTypes.isEmpty) return 0;
    final total =
        _itemTypes.fold<int>(0, (sum, item) => sum + (item['price'] as int));
    return (total / _itemTypes.length).round();
  }

  String _getFeeTypeHint() {
    switch (_feeType) {
      case 'daily':
        return '例: 8000（円）';
      case 'hourly':
        return '例: 1500（円）';
      default:
        return '';
    }
  }

  String _getFeeTypeSuffix() {
    switch (_feeType) {
      case 'daily':
        return '円/日';
      case 'hourly':
        return '円/時間';
      default:
        return '円';
    }
  }

  Future<void> _saveDelivery() async {
    if (!_formKey.currentState!.validate()) return;

    if (_feeType == 'per_item' && _itemTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('個数料金を選択した場合、最低1つの荷物種類を設定してください')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = <String, dynamic>{
        'projectName': _projectNameController.text.trim(),
        'pickupLocation': _pickupController.text.trim(),
        'deliveryLocation': _deliveryController.text.trim(),
        'customerName': _customerController.text.trim(),
        'priority': _priority,
        'notes': _notesController.text.trim(),
        'feeType': _feeType,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_feeType == 'per_item') {
        data['itemTypes'] = _itemTypes;
        data['unitPrice'] = _calculateAveragePrice();
        data['fee'] = _calculateAveragePrice();
      } else {
        final unitPrice = int.tryParse(_unitPriceController.text) ?? 0;
        data['unitPrice'] = unitPrice;
        data['fee'] = unitPrice;
      }

      if (_deadline != null) {
        data['deadline'] = Timestamp.fromDate(_deadline!);
      }

      if (widget.deliveryId == null) {
        data['status'] = '待機中';
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('deliveries').add(data);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('配送案件を追加しました'), backgroundColor: Colors.green),
        );
      } else {
        await FirebaseFirestore.instance
            .collection('deliveries')
            .doc(widget.deliveryId)
            .update(data);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('配送案件を更新しました'), backgroundColor: Colors.blue),
        );
      }

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  @override
  void dispose() {
    _projectNameController.dispose();
    _pickupController.dispose();
    _deliveryController.dispose();
    _customerController.dispose();
    _notesController.dispose();
    _unitPriceController.dispose();
    _itemTypeNameController.dispose();
    _itemTypePriceController.dispose();
    super.dispose();
  }
}

// CSV一括入稿ダイアログ（修正版）
class _MonthlyBulkImportDialog extends StatefulWidget {
  const _MonthlyBulkImportDialog();

  @override
  State<_MonthlyBulkImportDialog> createState() =>
      _MonthlyBulkImportDialogState();
}

class _MonthlyBulkImportDialogState extends State<_MonthlyBulkImportDialog> {
  bool _isLoading = false;
  List<Map<String, dynamic>>? _previewData;
  List<String> _validationErrors = [];
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  final List<String> _requiredHeaders = [
    '日付',
    '案件名',
    '集荷先',
    '配送先',
    '顧客名',
    '報酬形態',
    '単価',
    '優先度',
    '備考'
  ];

  final String _spreadsheetTemplateUrl =
      'https://docs.google.com/spreadsheets/d/1LkLoRl2br3_-9mD79lP59F1aJasJlOdMHQDntcLcrFU/edit?gid=0#gid=0';

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.file_upload, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          const Text('CSV一括入稿'),
        ],
      ),
      content: SizedBox(
        width: screenSize.width * 0.8,
        height: screenSize.height * 0.7,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _selectedYear,
                      decoration: const InputDecoration(
                          labelText: '年', border: OutlineInputBorder()),
                      items: List.generate(5, (index) {
                        final year = DateTime.now().year + index;
                        return DropdownMenuItem(
                            value: year, child: Text('$year年'));
                      }),
                      onChanged: (value) =>
                          setState(() => _selectedYear = value!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _selectedMonth,
                      decoration: const InputDecoration(
                          labelText: '月', border: OutlineInputBorder()),
                      items: List.generate(12, (index) {
                        final month = index + 1;
                        return DropdownMenuItem(
                            value: month, child: Text('$month月'));
                      }),
                      onChanged: (value) =>
                          setState(() => _selectedMonth = value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.table_chart,
                            color: Colors.green.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Step 1: スプレッドシートで入力',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openSpreadsheetTemplate,
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('スプレッドシートテンプレートを開く'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '1. 上記ボタンでテンプレートを開く\n2. データを入力してCSV形式で保存\n3. 下記でCSVファイルをアップロード',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('代替: CSVテンプレートダウンロード',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700)),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _downloadTemplate,
                      icon: const Icon(Icons.download, size: 14),
                      label: const Text('CSVダウンロード'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Step 2: CSVファイルアップロード',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700)),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _selectAndPreviewCSV,
                        icon: const Icon(Icons.file_open, size: 16),
                        label: const Text('CSVファイルを選択'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade600,
                            foregroundColor: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 200,
                child: _buildPreviewSection(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        if (_previewData != null && _validationErrors.isEmpty)
          ElevatedButton(
            onPressed: _isLoading ? null : _importData,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text('${_previewData!.length}件をインポート'),
          ),
      ],
    );
  }

  void _openSpreadsheetTemplate() {
    html.window.open(_spreadsheetTemplateUrl, '_blank');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('スプレッドシートテンプレートを新しいタブで開きました'),
          backgroundColor: Colors.green),
    );
  }

  Widget _buildPreviewSection() {
    if (_validationErrors.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('エラー',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.red.shade700)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _validationErrors.length,
                itemBuilder: (context, index) => Text(
                    '• ${_validationErrors[index]}',
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
              ),
            ),
          ],
        ),
      );
    }

    if (_previewData != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('プレビュー（${_previewData!.length}件）',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.green.shade700)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _previewData!.length,
                itemBuilder: (context, index) {
                  final item = _previewData![index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(
                        '${index + 1}. ${item['projectName']} - ¥${item['unitPrice']}',
                        style: const TextStyle(fontSize: 12)),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return const Center(
        child:
            Text('CSVファイルを選択してプレビューを表示', style: TextStyle(color: Colors.grey)));
  }

  void _downloadTemplate() {
    final csvData = [
      _requiredHeaders,
      [
        '2025/${_selectedMonth}/15',
        '東京-新宿配送案件',
        '東京都渋谷区〇〇',
        '東京都新宿区△△',
        '株式会社サンプル',
        'daily',
        '8000',
        'normal',
        '午前中配送希望'
      ],
    ];

    final csvString = const ListToCsvConverter().convert(csvData);
    _downloadFile(csvString,
        'delivery_template_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}.csv');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('CSVテンプレートをダウンロードしました'), backgroundColor: Colors.blue),
    );
  }

  Future<void> _selectAndPreviewCSV() async {
    setState(() {
      _isLoading = true;
      _previewData = null;
      _validationErrors.clear();
    });

    try {
      final input = html.FileUploadInputElement()..accept = '.csv';
      input.click();

      await input.onChange.first;
      final files = input.files;
      if (files!.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final file = files[0];
      final reader = html.FileReader();
      reader.readAsText(file);

      await reader.onLoad.first;
      final csvString = reader.result as String;
      final csvData = const CsvToListConverter().convert(csvString);

      if (csvData.isEmpty) throw Exception('CSVファイルが空です');

      final headers = csvData[0].map((h) => h.toString().trim()).toList();
      final missingHeaders = _requiredHeaders
          .where((required) => !headers.contains(required))
          .toList();

      if (missingHeaders.isNotEmpty) {
        throw Exception('必須ヘッダーが不足: ${missingHeaders.join(', ')}');
      }

      final dataRows = csvData.skip(1).toList();
      final previewData = <Map<String, dynamic>>[];
      final errors = <String>[];

      for (int i = 0; i < dataRows.length; i++) {
        final row = dataRows[i];
        try {
          final item = _parseAndValidateRow(row, headers);
          previewData.add(item);
        } catch (e) {
          errors.add('行${i + 2}: $e');
        }
      }

      setState(() {
        _previewData = previewData;
        _validationErrors = errors;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _validationErrors = ['ファイル読み込みエラー: $e'];
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _parseAndValidateRow(
      List<dynamic> row, List<String> headers) {
    final item = <String, dynamic>{};

    for (int i = 0; i < headers.length && i < row.length; i++) {
      item[headers[i]] = row[i]?.toString()?.trim() ?? '';
    }

    if (item['集荷先']?.isEmpty ?? true) throw Exception('集荷先が必須です');
    if (item['配送先']?.isEmpty ?? true) throw Exception('配送先が必須です');

    final unitPrice = int.tryParse(item['単価'] ?? '');
    if (unitPrice == null) throw Exception('単価は数値で入力してください');

    item['projectName'] = item['案件名'] ?? '';
    item['pickupLocation'] = item['集荷先'];
    item['deliveryLocation'] = item['配送先'];
    item['customerName'] = item['顧客名'] ?? '';
    item['unitPrice'] = unitPrice;

    return item;
  }

  Future<void> _importData() async {
    if (_previewData == null || _previewData!.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final batch = FirebaseFirestore.instance.batch();

      for (final item in _previewData!) {
        final docRef =
            FirebaseFirestore.instance.collection('deliveries').doc();
        batch.set(docRef, {
          'projectName': item['projectName'],
          'pickupLocation': item['pickupLocation'],
          'deliveryLocation': item['deliveryLocation'],
          'customerName': item['customerName'],
          'unitPrice': item['unitPrice'],
          'fee': item['unitPrice'],
          'status': '待機中',
          'feeType': 'daily',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${_previewData!.length}件をインポートしました'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('インポートエラー: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _downloadFile(String content, String filename) {
    final bytes = utf8.encode(content);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = filename;
    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
  }
}
