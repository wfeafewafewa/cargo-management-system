import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _setupAnimations();
    _loadDriverStats();
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
            const Text('ドライバー管理'),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
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
                value: 'bulk_actions',
                child: ListTile(
                  leading: Icon(Icons.checklist),
                  title: Text('一括操作'),
                ),
              ),
            ],
          ),
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
      floatingActionButton: Column(
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
                _buildFilterChip('新規ドライバー', () => _filterByNew()),
                _buildFilterChip('ベテラン', () => _filterByVeteran()),
                _buildFilterChip('高評価', () => _filterByHighRating()),
                _buildFilterChip('要注意', () => _filterByAlert()),
                _buildFilterChip('フィルタークリア', () => _clearFilters()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label),
        onPressed: onTap,
        backgroundColor: Colors.green.shade50,
        side: BorderSide(color: Colors.green.shade200),
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
    if (_searchQuery.isEmpty) return docs;

    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (_safeString(data['name']) ?? '').toLowerCase();
      final phone = (_safeString(data['phone']) ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();

      return name.contains(query) || phone.contains(query);
    }).toList();
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

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isAlert ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isAlert
            ? const BorderSide(color: Colors.orange, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDriverDetails(driverId, data),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
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
                  if (isAlert)
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

  Widget _buildScheduleTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildScheduleOverview(),
          const SizedBox(height: 16),
          _buildScheduleCalendar(),
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
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'スケジュール機能は準備中です。\n今後のアップデートで追加予定です。',
              style: TextStyle(color: Colors.grey),
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
      child: Container(
        height: 300,
        padding: const EdgeInsets.all(20),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_today, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'カレンダー機能',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              Text(
                '（実装予定）',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // アクション関数
  void _showAddDriverDialog() {
    showDialog(
      context: context,
      builder: (context) => _DriverFormDialog(),
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

  void _showBulkStatusUpdate() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('一括ステータス更新'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('全ドライバーのステータスを一括で変更します。'),
            SizedBox(height: 16),
            Text('実装予定の機能です。'),
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

  void _showBulkActions() {
    _showComingSoon('一括操作');
  }

  void _exportDriverData() {
    _showComingSoon('CSV出力');
  }

  void _importDriverData() {
    _showComingSoon('CSV取り込み');
  }

  void _filterByNew() {
    _showComingSoon('新規ドライバーフィルター');
  }

  void _filterByVeteran() {
    _showComingSoon('ベテランフィルター');
  }

  void _filterByHighRating() {
    _showComingSoon('高評価フィルター');
  }

  void _filterByAlert() {
    _showComingSoon('要注意フィルター');
  }

  void _clearFilters() {
    setState(() {
      _selectedStatus = 'すべて';
      _searchQuery = '';
      _searchController.clear();
    });
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

// NotificationServiceのスタブ
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
