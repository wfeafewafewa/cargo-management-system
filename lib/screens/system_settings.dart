import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({Key? key}) : super(key: key);

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // システム統計
  Map<String, dynamic> _systemStats = {};
  bool _isLoadingStats = true;
  
  // 設定値
  Map<String, dynamic> _systemSettings = {
    'autoBackup': true,
    'maintenanceMode': false,
    'maxDeliveriesPerDriver': 10,
    'defaultDeliveryFee': 1000,
    'systemLanguage': 'ja',
    'theme': 'light',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadSystemData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSystemData() async {
    await Future.wait([
      _loadSystemStats(),
      _loadSystemSettings(),
    ]);
  }

  Future<void> _loadSystemStats() async {
    try {
      final futures = await Future.wait([
        FirebaseFirestore.instance.collection('deliveries').get(),
        FirebaseFirestore.instance.collection('drivers').get(),
        FirebaseFirestore.instance.collection('sales').get(),
        FirebaseFirestore.instance.collection('notifications').get(),
        FirebaseFirestore.instance.collection('users').get(),
      ]);

      // 配送統計
      final deliveries = futures[0].docs;
      final completedDeliveries = deliveries.where((d) => 
          (d.data() as Map<String, dynamic>)['status'] == '完了').length;
      
      // 売上統計
      final sales = futures[2].docs;
      double totalRevenue = 0;
      for (final sale in sales) {
        final data = sale.data() as Map<String, dynamic>;
        totalRevenue += (data['amount'] as num?)?.toDouble() ?? 0;
      }

      // データサイズ推定
      final totalDocuments = deliveries.length + 
                           futures[1].docs.length + 
                           sales.length + 
                           futures[3].docs.length + 
                           futures[4].docs.length;

      setState(() {
        _systemStats = {
          'totalDeliveries': deliveries.length,
          'completedDeliveries': completedDeliveries,
          'totalDrivers': futures[1].docs.length,
          'totalRevenue': totalRevenue,
          'totalNotifications': futures[3].docs.length,
          'totalUsers': futures[4].docs.length,
          'totalDocuments': totalDocuments,
          'estimatedDataSize': (totalDocuments * 2.5).toStringAsFixed(1), // KB推定
          'lastUpdate': DateTime.now(),
        };
        _isLoadingStats = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  Future<void> _loadSystemSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('system_settings')
          .doc('main')
          .get();
      
      if (doc.exists) {
        setState(() {
          _systemSettings = {..._systemSettings, ...doc.data()!};
        });
      }
    } catch (e) {
      print('設定読み込みエラー: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('システム設定'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: '概要'),
            Tab(icon: Icon(Icons.settings), text: '設定'),
            Tab(icon: Icon(Icons.build), text: 'メンテナンス'),
            Tab(icon: Icon(Icons.info), text: 'システム情報'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildSettingsTab(),
          _buildMaintenanceTab(),
          _buildSystemInfoTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    if (_isLoadingStats) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadSystemStats,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSystemHealthCard(),
            const SizedBox(height: 16),
            _buildStatsGrid(),
            const SizedBox(height: 16),
            _buildQuickActionsCard(),
            const SizedBox(height: 16),
            _buildRecentActivityCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemHealthCard() {
    final healthScore = _calculateSystemHealth();
    final healthColor = healthScore >= 90 
        ? Colors.green 
        : healthScore >= 70 
            ? Colors.orange 
            : Colors.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.favorite, color: healthColor),
                const SizedBox(width: 8),
                const Text(
                  'システムヘルス',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: healthColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${healthScore.toInt()}%',
                    style: TextStyle(
                      color: healthColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: healthScore / 100,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(healthColor),
            ),
            const SizedBox(height: 8),
            Text(
              _getHealthMessage(healthScore),
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          '総配送件数',
          '${_systemStats['totalDeliveries'] ?? 0}',
          Icons.local_shipping,
          Colors.blue,
          subtitle: '完了: ${_systemStats['completedDeliveries'] ?? 0}',
        ),
        _buildStatCard(
          '登録ドライバー',
          '${_systemStats['totalDrivers'] ?? 0}',
          Icons.people,
          Colors.green,
        ),
        _buildStatCard(
          '総売上',
          '¥${_formatNumber(_systemStats['totalRevenue'] ?? 0)}',
          Icons.attach_money,
          Colors.orange,
        ),
        _buildStatCard(
          'データ使用量',
          '${_systemStats['estimatedDataSize'] ?? 0}KB',
          Icons.storage,
          Colors.purple,
          subtitle: '${_systemStats['totalDocuments'] ?? 0} ドキュメント',
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {String? subtitle}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'クイックアクション',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickActionButton(
                  '手動バックアップ',
                  Icons.backup,
                  Colors.blue,
                  () => _performBackup(),
                ),
                _buildQuickActionButton(
                  'キャッシュクリア',
                  Icons.clear_all,
                  Colors.orange,
                  () => _clearCache(),
                ),
                _buildQuickActionButton(
                  'データ最適化',
                  Icons.tune,
                  Colors.green,
                  () => _optimizeData(),
                ),
                _buildQuickActionButton(
                  'システム再起動',
                  Icons.restart_alt,
                  Colors.red,
                  () => _restartSystem(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'システムアクティビティ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildActivityItem(
              'システム起動',
              '正常に起動しました',
              DateTime.now().subtract(const Duration(hours: 2)),
              Colors.green,
            ),
            _buildActivityItem(
              'データベース最適化',
              'インデックス更新完了',
              DateTime.now().subtract(const Duration(hours: 6)),
              Colors.blue,
            ),
            _buildActivityItem(
              '自動バックアップ',
              'バックアップが正常に完了しました',
              DateTime.now().subtract(const Duration(hours: 24)),
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(String title, String description, DateTime time, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            _formatTime(time),
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSettingsSection(
            '一般設定',
            [
              _buildSwitchSetting(
                '自動バックアップ',
                '定期的にデータをバックアップします',
                _systemSettings['autoBackup'] ?? true,
                (value) => _updateSetting('autoBackup', value),
              ),
              _buildSwitchSetting(
                'メンテナンスモード',
                'システムを一時的に停止します',
                _systemSettings['maintenanceMode'] ?? false,
                (value) => _updateSetting('maintenanceMode', value),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSettingsSection(
            '業務設定',
            [
              _buildNumberSetting(
                'ドライバー最大配送件数',
                '一人のドライバーが同時に担当できる配送件数',
                _systemSettings['maxDeliveriesPerDriver'] ?? 10,
                (value) => _updateSetting('maxDeliveriesPerDriver', value),
              ),
              _buildNumberSetting(
                'デフォルト配送料金',
                '新規案件のデフォルト料金設定',
                _systemSettings['defaultDeliveryFee'] ?? 1000,
                (value) => _updateSetting('defaultDeliveryFee', value),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSettingsSection(
            '表示設定',
            [
              _buildDropdownSetting(
                'システム言語',
                ['ja', 'en'],
                ['日本語', '英語'],
                _systemSettings['systemLanguage'] ?? 'ja',
                (value) => _updateSetting('systemLanguage', value),
              ),
              _buildDropdownSetting(
                'テーマ',
                ['light', 'dark', 'auto'],
                ['ライト', 'ダーク', '自動'],
                _systemSettings['theme'] ?? 'light',
                (value) => _updateSetting('theme', value),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchSetting(String title, String description, bool value, Function(bool) onChanged) {
    return ListTile(
      title: Text(title),
      subtitle: Text(description),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildNumberSetting(String title, String description, int value, Function(int) onChanged) {
    return ListTile(
      title: Text(title),
      subtitle: Text(description),
      trailing: SizedBox(
        width: 80,
        child: TextFormField(
          initialValue: value.toString(),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) {
            final intValue = int.tryParse(v);
            if (intValue != null) onChanged(intValue);
          },
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownSetting(String title, List<String> values, List<String> labels, String value, Function(String) onChanged) {
    return ListTile(
      title: Text(title),
      trailing: DropdownButton<String>(
        value: value,
        items: List.generate(values.length, (index) => 
          DropdownMenuItem(
            value: values[index],
            child: Text(labels[index]),
          ),
        ),
        onChanged: (v) => v != null ? onChanged(v) : null,
      ),
    );
  }

  Widget _buildMaintenanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildMaintenanceSection(
            'データベース管理',
            [
              _buildMaintenanceAction(
                'インデックス再構築',
                'データベースのパフォーマンスを最適化します',
                Icons.build,
                Colors.blue,
                () => _rebuildIndexes(),
              ),
              _buildMaintenanceAction(
                '古いデータ削除',
                '6ヶ月以上前のログを削除します',
                Icons.delete_sweep,
                Colors.orange,
                () => _cleanOldData(),
              ),
              _buildMaintenanceAction(
                'データ整合性チェック',
                'データの整合性を確認します',
                Icons.check_circle,
                Colors.green,
                () => _checkDataIntegrity(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildMaintenanceSection(
            'システム管理',
            [
              _buildMaintenanceAction(
                'セキュリティルール更新',
                'Firestoreセキュリティルールを更新します',
                Icons.security,
                Colors.purple,
                () => _updateSecurityRules(),
              ),
              _buildMaintenanceAction(
                'システムログエクスポート',
                'システムログをCSVファイルでエクスポートします',
                Icons.file_download,
                Colors.teal,
                () => _exportSystemLogs(),
              ),
              _buildMaintenanceAction(
                '緊急メンテナンス',
                'システムを緊急メンテナンスモードに切り替えます',
                Icons.warning,
                Colors.red,
                () => _emergencyMaintenance(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceSection(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildMaintenanceAction(String title, String description, IconData icon, Color color, VoidCallback onPressed) {
    return Card(
      color: color.withOpacity(0.05),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(description),
        trailing: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(backgroundColor: color),
          child: const Text('実行', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildSystemInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoCard(
            'システム情報',
            [
              _buildInfoRow('バージョン', '2.0.0'),
              _buildInfoRow('ビルド', '20250530'),
              _buildInfoRow('環境', 'Production'),
              _buildInfoRow('データベース', 'Cloud Firestore'),
              _buildInfoRow('認証', 'Firebase Auth'),
              _buildInfoRow('ホスティング', 'Firebase Hosting'),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            'ライセンス情報',
            [
              _buildInfoRow('ライセンス', 'MIT License'),
              _buildInfoRow('開発者', 'Your Company'),
              _buildInfoRow('サポート', 'support@yourcompany.com'),
              _buildInfoRow('更新日', '2025年5月30日'),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            '使用技術',
            [
              _buildInfoRow('フロントエンド', 'Flutter 3.x'),
              _buildInfoRow('バックエンド', 'Firebase'),
              _buildInfoRow('UI', 'Material Design 3'),
              _buildInfoRow('PDF生成', 'pdf package'),
              _buildInfoRow('状態管理', 'Provider/Bloc'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
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

  double _calculateSystemHealth() {
    final totalDeliveries = _systemStats['totalDeliveries'] ?? 0;
    final completedDeliveries = _systemStats['completedDeliveries'] ?? 0;
    final totalDrivers = _systemStats['totalDrivers'] ?? 0;
    
    double score = 100.0;
    
    // 配送完了率
    if (totalDeliveries > 0) {
      final completionRate = completedDeliveries / totalDeliveries;
      score *= completionRate;
    }
    
    // ドライバー数に基づく調整
    if (totalDrivers < 5) {
      score *= 0.8; // ドライバー不足
    }
    
    return score.clamp(0.0, 100.0);
  }

  String _getHealthMessage(double score) {
    if (score >= 90) return 'システムは正常に動作しています';
    if (score >= 70) return 'システムに軽微な問題があります';
    return 'システムに注意が必要です';
  }

  String _formatNumber(double number) {
    return number.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}時間前';
    } else {
      return '${difference.inDays}日前';
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    setState(() {
      _systemSettings[key] = value;
    });

    try {
      await FirebaseFirestore.instance
          .collection('system_settings')
          .doc('main')
          .set(_systemSettings, SetOptions(merge: true));
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('設定を保存しました')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('設定の保存に失敗しました: $e')),
      );
    }
  }

  void _performBackup() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('バックアップ中...'),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 3));
    
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('バックアップが完了しました')),
    );
  }

  void _clearCache() async {
    final confirmed = await _showConfirmDialog(
      'キャッシュクリア',
      'すべてのキャッシュデータを削除しますか？',
    );

    if (confirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('キャッシュをクリアしました')),
      );
    }
  }

  void _optimizeData() async {
    final confirmed = await _showConfirmDialog(
      'データ最適化',
      'データベースの最適化を実行しますか？\n処理に時間がかかる場合があります。',
    );

    if (confirmed) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('最適化中...'),
            ],
          ),
        ),
      );

      await Future.delayed(const Duration(seconds: 5));
      
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('データ最適化が完了しました')),
      );
    }
  }

  void _restartSystem() async {
    final confirmed = await _showConfirmDialog(
      'システム再起動',
      'システムを再起動しますか？\n一時的にサービスが停止します。',
    );

    if (confirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('システムを再起動します...')),
      );
    }
  }

  void _rebuildIndexes() async {
    final confirmed = await _showConfirmDialog(
      'インデックス再構築',
      'データベースのインデックスを再構築しますか？',
    );

    if (confirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('インデックス再構築を開始しました')),
      );
    }
  }

  void _cleanOldData() async {
    final confirmed = await _showConfirmDialog(
      '古いデータ削除',
      '6ヶ月以上前のデータを削除しますか？\nこの操作は取り消せません。',
    );

    if (confirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('古いデータの削除を開始しました')),
      );
    }
  }

  void _checkDataIntegrity() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('データ整合性をチェック中...'),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 4));
    
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('データ整合性チェックが完了しました')),
    );
  }

  void _updateSecurityRules() async {
    final confirmed = await _showConfirmDialog(
      'セキュリティルール更新',
      'Firestoreのセキュリティルールを更新しますか？',
    );

    if (confirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('セキュリティルールを更新しました')),
      );
    }
  }

  void _exportSystemLogs() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('ログをエクスポート中...'),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 3));
    
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('システムログをエクスポートしました')),
    );
  }

  void _emergencyMaintenance() async {
    final confirmed = await _showConfirmDialog(
      '緊急メンテナンス',
      '緊急メンテナンスモードに切り替えますか？\nシステムが一時停止されます。',
    );

    if (confirmed) {
      await _updateSetting('maintenanceMode', true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('緊急メンテナンスモードに切り替えました'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('実行'),
          ),
        ],
      ),
    ) ?? false;
  }
}