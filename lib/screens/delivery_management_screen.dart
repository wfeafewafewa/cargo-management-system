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
  String _selectedDriver = 'すべて';
  bool _showOnlyUrgent = false;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _highValueFilter = false;
  bool _showArchived = false; // アーカイブ表示切替
  final TextEditingController _searchController = TextEditingController();
  List<String> _selectedDeliveryIds = []; // 一括選択用

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
        title: Row(
          children: [
            const Text('配送案件管理'),
            const SizedBox(width: 12),
            // アーカイブ切替ボタン
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color:
                    _showArchived ? Colors.grey.shade600 : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showArchived ? Icons.archive : Icons.inbox,
                    size: 16,
                    color: _showArchived ? Colors.white : Colors.white70,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _showArchived ? 'アーカイブ' : '通常',
                    style: TextStyle(
                      fontSize: 12,
                      color: _showArchived ? Colors.white : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          // アーカイブ切替ボタン
          IconButton(
            onPressed: () {
              setState(() {
                _showArchived = !_showArchived;
                _selectedDeliveryIds.clear(); // 選択をクリア
              });
            },
            icon: Icon(_showArchived ? Icons.inbox : Icons.archive),
            tooltip: _showArchived ? '通常表示' : 'アーカイブ表示',
          ),
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
          // 一括操作ボタン（選択中のアイテムがある場合のみ表示）
          if (_selectedDeliveryIds.isNotEmpty)
            Stack(
              children: [
                IconButton(
                  onPressed: () => _showBulkActions(),
                  icon: const Icon(Icons.checklist),
                  tooltip: '一括操作',
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${_selectedDeliveryIds.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          // ドライバー管理ボタン
          IconButton(
            onPressed: () => _showDriverManagementDialog(),
            icon: const Icon(Icons.person_add),
            tooltip: 'ドライバー管理',
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
                case 'restore_archived':
                  _restoreArchived();
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
              if (!_showArchived)
                const PopupMenuItem(
                  value: 'import_csv',
                  child: ListTile(
                    leading: Icon(Icons.file_upload),
                    title: Text('CSV一括入稿'),
                  ),
                ),
              const PopupMenuDivider(),
              if (!_showArchived)
                const PopupMenuItem(
                  value: 'archive',
                  child: ListTile(
                    leading: Icon(Icons.archive),
                    title: Text('完了案件をアーカイブ'),
                  ),
                ),
              if (_showArchived)
                const PopupMenuItem(
                  value: 'restore_archived',
                  child: ListTile(
                    leading: Icon(Icons.unarchive),
                    title: Text('選択したアーカイブを復元'),
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
          // 一括選択バー
          if (_selectedDeliveryIds.isNotEmpty) _buildBulkSelectionBar(),
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
      floatingActionButton: _showArchived
          ? null
          : FloatingActionButton.extended(
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
        _selectedDriver != 'すべて' ||
        _searchQuery.isNotEmpty ||
        _startDate != null ||
        _endDate != null ||
        _highValueFilter;
  }

  Widget _buildBulkSelectionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        border: Border(bottom: BorderSide(color: Colors.blue.shade300)),
      ),
      child: Row(
        children: [
          Icon(Icons.checklist, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Text(
            '${_selectedDeliveryIds.length}件選択中',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => setState(() => _selectedDeliveryIds.clear()),
            icon: const Icon(Icons.clear),
            label: const Text('選択解除'),
            style: TextButton.styleFrom(foregroundColor: Colors.blue.shade700),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _showBulkActions,
            icon: const Icon(Icons.settings),
            label: const Text('一括操作'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
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
              items: _showArchived
                  ? ['すべて', 'アーカイブ済み']
                      .map((status) => DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          ))
                      .toList()
                  : ['すべて', '待機中', '配送中', '完了', 'キャンセル']
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
      stream: _showArchived
          ? FirebaseFirestore.instance
              .collection('deliveries')
              .where('archived', isEqualTo: true)
              .snapshots()
          : FirebaseFirestore.instance.collection('deliveries').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final docs = snapshot.data!.docs;
        final total = docs.length;

        if (_showArchived) {
          // アーカイブ表示時の統計
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatItem('アーカイブ済み', total, Colors.grey, Icons.archive),
              ],
            ),
          );
        }

        // 通常表示時の統計
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
    Query query = FirebaseFirestore.instance.collection('deliveries');

    if (_showArchived) {
      query = query.where('archived', isEqualTo: true);
    } else {
      query = query.where('archived', isNotEqualTo: true);
    }

    query = query.orderBy('createdAt', descending: true);

    if (_selectedStatus != 'すべて') {
      if (!_showArchived) {
        query = query.where('status', isEqualTo: _selectedStatus);
      }
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

    // 優先度フィルター
    if (_selectedPriority != 'すべて') {
      filtered = filtered.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _safeStringFromData(data, 'priority') == _selectedPriority;
      }).toList();
    }

    // ドライバーフィルター
    if (_selectedDriver != 'すべて') {
      filtered = filtered.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        if (_selectedDriver == '未割り当て') {
          return _safeStringFromData(data, 'assignedDriverId') == null;
        } else {
          return _safeStringFromData(data, 'assignedDriverId') ==
              _selectedDriver;
        }
      }).toList();
    }

    // 日付範囲フィルター
    if (_startDate != null || _endDate != null) {
      filtered = filtered.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final createdAt = data['createdAt'] as Timestamp?;
        if (createdAt == null) return false;

        final docDate = createdAt.toDate();
        if (_startDate != null && docDate.isBefore(_startDate!)) return false;
        if (_endDate != null && docDate.isAfter(_endDate!)) return false;

        return true;
      }).toList();
    }

    // 高額案件フィルター
    if (_highValueFilter) {
      filtered = filtered.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final unitPrice = data['unitPrice'] as int? ?? 0;
        return unitPrice >= 10000; // 1万円以上を高額案件とする
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
            isFiltered
                ? Icons.search_off
                : _showArchived
                    ? Icons.archive_outlined
                    : Icons.inbox_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            isFiltered
                ? '該当する案件がありません'
                : _showArchived
                    ? 'アーカイブされた案件がありません'
                    : '配送案件がありません',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isFiltered
                ? 'フィルター条件を変更してください'
                : _showArchived
                    ? '案件をアーカイブするとここに表示されます'
                    : '新規案件を追加してください',
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: isFiltered
                ? _clearAllFilters
                : _showArchived
                    ? () => setState(() => _showArchived = false)
                    : _showAddDeliveryDialog,
            icon: Icon(isFiltered
                ? Icons.clear
                : _showArchived
                    ? Icons.inbox
                    : Icons.add),
            label: Text(isFiltered
                ? 'フィルターをクリア'
                : _showArchived
                    ? '通常表示に戻る'
                    : '新規案件を追加'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isFiltered
                  ? Colors.blue
                  : _showArchived
                      ? Colors.grey
                      : Colors.green,
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
    final driverName = _safeStringFromData(data, 'driverName');
    final assignedDriverId = _safeStringFromData(data, 'assignedDriverId');
    final createdAt = data['createdAt'] as Timestamp?;
    final feeType = data['feeType'] ?? 'daily';
    final isSelected = _selectedDeliveryIds.contains(deliveryId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSelected
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
                    // 選択チェックボックス
                    if (_selectedDeliveryIds.isNotEmpty || isSelected)
                      Checkbox(
                        value: isSelected,
                        onChanged: (value) => _toggleSelection(deliveryId),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
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
                    if (feeType == 'per_item' && status == '配送中')
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _showQuantityInputDialog(deliveryId, data),
                          icon: const Icon(Icons.numbers, size: 16),
                          label: const Text('個数入力'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
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
                // ドライバー情報表示とアサイン機能
                if (!_showArchived) ...[
                  const SizedBox(height: 8),
                  _buildDriverSection(
                      deliveryId, driverName, assignedDriverId, status),
                ],
                // 料金情報表示
                if (feeType == 'per_item') ...[
                  const SizedBox(height: 8),
                  _buildFeeInfo(data),
                ],
                const SizedBox(height: 12),
                Text(
                  _formatTimestamp(createdAt),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
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

  Widget _buildDriverSection(String deliveryId, String? driverName,
      String? assignedDriverId, String status) {
    if (driverName != null) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.drive_eta, size: 16, color: Colors.green.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'ドライバー: $driverName',
                style: TextStyle(fontSize: 12, color: Colors.green.shade700),
              ),
            ),
            if (status == '待機中')
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () =>
                        _showDriverAssignDialog(deliveryId, assignedDriverId),
                    icon: const Icon(Icons.edit, size: 16),
                    tooltip: 'ドライバー変更',
                    padding: const EdgeInsets.all(4),
                    constraints:
                        const BoxConstraints(minWidth: 24, minHeight: 24),
                  ),
                  IconButton(
                    onPressed: () => _unassignDriver(deliveryId),
                    icon: const Icon(Icons.person_remove, size: 16),
                    tooltip: 'アサイン解除',
                    padding: const EdgeInsets.all(4),
                    constraints:
                        const BoxConstraints(minWidth: 24, minHeight: 24),
                  ),
                ],
              ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.person_off, size: 16, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'ドライバー未割り当て',
                style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _showDriverAssignDialog(deliveryId, null),
              icon: const Icon(Icons.person_add, size: 14),
              label: const Text('アサイン'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                textStyle: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildFeeInfo(Map<String, dynamic> data) {
    final itemTypes = data['itemTypes'] as List<dynamic>?;
    final actualQuantities = data['actualQuantities'] as Map<String, dynamic>?;
    final finalAmount = data['finalAmount'] as int?;

    if (itemTypes == null || itemTypes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          '個数料金（設定なし）',
          style: TextStyle(fontSize: 12),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '個数料金設定:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
          ...itemTypes.map((item) {
            final itemName = item['name'] ?? '';
            final unitPrice = item['price'] ?? 0;
            final actualQty = actualQuantities?[itemName] as int?;

            return Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$itemName: ¥$unitPrice/個',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  if (actualQty != null)
                    Text(
                      '実績: ${actualQty}個',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
          if (finalAmount != null) ...[
            const SizedBox(height: 4),
            Text(
              '確定金額: ¥$finalAmount',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ],
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
      case 'アーカイブ済み':
        color = Colors.grey;
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

  // ★★★ 新機能実装 ★★★

  // 1. フィルター機能の実装
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => _FilterDialog(
        selectedPriority: _selectedPriority,
        selectedDriver: _selectedDriver,
        startDate: _startDate,
        endDate: _endDate,
        highValueFilter: _highValueFilter,
        onApplyFilters: (priority, driver, startDate, endDate, highValue) {
          setState(() {
            _selectedPriority = priority;
            _selectedDriver = driver;
            _startDate = startDate;
            _endDate = endDate;
            _highValueFilter = highValue;
          });
        },
        onClearFilters: _clearAllFilters,
      ),
    );
  }

  // 2. 一括操作機能の実装
  void _showBulkActions() {
    if (_selectedDeliveryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('案件を選択してください')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _BulkActionsDialog(
        selectedIds: _selectedDeliveryIds,
        isArchived: _showArchived,
        onActionCompleted: () {
          setState(() {
            _selectedDeliveryIds.clear();
          });
        },
      ),
    );
  }

  // 3. CSV出力機能の実装
  void _exportToCSV() async {
    try {
      // 現在表示中のデータを取得
      final snapshot = await _buildQuery().get();
      final filteredDocs = _filterDocuments(snapshot.docs);

      if (filteredDocs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('出力するデータがありません')),
        );
        return;
      }

      final csvData = <List<String>>[];

      // ヘッダー行
      csvData.add([
        'ID',
        '案件名',
        '集荷先',
        '配送先',
        '顧客名',
        'ステータス',
        '担当ドライバー',
        '報酬形態',
        '単価',
        '優先度',
        '作成日時',
        '備考',
      ]);

      // データ行
      for (final doc in filteredDocs) {
        final data = doc.data() as Map<String, dynamic>;
        final createdAt = data['createdAt'] as Timestamp?;

        csvData.add([
          doc.id.substring(0, 8),
          _safeStringFromData(data, 'projectName') ?? '',
          _safeStringFromData(data, 'pickupLocation') ?? '',
          _safeStringFromData(data, 'deliveryLocation') ?? '',
          _safeStringFromData(data, 'customerName') ?? '',
          _safeStringFromData(data, 'status') ?? '',
          _safeStringFromData(data, 'driverName') ?? '未割り当て',
          _getFeeTypeDisplayName(data['feeType'] ?? 'daily'),
          (data['unitPrice'] ?? 0).toString(),
          _getPriorityDisplayName(
              _safeStringFromData(data, 'priority') ?? 'normal'),
          createdAt != null
              ? '${createdAt.toDate().year}/${createdAt.toDate().month}/${createdAt.toDate().day} ${createdAt.toDate().hour}:${createdAt.toDate().minute.toString().padLeft(2, '0')}'
              : '',
          _safeStringFromData(data, 'notes') ?? '',
        ]);
      }

      final csvString = const ListToCsvConverter().convert(csvData);
      final now = DateTime.now();
      final filename =
          'delivery_export_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.csv';

      _downloadFile(csvString, filename);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${filteredDocs.length}件のデータをCSV出力しました'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV出力エラー: $e')),
      );
    }
  }

  String _getFeeTypeDisplayName(String feeType) {
    switch (feeType) {
      case 'daily':
        return '日当';
      case 'hourly':
        return '時給';
      case 'per_item':
        return '個数';
      default:
        return feeType;
    }
  }

  String _getPriorityDisplayName(String priority) {
    switch (priority) {
      case 'low':
        return '低';
      case 'normal':
        return '通常';
      case 'urgent':
        return '緊急';
      default:
        return priority;
    }
  }

  // 4. アーカイブ機能の実装
  void _archiveCompleted() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('deliveries')
          .where('status', isEqualTo: '完了')
          .where('archived', isNotEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('アーカイブ対象の完了案件がありません')),
        );
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('完了案件をアーカイブ'),
          content: Text(
              '${snapshot.docs.length}件の完了案件をアーカイブしますか？\nアーカイブされた案件は別途表示できます。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('アーカイブ'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'archived': true,
          'archivedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${snapshot.docs.length}件の完了案件をアーカイブしました'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('アーカイブエラー: $e')),
      );
    }
  }

  void _restoreArchived() async {
    if (_selectedDeliveryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('復元する案件を選択してください')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('アーカイブから復元'),
        content: Text('選択した${_selectedDeliveryIds.length}件を通常表示に復元しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('復元'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final deliveryId in _selectedDeliveryIds) {
        final docRef =
            FirebaseFirestore.instance.collection('deliveries').doc(deliveryId);
        batch.update(docRef, {
          'archived': FieldValue.delete(),
          'archivedAt': FieldValue.delete(),
          'restoredAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      setState(() {
        _selectedDeliveryIds.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedDeliveryIds.length}件を復元しました'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('復元エラー: $e')),
      );
    }
  }

  // ファイルダウンロード用ヘルパー関数
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

  // ★★★ 既存の機能（継続） ★★★

  // ドライバーアサインダイアログを表示
  void _showDriverAssignDialog(String deliveryId, String? currentDriverId) {
    showDialog(
      context: context,
      builder: (context) => _DriverAssignDialog(
        deliveryId: deliveryId,
        currentDriverId: currentDriverId,
      ),
    );
  }

  // ドライバーアサイン解除
  Future<void> _unassignDriver(String deliveryId) async {
    try {
      await FirebaseFirestore.instance
          .collection('deliveries')
          .doc(deliveryId)
          .update({
        'assignedDriverId': FieldValue.delete(),
        'driverName': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ドライバーアサインを解除しました'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $e')),
      );
    }
  }

  // ドライバー管理ダイアログを表示
  void _showDriverManagementDialog() {
    showDialog(
      context: context,
      builder: (context) => const _DriverManagementDialog(),
    );
  }

  void _showQuantityInputDialog(String deliveryId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => _QuantityInputDialog(
        deliveryId: deliveryId,
        deliveryData: data,
      ),
    );
  }

  void _importFromCSV() {
    showDialog(
      context: context,
      builder: (context) => const _MonthlyBulkImportDialog(),
    );
  }

  void _clearAllFilters() {
    setState(() {
      _selectedStatus = 'すべて';
      _selectedPriority = 'すべて';
      _selectedDriver = 'すべて';
      _searchQuery = '';
      _startDate = null;
      _endDate = null;
      _highValueFilter = false;
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
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('案件ID', deliveryId.substring(0, 8)),
              _buildDetailRow('集荷先', data['pickupLocation'] ?? 'N/A'),
              _buildDetailRow('配送先', data['deliveryLocation'] ?? 'N/A'),
              _buildDetailRow('顧客名', data['customerName'] ?? 'N/A'),
              _buildDetailRow('担当ドライバー', data['driverName'] ?? '未割り当て'),
              _buildDetailRow('ステータス', data['status'] ?? 'N/A'),

              // ドライバーアサイン機能を詳細ダイアログに追加
              if (!_showArchived) ...[
                const SizedBox(height: 16),
                if (data['status'] == '待機中') ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ドライバー操作',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context); // 詳細ダイアログを閉じる
                                  _showDriverAssignDialog(
                                      deliveryId, data['assignedDriverId']);
                                },
                                icon: const Icon(Icons.person_add, size: 16),
                                label: Text(data['driverName'] != null
                                    ? 'ドライバー変更'
                                    : 'ドライバーアサイン'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            if (data['driverName'] != null) ...[
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context); // 詳細ダイアログを閉じる
                                  _unassignDriver(deliveryId);
                                },
                                icon: const Icon(Icons.person_remove, size: 16),
                                label: const Text('アサイン解除'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],

              if (data['feeType'] == 'per_item') ...[
                const SizedBox(height: 8),
                const Text('個数料金詳細:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ..._buildItemTypesDetail(data),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
          if (!_showArchived && data['status'] == '待機中')
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => _DeliveryFormDialog(
                    deliveryId: deliveryId,
                    initialData: data,
                  ),
                );
              },
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('編集'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildItemTypesDetail(Map<String, dynamic> data) {
    final itemTypes = data['itemTypes'] as List<dynamic>?;
    final actualQuantities = data['actualQuantities'] as Map<String, dynamic>?;

    if (itemTypes == null || itemTypes.isEmpty) {
      return [const Text('設定なし', style: TextStyle(color: Colors.grey))];
    }

    return itemTypes.map<Widget>((item) {
      final itemName = item['name'] ?? '';
      final unitPrice = item['price'] ?? 0;
      final actualQty = actualQuantities?[itemName] as int?;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text('$itemName: ¥$unitPrice/個'),
            ),
            if (actualQty != null)
              Text(
                '実績: ${actualQty}個',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      );
    }).toList();
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

// ★★★ 新しいダイアログクラス ★★★

// フィルターダイアログ
class _FilterDialog extends StatefulWidget {
  final String selectedPriority;
  final String selectedDriver;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool highValueFilter;
  final Function(String, String, DateTime?, DateTime?, bool) onApplyFilters;
  final VoidCallback onClearFilters;

  const _FilterDialog({
    required this.selectedPriority,
    required this.selectedDriver,
    required this.startDate,
    required this.endDate,
    required this.highValueFilter,
    required this.onApplyFilters,
    required this.onClearFilters,
  });

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late String _selectedPriority;
  late String _selectedDriver;
  DateTime? _startDate;
  DateTime? _endDate;
  late bool _highValueFilter;
  List<Map<String, dynamic>> _drivers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedPriority = widget.selectedPriority;
    _selectedDriver = widget.selectedDriver;
    _startDate = widget.startDate;
    _endDate = widget.endDate;
    _highValueFilter = widget.highValueFilter;
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('drivers')
          .where('status', isEqualTo: 'active')
          .orderBy('driverName')
          .get();

      setState(() {
        _drivers = snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  'driverName': doc.data()['driverName'] ?? '',
                })
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _drivers = [
          {'id': 'driver1', 'driverName': '山田太郎'},
          {'id': 'driver2', 'driverName': '佐藤花子'},
          {'id': 'driver3', 'driverName': '田中次郎'},
        ];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.filter_list, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          const Text('詳細フィルター'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 優先度フィルター
              const Text('優先度', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: _selectedPriority,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'すべて', child: Text('すべて')),
                    DropdownMenuItem(value: 'low', child: Text('低')),
                    DropdownMenuItem(value: 'normal', child: Text('通常')),
                    DropdownMenuItem(value: 'urgent', child: Text('緊急')),
                  ],
                  onChanged: (value) =>
                      setState(() => _selectedPriority = value!),
                ),
              ),
              const SizedBox(height: 16),

              // ドライバーフィルター
              const Text('担当ドライバー',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('読み込み中...'),
                      )
                    : DropdownButton<String>(
                        value: _selectedDriver,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: [
                          const DropdownMenuItem(
                              value: 'すべて', child: Text('すべて')),
                          const DropdownMenuItem(
                              value: '未割り当て', child: Text('未割り当て')),
                          ..._drivers.map((driver) => DropdownMenuItem(
                                value: driver['id'],
                                child: Text(driver['driverName']),
                              )),
                        ],
                        onChanged: (value) =>
                            setState(() => _selectedDriver = value!),
                      ),
              ),
              const SizedBox(height: 16),

              // 日付範囲フィルター
              const Text('作成日範囲',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context, true),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              _startDate != null
                                  ? '${_startDate!.year}/${_startDate!.month}/${_startDate!.day}'
                                  : '開始日',
                              style: TextStyle(
                                color: _startDate != null
                                    ? Colors.black
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('〜'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context, false),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              _endDate != null
                                  ? '${_endDate!.year}/${_endDate!.month}/${_endDate!.day}'
                                  : '終了日',
                              style: TextStyle(
                                color: _endDate != null
                                    ? Colors.black
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_startDate != null || _endDate != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                    });
                  },
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('日付クリア'),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey),
                ),
              ],
              const SizedBox(height: 16),

              // 高額案件フィルター
              CheckboxListTile(
                title: const Text('高額案件のみ（¥10,000以上）'),
                subtitle: const Text('単価が1万円以上の案件のみ表示'),
                value: _highValueFilter,
                onChanged: (value) => setState(() => _highValueFilter = value!),
                contentPadding: EdgeInsets.zero,
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
        TextButton.icon(
          onPressed: () {
            widget.onClearFilters();
            Navigator.pop(context);
          },
          icon: const Icon(Icons.clear),
          label: const Text('クリア'),
          style: TextButton.styleFrom(foregroundColor: Colors.orange),
        ),
        ElevatedButton.icon(
          onPressed: () {
            widget.onApplyFilters(
              _selectedPriority,
              _selectedDriver,
              _startDate,
              _endDate,
              _highValueFilter,
            );
            Navigator.pop(context);
          },
          icon: const Icon(Icons.check),
          label: const Text('適用'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final initialDate =
        isStartDate ? _startDate ?? DateTime.now() : _endDate ?? DateTime.now();

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (selectedDate != null) {
      setState(() {
        if (isStartDate) {
          _startDate = selectedDate;
        } else {
          _endDate = selectedDate;
        }
      });
    }
  }
}

// 一括操作ダイアログ
class _BulkActionsDialog extends StatefulWidget {
  final List<String> selectedIds;
  final bool isArchived;
  final VoidCallback onActionCompleted;

  const _BulkActionsDialog({
    required this.selectedIds,
    required this.isArchived,
    required this.onActionCompleted,
  });

  @override
  State<_BulkActionsDialog> createState() => _BulkActionsDialogState();
}

class _BulkActionsDialogState extends State<_BulkActionsDialog> {
  bool _isLoading = false;
  String? _selectedNewStatus;
  String? _selectedDriverId;
  List<Map<String, dynamic>> _drivers = [];

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('drivers')
          .where('status', isEqualTo: 'active')
          .orderBy('driverName')
          .get();

      setState(() {
        _drivers = snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  'driverName': doc.data()['driverName'] ?? '',
                })
            .toList();
      });
    } catch (e) {
      setState(() {
        _drivers = [
          {'id': 'driver1', 'driverName': '山田太郎'},
          {'id': 'driver2', 'driverName': '佐藤花子'},
          {'id': 'driver3', 'driverName': '田中次郎'},
        ];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.checklist, color: Colors.purple.shade700),
          const SizedBox(width: 8),
          Text('一括操作（${widget.selectedIds.length}件）'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '選択中の案件: ${widget.selectedIds.length}件',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (!widget.isArchived) ...[
              // ステータス一括変更
              const Text('ステータス一括変更',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: _selectedNewStatus,
                  hint: const Text('変更先ステータスを選択'),
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: '待機中', child: Text('待機中')),
                    DropdownMenuItem(value: '配送中', child: Text('配送中')),
                    DropdownMenuItem(value: '完了', child: Text('完了')),
                    DropdownMenuItem(value: 'キャンセル', child: Text('キャンセル')),
                  ],
                  onChanged: (value) =>
                      setState(() => _selectedNewStatus = value),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _selectedNewStatus != null && !_isLoading
                      ? _bulkUpdateStatus
                      : null,
                  icon: const Icon(Icons.update, size: 16),
                  label: const Text('ステータス変更'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ドライバー一括アサイン
              const Text('ドライバー一括アサイン',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: _selectedDriverId,
                  hint: const Text('アサインするドライバーを選択'),
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: [
                    const DropdownMenuItem(
                        value: 'unassign', child: Text('アサイン解除')),
                    ..._drivers.map((driver) => DropdownMenuItem(
                          value: driver['id'],
                          child: Text(driver['driverName']),
                        )),
                  ],
                  onChanged: (value) =>
                      setState(() => _selectedDriverId = value),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _selectedDriverId != null && !_isLoading
                      ? _bulkAssignDriver
                      : null,
                  icon: const Icon(Icons.person_add, size: 16),
                  label: const Text('ドライバーアサイン'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 一括削除
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      '危険な操作',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: !_isLoading ? _bulkDelete : null,
                        icon: const Icon(Icons.delete_forever, size: 16),
                        label: Text(widget.isArchived ? '完全削除' : '削除'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('閉じる'),
        ),
      ],
    );
  }

  Future<void> _bulkUpdateStatus() async {
    if (_selectedNewStatus == null) return;

    final confirmed = await _showConfirmationDialog(
      '${widget.selectedIds.length}件のステータスを「$_selectedNewStatus」に変更しますか？',
    );

    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      final batch = FirebaseFirestore.instance.batch();

      for (final deliveryId in widget.selectedIds) {
        final docRef =
            FirebaseFirestore.instance.collection('deliveries').doc(deliveryId);
        batch.update(docRef, {
          'status': _selectedNewStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      widget.onActionCompleted();
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${widget.selectedIds.length}件のステータスを「$_selectedNewStatus」に変更しました'),
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

  Future<void> _bulkAssignDriver() async {
    if (_selectedDriverId == null) return;

    final driverName = _selectedDriverId == 'unassign'
        ? 'アサイン解除'
        : _drivers
            .firstWhere((d) => d['id'] == _selectedDriverId)['driverName'];

    final confirmed = await _showConfirmationDialog(
      '${widget.selectedIds.length}件を「$driverName」${_selectedDriverId == 'unassign' ? 'します' : 'にアサインします'}か？',
    );

    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      final batch = FirebaseFirestore.instance.batch();

      for (final deliveryId in widget.selectedIds) {
        final docRef =
            FirebaseFirestore.instance.collection('deliveries').doc(deliveryId);

        if (_selectedDriverId == 'unassign') {
          batch.update(docRef, {
            'assignedDriverId': FieldValue.delete(),
            'driverName': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          batch.update(docRef, {
            'assignedDriverId': _selectedDriverId,
            'driverName': driverName,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();

      widget.onActionCompleted();
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${widget.selectedIds.length}件を「$driverName」${_selectedDriverId == 'unassign' ? 'しました' : 'にアサインしました'}'),
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

  Future<void> _bulkDelete() async {
    final confirmed = await _showConfirmationDialog(
      '${widget.selectedIds.length}件を${widget.isArchived ? '完全に' : ''}削除しますか？\nこの操作は元に戻せません。',
      isDestructive: true,
    );

    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      final batch = FirebaseFirestore.instance.batch();

      for (final deliveryId in widget.selectedIds) {
        final docRef =
            FirebaseFirestore.instance.collection('deliveries').doc(deliveryId);
        batch.delete(docRef);
      }

      await batch.commit();

      widget.onActionCompleted();
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.selectedIds.length}件を削除しました'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('削除エラー: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _showConfirmationDialog(String message,
      {bool isDestructive = false}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isDestructive ? '危険な操作' : '確認'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? Colors.red : Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text(isDestructive ? '削除' : '実行'),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}

// ★★★ 既存のダイアログクラス（継続） ★★★

// ドライバーアサインダイアログ
class _DriverAssignDialog extends StatefulWidget {
  final String deliveryId;
  final String? currentDriverId;

  const _DriverAssignDialog({
    required this.deliveryId,
    this.currentDriverId,
  });

  @override
  State<_DriverAssignDialog> createState() => _DriverAssignDialogState();
}

class _DriverAssignDialogState extends State<_DriverAssignDialog> {
  List<Map<String, dynamic>> _drivers = [];
  bool _isLoading = false;
  bool _isLoadingData = true;
  String? _selectedDriverId;

  @override
  void initState() {
    super.initState();
    _selectedDriverId = widget.currentDriverId;
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    setState(() => _isLoadingData = true);

    try {
      final driversSnapshot = await FirebaseFirestore.instance
          .collection('drivers')
          .where('status', isEqualTo: 'active')
          .orderBy('driverName')
          .get();

      _drivers = driversSnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              })
          .toList();

      setState(() => _isLoadingData = false);
    } catch (e) {
      print('ドライバー読み込みエラー: $e');
      setState(() => _isLoadingData = false);

      // テストデータ
      _drivers = [
        {
          'id': 'driver1',
          'driverName': '山田太郎',
          'vehicleType': '軽トラック',
          'phone': '090-1234-5678'
        },
        {
          'id': 'driver2',
          'driverName': '佐藤花子',
          'vehicleType': '軽バン',
          'phone': '090-2345-6789'
        },
        {
          'id': 'driver3',
          'driverName': '田中次郎',
          'vehicleType': '軽トラック',
          'phone': '090-3456-7890'
        },
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.person_add, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          const Text('ドライバーアサイン'),
        ],
      ),
      content: SizedBox(
        width: 400,
        height: 400,
        child: _isLoadingData
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '案件ID: ${widget.deliveryId.substring(0, 8)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (widget.currentDriverId != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '現在のドライバー: ${_getCurrentDriverName()}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ドライバーを選択:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _drivers.length,
                      itemBuilder: (context, index) {
                        final driver = _drivers[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: RadioListTile<String>(
                            value: driver['id'],
                            groupValue: _selectedDriverId,
                            onChanged: (value) {
                              setState(() => _selectedDriverId = value);
                            },
                            title: Text(
                              driver['driverName'] ?? '',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('車両: ${driver['vehicleType'] ?? 'N/A'}'),
                                if (driver['phone'] != null)
                                  Text('電話: ${driver['phone']}'),
                              ],
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            dense: true,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: _showAddDriverDialog,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('新規ドライバー'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
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
          onPressed:
              _selectedDriverId != null && !_isLoading ? _assignDriver : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('アサイン'),
        ),
      ],
    );
  }

  String _getCurrentDriverName() {
    if (widget.currentDriverId == null) return '';
    final driver = _drivers.firstWhere(
      (d) => d['id'] == widget.currentDriverId,
      orElse: () => {'driverName': '不明'},
    );
    return driver['driverName'] ?? '';
  }

  void _showAddDriverDialog() {
    showDialog(
      context: context,
      builder: (context) => _QuickAddDriverDialog(
        onDriverAdded: (driver) {
          setState(() {
            _drivers.add(driver);
            _selectedDriverId = driver['id'];
          });
        },
      ),
    );
  }

  Future<void> _assignDriver() async {
    if (_selectedDriverId == null) return;

    setState(() => _isLoading = true);

    try {
      final selectedDriver =
          _drivers.firstWhere((d) => d['id'] == _selectedDriverId);

      await FirebaseFirestore.instance
          .collection('deliveries')
          .doc(widget.deliveryId)
          .update({
        'assignedDriverId': _selectedDriverId,
        'driverName': selectedDriver['driverName'],
        'updatedAt': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selectedDriver['driverName']}をアサインしました'),
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

// ドライバー管理ダイアログ
class _DriverManagementDialog extends StatefulWidget {
  const _DriverManagementDialog();

  @override
  State<_DriverManagementDialog> createState() =>
      _DriverManagementDialogState();
}

class _DriverManagementDialogState extends State<_DriverManagementDialog> {
  List<Map<String, dynamic>> _drivers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    setState(() => _isLoading = true);

    try {
      final driversSnapshot = await FirebaseFirestore.instance
          .collection('drivers')
          .orderBy('driverName')
          .get();

      _drivers = driversSnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              })
          .toList();

      setState(() => _isLoading = false);
    } catch (e) {
      print('ドライバー読み込みエラー: $e');
      setState(() => _isLoading = false);

      // テストデータ
      _drivers = [
        {
          'id': 'driver1',
          'driverName': '山田太郎',
          'vehicleType': '軽トラック',
          'phone': '090-1234-5678',
          'status': 'active'
        },
        {
          'id': 'driver2',
          'driverName': '佐藤花子',
          'vehicleType': '軽バン',
          'phone': '090-2345-6789',
          'status': 'active'
        },
        {
          'id': 'driver3',
          'driverName': '田中次郎',
          'vehicleType': '軽トラック',
          'phone': '090-3456-7890',
          'status': 'inactive'
        },
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.group, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          const Text('ドライバー管理'),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 400,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _showAddDriverDialog,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('新規ドライバー追加'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _drivers.length,
                      itemBuilder: (context, index) {
                        final driver = _drivers[index];
                        final isActive = driver['status'] == 'active';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  isActive ? Colors.green : Colors.grey,
                              child: Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              driver['driverName'] ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: isActive ? Colors.black : Colors.grey,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('車両: ${driver['vehicleType'] ?? 'N/A'}'),
                                if (driver['phone'] != null)
                                  Text('電話: ${driver['phone']}'),
                                Text(
                                  'ステータス: ${isActive ? 'アクティブ' : '非アクティブ'}',
                                  style: TextStyle(
                                    color: isActive ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                switch (value) {
                                  case 'edit':
                                    _editDriver(driver);
                                    break;
                                  case 'toggle_status':
                                    _toggleDriverStatus(driver);
                                    break;
                                  case 'delete':
                                    _deleteDriver(driver);
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: ListTile(
                                    leading: Icon(Icons.edit),
                                    title: Text('編集'),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'toggle_status',
                                  child: ListTile(
                                    leading: Icon(isActive
                                        ? Icons.person_off
                                        : Icons.person),
                                    title: Text(
                                        isActive ? '非アクティブにする' : 'アクティブにする'),
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                    leading:
                                        Icon(Icons.delete, color: Colors.red),
                                    title: Text('削除',
                                        style: TextStyle(color: Colors.red)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
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

  void _showAddDriverDialog() {
    showDialog(
      context: context,
      builder: (context) => _QuickAddDriverDialog(
        onDriverAdded: (driver) {
          setState(() {
            _drivers.add(driver);
          });
        },
      ),
    );
  }

  void _editDriver(Map<String, dynamic> driver) {
    showDialog(
      context: context,
      builder: (context) => _QuickAddDriverDialog(
        driver: driver,
        onDriverAdded: (updatedDriver) {
          setState(() {
            final index =
                _drivers.indexWhere((d) => d['id'] == updatedDriver['id']);
            if (index != -1) {
              _drivers[index] = updatedDriver;
            }
          });
        },
      ),
    );
  }

  Future<void> _toggleDriverStatus(Map<String, dynamic> driver) async {
    final newStatus = driver['status'] == 'active' ? 'inactive' : 'active';

    try {
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driver['id'])
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        driver['status'] = newStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${driver['driverName']}のステータスを${newStatus == 'active' ? 'アクティブ' : '非アクティブ'}に変更しました'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $e')),
      );
    }
  }

  Future<void> _deleteDriver(Map<String, dynamic> driver) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ドライバー削除'),
        content: Text('${driver['driverName']}を削除しますか？\nこの操作は元に戻せません。'),
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
        await FirebaseFirestore.instance
            .collection('drivers')
            .doc(driver['id'])
            .delete();

        setState(() {
          _drivers.removeWhere((d) => d['id'] == driver['id']);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${driver['driverName']}を削除しました'),
            backgroundColor: Colors.red,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除エラー: $e')),
        );
      }
    }
  }
}

// ドライバークイック追加ダイアログ
class _QuickAddDriverDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onDriverAdded;
  final Map<String, dynamic>? driver; // 編集の場合

  const _QuickAddDriverDialog({
    required this.onDriverAdded,
    this.driver,
  });

  @override
  State<_QuickAddDriverDialog> createState() => _QuickAddDriverDialogState();
}

class _QuickAddDriverDialogState extends State<_QuickAddDriverDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _licenseController = TextEditingController();
  String _vehicleType = '軽トラック';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.driver != null) {
      _nameController.text = widget.driver!['driverName'] ?? '';
      _phoneController.text = widget.driver!['phone'] ?? '';
      _licenseController.text = widget.driver!['licenseNumber'] ?? '';
      _vehicleType = widget.driver!['vehicleType'] ?? '軽トラック';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.driver != null;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.drive_eta, color: Colors.orange),
          const SizedBox(width: 8),
          Text(isEditing ? 'ドライバー編集' : '新規ドライバー追加'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'ドライバー名 *',
                  hintText: '例: 山田太郎',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) => value?.isEmpty == true ? '必須' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: '電話番号',
                  hintText: '例: 090-1234-5678',
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _vehicleType,
                decoration: const InputDecoration(
                  labelText: '車両タイプ',
                  prefixIcon: Icon(Icons.local_shipping),
                ),
                items: const [
                  DropdownMenuItem(value: '軽トラック', child: Text('軽トラック')),
                  DropdownMenuItem(value: '軽バン', child: Text('軽バン')),
                  DropdownMenuItem(value: '普通トラック', child: Text('普通トラック')),
                ],
                onChanged: (value) => setState(() => _vehicleType = value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _licenseController,
                decoration: const InputDecoration(
                  labelText: '免許番号',
                  hintText: '例: 12345678901234',
                  prefixIcon: Icon(Icons.credit_card),
                ),
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
          onPressed: _isLoading ? null : _saveDriver,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEditing ? '更新' : '追加'),
        ),
      ],
    );
  }

  Future<void> _saveDriver() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final driverData = {
        'driverName': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'vehicleType': _vehicleType,
        'licenseNumber': _licenseController.text.trim(),
        'status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.driver != null) {
        // 編集の場合
        await FirebaseFirestore.instance
            .collection('drivers')
            .doc(widget.driver!['id'])
            .update(driverData);

        final updatedDriver = {
          'id': widget.driver!['id'],
          ...driverData,
        };

        widget.onDriverAdded(updatedDriver);
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ドライバー情報を更新しました'),
            backgroundColor: Colors.blue,
          ),
        );
      } else {
        // 新規追加の場合
        driverData['createdAt'] = FieldValue.serverTimestamp();

        final docRef = await FirebaseFirestore.instance
            .collection('drivers')
            .add(driverData);

        final newDriver = {
          'id': docRef.id,
          ...driverData,
        };

        widget.onDriverAdded(newDriver);
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('新規ドライバーを追加しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
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
    _nameController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    super.dispose();
  }
}

// 個数入力ダイアログ
class _QuantityInputDialog extends StatefulWidget {
  final String deliveryId;
  final Map<String, dynamic> deliveryData;

  const _QuantityInputDialog({
    required this.deliveryId,
    required this.deliveryData,
  });

  @override
  State<_QuantityInputDialog> createState() => _QuantityInputDialogState();
}

class _QuantityInputDialogState extends State<_QuantityInputDialog> {
  final Map<String, TextEditingController> _quantityControllers = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final itemTypes = widget.deliveryData['itemTypes'] as List<dynamic>?;
    final actualQuantities =
        widget.deliveryData['actualQuantities'] as Map<String, dynamic>?;

    if (itemTypes != null) {
      for (final item in itemTypes) {
        final itemName = item['name'] as String;
        final currentQty = actualQuantities?[itemName] as int?;
        _quantityControllers[itemName] = TextEditingController(
          text: currentQty?.toString() ?? '',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemTypes = widget.deliveryData['itemTypes'] as List<dynamic>?;

    if (itemTypes == null || itemTypes.isEmpty) {
      return AlertDialog(
        title: const Text('個数入力'),
        content: const Text('この案件には個数料金の設定がありません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.numbers, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          const Text('実際の個数を入力'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '案件: ${widget.deliveryData['projectName'] ?? 'N/A'}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '配送先: ${widget.deliveryData['deliveryLocation'] ?? 'N/A'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...itemTypes.map((item) {
                final itemName = item['name'] as String;
                final unitPrice = item['price'] as int;
                final controller = _quantityControllers[itemName]!;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        itemName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '単価: ¥$unitPrice/個',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: controller,
                              decoration: const InputDecoration(
                                labelText: '実際の個数',
                                suffixText: '個',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) => _updateCalculation(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                '小計',
                                style: TextStyle(fontSize: 12),
                              ),
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: controller,
                                builder: (context, value, child) {
                                  final qty = int.tryParse(value.text) ?? 0;
                                  final subtotal = qty * unitPrice;
                                  return Text(
                                    '¥$subtotal',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                      fontSize: 16,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '合計金額:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    AnimatedBuilder(
                      animation: Listenable.merge(_quantityControllers.values),
                      builder: (context, _) {
                        final total = _calculateTotal();
                        return Text(
                          '¥$total',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        );
                      },
                    ),
                  ],
                ),
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
          onPressed: _isLoading ? null : _saveQuantities,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('確定'),
        ),
      ],
    );
  }

  void _updateCalculation() {
    setState(() {}); // 計算結果を更新するため
  }

  int _calculateTotal() {
    final itemTypes = widget.deliveryData['itemTypes'] as List<dynamic>;
    int total = 0;

    for (final item in itemTypes) {
      final itemName = item['name'] as String;
      final unitPrice = item['price'] as int;
      final qty = int.tryParse(_quantityControllers[itemName]?.text ?? '') ?? 0;
      total += qty * unitPrice;
    }

    return total;
  }

  Future<void> _saveQuantities() async {
    setState(() => _isLoading = true);

    try {
      final actualQuantities = <String, int>{};
      final itemTypes = widget.deliveryData['itemTypes'] as List<dynamic>;

      // 各荷物種類の実際の個数を取得
      for (final item in itemTypes) {
        final itemName = item['name'] as String;
        final qty =
            int.tryParse(_quantityControllers[itemName]?.text ?? '') ?? 0;
        actualQuantities[itemName] = qty;
      }

      final finalAmount = _calculateTotal();

      // Firestoreに保存
      await FirebaseFirestore.instance
          .collection('deliveries')
          .doc(widget.deliveryId)
          .update({
        'actualQuantities': actualQuantities,
        'finalAmount': finalAmount,
        'status': '完了',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('個数を確定しました。最終金額: ¥$finalAmount'),
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

  @override
  void dispose() {
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }
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
  final _projectNameController = TextEditingController();
  final _pickupController = TextEditingController();
  final _deliveryController = TextEditingController();
  final _customerController = TextEditingController();
  final _notesController = TextEditingController();
  final _unitPriceController = TextEditingController();

  String? _selectedCustomerId;
  String? _selectedDriverId;
  String _priority = 'normal';
  String _feeType = 'daily';
  DateTime? _deadline;
  bool _isLoading = false;

  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _drivers = [];
  bool _isLoadingData = false;

  // 個数料金の詳細設定用
  List<Map<String, dynamic>> _itemTypes = [];
  final _itemTypeNameController = TextEditingController();
  final _itemTypePriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCustomersAndDrivers();
    if (widget.initialData != null) {
      _initializeFormData();
    }
  }

  void _initializeFormData() {
    final data = widget.initialData!;
    _projectNameController.text = data['projectName'] ?? '';
    _pickupController.text = data['pickupLocation'] ?? '';
    _deliveryController.text = data['deliveryLocation'] ?? '';
    _customerController.text = data['customerName'] ?? '';
    _notesController.text = data['notes'] ?? '';
    _unitPriceController.text = (data['unitPrice'] ?? 0).toString();
    _priority = data['priority'] ?? 'normal';
    _feeType = data['feeType'] ?? 'daily';
    _selectedCustomerId = data['customerId'];
    _selectedDriverId = data['assignedDriverId'];

    if (data['itemTypes'] != null) {
      _itemTypes = List<Map<String, dynamic>>.from(data['itemTypes']);
    }

    if (data['deadline'] != null) {
      _deadline = (data['deadline'] as Timestamp).toDate();
    }
  }

  Future<void> _loadCustomersAndDrivers() async {
    setState(() => _isLoadingData = true);

    try {
      final customersSnapshot = await FirebaseFirestore.instance
          .collection('customers')
          .orderBy('customerName')
          .get();

      _customers = customersSnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              })
          .toList();

      final driversSnapshot = await FirebaseFirestore.instance
          .collection('drivers')
          .where('status', isEqualTo: 'active')
          .orderBy('driverName')
          .get();

      _drivers = driversSnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              })
          .toList();

      setState(() => _isLoadingData = false);
    } catch (e) {
      print('データ読み込みエラー: $e');
      setState(() => _isLoadingData = false);

      _customers = [
        {'id': 'customer1', 'customerName': '株式会社ABC', 'address': '東京都渋谷区'},
        {'id': 'customer2', 'customerName': '合同会社XYZ', 'address': '東京都新宿区'},
        {'id': 'customer3', 'customerName': '個人太郎', 'address': '千葉県千葉市'},
      ];

      _drivers = [
        {'id': 'driver1', 'driverName': '山田太郎', 'vehicleType': '軽トラック'},
        {'id': 'driver2', 'driverName': '佐藤花子', 'vehicleType': '軽バン'},
        {'id': 'driver3', 'driverName': '田中次郎', 'vehicleType': '軽トラック'},
      ];
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
            width: 550,
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
                    prefixIcon: Icon(Icons.business),
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
                    hintText: '500',
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
                            '¥${item['price']}/個',
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
          ],
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
        data['unitPrice'] = 0;
        data['fee'] = 0;
      } else {
        final unitPrice = int.tryParse(_unitPriceController.text) ?? 0;
        data['unitPrice'] = unitPrice;
        data['fee'] = unitPrice;
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

// CSV一括入稿ダイアログ（完全版）
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
    '備考',
    // 個数料金詳細設定用（個数なし版）
    '荷物種類1_名前',
    '荷物種類1_単価',
    '荷物種類2_名前',
    '荷物種類2_単価',
    '荷物種類3_名前',
    '荷物種類3_単価',
    '荷物種類4_名前',
    '荷物種類4_単価',
    '荷物種類5_名前',
    '荷物種類5_単価',
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
        width: screenSize.width * 0.9,
        height: screenSize.height * 0.8,
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
              _buildSpreadsheetSection(),
              const SizedBox(height: 12),
              _buildCSVFormatSection(),
              const SizedBox(height: 12),
              _buildTemplateDownloadSection(),
              const SizedBox(height: 12),
              _buildUploadSection(),
              const SizedBox(height: 16),
              Container(
                height: 300,
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

  Widget _buildSpreadsheetSection() {
    return Container(
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
              Icon(Icons.table_chart, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Step 1: スプレッドシートで入力（推奨）',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.green.shade700),
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
              '1. 上記ボタンでテンプレートを開く\n2. データを入力（個数料金の場合は荷物種類と単価を記入）\n3. CSV形式で保存\n4. 下記でCSVファイルをアップロード',
              style: TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCSVFormatSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.amber.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                '個数料金について（実配送時個数入力版）',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.amber.shade700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '報酬形態が「個数」の場合：',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 4),
                const Text(
                  '• CSVでは荷物種類と単価のみ設定',
                  style: TextStyle(fontSize: 11),
                ),
                const Text(
                  '• 実際の個数は配送完了時にドライバーが入力',
                  style: TextStyle(fontSize: 11),
                ),
                const Text(
                  '• システムが自動で個数×単価を計算',
                  style: TextStyle(fontSize: 11),
                ),
                const SizedBox(height: 8),
                Text(
                  '例：',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade700,
                      fontSize: 12),
                ),
                const Text(
                  'CSV: 大型荷物 ¥500/個, 小型荷物 ¥200/個',
                  style: TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
                const Text(
                  '配送時: 大型3個、小型5個 → 合計¥2,500',
                  style: TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateDownloadSection() {
    return Container(
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
                  fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _downloadBasicTemplate,
                  icon: const Icon(Icons.download, size: 14),
                  label: const Text('基本テンプレート'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _downloadDetailedTemplate,
                  icon: const Icon(Icons.download, size: 14),
                  label: const Text('個数料金対応版'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade600,
                      foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUploadSection() {
    return Container(
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
                  fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${index + 1}. ${item['projectName']} - ${_getFeeDisplayText(item)}',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w500)),
                        if (item['feeType'] == 'per_item' &&
                            item['itemTypes'] != null &&
                            (item['itemTypes'] as List).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 16, top: 4),
                            child: Text(
                              '荷物種類: ${(item['itemTypes'] as List).map((type) => '${type['name']}(¥${type['price']}/個)').join(', ')}',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade600),
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
      );
    }

    return const Center(
        child:
            Text('CSVファイルを選択してプレビューを表示', style: TextStyle(color: Colors.grey)));
  }

  String _getFeeDisplayText(Map<String, dynamic> item) {
    switch (item['feeType']) {
      case 'daily':
        return '¥${item['unitPrice']}/日';
      case 'hourly':
        return '¥${item['unitPrice']}/時間';
      case 'per_item':
        if (item['itemTypes'] != null &&
            (item['itemTypes'] as List).isNotEmpty) {
          return '個数料金（${(item['itemTypes'] as List).length}種類）';
        }
        return '個数料金（設定なし）';
      default:
        return '¥${item['unitPrice']}';
    }
  }

  void _openSpreadsheetTemplate() {
    html.window.open(_spreadsheetTemplateUrl, '_blank');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('スプレッドシートテンプレートを新しいタブで開きました'),
          backgroundColor: Colors.green),
    );
  }

  void _downloadBasicTemplate() {
    final basicHeaders = [
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

    final csvData = [
      basicHeaders,
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
      [
        '2025/${_selectedMonth}/16',
        '千葉-東京配送案件',
        '千葉県千葉市〇〇',
        '東京都港区△△',
        '個人太郎',
        'hourly',
        '1500',
        'urgent',
        '急ぎの配送'
      ],
    ];

    final csvString = const ListToCsvConverter().convert(csvData);
    _downloadFile(csvString,
        'delivery_basic_template_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}.csv');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('基本CSVテンプレートをダウンロードしました'),
          backgroundColor: Colors.blue),
    );
  }

  void _downloadDetailedTemplate() {
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
        '午前中配送希望',
        '', '', '', '', '', '', '', '', '', '' // 個数料金用列は空
      ],
      [
        '2025/${_selectedMonth}/16',
        '荷物配送案件',
        '東京都港区〇〇',
        '千葉県船橋市△△',
        '運送会社ABC',
        'per_item',
        '0',
        'normal',
        '複数種類の荷物（配送時に個数入力）',
        '大型荷物', '500', // 荷物種類1
        '中型荷物', '300', // 荷物種類2
        '小型荷物', '150', // 荷物種類3
        '', '', '', '', '', '' // 残りは空
      ],
      [
        '2025/${_selectedMonth}/17',
        '時給案件',
        '神奈川県横浜市〇〇',
        '東京都新宿区△△',
        '個人花子',
        'hourly',
        '1500',
        'urgent',
        '時間単価',
        '', '', '', '', '', '', '', '', '', '' // 個数料金用列は空
      ],
    ];

    final csvString = const ListToCsvConverter().convert(csvData);
    _downloadFile(csvString,
        'delivery_detailed_template_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}.csv');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('個数料金対応CSVテンプレートをダウンロードしました'),
          backgroundColor: Colors.purple),
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

      final basicRequiredHeaders = [
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
      final missingHeaders = basicRequiredHeaders
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

    final feeType = _mapFeeType(item['報酬形態'] ?? '');
    if (feeType == null) {
      throw Exception('報酬形態は "daily", "hourly", "per_item" のいずれかを指定してください');
    }

    item['projectName'] = item['案件名'] ?? '';
    item['pickupLocation'] = item['集荷先'];
    item['deliveryLocation'] = item['配送先'];
    item['customerName'] = item['顧客名'] ?? '';
    item['feeType'] = feeType;
    item['priority'] = _mapPriority(item['優先度'] ?? 'normal');
    item['notes'] = item['備考'] ?? '';

    if (feeType == 'per_item') {
      final itemTypes = <Map<String, dynamic>>[];

      for (int i = 1; i <= 5; i++) {
        final nameKey = '荷物種類${i}_名前';
        final priceKey = '荷物種類${i}_単価';

        final typeName = item[nameKey]?.toString()?.trim();
        final priceStr = item[priceKey]?.toString()?.trim();

        if (typeName != null && typeName.isNotEmpty) {
          final price = int.tryParse(priceStr ?? '');
          if (price == null || price <= 0) {
            throw Exception('${priceKey} の値は正の数値で入力してください');
          }

          itemTypes.add({
            'name': typeName,
            'price': price,
          });
        }
      }

      item['itemTypes'] = itemTypes;
      item['unitPrice'] = 0; // 個数料金の場合は実配送時に決定
    } else {
      final unitPrice = int.tryParse(item['単価'] ?? '');
      if (unitPrice == null) throw Exception('単価は数値で入力してください');
      item['unitPrice'] = unitPrice;
    }

    return item;
  }

  String? _mapFeeType(String feeTypeStr) {
    switch (feeTypeStr.toLowerCase()) {
      case 'daily':
      case '日当':
      case '日給':
        return 'daily';
      case 'hourly':
      case '時給':
      case '時間':
        return 'hourly';
      case 'per_item':
      case '個数':
      case 'piece':
        return 'per_item';
      default:
        return null;
    }
  }

  String _mapPriority(String priorityStr) {
    switch (priorityStr.toLowerCase()) {
      case 'low':
      case '低':
        return 'low';
      case 'urgent':
      case '緊急':
      case 'high':
      case '高':
        return 'urgent';
      case 'normal':
      case '通常':
      default:
        return 'normal';
    }
  }

  Future<void> _importData() async {
    if (_previewData == null || _previewData!.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final batch = FirebaseFirestore.instance.batch();

      for (final item in _previewData!) {
        final docRef =
            FirebaseFirestore.instance.collection('deliveries').doc();

        final deliveryData = {
          'projectName': item['projectName'],
          'pickupLocation': item['pickupLocation'],
          'deliveryLocation': item['deliveryLocation'],
          'customerName': item['customerName'],
          'unitPrice': item['unitPrice'],
          'fee': item['unitPrice'],
          'feeType': item['feeType'],
          'priority': item['priority'],
          'notes': item['notes'],
          'status': '待機中',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (item['feeType'] == 'per_item' && item['itemTypes'] != null) {
          deliveryData['itemTypes'] = item['itemTypes'];
        }

        batch.set(docRef, deliveryData);
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
