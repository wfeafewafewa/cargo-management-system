// lib/screens/data_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/data_export_service.dart';
import '../services/firestore_service.dart';

class DataManagementScreen extends StatefulWidget {
  @override
  _DataManagementScreenState createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirestoreService _firestoreService = FirestoreService();

  bool _isExporting = false;
  bool _isImporting = false;
  Map<String, int> _collectionCounts = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCollectionCounts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('データ管理'),
        backgroundColor: Colors.purple[600],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'エクスポート', icon: Icon(Icons.file_download)),
            Tab(text: 'インポート', icon: Icon(Icons.file_upload)),
            Tab(text: 'バックアップ', icon: Icon(Icons.backup)),
            Tab(text: 'システム', icon: Icon(Icons.settings)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadCollectionCounts,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExportTab(),
          _buildImportTab(),
          _buildBackupTab(),
          _buildSystemTab(),
        ],
      ),
    );
  }

  // エクスポートタブ
  Widget _buildExportTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'データエクスポート',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'システムのデータをCSV形式でエクスポートできます',
            style: TextStyle(color: Colors.grey[600]),
          ),
          SizedBox(height: 24),

          // 売上データエクスポート
          _buildExportCard(
            title: '売上データ',
            description: '売上情報をCSV形式でエクスポート',
            icon: Icons.attach_money,
            color: Colors.green,
            count: _collectionCounts['sales'] ?? 0,
            onPressed: () => _showSalesExportDialog(),
          ),

          SizedBox(height: 16),

          // 配送データエクスポート
          _buildExportCard(
            title: '配送データ',
            description: '配送案件情報をCSV形式でエクスポート',
            icon: Icons.local_shipping,
            color: Colors.blue,
            count: _collectionCounts['deliveries'] ?? 0,
            onPressed: () => _showDeliveryExportDialog(),
          ),

          SizedBox(height: 16),

          // ドライバーデータエクスポート
          _buildExportCard(
            title: 'ドライバーデータ',
            description: 'ドライバー情報をCSV形式でエクスポート',
            icon: Icons.person,
            color: Colors.orange,
            count: _collectionCounts['drivers'] ?? 0,
            onPressed: () => _exportDriverData(),
          ),

          SizedBox(height: 24),

          // 一括エクスポート
          Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cloud_download,
                          color: Colors.purple, size: 32),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '全データ一括エクスポート',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'すべてのデータをまとめてエクスポート',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              _isExporting ? null : () => _exportAllDataAsCSV(),
                          icon: Icon(Icons.table_chart),
                          label: Text('CSV形式'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              _isExporting ? null : () => _exportFullBackup(),
                          icon: Icon(Icons.code),
                          label: Text('JSON形式'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
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
        ],
      ),
    );
  }

  // インポートタブ
  Widget _buildImportTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'データインポート',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'CSVファイルからデータをインポートできます',
            style: TextStyle(color: Colors.grey[600]),
          ),
          SizedBox(height: 24),

          // 注意事項
          Card(
            color: Colors.orange[50],
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange),
                      SizedBox(width: 8),
                      Text(
                        '重要な注意事項',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text('• インポート前に必ずデータのバックアップを取ってください'),
                  Text('• 既存データと重複する場合、新しいデータで上書きされます'),
                  Text('• CSVファイルの形式が正しいことを確認してください'),
                  Text('• 大量データのインポートには時間がかかる場合があります'),
                ],
              ),
            ),
          ),

          SizedBox(height: 24),

          // ドライバーデータインポート
          _buildImportCard(
            title: 'ドライバーデータインポート',
            description: 'ドライバー情報をCSVから一括登録',
            icon: Icons.person_add,
            color: Colors.orange,
            onPressed: () => _importDriverData(),
          ),

          SizedBox(height: 16),

          // 配送データインポート
          _buildImportCard(
            title: '配送データインポート',
            description: '配送案件をCSVから一括登録',
            icon: Icons.add_business,
            color: Colors.blue,
            onPressed: () => _importDeliveryData(),
          ),

          SizedBox(height: 24),

          // サンプルCSVダウンロード
          Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'サンプルCSVファイル',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '正しい形式のサンプルファイルをダウンロードできます',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _downloadSampleCSV('drivers'),
                          icon: Icon(Icons.download),
                          label: Text('ドライバーサンプル'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _downloadSampleCSV('deliveries'),
                          icon: Icon(Icons.download),
                          label: Text('配送サンプル'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
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
        ],
      ),
    );
  }

  // バックアップタブ
  Widget _buildBackupTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'データバックアップ',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'システム全体のデータをバックアップ・復元できます',
            style: TextStyle(color: Colors.grey[600]),
          ),
          SizedBox(height: 24),

          // 自動バックアップ状況
          Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.schedule, color: Colors.green, size: 32),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '自動バックアップ',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Firebase Firestoreは自動的にデータを保護します',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '有効',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                      '最後のバックアップ: ${DateTime.now().toString().substring(0, 19)}'),
                  Text('次回バックアップ: 自動（リアルタイム）'),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // 手動バックアップ
          Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.backup, color: Colors.blue, size: 32),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '手動バックアップ',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'システム全体のデータを手動でエクスポート',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed:
                        _isExporting ? null : () => _createManualBackup(),
                    icon: _isExporting
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Icon(Icons.backup),
                    label: Text(_isExporting ? 'バックアップ中...' : '今すぐバックアップ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // システムタブ
  Widget _buildSystemTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'システム管理',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 24),

          // データ統計
          Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'データベース統計',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  _buildStatRow('売上データ', _collectionCounts['sales'] ?? 0,
                      Icons.attach_money),
                  _buildStatRow('配送データ', _collectionCounts['deliveries'] ?? 0,
                      Icons.local_shipping),
                  _buildStatRow(
                      'ドライバー', _collectionCounts['drivers'] ?? 0, Icons.person),
                  _buildStatRow('ユーザー', _collectionCounts['users'] ?? 0,
                      Icons.account_circle),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // システム情報
          Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'システム情報',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  _buildInfoRow('バージョン', '1.0.0'),
                  _buildInfoRow('データベース', 'Firebase Firestore'),
                  _buildInfoRow(
                      '最終更新', DateTime.now().toString().substring(0, 19)),
                  _buildInfoRow('稼働時間',
                      '${DateTime.now().difference(DateTime.now().subtract(Duration(hours: 24))).inHours}時間'),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // メンテナンス機能
          Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'メンテナンス',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showDataCleanupDialog(),
                    icon: Icon(Icons.cleaning_services),
                    label: Text('データクリーンアップ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 48),
                    ),
                  ),
                  SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showDatabaseOptimizeDialog(),
                    icon: Icon(Icons.speed),
                    label: Text('データベース最適化'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // エクスポートカード
  Widget _buildExportCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required int count,
    required VoidCallback onPressed,
  }) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 32),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        description,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$count件',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isExporting ? null : onPressed,
              icon: Icon(Icons.download),
              label: Text('CSVダウンロード'),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // インポートカード
  Widget _buildImportCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 32),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        description,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isImporting ? null : onPressed,
              icon: _isImporting
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Icon(Icons.upload),
              label: Text(_isImporting ? 'インポート中...' : 'CSVファイル選択'),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, int count, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(
            '$count件',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label)),
          Expanded(
              child:
                  Text(value, style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  // メソッド実装
  Future<void> _loadCollectionCounts() async {
    try {
      final collections = ['sales', 'deliveries', 'drivers', 'users'];
      Map<String, int> counts = {};

      for (String collection in collections) {
        final snapshot =
            await FirebaseFirestore.instance.collection(collection).get();
        counts[collection] = snapshot.docs.length;
      }

      setState(() {
        _collectionCounts = counts;
      });
    } catch (e) {
      debugPrint('データ統計読み込みエラー: $e');
    }
  }

  void _showSalesExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('売上データエクスポート'),
        content: Text('売上データをCSV形式でエクスポートしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _exportSalesData();
            },
            child: Text('エクスポート'),
          ),
        ],
      ),
    );
  }

  void _showDeliveryExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('配送データエクスポート'),
        content: Text('配送データをCSV形式でエクスポートしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _exportDeliveryData();
            },
            child: Text('エクスポート'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportSalesData() async {
    setState(() => _isExporting = true);

    try {
      await DataExportService.exportSalesDataToCSV();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('売上データをエクスポートしました'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エクスポートエラー: $e')),
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportDeliveryData() async {
    setState(() => _isExporting = true);

    try {
      await DataExportService.exportDeliveryDataToCSV();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('配送データをエクスポートしました'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エクスポートエラー: $e')),
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportDriverData() async {
    setState(() => _isExporting = true);

    try {
      await DataExportService.exportDriverDataToCSV();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ドライバーデータをエクスポートしました'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エクスポートエラー: $e')),
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportAllDataAsCSV() async {
    setState(() => _isExporting = true);

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('全データのCSVエクスポート機能は準備中です'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('一括エクスポートエラー: $e')),
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportFullBackup() async {
    setState(() => _isExporting = true);

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('フルバックアップ機能は準備中です'),
          backgroundColor: Colors.purple,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('バックアップエラー: $e')),
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _createManualBackup() async {
    setState(() => _isExporting = true);

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('手動バックアップ機能は準備中です'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('バックアップエラー: $e')),
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _importDriverData() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('インポート機能は準備中です')),
    );
  }

  Future<void> _importDeliveryData() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('インポート機能は準備中です')),
    );
  }

  Future<void> _downloadSampleCSV(String type) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('サンプルCSV機能は準備中です')),
    );
  }

  void _showDataCleanupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('データクリーンアップ'),
        content: Text('古いデータや不要なデータを削除しますか？\n\n※この操作は元に戻せません'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('クリーンアップ機能は準備中です')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('実行'),
          ),
        ],
      ),
    );
  }

  void _showDatabaseOptimizeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('データベース最適化'),
        content: Text('データベースのパフォーマンスを最適化しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('最適化機能は準備中です')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: Text('実行'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
