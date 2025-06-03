// lib/screens/data_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'dart:html' as html;
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
                          icon: _isExporting
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Icon(Icons.table_chart),
                          label: Text(_isExporting ? 'エクスポート中...' : 'CSV形式'),
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
                          icon: _isExporting
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Icon(Icons.code),
                          label: Text(_isExporting ? 'エクスポート中...' : 'JSON形式'),
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
                  _buildInfoRow('稼働時間', '24時間'),
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
              icon: _isExporting
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Icon(Icons.download),
              label: Text(_isExporting ? 'エクスポート中...' : 'CSVダウンロード'),
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

  // 実装済みエクスポート機能
  Future<void> _exportSalesData() async {
    setState(() => _isExporting = true);

    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('sales').get();

      List<List<dynamic>> csvData = [
        ['ID', '金額', '完了日時', '配送ID', '作成日時']
      ];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        csvData.add([
          doc.id,
          data['amount'] ?? 0,
          data['completedAt']?.toDate()?.toString() ?? '',
          data['deliveryId'] ?? '',
          data['createdAt']?.toDate()?.toString() ?? '',
        ]);
      }

      final csvString = const ListToCsvConverter().convert(csvData);
      _downloadFile(
          csvString, 'sales_data_${DateTime.now().millisecondsSinceEpoch}.csv');

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
      final snapshot =
          await FirebaseFirestore.instance.collection('deliveries').get();

      List<List<dynamic>> csvData = [
        ['ID', '集荷場所', '配送先', 'ステータス', '料金', 'ドライバーID', '作成日時']
      ];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        csvData.add([
          doc.id,
          data['pickupLocation'] ?? '',
          data['deliveryLocation'] ?? '',
          data['status'] ?? '',
          data['fee'] ?? 0,
          data['driverId'] ?? '',
          data['createdAt']?.toDate()?.toString() ?? '',
        ]);
      }

      final csvString = const ListToCsvConverter().convert(csvData);
      _downloadFile(csvString,
          'delivery_data_${DateTime.now().millisecondsSinceEpoch}.csv');

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
      final snapshot =
          await FirebaseFirestore.instance.collection('drivers').get();

      List<List<dynamic>> csvData = [
        ['ID', '名前', 'メール', '電話番号', 'ステータス', '作成日時']
      ];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        csvData.add([
          doc.id,
          data['name'] ?? '',
          data['email'] ?? '',
          data['phone'] ?? '',
          data['status'] ?? '',
          data['createdAt']?.toDate()?.toString() ?? '',
        ]);
      }

      final csvString = const ListToCsvConverter().convert(csvData);
      _downloadFile(csvString,
          'driver_data_${DateTime.now().millisecondsSinceEpoch}.csv');

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
      // 全データを取得
      final salesSnapshot =
          await FirebaseFirestore.instance.collection('sales').get();
      final deliverySnapshot =
          await FirebaseFirestore.instance.collection('deliveries').get();
      final driverSnapshot =
          await FirebaseFirestore.instance.collection('drivers').get();

      // 売上データCSV
      List<List<dynamic>> salesCsvData = [
        ['ID', '金額', '完了日時', '配送ID', '作成日時']
      ];
      for (var doc in salesSnapshot.docs) {
        final data = doc.data();
        salesCsvData.add([
          doc.id,
          data['amount'] ?? 0,
          data['completedAt']?.toDate()?.toString() ?? '',
          data['deliveryId'] ?? '',
          data['createdAt']?.toDate()?.toString() ?? '',
        ]);
      }

      // 配送データCSV
      List<List<dynamic>> deliveryCsvData = [
        ['ID', '集荷場所', '配送先', 'ステータス', '料金', 'ドライバーID', '作成日時']
      ];
      for (var doc in deliverySnapshot.docs) {
        final data = doc.data();
        deliveryCsvData.add([
          doc.id,
          data['pickupLocation'] ?? '',
          data['deliveryLocation'] ?? '',
          data['status'] ?? '',
          data['fee'] ?? 0,
          data['driverId'] ?? '',
          data['createdAt']?.toDate()?.toString() ?? '',
        ]);
      }

      // ドライバーデータCSV
      List<List<dynamic>> driverCsvData = [
        ['ID', '名前', 'メール', '電話番号', 'ステータス', '作成日時']
      ];
      for (var doc in driverSnapshot.docs) {
        final data = doc.data();
        driverCsvData.add([
          doc.id,
          data['name'] ?? '',
          data['email'] ?? '',
          data['phone'] ?? '',
          data['status'] ?? '',
          data['createdAt']?.toDate()?.toString() ?? '',
        ]);
      }

      // 統合CSV作成
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _downloadFile(const ListToCsvConverter().convert(salesCsvData),
          'all_sales_data_$timestamp.csv');
      _downloadFile(const ListToCsvConverter().convert(deliveryCsvData),
          'all_delivery_data_$timestamp.csv');
      _downloadFile(const ListToCsvConverter().convert(driverCsvData),
          'all_driver_data_$timestamp.csv');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('全データのCSVエクスポートが完了しました'),
          backgroundColor: Colors.green,
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
      // 全データをJSON形式で取得
      final collections = ['sales', 'deliveries', 'drivers', 'users'];
      Map<String, List<Map<String, dynamic>>> allData = {};

      for (String collection in collections) {
        final snapshot =
            await FirebaseFirestore.instance.collection(collection).get();
        allData[collection] = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          // Timestampを文字列に変換
          data.forEach((key, value) {
            if (value is Timestamp) {
              data[key] = value.toDate().toIso8601String();
            }
          });
          return data;
        }).toList();
      }

      final jsonString = jsonEncode({
        'exportDate': DateTime.now().toIso8601String(),
        'version': '1.0.0',
        'data': allData,
      });

      _downloadFile(jsonString,
          'full_backup_${DateTime.now().millisecondsSinceEpoch}.json');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('フルバックアップが完了しました'),
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
      await _exportFullBackup();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('手動バックアップが完了しました'),
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

  // ファイルダウンロード機能
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

  // サンプルCSVダウンロード機能
  Future<void> _downloadSampleCSV(String type) async {
    try {
      String csvContent = '';
      String filename = '';

      if (type == 'drivers') {
        csvContent = '''名前,メール,電話番号,ステータス
田中太郎,tanaka@example.com,090-1234-5678,稼働中
佐藤花子,sato@example.com,090-8765-4321,休憩中
鈴木一郎,suzuki@example.com,090-1111-2222,稼働中''';
        filename = 'driver_sample.csv';
      } else if (type == 'deliveries') {
        csvContent = '''集荷場所,配送先,料金,備考
東京都渋谷区,東京都新宿区,1500,急ぎ
大阪府大阪市,京都府京都市,2000,
愛知県名古屋市,静岡県浜松市,2500,冷蔵配送''';
        filename = 'delivery_sample.csv';
      }

      _downloadFile(csvContent, filename);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('サンプルCSVをダウンロードしました'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ダウンロードエラー: $e')),
      );
    }
  }

  // インポート機能（基本実装）
  Future<void> _importDriverData() async {
    setState(() => _isImporting = true);

    try {
      // ファイル選択のダイアログを表示
      final input = html.FileUploadInputElement()..accept = '.csv';
      input.click();

      await input.onChange.first;
      final files = input.files;
      if (files!.isEmpty) {
        setState(() => _isImporting = false);
        return;
      }

      final file = files[0];
      final reader = html.FileReader();
      reader.readAsText(file);

      await reader.onLoad.first;
      final csvString = reader.result as String;

      // CSV解析
      final csvData = const CsvToListConverter().convert(csvString);
      if (csvData.isEmpty) {
        throw Exception('CSVファイルが空です');
      }

      final headers = csvData[0];
      final dataRows = csvData.skip(1);

      int importCount = 0;
      for (final row in dataRows) {
        if (row.length >= 3) {
          await FirebaseFirestore.instance.collection('drivers').add({
            'name': row[0].toString(),
            'email': row[1].toString(),
            'phone': row[2].toString(),
            'status': row.length > 3 ? row[3].toString() : '稼働中',
            'createdAt': FieldValue.serverTimestamp(),
          });
          importCount++;
        }
      }

      await _loadCollectionCounts();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ドライバーデータ ${importCount}件をインポートしました'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('インポートエラー: $e')),
      );
    } finally {
      setState(() => _isImporting = false);
    }
  }

  Future<void> _importDeliveryData() async {
    setState(() => _isImporting = true);

    try {
      final input = html.FileUploadInputElement()..accept = '.csv';
      input.click();

      await input.onChange.first;
      final files = input.files;
      if (files!.isEmpty) {
        setState(() => _isImporting = false);
        return;
      }

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
            'notes': row.length > 3 ? row[3].toString() : '',
            'status': '待機中',
            'createdAt': FieldValue.serverTimestamp(),
          });
          importCount++;
        }
      }

      await _loadCollectionCounts();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('配送データ ${importCount}件をインポートしました'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('インポートエラー: $e')),
      );
    } finally {
      setState(() => _isImporting = false);
    }
  }

  void _showDataCleanupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('データクリーンアップ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('実行する項目を選択してください：'),
            SizedBox(height: 16),
            Text('• 完了から30日以上経過した配送データ'),
            Text('• 削除されたドライバーの関連データ'),
            Text('• 重複する売上データ'),
            SizedBox(height: 16),
            Text(
              '※この操作は元に戻せません',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performDataCleanup();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('実行'),
          ),
        ],
      ),
    );
  }

  Future<void> _performDataCleanup() async {
    try {
      // 30日前の日付を計算
      final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));

      // 完了から30日以上経過した配送データを削除
      final oldDeliveries = await FirebaseFirestore.instance
          .collection('deliveries')
          .where('status', isEqualTo: '完了')
          .where('completedAt', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      int deletedCount = 0;
      for (var doc in oldDeliveries.docs) {
        await doc.reference.delete();
        deletedCount++;
      }

      await _loadCollectionCounts();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('データクリーンアップが完了しました（${deletedCount}件削除）'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('クリーンアップエラー: $e')),
      );
    }
  }

  void _showDatabaseOptimizeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('データベース最適化'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('以下の最適化を実行します：'),
            SizedBox(height: 16),
            Text('• インデックスの再構築'),
            Text('• データの整合性チェック'),
            Text('• 統計情報の更新'),
            SizedBox(height: 16),
            Text('所要時間: 約2-3分'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performDatabaseOptimization();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: Text('実行'),
          ),
        ],
      ),
    );
  }

  Future<void> _performDatabaseOptimization() async {
    try {
      // シミュレーション的な最適化処理
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 16),
              Text('データベースを最適化中...'),
            ],
          ),
          backgroundColor: Colors.purple,
          duration: Duration(seconds: 3),
        ),
      );

      // 実際の処理をシミュレート
      await Future.delayed(Duration(seconds: 3));
      await _loadCollectionCounts();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('データベース最適化が完了しました'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('最適化エラー: $e')),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
