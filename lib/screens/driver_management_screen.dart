import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:html' as html;

class DriverManagementScreen extends StatefulWidget {
  const DriverManagementScreen({Key? key}) : super(key: key);

  @override
  State<DriverManagementScreen> createState() => _DriverManagementScreenState();
}

class _DriverManagementScreenState extends State<DriverManagementScreen>
    with TickerProviderStateMixin {
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
    _setupAnimations();
    _loadDriverStats();
  }

  @override
  void dispose() {
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

      final drivers = driversSnapshot.docs;
      final totalDrivers = drivers.length;
      final activeDrivers =
          drivers.where((d) => (d.data()['status'] as String?) == '稼働中').length;
      final restingDrivers =
          drivers.where((d) => (d.data()['status'] as String?) == '休憩中').length;
      final offlineDrivers = drivers
          .where((d) => (d.data()['status'] as String?) == 'オフライン')
          .length;

      setState(() {
        _stats = {
          'totalDrivers': totalDrivers,
          'activeDrivers': activeDrivers,
          'restingDrivers': restingDrivers,
          'offlineDrivers': offlineDrivers,
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
            onPressed: _loadDriverStats,
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            if (_isLoading)
              const LinearProgressIndicator()
            else
              _buildStatsBar(),
            _buildFilterSection(),
            Expanded(child: _buildDriverList()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDriverDialog,
        heroTag: "add_driver",
        icon: const Icon(Icons.person_add),
        label: const Text('新規ドライバー'),
        backgroundColor: Colors.green,
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
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value, Color color, IconData icon) {
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
          '$value',
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
    final email = _safeString(data['email']) ?? '';
    final adminMemo = _safeString(data['adminMemo']) ?? '';
    final joinDate = data['createdAt'] as Timestamp?;

    final statusColor = _getStatusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
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
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.email,
                                  size: 16, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  email,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
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

              if (adminMemo.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.note,
                              color: Colors.blue.shade700, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '管理者メモ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        adminMemo,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // 入社日
              if (joinDate != null)
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '入社: ${_formatDate(joinDate.toDate())}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
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
                      onPressed: () => _showEditDriverDialog(driverId, data),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('編集'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
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

  // アクション関数
  void _showAddDriverDialog() {
    showDialog(
      context: context,
      builder: (context) => const _DriverFormDialog(),
    );
  }

  void _showEditDriverDialog(String driverId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => _DriverFormDialog(
        driverId: driverId,
        initialData: data,
      ),
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

  void _clearFilters() {
    setState(() {
      _selectedStatus = 'すべて';
      _searchQuery = '';
      _searchController.clear();
    });
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

  String? _safeString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.isEmpty ? null : value;
    if (value is Map || value is List) return null;
    return value.toString();
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }
}

// 修正版ドライバー登録・編集フォーム（自賠責保険証書追加）
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

  // 基本情報項目
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _adminMemoController = TextEditingController();

  // 画像関連（自賠責保険証書を追加）
  Map<String, String> _uploadedImages = {
    'license': '', // 免許証
    'vehicleReg': '', // 車検証
    'insurance': '', // 自動車任意保険証書
    'compulsoryInsurance': '', // 自賠責保険証書（新規追加）
  };

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final data = widget.initialData!;
      _nameController.text = data['name'] as String? ?? '';
      _phoneController.text = data['phone'] as String? ?? '';
      _emailController.text = data['email'] as String? ?? '';
      _adminMemoController.text = data['adminMemo'] as String? ?? '';

      // 画像データの読み込み（自賠責保険証書を追加）
      _uploadedImages = {
        'license': data['licenseImage'] as String? ?? '',
        'vehicleReg': data['vehicleRegImage'] as String? ?? '',
        'insurance': data['insuranceImage'] as String? ?? '',
        'compulsoryInsurance':
            data['compulsoryInsuranceImage'] as String? ?? '',
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            widget.driverId == null ? Icons.person_add : Icons.edit,
            color: Colors.green.shade700,
          ),
          const SizedBox(width: 8),
          Text(widget.driverId == null ? '新規ドライバー登録' : 'ドライバー情報編集'),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 700, // 高さを少し増やす
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 基本情報セクション
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
                      Row(
                        children: [
                          Icon(Icons.person, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text(
                            '基本情報',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: '氏名 *',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
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
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) =>
                            value?.isEmpty == true ? '必須項目です' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'メールアドレス *',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) =>
                            value?.isEmpty == true ? '必須項目です' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _adminMemoController,
                        decoration: const InputDecoration(
                          labelText: '管理者メモ',
                          prefixIcon: Icon(Icons.note),
                          border: OutlineInputBorder(),
                          hintText: 'ドライバーに対するメモ・備考',
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 画像アップロードセクション（自賠責保険証書を追加）
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.file_upload, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Text(
                            '画像アップロード',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildImageUploadSection(
                        '免許証',
                        'license',
                        Icons.credit_card,
                        Colors.blue,
                      ),
                      const SizedBox(height: 16),
                      _buildImageUploadSection(
                        '車検証',
                        'vehicleReg',
                        Icons.directions_car,
                        Colors.orange,
                      ),
                      const SizedBox(height: 16),
                      _buildImageUploadSection(
                        '自動車任意保険証書',
                        'insurance',
                        Icons.security,
                        Colors.purple,
                      ),
                      const SizedBox(height: 16),
                      // 自賠責保険証書を追加
                      _buildImageUploadSection(
                        '自賠責保険証書',
                        'compulsoryInsurance',
                        Icons.verified_user,
                        Colors.red,
                      ),
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

  Widget _buildImageUploadSection(
    String title,
    String key,
    IconData icon,
    Color color,
  ) {
    final hasImage = _uploadedImages[key]?.isNotEmpty == true;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
        color: hasImage ? color.withValues(alpha: 0.05) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              if (hasImage) ...[
                const Spacer(),
                Icon(Icons.check_circle, color: Colors.green, size: 20),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _selectImage(key),
                  icon: Icon(hasImage ? Icons.edit : Icons.file_upload),
                  label: Text(hasImage ? '変更' : '選択'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              if (hasImage) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _removeImage(key),
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: '削除',
                ),
              ],
            ],
          ),
          if (hasImage) ...[
            const SizedBox(height: 8),
            Container(
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
                    'アップロード済み',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _selectImage(String key) async {
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
        _uploadedImages[key] = dataUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_getImageTitle(key)}をアップロードしました'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _removeImage(String key) {
    setState(() {
      _uploadedImages[key] = '';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_getImageTitle(key)}を削除しました'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  String _getImageTitle(String key) {
    switch (key) {
      case 'license':
        return '免許証';
      case 'vehicleReg':
        return '車検証';
      case 'insurance':
        return '自動車任意保険証書';
      case 'compulsoryInsurance':
        return '自賠責保険証書';
      default:
        return '画像';
    }
  }

  Future<void> _saveDriver() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'adminMemo': _adminMemoController.text.trim(),
        'licenseImage': _uploadedImages['license'] ?? '',
        'vehicleRegImage': _uploadedImages['vehicleReg'] ?? '',
        'insuranceImage': _uploadedImages['insurance'] ?? '',
        'compulsoryInsuranceImage':
            _uploadedImages['compulsoryInsurance'] ?? '', // 自賠責保険証書を追加
        'status': '稼働中', // デフォルトステータス
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

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _adminMemoController.dispose();
    super.dispose();
  }
}

// 修正版ドライバー詳細ダイアログ（自賠責保険証書追加）
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
      title: Row(
        children: [
          Icon(Icons.person, color: Colors.green.shade700),
          const SizedBox(width: 8),
          const Text('ドライバー詳細'),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 600,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 基本情報
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
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          '基本情報',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('氏名', data['name'] as String? ?? 'N/A'),
                    _buildDetailRow('電話番号', data['phone'] as String? ?? 'N/A'),
                    _buildDetailRow(
                        'メールアドレス', data['email'] as String? ?? 'N/A'),
                    _buildDetailRow(
                        'ステータス', data['status'] as String? ?? 'N/A'),
                    if (data['createdAt'] != null)
                      _buildDetailRow('登録日',
                          _formatTimestamp(data['createdAt'] as Timestamp)),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 管理者メモ
              if (data['adminMemo'] != null &&
                  (data['adminMemo'] as String).isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
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
                          Icon(Icons.note, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Text(
                            '管理者メモ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(data['adminMemo'] as String),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // アップロード済み画像（自賠責保険証書を追加）
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.file_present, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'アップロード済み書類',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildImageStatus('免許証', data['licenseImage'] as String?),
                    _buildImageStatus(
                        '車検証', data['vehicleRegImage'] as String?),
                    _buildImageStatus(
                        '自動車任意保険証書', data['insuranceImage'] as String?),
                    // 自賠責保険証書を追加
                    _buildImageStatus(
                        '自賠責保険証書', data['compulsoryInsuranceImage'] as String?),
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
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
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
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageStatus(String title, String? imageData) {
    final hasImage = imageData?.isNotEmpty == true;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            hasImage ? Icons.check_circle : Icons.cancel,
            color: hasImage ? Colors.green : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: hasImage ? Colors.black : Colors.grey,
            ),
          ),
          const Spacer(),
          Text(
            hasImage ? 'アップロード済み' : '未アップロード',
            style: TextStyle(
              fontSize: 12,
              color: hasImage ? Colors.green : Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.year}/${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
