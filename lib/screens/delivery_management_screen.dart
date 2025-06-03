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
        _searchQuery.isNotEmpty ||
        _startDate != null ||
        _endDate != null ||
        _highValueFilter;
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
    final isActive = (label == '緊急' && _showOnlyUrgent) ||
        (label == '高額案件' && _highValueFilter) ||
        (label == '今日' && _isDateFilterActive(DateTime.now())) ||
        (label == '昨日' &&
            _isDateFilterActive(DateTime.now().subtract(Duration(days: 1))));

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

  bool _isDateFilterActive(DateTime date) {
    if (_startDate == null) return false;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    return _startDate!.isAtSameMomentAs(startOfDay) &&
        _endDate?.isAtSameMomentAs(endOfDay) == true;
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

    // 高額案件フィルター
    if (_highValueFilter) {
      filtered = filtered.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final fee = _safeNumberFromData(data, 'fee') ?? 0;
        return fee >= 5000; // 5000円以上を高額案件とする
      }).toList();
    }

    // 日付フィルター
    if (_startDate != null || _endDate != null) {
      filtered = filtered.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final createdAt = data['createdAt'] as Timestamp?;
        if (createdAt == null) return false;

        final docDate = createdAt.toDate();

        if (_startDate != null && docDate.isBefore(_startDate!)) {
          return false;
        }
        if (_endDate != null && docDate.isAfter(_endDate!)) {
          return false;
        }
        return true;
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
    final isSelected = _selectedDeliveryIds.contains(deliveryId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isUrgent ? 6 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isOverdue
            ? const BorderSide(color: Colors.red, width: 2)
            : isUrgent
                ? BorderSide(color: Colors.orange.shade300, width: 2)
                : isSelected
                    ? BorderSide(color: Colors.blue.shade300, width: 2)
                    : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDeliveryDetails(deliveryId, data),
        onLongPress: () => _toggleSelection(deliveryId),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isSelected ? Colors.blue.shade50 : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isSelected)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: Icon(Icons.check_circle,
                            color: Colors.blue.shade600),
                      ),
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
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
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
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
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
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                    ..._buildActionButtons(deliveryId, data),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleSelection(String deliveryId) {
    setState(() {
      if (_selectedDeliveryIds.contains(deliveryId)) {
        _selectedDeliveryIds.remove(deliveryId);
      } else {
        _selectedDeliveryIds.add(deliveryId);
      }
    });
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
          builder: (context, setState) => SingleChildScrollView(
            child: Column(
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
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(
                          labelText: '開始日',
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        readOnly: true,
                        controller: TextEditingController(
                          text: _startDate != null
                              ? _formatDate(_startDate!)
                              : '',
                        ),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _startDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(Duration(days: 365)),
                          );
                          if (date != null) {
                            setState(() => _startDate = date);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(
                          labelText: '終了日',
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        readOnly: true,
                        controller: TextEditingController(
                          text: _endDate != null ? _formatDate(_endDate!) : '',
                        ),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _endDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(Duration(days: 365)),
                          );
                          if (date != null) {
                            setState(() => _endDate = date);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('緊急案件のみ'),
                  value: _showOnlyUrgent,
                  onChanged: (value) {
                    setState(() => _showOnlyUrgent = value ?? false);
                  },
                ),
                CheckboxListTile(
                  title: const Text('高額案件のみ（5000円以上）'),
                  value: _highValueFilter,
                  onChanged: (value) {
                    setState(() => _highValueFilter = value ?? false);
                  },
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
          TextButton(
            onPressed: () {
              setState(() {
                _startDate = null;
                _endDate = null;
                _selectedPriority = 'すべて';
                _showOnlyUrgent = false;
                _highValueFilter = false;
              });
            },
            child: const Text('クリア'),
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
      _highValueFilter = false;
      _startDate = null;
      _endDate = null;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _filterByDate(DateTime date) {
    setState(() {
      _startDate = DateTime(date.year, date.month, date.day);
      _endDate = DateTime(date.year, date.month, date.day, 23, 59, 59);
    });
  }

  void _filterByWeek() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(Duration(days: 6));

    setState(() {
      _startDate =
          DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      _endDate =
          DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day, 23, 59, 59);
    });
  }

  void _filterByMonth() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    setState(() {
      _startDate = startOfMonth;
      _endDate = endOfMonth;
    });
  }

  void _filterByHighValue() {
    setState(() {
      _highValueFilter = !_highValueFilter;
    });
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
    if (_selectedDeliveryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('一括操作を行うには、まず案件を長押しして選択してください'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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
            Text(
              '一括操作（${_selectedDeliveryIds.length}件選択中）',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                _bulkCompleteDeliveries();
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
                _bulkAssignDriver();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.priority_high, color: Colors.orange.shade700),
              ),
              title: const Text('一括優先度変更'),
              subtitle: const Text('複数の案件の優先度を変更します'),
              onTap: () {
                Navigator.pop(context);
                _bulkChangePriority();
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
                _bulkDeleteDeliveries();
              },
            ),
          ],
        ),
      ),
    );
  }

  // 一括操作の実装
  Future<void> _bulkCompleteDeliveries() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('一括完了確認'),
        content: Text('選択した${_selectedDeliveryIds.length}件の案件を完了にしますか？'),
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

        for (String deliveryId in _selectedDeliveryIds) {
          final deliveryRef = FirebaseFirestore.instance
              .collection('deliveries')
              .doc(deliveryId);
          batch.update(deliveryRef, {
            'status': '完了',
            'completedAt': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();
        setState(() => _selectedDeliveryIds.clear());

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedDeliveryIds.length}件の案件を完了にしました'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _bulkAssignDriver() async {
    // ドライバー一覧を取得
    final driversSnapshot = await FirebaseFirestore.instance
        .collection('drivers')
        .where('status', isEqualTo: '稼働中')
        .get();

    if (driversSnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('稼働中のドライバーがいません'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selectedDriver = await showDialog<QueryDocumentSnapshot>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ドライバーを選択'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: driversSnapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return ListTile(
              title: Text(data['name'] ?? 'N/A'),
              subtitle: Text(data['email'] ?? ''),
              onTap: () => Navigator.pop(context, doc),
            );
          }).toList(),
        ),
      ),
    );

    if (selectedDriver != null) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        final driverData = selectedDriver.data() as Map<String, dynamic>;

        for (String deliveryId in _selectedDeliveryIds) {
          final deliveryRef = FirebaseFirestore.instance
              .collection('deliveries')
              .doc(deliveryId);
          batch.update(deliveryRef, {
            'driverId': selectedDriver.id,
            'driverName': driverData['name'],
            'status': '配送中',
            'assignedAt': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();
        setState(() => _selectedDeliveryIds.clear());

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedDeliveryIds.length}件の案件にドライバーを割り当てました'),
            backgroundColor: Colors.blue,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _bulkChangePriority() async {
    final priority = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('優先度を選択'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('緊急'),
              leading: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              onTap: () => Navigator.pop(context, 'urgent'),
            ),
            ListTile(
              title: const Text('通常'),
              leading: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
              onTap: () => Navigator.pop(context, 'normal'),
            ),
            ListTile(
              title: const Text('低'),
              leading: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              onTap: () => Navigator.pop(context, 'low'),
            ),
          ],
        ),
      ),
    );

    if (priority != null) {
      try {
        final batch = FirebaseFirestore.instance.batch();

        for (String deliveryId in _selectedDeliveryIds) {
          final deliveryRef = FirebaseFirestore.instance
              .collection('deliveries')
              .doc(deliveryId);
          batch.update(deliveryRef, {
            'priority': priority,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();
        setState(() => _selectedDeliveryIds.clear());

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedDeliveryIds.length}件の案件の優先度を変更しました'),
            backgroundColor: Colors.orange,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _bulkDeleteDeliveries() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('一括削除確認'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('選択した${_selectedDeliveryIds.length}件の案件を削除しますか？'),
            const SizedBox(height: 16),
            const Text(
              '※この操作は元に戻せません',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final batch = FirebaseFirestore.instance.batch();

        for (String deliveryId in _selectedDeliveryIds) {
          final deliveryRef = FirebaseFirestore.instance
              .collection('deliveries')
              .doc(deliveryId);
          batch.delete(deliveryRef);
        }

        await batch.commit();
        setState(() => _selectedDeliveryIds.clear());

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedDeliveryIds.length}件の案件を削除しました'),
            backgroundColor: Colors.red,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // CSV機能の実装
  Future<void> _exportToCSV() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('deliveries')
          .orderBy('createdAt', descending: true)
          .get();

      List<List<dynamic>> csvData = [
        [
          'ID',
          '集荷場所',
          '配送先',
          'ステータス',
          '優先度',
          '料金',
          'ドライバー名',
          '顧客名',
          '作成日時',
          '完了日時',
          '期限',
        ]
      ];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        csvData.add([
          doc.id,
          data['pickupLocation'] ?? '',
          data['deliveryLocation'] ?? '',
          data['status'] ?? '',
          data['priority'] ?? '',
          data['fee'] ?? 0,
          data['driverName'] ?? '',
          data['customerName'] ?? '',
          data['createdAt']?.toDate()?.toString() ?? '',
          data['completedAt']?.toDate()?.toString() ?? '',
          data['deadline']?.toDate()?.toString() ?? '',
        ]);
      }

      final csvString = const ListToCsvConverter().convert(csvData);
      _downloadFile(
          csvString, 'deliveries_${DateTime.now().millisecondsSinceEpoch}.csv');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('配送データをCSV形式でエクスポートしました'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エクスポートエラー: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _importFromCSV() async {
    try {
      final input = html.FileUploadInputElement()..accept = '.csv';
      input.click();

      await input.onChange.first;
      final files = input.files;
      if (files!.isEmpty) return;

      final file = files[0];
      final reader = html.FileReader();
      reader.readAsText(file);

      await reader.onLoad.first;
      final csvString = reader.result as String;

      final csvData = const CsvToListConverter().convert(csvString);
      if (csvData.isEmpty) {
        throw Exception('CSVファイルが空です');
      }

      final dataRows = csvData.skip(1);
      int importCount = 0;

      for (final row in dataRows) {
        if (row.length >= 3) {
          await FirebaseFirestore.instance.collection('deliveries').add({
            'pickupLocation': row[0].toString(),
            'deliveryLocation': row[1].toString(),
            'fee': int.tryParse(row[2].toString()) ?? 0,
            'status': row.length > 3 ? row[3].toString() : '待機中',
            'priority': row.length > 4 ? row[4].toString() : 'normal',
            'customerName': row.length > 5 ? row[5].toString() : '',
            'notes': row.length > 6 ? row[6].toString() : '',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          importCount++;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('配送データ ${importCount}件をインポートしました'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('インポートエラー: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _archiveCompleted() async {
    try {
      final completedDeliveries = await FirebaseFirestore.instance
          .collection('deliveries')
          .where('status', isEqualTo: '完了')
          .get();

      if (completedDeliveries.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('アーカイブする完了案件がありません'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('完了案件アーカイブ'),
          content: Text('${completedDeliveries.docs.length}件の完了案件をアーカイブしますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('アーカイブ'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        final batch = FirebaseFirestore.instance.batch();

        for (var doc in completedDeliveries.docs) {
          // アーカイブコレクションに移動
          final archiveRef = FirebaseFirestore.instance
              .collection('archived_deliveries')
              .doc(doc.id);
          final data = doc.data();
          data['archivedAt'] = FieldValue.serverTimestamp();
          batch.set(archiveRef, data);

          // 元のドキュメントを削除
          batch.delete(doc.reference);
        }

        await batch.commit();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${completedDeliveries.docs.length}件の完了案件をアーカイブしました'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('アーカイブエラー: $e'), backgroundColor: Colors.red),
      );
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

  @override
  void dispose() {
    _pickupController.dispose();
    _deliveryController.dispose();
    _feeController.dispose();
    super.dispose();
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
  final _customerController = TextEditingController();
  final _notesController = TextEditingController();

  String _priority = 'normal';
  DateTime? _deadline;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final data = widget.initialData!;
      _pickupController.text = data['pickupLocation'] ?? '';
      _deliveryController.text = data['deliveryLocation'] ?? '';
      _feeController.text = (data['fee'] ?? 0).toString();
      _customerController.text = data['customerName'] ?? '';
      _notesController.text = data['notes'] ?? '';
      _priority = data['priority'] ?? 'normal';
      if (data['deadline'] != null) {
        _deadline = (data['deadline'] as Timestamp).toDate();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.deliveryId == null ? '新規配送案件' : '配送案件編集'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
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
                value: _priority,
                decoration: const InputDecoration(
                  labelText: '優先度',
                  prefixIcon: Icon(Icons.priority_high),
                ),
                items: [
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
                  prefixIcon: Icon(Icons.calendar_today),
                  suffixIcon: _deadline != null
                      ? IconButton(
                          icon: Icon(Icons.clear),
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
                    lastDate: DateTime.now().add(Duration(days: 365)),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveDelivery,
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

  Future<void> _saveDelivery() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final data = {
        'pickupLocation': _pickupController.text.trim(),
        'deliveryLocation': _deliveryController.text.trim(),
        'fee': int.tryParse(_feeController.text) ?? 0,
        'customerName': _customerController.text.trim(),
        'priority': _priority,
        'notes': _notesController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_deadline != null) {
        data['deadline'] = Timestamp.fromDate(_deadline!);
      }

      if (widget.deliveryId == null) {
        // 新規追加
        data['status'] = '待機中';
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('deliveries').add(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('配送案件を追加しました'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // 更新
        await FirebaseFirestore.instance
            .collection('deliveries')
            .doc(widget.deliveryId)
            .update(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('配送案件を更新しました'),
            backgroundColor: Colors.blue,
          ),
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

  @override
  void dispose() {
    _pickupController.dispose();
    _deliveryController.dispose();
    _feeController.dispose();
    _customerController.dispose();
    _notesController.dispose();
    super.dispose();
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
  QueryDocumentSnapshot? _selectedDriver;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ドライバー割り当て'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('配送案件詳細', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('集荷先: ${widget.deliveryData['pickupLocation'] ?? 'N/A'}'),
                Text(
                    '配送先: ${widget.deliveryData['deliveryLocation'] ?? 'N/A'}'),
                Text('料金: ¥${widget.deliveryData['fee'] ?? 0}'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('ドライバーを選択してください:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            height: 200,
            width: double.maxFinite,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('drivers')
                  .where('status', isEqualTo: '稼働中')
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
                        Icon(Icons.person_off, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('稼働中のドライバーがいません'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isSelected = _selectedDriver?.id == doc.id;

                    return Card(
                      color: isSelected ? Colors.blue.shade50 : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              isSelected ? Colors.blue : Colors.grey,
                          child: Icon(
                            Icons.person,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(data['name'] ?? 'N/A'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['email'] ?? ''),
                            Text(data['phone'] ?? ''),
                          ],
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle, color: Colors.blue)
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedDriver = isSelected ? null : doc;
                          });
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed:
              _selectedDriver == null || _isLoading ? null : _assignDriver,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('割り当て'),
        ),
      ],
    );
  }

  Future<void> _assignDriver() async {
    if (_selectedDriver == null) return;

    setState(() => _isLoading = true);

    try {
      final driverData = _selectedDriver!.data() as Map<String, dynamic>;

      await FirebaseFirestore.instance
          .collection('deliveries')
          .doc(widget.deliveryId)
          .update({
        'driverId': _selectedDriver!.id,
        'driverName': driverData['name'],
        'status': '配送中',
        'assignedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${driverData['name']}にドライバーを割り当てました'),
          backgroundColor: Colors.green,
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

// 配送詳細ダイアログ
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
      title: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          const Text('配送案件詳細'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('案件ID', deliveryId),
            _buildDetailRow('集荷先', data['pickupLocation'] ?? 'N/A'),
            _buildDetailRow('配送先', data['deliveryLocation'] ?? 'N/A'),
            _buildDetailRow('料金', '¥${data['fee'] ?? 0}'),
            _buildDetailRow('ステータス', data['status'] ?? 'N/A'),
            _buildDetailRow('優先度', _getPriorityText(data['priority'])),
            _buildDetailRow('顧客名', data['customerName'] ?? 'N/A'),
            _buildDetailRow('ドライバー', data['driverName'] ?? '未割り当て'),
            if (data['deadline'] != null)
              _buildDetailRow(
                  '期限', _formatDate((data['deadline'] as Timestamp).toDate())),
            if (data['notes'] != null && data['notes'].toString().isNotEmpty)
              _buildDetailRow('備考', data['notes']),
            _buildDetailRow('作成日時', _formatTimestamp(data['createdAt'])),
            if (data['assignedAt'] != null)
              _buildDetailRow('割り当て日時', _formatTimestamp(data['assignedAt'])),
            if (data['completedAt'] != null)
              _buildDetailRow('完了日時', _formatTimestamp(data['completedAt'])),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('閉じる'),
        ),
        if (data['status'] != '完了')
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // 編集ダイアログを開く
              showDialog(
                context: context,
                builder: (context) => _DeliveryFormDialog(
                  deliveryId: deliveryId,
                  initialData: data,
                ),
              );
            },
            icon: const Icon(Icons.edit),
            label: const Text('編集'),
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
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _getPriorityText(String? priority) {
    switch (priority) {
      case 'urgent':
        return '緊急';
      case 'normal':
        return '通常';
      case 'low':
        return '低';
      default:
        return 'N/A';
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
}
