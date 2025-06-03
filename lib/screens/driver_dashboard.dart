import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:io';
import 'dart:convert';

class DriverManagementScreen extends StatefulWidget {
  const DriverManagementScreen({Key? key}) : super(key: key);

  @override
  State<DriverManagementScreen> createState() => _DriverManagementScreenState();
}

class _DriverManagementScreenState extends State<DriverManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  String _selectedStatus = 'すべて';
  String _searchQuery = '';
  String _activeFilter = '';
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  List<String> _selectedDriverIds = [];
  bool _isSelectionMode = false;

  // カレンダー用
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _setupAnimations();
    _loadDriverStats();
    _selectedDay = DateTime.now();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
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

  Future<void> _loadDriverStats() async {
    setState(() => _isLoading = true);

    try {
      final driversSnapshot =
          await FirebaseFirestore.instance.collection('drivers').get();

      final deliveriesSnapshot =
          await FirebaseFirestore.instance.collection('deliveries').get();

      final drivers = driversSnapshot.docs;
      final deliveries = deliveriesSnapshot.docs;

      final totalDrivers = drivers.length;
      final activeDrivers =
          drivers.where((d) => (d.data()['status'] as String?) == '稼働中').length;
      final restingDrivers =
          drivers.where((d) => (d.data()['status'] as String?) == '休憩中').length;
      final offlineDrivers = drivers
          .where((d) => (d.data()['status'] as String?) == 'オフライン')
          .length;

      // 今日の配送実績
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayDeliveries = deliveries.where((d) {
        final completedAt = (d.data()['completedAt'] as Timestamp?)?.toDate();
        return completedAt != null && completedAt.isAfter(todayStart);
      }).length;

      setState(() {
        _stats = {
          'totalDrivers': totalDrivers,
          'activeDrivers': activeDrivers,
          'restingDrivers': restingDrivers,
          'offlineDrivers': offlineDrivers,
          'todayDeliveries': todayDeliveries,
          'utilization': totalDrivers > 0
              ? ((activeDrivers / totalDrivers) * 100).round()
              : 0,
        };
        _isLoading = false;
      });

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
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.people, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(_isSelectionMode
                ? '${_selectedDriverIds.length}人選択中'
                : 'ドライバー管理'),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              onPressed: _cancelSelection,
              icon: const Icon(Icons.close),
              tooltip: '選択解除',
            ),
            IconButton(
              onPressed: _selectedDriverIds.isNotEmpty
                  ? _showBulkActionsForSelected
                  : null,
              icon: const Icon(Icons.checklist),
              tooltip: '一括操作',
            ),
          ] else ...[
            IconButton(
              onPressed: _showDriverStats,
              icon: Stack(
                children: [
                  const Icon(Icons.analytics),
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
                      child: Text(
                        '${_stats['activeDrivers'] ?? 0}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
              tooltip: '稼働状況',
            ),
            IconButton(
              onPressed: _loadDriverStats,
              icon: const Icon(Icons.refresh),
              tooltip: '更新',
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'export':
                    _exportDriverData();
                    break;
                  case 'import':
                    _importDriverData();
                    break;
                  case 'bulk_actions':
                    _showBulkActions();
                    break;
                  case 'selection_mode':
                    _toggleSelectionMode();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'export',
                  child: ListTile(
                    leading: Icon(Icons.file_download),
                    title: Text('CSV出力'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'import',
                  child: ListTile(
                    leading: Icon(Icons.file_upload),
                    title: Text('CSV取り込み'),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'selection_mode',
                  child: ListTile(
                    leading: Icon(Icons.checklist),
                    title: Text('選択モード'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'bulk_actions',
                  child: ListTile(
                    leading: Icon(Icons.settings),
                    title: Text('一括操作'),
                  ),
                ),
              ],
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'ドライバー一覧'),
            Tab(icon: Icon(Icons.analytics), text: 'パフォーマンス'),
            Tab(icon: Icon(Icons.schedule), text: 'スケジュール'),
          ],
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            if (_isLoading)
              const LinearProgressIndicator()
            else
              _buildStatsBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDriverListTab(),
                  _buildPerformanceTab(),
                  _buildScheduleTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  onPressed: _showBulkStatusUpdate,
                  heroTag: "bulk_update",
                  child: const Icon(Icons.update),
                  backgroundColor: Colors.orange,
                  tooltip: '一括ステータス更新',
                ),
                const SizedBox(height: 16),
                FloatingActionButton.extended(
                  onPressed: _showAddDriverDialog,
                  heroTag: "add_driver",
                  icon: const Icon(Icons.person_add),
                  label: const Text('新規ドライバー'),
                  backgroundColor: Colors.green,
                ),
              ],
            ),
    );
  }

  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
              '総数', _stats['totalDrivers'] ?? 0, Colors.blue, Icons.people),
          _buildStatItem(
              '稼働中', _stats['activeDrivers'] ?? 0, Colors.green, Icons.work),
          _buildStatItem(
              '休憩中', _stats['restingDrivers'] ?? 0, Colors.orange, Icons.pause),
          _buildStatItem('オフライン', _stats['offlineDrivers'] ?? 0, Colors.grey,
              Icons.offline_bolt),
          _buildStatItem('稼働率', _stats['utilization'] ?? 0, Colors.purple,
              Icons.trending_up,
              suffix: '%'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value, Color color, IconData icon,
      {String suffix = ''}) {
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
          '$value$suffix',
          style: TextStyle(
            fontSize: 16,
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

  Widget _buildDriverListTab() {
    return Column(
      children: [
        _buildFilterSection(),
        Expanded(child: _buildDriverList()),
      ],
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
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'ドライバー名、電話番号で検索...',
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
                  items: ['すべて', '稼働中', '休憩中', 'オフライン']
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
                _buildFilterChip('新規ドライバー', () => _filterByNew(), 'new'),
                _buildFilterChip('ベテラン', () => _filterByVeteran(), 'veteran'),
                _buildFilterChip(
                    '高評価', () => _filterByHighRating(), 'high_rating'),
                _buildFilterChip('要注意', () => _filterByAlert(), 'alert'),
                _buildFilterChip('フィルタークリア', () => _clearFilters(), ''),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onTap, String filterId) {
    final isActive = _activeFilter == filterId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label),
        onPressed: onTap,
        backgroundColor:
            isActive ? Colors.green.shade200 : Colors.green.shade50,
        side: BorderSide(
          color: isActive ? Colors.green.shade600 : Colors.green.shade200,
          width: isActive ? 2 : 1,
        ),
      ),
    );
  }

  Widget _buildDriverList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildDriverQuery().snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('ドライバー情報を読み込み中...'),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyDriverList();
        }

        final filteredDocs = _filterDrivers(snapshot.data!.docs);

        if (filteredDocs.isEmpty) {
          return _buildEmptyDriverList(isFiltered: true);
        }

        return RefreshIndicator(
          onRefresh: _loadDriverStats,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              final doc = filteredDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              return AnimatedContainer(
                duration: Duration(milliseconds: 300 + (index * 50)),
                curve: Curves.easeInOut,
                child: _buildDriverCard(doc.id, data),
              );
            },
          ),
        );
      },
    );
  }

  Query _buildDriverQuery() {
    Query query = FirebaseFirestore.instance
        .collection('drivers')
        .orderBy('createdAt', descending: true);

    if (_selectedStatus != 'すべて') {
      query = query.where('status', isEqualTo: _selectedStatus);
    }

    return query;
  }

  List<QueryDocumentSnapshot> _filterDrivers(List<QueryDocumentSnapshot> docs) {
    var filtered = docs;

    // 検索クエリでフィルタ
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = (_safeString(data['name']) ?? '').toLowerCase();
        final phone = (_safeString(data['phone']) ?? '').toLowerCase();
        final query = _searchQuery.toLowerCase();

        return name.contains(query) || phone.contains(query);
      }).toList();
    }

    // 特殊フィルタを適用
    switch (_activeFilter) {
      case 'new':
        filtered = filtered.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final createdAt = data['createdAt'] as Timestamp?;
          if (createdAt == null) return false;
          final daysSinceJoin =
              DateTime.now().difference(createdAt.toDate()).inDays;
          return daysSinceJoin <= 30; // 30日以内を新規とする
        }).toList();
        break;
      case 'veteran':
        filtered = filtered.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final createdAt = data['createdAt'] as Timestamp?;
          if (createdAt == null) return false;
          final daysSinceJoin =
              DateTime.now().difference(createdAt.toDate()).inDays;
          return daysSinceJoin > 365; // 1年以上をベテランとする
        }).toList();
        break;
      case 'high_rating':
        filtered = filtered.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final rating = (_safeNumber(data['rating']) ?? 0).toDouble();
          return rating >= 4.5;
        }).toList();
        break;
      case 'alert':
        filtered = filtered.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final rating = (_safeNumber(data['rating']) ?? 0).toDouble();
          final currentDeliveries = _safeNumber(data['currentDeliveries']) ?? 0;
          return rating < 3.0 || currentDeliveries > 10;
        }).toList();
        break;
    }

    return filtered;
  }

  Widget _buildEmptyDriverList({bool isFiltered = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFiltered ? Icons.search_off : Icons.people_outlined,
              size: 80,
              color: Colors.green.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isFiltered ? '該当するドライバーがいません' : 'ドライバーが登録されていません',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isFiltered ? 'フィルター条件を変更してください' : '新しいドライバーを登録してください',
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: isFiltered ? _clearFilters : _showAddDriverDialog,
            icon: Icon(isFiltered ? Icons.clear : Icons.person_add),
            label: Text(isFiltered ? 'フィルタークリア' : '新規ドライバー登録'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverCard(String driverId, Map<String, dynamic> data) {
    final status = _safeString(data['status']) ?? 'オフライン';
    final name = _safeString(data['name']) ?? 'N/A';
    final phone = _safeString(data['phone']) ?? 'N/A';
    final vehicle = _safeString(data['vehicle']) ?? 'N/A';
    final currentDeliveries = _safeNumber(data['currentDeliveries']) ?? 0;
    final rating = (_safeNumber(data['rating']) ?? 0).toDouble();
    final joinDate = data['createdAt'] as Timestamp?;

    final statusColor = _getStatusColor(status);
    final isAlert = rating < 3.0 || currentDeliveries > 10;
    final isSelected = _selectedDriverIds.contains(driverId);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isAlert ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSelected
            ? const BorderSide(color: Colors.green, width: 3)
            : isAlert
                ? const BorderSide(color: Colors.orange, width: 2)
                : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _isSelectionMode
            ? _toggleDriverSelection(driverId)
            : _showDriverDetails(driverId, data),
        onLongPress: () => _toggleDriverSelection(driverId),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (_isSelectionMode)
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (_) => _toggleDriverSelection(driverId),
                        activeColor: Colors.green,
                      ),
                    ),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: statusColor, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'D',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildStatusBadge(status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.phone,
                                size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              phone,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isAlert && !_isSelectionMode)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.warning,
                        color: Colors.orange.shade700,
                        size: 20,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // 詳細情報
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildInfoItem('車両', vehicle, Icons.directions_car),
                        const SizedBox(width: 24),
                        _buildInfoItem('担当案件', '${currentDeliveries.round()}件',
                            Icons.local_shipping),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildInfoItem(
                            '評価', '${rating.toStringAsFixed(1)}★', Icons.star),
                        const SizedBox(width: 24),
                        _buildInfoItem(
                            '入社',
                            joinDate != null
                                ? _formatDate(joinDate.toDate())
                                : 'N/A',
                            Icons.calendar_today),
                      ],
                    ),
                  ],
                ),
              ),

              if (!_isSelectionMode) ...[
                const SizedBox(height: 16),

                // アクションボタン
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showDriverDetails(driverId, data),
                        icon: const Icon(Icons.info_outline, size: 18),
                        label: const Text('詳細'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: BorderSide(color: Colors.blue.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _toggleDriverStatus(driverId, status),
                        icon: Icon(_getStatusIcon(status), size: 18),
                        label: Text(_getStatusToggleText(status)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: statusColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    final icon = _getStatusIcon(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
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

  Widget _buildPerformanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildPerformanceOverview(),
          const SizedBox(height: 16),
          _buildTopPerformers(),
          const SizedBox(height: 16),
          _buildPerformanceMetrics(),
          const SizedBox(height: 16),
          _buildPerformanceChart(),
        ],
      ),
    );
  }

  Widget _buildPerformanceOverview() {
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
                Icon(Icons.analytics, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Text(
                  'パフォーマンス概要',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildPerformanceCard(
                  '今日の配送',
                  '${_stats['todayDeliveries'] ?? 0}件',
                  Icons.today,
                  Colors.blue,
                ),
                _buildPerformanceCard(
                  '平均評価',
                  '4.2★',
                  Icons.star,
                  Colors.orange,
                ),
                _buildPerformanceCard(
                  '完了率',
                  '94%',
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildPerformanceCard(
                  '稼働率',
                  '${_stats['utilization'] ?? 0}%',
                  Icons.trending_up,
                  Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopPerformers() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'トップパフォーマー',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('drivers')
                  .orderBy('rating', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                return Column(
                  children: snapshot.data!.docs.asMap().entries.map((entry) {
                    final index = entry.key;
                    final doc = entry.value;
                    final data = doc.data() as Map<String, dynamic>;

                    return _buildTopPerformerItem(
                      index + 1,
                      _safeString(data['name']) ?? 'N/A',
                      (_safeNumber(data['rating']) ?? 0).toDouble(),
                      _safeNumber(data['currentDeliveries']) ?? 0,
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopPerformerItem(
      int rank, String name, double rating, num deliveries) {
    final medalColor = rank == 1
        ? Colors.amber
        : rank == 2
            ? Colors.grey
            : rank == 3
                ? Colors.brown
                : Colors.grey.shade400;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            rank <= 3 ? medalColor.withValues(alpha: 0.1) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: rank <= 3
              ? medalColor.withValues(alpha: 0.3)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: medalColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${deliveries.round()}件配送 • ${rating.toStringAsFixed(1)}★',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '詳細メトリクス',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildMetricRow('総配送件数', '1,234件'),
            _buildMetricRow('平均配送時間', '45分'),
            _buildMetricRow('顧客満足度', '4.3/5.0'),
            _buildMetricRow('事故率', '0.1%'),
            _buildMetricRow('遅延率', '2.3%'),
            _buildMetricRow('燃費効率', '12.5km/L'),
            _buildMetricRow('稼働時間/日', '8.2時間'),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceChart() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '月別パフォーマンス推移',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              child: CustomScrollView(
                scrollDirection: Axis.horizontal,
                slivers: [
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildChartBar(
                        month: index + 1,
                        value: (index + 1) * 20 + (index % 3) * 10,
                        maxValue: 100,
                      ),
                      childCount: 12,
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

  Widget _buildChartBar(
      {required int month, required double value, required double maxValue}) {
    final percentage = value / maxValue;
    return Container(
      width: 60,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: 30,
                height: 150 * percentage,
                decoration: BoxDecoration(
                  color: Colors.green.shade400,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${month}月',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildScheduleOverview(),
          const SizedBox(height: 16),
          _buildScheduleCalendar(),
          const SizedBox(height: 16),
          _buildScheduledEvents(),
        ],
      ),
    );
  }

  Widget _buildScheduleOverview() {
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
                Icon(Icons.schedule, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text(
                  'スケジュール管理',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _showAddEventDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('予定追加'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildScheduleStatCard('今日の予定', '5件', Icons.today, Colors.blue),
                const SizedBox(width: 16),
                _buildScheduleStatCard(
                    '明日の予定', '8件', Icons.tomorrow, Colors.orange),
                const SizedBox(width: 16),
                _buildScheduleStatCard(
                    '今週の予定', '32件', Icons.date_range, Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleStatCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCalendar() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'カレンダー',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TableCalendar<String>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              eventLoader: _getEventsForDay,
              startingDayOfWeek: StartingDayOfWeek.monday,
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                weekendTextStyle: const TextStyle(color: Colors.red),
                holidayTextStyle: const TextStyle(color: Colors.red),
                selectedDecoration: BoxDecoration(
                  color: Colors.green.shade400,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Colors.green.shade200,
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
                formatButtonShowsNext: false,
                formatButtonDecoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.all(Radius.circular(12.0)),
                ),
                formatButtonTextStyle: TextStyle(
                  color: Colors.white,
                ),
              ),
              onDaySelected: _onDaySelected,
              onFormatChanged: (format) {
                if (_calendarFormat != format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                }
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduledEvents() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedDay != null
                  ? '${_selectedDay!.month}月${_selectedDay!.day}日の予定'
                  : '今日の予定',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: _getScheduleStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      children: [
                        Icon(Icons.event_busy,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'この日の予定はありません',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildEventItem(doc.id, data);
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventItem(String eventId, Map<String, dynamic> data) {
    final title = data['title'] as String? ?? 'タイトルなし';
    final description = data['description'] as String? ?? '';
    final startTime = (data['startTime'] as Timestamp?)?.toDate();
    final endTime = (data['endTime'] as Timestamp?)?.toDate();
    final driverId = data['driverId'] as String?;
    final type = data['type'] as String? ?? 'general';

    Color typeColor = Colors.blue;
    IconData typeIcon = Icons.event;

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
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: typeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: typeColor.withValues(alpha: 0.3)),
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
                if (startTime != null || endTime != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        _formatEventTime(startTime, endTime),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
                if (driverId != null) ...[
                  const SizedBox(height: 4),
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('drivers')
                        .doc(driverId)
                        .get(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final driverData =
                            snapshot.data!.data() as Map<String, dynamic>;
                        final driverName =
                            driverData['name'] as String? ?? 'N/A';
                        return Row(
                          children: [
                            const Icon(Icons.person,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              driverName,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  _showEditEventDialog(eventId, data);
                  break;
                case 'delete':
                  _deleteEvent(eventId);
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
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete),
                  title: Text('削除'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // イベント関連のヘルパーメソッド
  List<String> _getEventsForDay(DateTime day) {
    // 実際のアプリではFirestoreからデータを取得
    // ここではサンプルデータを返す
    final events = <String>[];
    if (day.day % 3 == 0) events.add('配送予定');
    if (day.day % 5 == 0) events.add('メンテナンス');
    return events;
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
    }
  }

  Stream<QuerySnapshot> _getScheduleStream() {
    final selectedDate = _selectedDay ?? DateTime.now();
    final startOfDay =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return FirebaseFirestore.instance
        .collection('schedule_events')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('date')
        .orderBy('startTime')
        .snapshots();
  }

  String _formatEventTime(DateTime? startTime, DateTime? endTime) {
    if (startTime == null && endTime == null) return '';

    final format =
        '${startTime?.hour.toString().padLeft(2, '0') ?? ''}:${startTime?.minute.toString().padLeft(2, '0') ?? ''}';
    final endFormat = endTime != null
        ? ' - ${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}'
        : '';

    return '$format$endFormat';
  }

  // アクション関数の実装
  void _showAddDriverDialog() {
    showDialog(
      context: context,
      builder: (context) => const _DriverFormDialog(),
    );
  }

  void _showDriverDetails(String driverId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => _DriverDetailsDialog(
        driverId: driverId,
        data: data,
      ),
    );
  }

  void _showDriverStats() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ドライバー稼働状況'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatRow('総ドライバー数', '${_stats['totalDrivers'] ?? 0}人'),
            _buildStatRow('稼働中', '${_stats['activeDrivers'] ?? 0}人'),
            _buildStatRow('休憩中', '${_stats['restingDrivers'] ?? 0}人'),
            _buildStatRow('オフライン', '${_stats['offlineDrivers'] ?? 0}人'),
            _buildStatRow('稼働率', '${_stats['utilization'] ?? 0}%'),
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

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleDriverStatus(
      String driverId, String currentStatus) async {
    String newStatus;
    switch (currentStatus) {
      case '稼働中':
        newStatus = '休憩中';
        break;
      case '休憩中':
        newStatus = 'オフライン';
        break;
      default:
        newStatus = '稼働中';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ステータス変更'),
        content: Text('ドライバーのステータスを「$newStatus」に変更しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('変更'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('drivers')
            .doc(driverId)
            .update({
          'status': newStatus,
          'statusUpdatedAt': FieldValue.serverTimestamp(),
        });

        // 通知を送信
        await NotificationService.notifyStatusChange(
          driverId: driverId,
          newStatus: newStatus,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ステータスを「$newStatus」に変更しました'),
            backgroundColor: Colors.green,
          ),
        );

        _loadDriverStats();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 新機能: 選択モード関連
  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedDriverIds.clear();
      }
    });
  }

  void _toggleDriverSelection(String driverId) {
    setState(() {
      if (!_isSelectionMode) {
        _isSelectionMode = true;
      }

      if (_selectedDriverIds.contains(driverId)) {
        _selectedDriverIds.remove(driverId);
      } else {
        _selectedDriverIds.add(driverId);
      }

      if (_selectedDriverIds.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  void _cancelSelection() {
    setState(() {
      _isSelectionMode = false;
      _selectedDriverIds.clear();
    });
  }

  void _showBulkActionsForSelected() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_selectedDriverIds.length}人のドライバーを一括操作'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.work),
              title: const Text('全員を稼働中にする'),
              onTap: () => _bulkUpdateStatus('稼働中'),
            ),
            ListTile(
              leading: const Icon(Icons.pause),
              title: const Text('全員を休憩中にする'),
              onTap: () => _bulkUpdateStatus('休憩中'),
            ),
            ListTile(
              leading: const Icon(Icons.offline_bolt),
              title: const Text('全員をオフラインにする'),
              onTap: () => _bulkUpdateStatus('オフライン'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('選択したドライバーを削除'),
              onTap: () => _bulkDeleteDrivers(),
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

  Future<void> _bulkUpdateStatus(String newStatus) async {
    Navigator.pop(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('一括ステータス更新'),
        content: Text(
            '選択した${_selectedDriverIds.length}人のドライバーのステータスを「$newStatus」に変更しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('更新'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final batch = FirebaseFirestore.instance.batch();

        for (final driverId in _selectedDriverIds) {
          final docRef =
              FirebaseFirestore.instance.collection('drivers').doc(driverId);
          batch.update(docRef, {
            'status': newStatus,
            'statusUpdatedAt': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();

        // 通知を送信
        for (final driverId in _selectedDriverIds) {
          await NotificationService.notifyStatusChange(
            driverId: driverId,
            newStatus: newStatus,
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${_selectedDriverIds.length}人のステータスを「$newStatus」に更新しました'),
            backgroundColor: Colors.green,
          ),
        );

        _cancelSelection();
        _loadDriverStats();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _bulkDeleteDrivers() async {
    Navigator.pop(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ドライバー削除'),
        content: Text(
            '選択した${_selectedDriverIds.length}人のドライバーを削除しますか？\nこの操作は元に戻せません。'),
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

        for (final driverId in _selectedDriverIds) {
          final docRef =
              FirebaseFirestore.instance.collection('drivers').doc(driverId);
          batch.delete(docRef);
        }

        await batch.commit();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedDriverIds.length}人のドライバーを削除しました'),
            backgroundColor: Colors.green,
          ),
        );

        _cancelSelection();
        _loadDriverStats();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showBulkStatusUpdate() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('一括ステータス更新'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('全ドライバーのステータスを一括で変更します。'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.work, color: Colors.green),
              title: const Text('全員を稼働中にする'),
              onTap: () => _bulkUpdateAllDriversStatus('稼働中'),
            ),
            ListTile(
              leading: const Icon(Icons.pause, color: Colors.orange),
              title: const Text('全員を休憩中にする'),
              onTap: () => _bulkUpdateAllDriversStatus('休憩中'),
            ),
            ListTile(
              leading: const Icon(Icons.offline_bolt, color: Colors.grey),
              title: const Text('全員をオフラインにする'),
              onTap: () => _bulkUpdateAllDriversStatus('オフライン'),
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

  Future<void> _bulkUpdateAllDriversStatus(String newStatus) async {
    Navigator.pop(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('全ドライバー一括更新'),
        content: Text('全てのドライバーのステータスを「$newStatus」に変更しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('更新'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final driversSnapshot =
            await FirebaseFirestore.instance.collection('drivers').get();
        final batch = FirebaseFirestore.instance.batch();

        for (final doc in driversSnapshot.docs) {
          batch.update(doc.reference, {
            'status': newStatus,
            'statusUpdatedAt': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();

        // 全ドライバーに通知を送信
        for (final doc in driversSnapshot.docs) {
          await NotificationService.notifyStatusChange(
            driverId: doc.id,
            newStatus: newStatus,
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '全ドライバー（${driversSnapshot.docs.length}人）のステータスを「$newStatus」に更新しました'),
            backgroundColor: Colors.green,
          ),
        );

        _loadDriverStats();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showBulkActions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('一括操作'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.update),
              title: const Text('全員ステータス更新'),
              subtitle: const Text('全ドライバーのステータスを一括変更'),
              onTap: () {
                Navigator.pop(context);
                _showBulkStatusUpdate();
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('一括通知送信'),
              subtitle: const Text('全ドライバーに通知を送信'),
              onTap: () {
                Navigator.pop(context);
                _showBulkNotificationDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment),
              title: const Text('一括配送割り当て'),
              subtitle: const Text('複数の配送を一括で割り当て'),
              onTap: () {
                Navigator.pop(context);
                _showBulkAssignmentDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_download),
              title: const Text('レポート出力'),
              subtitle: const Text('ドライバー情報をレポート形式で出力'),
              onTap: () {
                Navigator.pop(context);
                _exportDriverReport();
              },
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

  void _showBulkNotificationDialog() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    String selectedType = 'info';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('一括通知送信'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: '通知タイプ',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'info', child: Text('情報')),
                    DropdownMenuItem(value: 'warning', child: Text('警告')),
                    DropdownMenuItem(value: 'urgent', child: Text('緊急')),
                    DropdownMenuItem(
                        value: 'maintenance', child: Text('メンテナンス')),
                  ],
                  onChanged: (value) => setState(() => selectedType = value!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'タイトル',
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'メッセージ',
                    prefixIcon: Icon(Icons.message),
                  ),
                  maxLines: 3,
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
                if (titleController.text.isNotEmpty &&
                    messageController.text.isNotEmpty) {
                  Navigator.pop(context);
                  _sendBulkNotification(
                    titleController.text,
                    messageController.text,
                    selectedType,
                  );
                }
              },
              child: const Text('送信'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendBulkNotification(
      String title, String message, String type) async {
    try {
      await NotificationService.notifyAllDrivers(
        title: title,
        message: message,
        type: type,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('全ドライバーに通知を送信しました'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('通知送信エラー: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showBulkAssignmentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('一括配送割り当て'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('未割り当ての配送を稼働中のドライバーに自動で割り当てます。'),
            SizedBox(height: 16),
            Text('割り当て条件：'),
            Text('• 稼働中のドライバー'),
            Text('• 現在の担当件数が10件未満'),
            Text('• 評価3.0以上'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performBulkAssignment();
            },
            child: const Text('実行'),
          ),
        ],
      ),
    );
  }

  Future<void> _performBulkAssignment() async {
    try {
      // 未割り当ての配送を取得
      final unassignedDeliveries = await FirebaseFirestore.instance
          .collection('deliveries')
          .where('status', isEqualTo: 'pending')
          .where('driverId', isNull: true)
          .get();

      // 条件に合うドライバーを取得
      final eligibleDrivers = await FirebaseFirestore.instance
          .collection('drivers')
          .where('status', isEqualTo: '稼働中')
          .where('currentDeliveries', isLessThan: 10)
          .where('rating', isGreaterThanOrEqualTo: 3.0)
          .get();

      if (unassignedDeliveries.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('未割り当ての配送がありません'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (eligibleDrivers.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('条件に合うドライバーがいません'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      int assignmentCount = 0;
      int driverIndex = 0;

      for (final delivery in unassignedDeliveries.docs) {
        if (driverIndex >= eligibleDrivers.docs.length) {
          driverIndex = 0; // ラウンドロビン
        }

        final driver = eligibleDrivers.docs[driverIndex];
        final driverId = driver.id;
        final deliveryId = delivery.id;

        // 配送にドライバーを割り当て
        batch.update(delivery.reference, {
          'driverId': driverId,
          'status': 'assigned',
          'assignedAt': FieldValue.serverTimestamp(),
        });

        // ドライバーの担当件数を更新
        final currentDeliveries =
            (driver.data()['currentDeliveries'] as num? ?? 0) + 1;
        batch.update(driver.reference, {
          'currentDeliveries': currentDeliveries,
        });

        // 通知を送信
        await NotificationService.notifyDeliveryAssigned(
          driverId: driverId,
          deliveryId: deliveryId,
          pickupLocation: delivery.data()['pickupLocation'] as String? ?? '',
          deliveryLocation:
              delivery.data()['deliveryLocation'] as String? ?? '',
        );

        assignmentCount++;
        driverIndex++;
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '$assignmentCount件の配送を${eligibleDrivers.docs.length}人のドライバーに割り当てました'),
          backgroundColor: Colors.green,
        ),
      );

      _loadDriverStats();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('一括割り当てエラー: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // CSV出力/取り込み機能
  Future<void> _exportDriverData() async {
    try {
      final driversSnapshot =
          await FirebaseFirestore.instance.collection('drivers').get();

      if (driversSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('エクスポートするドライバーデータがありません'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final csvData = <List<dynamic>>[];

      // ヘッダー行
      csvData.add([
        'ID',
        '氏名',
        '電話番号',
        'メールアドレス',
        '車両',
        '免許番号',
        'ステータス',
        '評価',
        '担当案件数',
        '登録日',
        '最終ステータス更新',
      ]);

      // データ行
      for (final doc in driversSnapshot.docs) {
        final data = doc.data();
        csvData.add([
          doc.id,
          data['name'] ?? '',
          data['phone'] ?? '',
          data['email'] ?? '',
          data['vehicle'] ?? '',
          data['license'] ?? '',
          data['status'] ?? '',
          data['rating'] ?? 0,
          data['currentDeliveries'] ?? 0,
          data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate().toString()
              : '',
          data['statusUpdatedAt'] != null
              ? (data['statusUpdatedAt'] as Timestamp).toDate().toString()
              : '',
        ]);
      }

      final csvString = const ListToCsvConverter().convert(csvData);

      // ファイルを保存
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'drivers_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csvString, encoding: utf8);

      // ファイルを共有
      await Share.shareXFiles([XFile(file.path)], text: 'ドライバーデータ');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${driversSnapshot.docs.length}件のドライバーデータをエクスポートしました'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('エクスポートエラー: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportDriverReport() async {
    try {
      final driversSnapshot =
          await FirebaseFirestore.instance.collection('drivers').get();
      final deliveriesSnapshot =
          await FirebaseFirestore.instance.collection('deliveries').get();

      // 統計データを計算
      final totalDrivers = driversSnapshot.docs.length;
      final activeDrivers =
          driversSnapshot.docs.where((d) => d.data()['status'] == '稼働中').length;
      final avgRating = driversSnapshot.docs.isEmpty
          ? 0.0
          : driversSnapshot.docs
                  .map((d) => (d.data()['rating'] as num? ?? 0).toDouble())
                  .reduce((a, b) => a + b) /
              totalDrivers;

      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayDeliveries = deliveriesSnapshot.docs.where((d) {
        final completedAt = (d.data()['completedAt'] as Timestamp?)?.toDate();
        return completedAt != null && completedAt.isAfter(todayStart);
      }).length;

      final reportData = <List<dynamic>>[];

      // レポートヘッダー
      reportData.add(['ドライバー管理レポート']);
      reportData.add(['生成日時', DateTime.now().toString()]);
      reportData.add([]);

      // サマリー
      reportData.add(['=== サマリー ===']);
      reportData.add(['総ドライバー数', totalDrivers]);
      reportData.add(['稼働中ドライバー数', activeDrivers]);
      reportData.add([
        '稼働率',
        '${totalDrivers > 0 ? ((activeDrivers / totalDrivers) * 100).round() : 0}%'
      ]);
      reportData.add(['平均評価', avgRating.toStringAsFixed(2)]);
      reportData.add(['今日の配送件数', todayDeliveries]);
      reportData.add([]);

      // ドライバー詳細
      reportData.add(['=== ドライバー詳細 ===']);
      reportData.add([
        'ID',
        '氏名',
        'ステータス',
        '評価',
        '担当案件数',
        '入社日',
      ]);

      for (final doc in driversSnapshot.docs) {
        final data = doc.data();
        reportData.add([
          doc.id.substring(0, 8),
          data['name'] ?? '',
          data['status'] ?? '',
          (data['rating'] as num? ?? 0).toStringAsFixed(1),
          data['currentDeliveries'] ?? 0,
          data['createdAt'] != null
              ? _formatDate((data['createdAt'] as Timestamp).toDate())
              : '',
        ]);
      }

      final csvString = const ListToCsvConverter().convert(reportData);

      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'driver_report_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csvString, encoding: utf8);

      await Share.shareXFiles([XFile(file.path)], text: 'ドライバー管理レポート');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ドライバー管理レポートを生成しました'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('レポート生成エラー: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _importDriverData() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.single.path == null) {
        return;
      }

      final file = File(result.files.single.path!);
      final csvString = await file.readAsString(encoding: utf8);
      final csvData = const CsvToListConverter().convert(csvString);

      if (csvData.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSVファイルが空またはヘッダーのみです'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('CSV取り込み確認'),
          content: Text(
              '${csvData.length - 1}件のドライバーデータを取り込みますか？\n既存のデータと重複する場合は更新されます。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('取り込み'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      final headers =
          csvData[0].map((e) => e.toString().toLowerCase()).toList();
      final batch = FirebaseFirestore.instance.batch();
      int importCount = 0;

      for (int i = 1; i < csvData.length; i++) {
        final row = csvData[i];
        if (row.length < headers.length) continue;

        final driverData = <String, dynamic>{};

        for (int j = 0; j < headers.length && j < row.length; j++) {
          final header = headers[j];
          final value = row[j]?.toString().trim() ?? '';

          switch (header) {
            case 'name' || '氏名':
              if (value.isNotEmpty) driverData['name'] = value;
              break;
            case 'phone' || '電話番号':
              if (value.isNotEmpty) driverData['phone'] = value;
              break;
            case 'email' || 'メールアドレス':
              if (value.isNotEmpty) driverData['email'] = value;
              break;
            case 'vehicle' || '車両':
              if (value.isNotEmpty) driverData['vehicle'] = value;
              break;
            case 'license' || '免許番号':
              if (value.isNotEmpty) driverData['license'] = value;
              break;
            case 'status' || 'ステータス':
              if (['稼働中', '休憩中', 'オフライン'].contains(value)) {
                driverData['status'] = value;
              }
              break;
            case 'rating' || '評価':
              final rating = double.tryParse(value);
              if (rating != null && rating >= 0 && rating <= 5) {
                driverData['rating'] = rating;
              }
              break;
          }
        }

        if (driverData['name'] != null && driverData['phone'] != null) {
          driverData.addAll({
            'currentDeliveries': 0,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // デフォルト値を設定
          driverData['status'] ??= 'オフライン';
          driverData['rating'] ??= 5.0;

          final docRef = FirebaseFirestore.instance.collection('drivers').doc();
          batch.set(docRef, driverData);
          importCount++;
        }
      }

      if (importCount > 0) {
        await batch.commit();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${importCount}件のドライバーデータを取り込みました'),
            backgroundColor: Colors.green,
          ),
        );

        _loadDriverStats();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('有効なデータがありませんでした'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('取り込みエラー: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // フィルター機能の実装
  void _filterByNew() {
    setState(() {
      _activeFilter = _activeFilter == 'new' ? '' : 'new';
    });
  }

  void _filterByVeteran() {
    setState(() {
      _activeFilter = _activeFilter == 'veteran' ? '' : 'veteran';
    });
  }

  void _filterByHighRating() {
    setState(() {
      _activeFilter = _activeFilter == 'high_rating' ? '' : 'high_rating';
    });
  }

  void _filterByAlert() {
    setState(() {
      _activeFilter = _activeFilter == 'alert' ? '' : 'alert';
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedStatus = 'すべて';
      _searchQuery = '';
      _activeFilter = '';
      _searchController.clear();
    });
  }

  // スケジュール機能
  void _showAddEventDialog() {
    showDialog(
      context: context,
      builder: (context) => _ScheduleEventDialog(selectedDate: _selectedDay),
    );
  }

  void _showEditEventDialog(String eventId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => _ScheduleEventDialog(
        eventId: eventId,
        initialData: data,
        selectedDate: _selectedDay,
      ),
    );
  }

  Future<void> _deleteEvent(String eventId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('予定削除'),
        content: const Text('この予定を削除しますか？'),
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
            .collection('schedule_events')
            .doc(eventId)
            .delete();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('予定を削除しました'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('削除エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

  String _getStatusToggleText(String status) {
    switch (status) {
      case '稼働中':
        return '休憩';
      case '休憩中':
        return 'オフライン';
      default:
        return '稼働開始';
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

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }
}

// ドライバー登録・編集フォーム
class _DriverFormDialog extends StatefulWidget {
  final String? driverId;
  final Map<String, dynamic>? initialData;

  const _DriverFormDialog({
    this.driverId,
    this.initialData,
  });

  @override
  State<_DriverFormDialog> createState() => _DriverFormDialogState();
}

class _DriverFormDialogState extends State<_DriverFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _vehicleController = TextEditingController();
  final _licenseController = TextEditingController();

  String _status = '稼働中';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final data = widget.initialData!;
      _nameController.text = data['name'] as String? ?? '';
      _phoneController.text = data['phone'] as String? ?? '';
      _emailController.text = data['email'] as String? ?? '';
      _vehicleController.text = data['vehicle'] as String? ?? '';
      _licenseController.text = data['license'] as String? ?? '';
      _status = data['status'] as String? ?? '稼働中';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _vehicleController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.driverId == null ? '新規ドライバー登録' : 'ドライバー情報編集'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '氏名 *',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) =>
                      value?.isEmpty == true ? '必須項目です' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: '電話番号 *',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) =>
                      value?.isEmpty == true ? '必須項目です' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'メールアドレス',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _vehicleController,
                        decoration: const InputDecoration(
                          labelText: '車両',
                          prefixIcon: Icon(Icons.directions_car),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _licenseController,
                        decoration: const InputDecoration(
                          labelText: '免許番号',
                          prefixIcon: Icon(Icons.credit_card),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(
                    labelText: 'ステータス',
                    prefixIcon: Icon(Icons.work),
                  ),
                  items: const [
                    DropdownMenuItem(value: '稼働中', child: Text('稼働中')),
                    DropdownMenuItem(value: '休憩中', child: Text('休憩中')),
                    DropdownMenuItem(value: 'オフライン', child: Text('オフライン')),
                  ],
                  onChanged: (value) => setState(() => _status = value!),
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
          onPressed: _isLoading ? null : _saveDriver,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.driverId == null ? '登録' : '更新'),
        ),
      ],
    );
  }

  Future<void> _saveDriver() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'vehicle': _vehicleController.text.trim(),
        'license': _licenseController.text.trim(),
        'status': _status,
        'rating': 5.0,
        'currentDeliveries': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.driverId == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('drivers').add(data);

        // 新規登録通知
        await NotificationService.notifyDriverRegistered(
          driverName: _nameController.text.trim(),
        );
      } else {
        await FirebaseFirestore.instance
            .collection('drivers')
            .doc(widget.driverId)
            .update(data);
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(widget.driverId == null ? 'ドライバーを登録しました' : 'ドライバー情報を更新しました'),
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
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

// ドライバー詳細ダイアログ
class _DriverDetailsDialog extends StatelessWidget {
  final String driverId;
  final Map<String, dynamic> data;

  const _DriverDetailsDialog({
    required this.driverId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ドライバー詳細'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('ID', driverId.substring(0, 8)),
              _buildDetailRow('氏名', data['name'] as String? ?? 'N/A'),
              _buildDetailRow('電話番号', data['phone'] as String? ?? 'N/A'),
              _buildDetailRow('メール', data['email'] as String? ?? 'N/A'),
              _buildDetailRow('車両', data['vehicle'] as String? ?? 'N/A'),
              _buildDetailRow('免許番号', data['license'] as String? ?? 'N/A'),
              _buildDetailRow('ステータス', data['status'] as String? ?? 'N/A'),
              _buildDetailRow(
                  '評価', '${(data['rating'] as num? ?? 0).toStringAsFixed(1)}★'),
              _buildDetailRow('担当案件数',
                  '${(data['currentDeliveries'] as num? ?? 0).round()}件'),
              if (data['createdAt'] != null)
                _buildDetailRow(
                    '登録日', _formatTimestamp(data['createdAt'] as Timestamp)),
              if (data['statusUpdatedAt'] != null)
                _buildDetailRow('ステータス更新',
                    _formatTimestamp(data['statusUpdatedAt'] as Timestamp)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('閉じる'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            showDialog(
              context: context,
              builder: (context) => _DriverFormDialog(
                driverId: driverId,
                initialData: data,
              ),
            );
          },
          child: const Text('編集'),
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

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.year}/${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// スケジュールイベントダイアログ
class _ScheduleEventDialog extends StatefulWidget {
  final String? eventId;
  final Map<String, dynamic>? initialData;
  final DateTime? selectedDate;

  const _ScheduleEventDialog({
    this.eventId,
    this.initialData,
    this.selectedDate,
  });

  @override
  State<_ScheduleEventDialog> createState() => _ScheduleEventDialogState();
}

class _ScheduleEventDialogState extends State<_ScheduleEventDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _type = 'general';
  String? _selectedDriverId;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = TimeOfDay.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    if (widget.selectedDate != null) {
      _selectedDate = widget.selectedDate!;
    }

    if (widget.initialData != null) {
      final data = widget.initialData!;
      _titleController.text = data['title'] as String? ?? '';
      _descriptionController.text = data['description'] as String? ?? '';
      _type = data['type'] as String? ?? 'general';
      _selectedDriverId = data['driverId'] as String?;

      if (data['date'] != null) {
        _selectedDate = (data['date'] as Timestamp).toDate();
      }
      if (data['startTime'] != null) {
        final startDateTime = (data['startTime'] as Timestamp).toDate();
        _startTime = TimeOfDay.fromDateTime(startDateTime);
      }
      if (data['endTime'] != null) {
        final endDateTime = (data['endTime'] as Timestamp).toDate();
        _endTime = TimeOfDay.fromDateTime(endDateTime);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.eventId == null ? '予定追加' : '予定編集'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'タイトル *',
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (value) =>
                      value?.isEmpty == true ? '必須項目です' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _type,
                  decoration: const InputDecoration(
                    labelText: 'タイプ',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'general', child: Text('一般')),
                    DropdownMenuItem(value: 'delivery', child: Text('配送')),
                    DropdownMenuItem(
                        value: 'maintenance', child: Text('メンテナンス')),
                    DropdownMenuItem(value: 'break', child: Text('休憩')),
                    DropdownMenuItem(value: 'training', child: Text('研修')),
                  ],
                  onChanged: (value) => setState(() => _type = value!),
                ),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('drivers')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }

                    return DropdownButtonFormField<String>(
                      value: _selectedDriverId,
                      decoration: const InputDecoration(
                        labelText: 'ドライバー（任意）',
                        prefixIcon: Icon(Icons.person),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('選択なし'),
                        ),
                        ...snapshot.data!.docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(data['name'] as String? ?? 'N/A'),
                          );
                        }),
                      ],
                      onChanged: (value) =>
                          setState(() => _selectedDriverId = value),
                    );
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('日付'),
                  subtitle: Text(
                      '${_selectedDate.year}/${_selectedDate.month}/${_selectedDate.day}'),
                  onTap: _selectDate,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        leading: const Icon(Icons.access_time),
                        title: const Text('開始時刻'),
                        subtitle: Text(_startTime.format(context)),
                        onTap: () => _selectTime(true),
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        leading: const Icon(Icons.access_time_filled),
                        title: const Text('終了時刻'),
                        subtitle: Text(_endTime.format(context)),
                        onTap: () => _selectTime(false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: '説明',
                    prefixIcon: Icon(Icons.description),
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
          onPressed: _isLoading ? null : _saveEvent,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.eventId == null ? '追加' : '更新'),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime(bool isStartTime) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _startTime : _endTime,
    );

    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final startDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startTime.hour,
        _startTime.minute,
      );

      final endDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _endTime.hour,
        _endTime.minute,
      );

      final eventData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'type': _type,
        'driverId': _selectedDriverId,
        'date': Timestamp.fromDate(_selectedDate),
        'startTime': Timestamp.fromDate(startDateTime),
        'endTime': Timestamp.fromDate(endDateTime),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.eventId == null) {
        eventData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('schedule_events')
            .add(eventData);
      } else {
        await FirebaseFirestore.instance
            .collection('schedule_events')
            .doc(widget.eventId)
            .update(eventData);
      }

      // ドライバーが選択されている場合は通知を送信
      if (_selectedDriverId != null) {
        await NotificationService.notifyScheduleEvent(
          driverId: _selectedDriverId!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          eventTime: startDateTime,
        );
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.eventId == null ? '予定を追加しました' : '予定を更新しました'),
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
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

// 完全実装版 NotificationService
class NotificationService {
  static Future<void> notifyAllAdmins({
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      // 管理者全員に通知を送信
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': title,
        'message': message,
        'type': type,
        'targetType': 'admin',
        'data': data ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      print('Admin notification error: $e');
    }
  }

  static Future<void> notifyAllDrivers({
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      // 全ドライバーに通知を送信
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': title,
        'message': message,
        'type': type,
        'targetType': 'all_drivers',
        'data': data ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      print('Driver notification error: $e');
    }
  }

  static Future<void> notifyDeliveryAssigned({
    required String driverId,
    required String deliveryId,
    required String pickupLocation,
    required String deliveryLocation,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': '新しい配送が割り当てられました',
        'message': '$pickupLocation から $deliveryLocation への配送',
        'type': 'delivery_assigned',
        'targetType': 'driver',
        'targetId': driverId,
        'data': {
          'deliveryId': deliveryId,
          'pickupLocation': pickupLocation,
          'deliveryLocation': deliveryLocation,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      print('Delivery assignment notification error: $e');
    }
  }

  static Future<void> notifyStatusChange({
    required String driverId,
    required String newStatus,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': 'ステータス変更',
        'message': 'あなたのステータスが「$newStatus」に変更されました',
        'type': 'status_change',
        'targetType': 'driver',
        'targetId': driverId,
        'data': {
          'newStatus': newStatus,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      print('Status change notification error: $e');
    }
  }

  static Future<void> notifyDriverRegistered({
    required String driverName,
  }) async {
    try {
      await notifyAllAdmins(
        title: '新しいドライバーが登録されました',
        message: '$driverName さんが新規登録されました',
        type: 'driver_registered',
        data: {'driverName': driverName},
      );
    } catch (e) {
      print('Driver registration notification error: $e');
    }
  }

  static Future<void> notifyScheduleEvent({
    required String driverId,
    required String title,
    required String description,
    required DateTime eventTime,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': '新しい予定: $title',
        'message': description.isNotEmpty ? description : '予定が追加されました',
        'type': 'schedule_event',
        'targetType': 'driver',
        'targetId': driverId,
        'data': {
          'eventTitle': title,
          'eventTime': Timestamp.fromDate(eventTime),
        },
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      print('Schedule event notification error: $e');
    }
  }
}
