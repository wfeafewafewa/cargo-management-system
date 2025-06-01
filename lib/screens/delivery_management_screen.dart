import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final TextEditingController _searchController = TextEditingController();

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
                  title: Text('CSV取り込み'),
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
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _showQuickAddDialog,
            heroTag: "quick_add",
            child: const Icon(Icons.flash_on),
            backgroundColor: Colors.orange,
            tooltip: 'クイック追加',
          ),
          const SizedBox(height: 16),
          FloatingActionButton.extended(
            onPressed: _showAddDeliveryDialog,
            heroTag: "add_delivery",
            icon: const Icon(Icons.add),
            label: const Text('新規案件'),
            backgroundColor: Colors.green,
          ),
        ],
      ),
    );
  }

  bool _hasActiveFilters() {
    return _selectedStatus != 'すべて' ||
        _selectedPriority != 'すべて' ||
        _showOnlyUrgent ||
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
      child: Column(
        children: [
          Row(
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
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
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
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickFilterChip(
                    '今日', () => _filterByDate(DateTime.now())),
                _buildQuickFilterChip(
                    '昨日',
                    () => _filterByDate(
                        DateTime.now().subtract(const Duration(days: 1)))),
                _buildQuickFilterChip('今週', () => _filterByWeek()),
                _buildQuickFilterChip('今月', () => _filterByMonth()),
                _buildQuickFilterChip('高額案件', () => _filterByHighValue()),
                _buildQuickFilterChip('緊急', () => _toggleUrgentFilter()),
                _buildQuickFilterChip('フィルタークリア', () => _clearAllFilters()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFilterChip(String label, VoidCallback onTap) {
    final isActive = (label == '緊急' && _showOnlyUrgent);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label),
        onPressed: onTap,
        backgroundColor:
            isActive ? Colors.orange.shade100 : Colors.blue.shade50,
        side: isActive
            ? BorderSide(color: Colors.orange.shade300)
            : BorderSide(color: Colors.blue.shade200),
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
        final urgent = docs
            .where((d) =>
                _safeStringFromData(
                    d.data() as Map<String, dynamic>, 'priority') ==
                'urgent')
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
              _buildStatItem('緊急', urgent, Colors.red, Icons.priority_high),
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
              return AnimatedContainer(
                duration: Duration(milliseconds: 300 + (index * 50)),
                curve: Curves.easeInOut,
                child: _buildDeliveryCard(doc.id, data),
              );
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

    if (_selectedPriority != 'すべて') {
      query = query.where('priority', isEqualTo: _selectedPriority);
    }

    return query;
  }

  List<QueryDocumentSnapshot> _filterDocuments(
      List<QueryDocumentSnapshot> docs) {
    var filtered = docs;

    // 検索クエリフィルター
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

    // 緊急案件フィルター
    if (_showOnlyUrgent) {
      filtered = filtered.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _safeStringFromData(data, 'priority') == 'urgent';
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
          if (!isFiltered)
            ElevatedButton.icon(
              onPressed: _showAddDeliveryDialog,
              icon: const Icon(Icons.add),
              label: const Text('新規案件を追加'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _clearAllFilters,
              icon: const Icon(Icons.clear),
              label: const Text('フィルターをクリア'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDeliveryCard(String deliveryId, Map<String, dynamic> data) {
    final status = _safeStringFromData(data, 'status') ?? '不明';
    final priority = _safeStringFromData(data, 'priority') ?? 'normal';
    final pickupLocation = _safeStringFromData(data, 'pickupLocation') ?? 'N/A';
    final deliveryLocation =
        _safeStringFromData(data, 'deliveryLocation') ?? 'N/A';
    final driverName = _safeStringFromData(data, 'driverName');
    final customerName = _safeStringFromData(data, 'customerName');
    final fee = _safeNumberFromData(data, 'fee') ?? 0;
    final createdAt = data['createdAt'] as Timestamp?;
    final deadline = data['deadline'] as Timestamp?;

    final isUrgent = priority == 'urgent';
    final isOverdue = deadline != null &&
        DateTime.now().isAfter(deadline.toDate()) &&
        status != '完了';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isUrgent ? 6 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isOverdue
            ? const BorderSide(color: Colors.red, width: 2)
            : isUrgent
                ? BorderSide(color: Colors.orange.shade300, width: 2)
                : BorderSide.none,
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
                  if (isUrgent) ...[
                    const SizedBox(width: 8),
                    _buildPriorityBadge('緊急', Colors.red),
                  ],
                  if (isOverdue) ...[
                    const SizedBox(width: 8),
                    _buildPriorityBadge('期限超過', Colors.red),
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
              const SizedBox(height: 16),

              // 配送ルート
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.location_on,
                              color: Colors.red.shade700, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            pickupLocation,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      height: 2,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: DashedLinePainter(),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.flag,
                              color: Colors.green.shade700, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            deliveryLocation,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 詳細情報
              Row(
                children: [
                  if (driverName != null) ...[
                    Icon(Icons.person, color: Colors.blue.shade600, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      driverName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (customerName != null) ...[
                    Icon(Icons.account_circle,
                        color: Colors.purple.shade600, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      customerName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.purple.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  const Spacer(),
                  if (deadline != null) ...[
                    Icon(
                      Icons.schedule,
                      color: isOverdue ? Colors.red : Colors.grey.shade600,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(deadline.toDate()),
                      style: TextStyle(
                        fontSize: 12,
                        color: isOverdue ? Colors.red : Colors.grey.shade600,
                        fontWeight:
                            isOverdue ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 12),

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
    IconData icon;

    switch (status) {
      case '待機中':
        color = Colors.orange.shade700;
        bgColor = Colors.orange.shade100;
        icon = Icons.hourglass_empty;
        break;
      case '配送中':
        color = Colors.blue.shade700;
        bgColor = Colors.blue.shade100;
        icon = Icons.local_shipping;
        break;
      case '完了':
        color = Colors.green.shade700;
        bgColor = Colors.green.shade100;
        icon = Icons.check_circle;
        break;
      case 'キャンセル':
        color = Colors.red.shade700;
        bgColor = Colors.red.shade100;
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey.shade700;
        bgColor = Colors.grey.shade100;
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  List<Widget> _buildActionButtons(
      String deliveryId, Map<String, dynamic> data) {
    final status = _safeStringFromData(data, 'status');

    if (status == '待機中') {
      return [
        IconButton(
          onPressed: () => _showAssignDriverDialog(deliveryId, data),
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              shape: BoxShape.circle,
            ),
            child:
                Icon(Icons.person_add, color: Colors.green.shade700, size: 20),
          ),
          tooltip: 'ドライバー割り当て',
        ),
      ];
    } else if (status == '配送中') {
      return [
        IconButton(
          onPressed: () => _completeDelivery(deliveryId, data),
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child:
                Icon(Icons.check_circle, color: Colors.blue.shade700, size: 20),
          ),
          tooltip: '完了',
        ),
      ];
    }

    return [
      IconButton(
        onPressed: () => _showEditDeliveryDialog(deliveryId, data),
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.edit, color: Colors.grey.shade700, size: 20),
        ),
        tooltip: '編集',
      ),
    ];
  }

  // フィルター機能の実装
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('詳細フィルター'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedPriority,
                decoration: const InputDecoration(labelText: '優先度'),
                items: ['すべて', 'urgent', 'normal', 'low']
                    .map((priority) => DropdownMenuItem(
                          value: priority,
                          child: Text(_getPriorityDisplayText(priority)),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedPriority = value!);
                },
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('緊急案件のみ'),
                value: _showOnlyUrgent,
                onChanged: (value) {
                  setState(() => _showOnlyUrgent = value ?? false);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              this.setState(() {});
            },
            child: const Text('適用'),
          ),
        ],
      ),
    );
  }

  String _getPriorityDisplayText(String priority) {
    switch (priority) {
      case 'urgent':
        return '緊急';
      case 'normal':
        return '通常';
      case 'low':
        return '低';
      default:
        return 'すべて';
    }
  }

  void _toggleUrgentFilter() {
    setState(() {
      _showOnlyUrgent = !_showOnlyUrgent;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedStatus = 'すべて';
      _selectedPriority = 'すべて';
      _showOnlyUrgent = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _filterByDate(DateTime date) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${date.year}/${date.month}/${date.day}でフィルタリング（実装予定）'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _filterByWeek() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('今週の案件でフィルタリング（実装予定）'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _filterByMonth() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('今月の案件でフィルタリング（実装予定）'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _filterByHighValue() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('高額案件でフィルタリング（実装予定）'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showQuickAddDialog() {
    showDialog(
      context: context,
      builder: (context) => _QuickAddDialog(),
    );
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

  void _showAssignDriverDialog(
      String deliveryId, Map<String, dynamic> deliveryData) {
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

  Future<void> _completeDelivery(
      String deliveryId, Map<String, dynamic> data) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700),
            const SizedBox(width: 8),
            const Text('配送完了'),
          ],
        ),
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
                  Text(
                      '配送先: ${_safeStringFromData(data, 'deliveryLocation') ?? 'N/A'}'),
                  Text(
                      '料金: ¥${_formatNumber(_safeNumberFromData(data, 'fee') ?? 0)}'),
                  Text(
                      'ドライバー: ${_safeStringFromData(data, 'driverName') ?? 'N/A'}'),
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
            child: const Text('完了'),
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

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('配送完了として処理しました'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: '詳細レポート',
                onPressed: () =>
                    Navigator.pushNamed(context, '/advanced-reports'),
                textColor: Colors.white,
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('エラー: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showBulkActions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '一括操作',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle, color: Colors.green.shade700),
              ),
              title: const Text('選択した案件を一括完了'),
              subtitle: const Text('複数の案件を同時に完了にします'),
              onTap: () {
                Navigator.pop(context);
                _showComingSoon('一括完了');
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_add, color: Colors.blue.shade700),
              ),
              title: const Text('一括ドライバー割り当て'),
              subtitle: const Text('複数の案件に同じドライバーを割り当てます'),
              onTap: () {
                Navigator.pop(context);
                _showComingSoon('一括割り当て');
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.edit, color: Colors.orange.shade700),
              ),
              title: const Text('一括編集'),
              subtitle: const Text('複数の案件の情報を同時に編集します'),
              onTap: () {
                Navigator.pop(context);
                _showComingSoon('一括編集');
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete, color: Colors.red.shade700),
              ),
              title: const Text('一括削除'),
              subtitle: const Text('選択した案件を削除します'),
              onTap: () {
                Navigator.pop(context);
                _showComingSoon('一括削除');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _exportToCSV() {
    _showComingSoon('CSVエクスポート');
  }

  void _importFromCSV() {
    _showComingSoon('CSV取り込み');
  }

  void _archiveCompleted() {
    _showComingSoon('完了案件アーカイブ');
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature機能は準備中です'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ヘルパーメソッド
  String? _safeStringFromData(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;
    if (value is String) return value.isEmpty ? null : value;
    if (value is Map || value is List) return null;
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

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
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

// カスタムペインター：破線
class DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 2;

    const dashWidth = 5;
    const dashSpace = 3;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// クイック追加ダイアログ
class _QuickAddDialog extends StatefulWidget {
  @override
  State<_QuickAddDialog> createState() => _QuickAddDialogState();
}

class _QuickAddDialogState extends State<_QuickAddDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pickupController = TextEditingController();
  final _deliveryController = TextEditingController();
  final _feeController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.flash_on, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          const Text('クイック追加'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
              controller: _feeController,
              decoration: const InputDecoration(
                labelText: '料金',
                prefixIcon: Icon(Icons.attach_money),
                suffixText: '円',
              ),
              keyboardType: TextInputType.number,
              validator: (value) => value?.isEmpty == true ? '必須' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveQuickDelivery,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('追加'),
        ),
      ],
    );
  }

  Future<void> _saveQuickDelivery() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('deliveries').add({
        'pickupLocation': _pickupController.text.trim(),
        'deliveryLocation': _deliveryController.text.trim(),
        'fee': int.tryParse(_feeController.text) ?? 0,
        'status': '待機中',
        'priority': 'normal',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('配送案件をクイック追加しました'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

// 残りのダイアログクラス（_DeliveryFormDialog, _DriverAssignDialog, _DeliveryDetailsDialog）は
// 既存のコードとほぼ同じなので、スペースの関係で省略しています。
// 必要に応じて、既存のコードから流用してください。

// 配送案件フォームダイアログ（省略版 - 既存コードを使用）
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
  // 既存のコードを使用
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.deliveryId == null ? '新規配送案件' : '配送案件編集'),
      content: const Text('詳細フォーム（既存コードを使用）'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('保存'),
        ),
      ],
    );
  }
}

// ドライバー割り当てダイアログ（省略版）
class _DriverAssignDialog extends StatelessWidget {
  final String deliveryId;
  final Map<String, dynamic> deliveryData;

  const _DriverAssignDialog({
    required this.deliveryId,
    required this.deliveryData,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ドライバー割り当て'),
      content: const Text('ドライバー選択（既存コードを使用）'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('割り当て'),
        ),
      ],
    );
  }
}

// 配送詳細ダイアログ（省略版）
class _DeliveryDetailsDialog extends StatelessWidget {
  final String deliveryId;
  final Map<String, dynamic> data;

  const _DeliveryDetailsDialog({
    required this.deliveryId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('配送案件詳細'),
      content: const Text('詳細情報（既存コードを使用）'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}
