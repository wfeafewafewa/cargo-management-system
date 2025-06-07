import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data'; // Uint8List用
import '../services/pdf_service.dart'; // PDF Serviceをインポート

class SalesManagementUnifiedScreen extends StatefulWidget {
  @override
  _SalesManagementUnifiedScreenState createState() =>
      _SalesManagementUnifiedScreenState();
}

class _SalesManagementUnifiedScreenState
    extends State<SalesManagementUnifiedScreen> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;

  // フィルター用の変数
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedCustomer;
  String? _selectedDriver;

  // データ格納用
  List<Map<String, dynamic>> _deliveries = [];
  List<Map<String, dynamic>> _workReports = [];
  List<String> _customers = [];
  List<String> _drivers = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      // 顧客とドライバーのリストを取得
      await _loadCustomersAndDrivers();

      // 全データを取得（初期表示用）
      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('データの読み込みに失敗しました: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCustomersAndDrivers() async {
    // 顧客リスト取得
    final deliveriesSnapshot = await _firestore.collection('deliveries').get();
    final customers = deliveriesSnapshot.docs
        .map((doc) => doc.data()['customerName'] as String?)
        .where((name) => name != null)
        .toSet()
        .toList();

    // ドライバーリスト取得
    final driversSnapshot = await _firestore.collection('drivers').get();
    final drivers = driversSnapshot.docs
        .map((doc) => doc.data()['name'] as String?)
        .where((name) => name != null)
        .toList();

    setState(() {
      _customers = customers.cast<String>();
      _drivers = drivers.cast<String>();
    });
  }

  Future<void> _loadData() async {
    Query deliveriesQuery = _firestore.collection('deliveries');
    Query workReportsQuery = _firestore.collection('work_reports');

    // 日付フィルター適用
    if (_startDate != null) {
      deliveriesQuery = deliveriesQuery.where('createdAt',
          isGreaterThanOrEqualTo: _startDate);
      workReportsQuery = workReportsQuery.where('workDate',
          isGreaterThanOrEqualTo: _startDate);
    }
    if (_endDate != null) {
      DateTime endOfDay =
          DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
      deliveriesQuery =
          deliveriesQuery.where('createdAt', isLessThanOrEqualTo: endOfDay);
      workReportsQuery =
          workReportsQuery.where('workDate', isLessThanOrEqualTo: endOfDay);
    }

    // 顧客フィルター適用
    if (_selectedCustomer != null) {
      deliveriesQuery =
          deliveriesQuery.where('customerName', isEqualTo: _selectedCustomer);
    }

    // ドライバーフィルター適用
    if (_selectedDriver != null) {
      deliveriesQuery =
          deliveriesQuery.where('driverName', isEqualTo: _selectedDriver);
      workReportsQuery =
          workReportsQuery.where('driverName', isEqualTo: _selectedDriver);
    }

    // データ取得
    final deliveriesSnapshot = await deliveriesQuery.get();
    final workReportsSnapshot = await workReportsQuery.get();

    setState(() {
      _deliveries = deliveriesSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      _workReports = workReportsSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  // 休憩時間を自動計算する関数（労働基準法に基づく）
  Duration _calculateBreakTime(Duration workDuration) {
    if (workDuration.inHours > 8) {
      return Duration(hours: 1);
    } else if (workDuration.inHours > 6) {
      return Duration(minutes: 45);
    } else {
      return Duration(minutes: 0);
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours}h${minutes}m';
  }

  // ===== 修正されたPDF生成機能（PdfServiceを使用） =====

  Future<void> _generateInvoicePDF() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('請求書生成には顧客を選択してください')),
      );
      return;
    }

    try {
      // 顧客別・案件別の集計
      final customerDeliveries = _deliveries
          .where((delivery) => delivery['customerName'] == _selectedCustomer)
          .toList();

      if (customerDeliveries.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('選択した顧客の配送データがありません')),
        );
        return;
      }

      // PdfServiceを使用してPDF生成
      final pdfBytes = await PdfService.generateInvoice(
        customerId: 'customer_001',
        customerName: _selectedCustomer!, // 英語版なので顧客名はそのまま
        deliveries: customerDeliveries,
        startDate: _startDate ?? DateTime.now().subtract(Duration(days: 30)),
        endDate: _endDate ?? DateTime.now(),
      );

      // PDF表示オプションダイアログを表示
      _showPdfOptionsDialog(
        pdfBytes,
        'Invoice_${_selectedCustomer}_${DateFormat('yyyyMM').format(DateTime.now())}.pdf',
        'Invoice',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF生成エラー: $e')),
      );
    }
  }

  Future<void> _generatePaymentNoticePDF() async {
    if (_selectedDriver == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('支払通知書生成にはドライバーを選択してください')),
      );
      return;
    }

    try {
      // ドライバーの稼働レポートを取得
      final driverReports = _workReports
          .where((report) => report['driverName'] == _selectedDriver)
          .toList();

      if (driverReports.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('選択したドライバーの稼働データがありません')),
        );
        return;
      }

      // PdfServiceを使用してPDF生成
      final pdfBytes = await PdfService.generatePaymentNotice(
        driverId: 'driver_001',
        driverName: _selectedDriver!, // 英語版なので名前はそのまま
        workReports: driverReports,
        startDate: _startDate ?? DateTime.now().subtract(Duration(days: 30)),
        endDate: _endDate ?? DateTime.now(),
      );

      // PDF表示オプションダイアログを表示
      _showPdfOptionsDialog(
        pdfBytes,
        'PaymentNotice_${_selectedDriver}_${DateFormat('yyyyMM').format(DateTime.now())}.pdf',
        'Payment Notice',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF生成エラー: $e')),
      );
    }
  }

  // PDF出力オプションダイアログ（PdfServiceのメソッドを使用）
  void _showPdfOptionsDialog(
      Uint8List pdfBytes, String filename, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$title - 出力オプション'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.preview, color: Colors.blue),
              title: const Text('プレビュー'),
              subtitle: const Text('PDFを画面で確認'),
              onTap: () async {
                Navigator.pop(context);
                await PdfService.previewPdf(pdfBytes, title);
              },
            ),
            ListTile(
              leading: const Icon(Icons.print, color: Colors.green),
              title: const Text('印刷'),
              subtitle: const Text('直接印刷'),
              onTap: () async {
                Navigator.pop(context);
                await PdfService.printPdf(pdfBytes, title);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download, color: Colors.orange),
              title: const Text('ダウンロード'),
              subtitle: const Text('ファイルとして保存'),
              onTap: () async {
                Navigator.pop(context);
                await PdfService.downloadPdf(pdfBytes, filename);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ===== 既存のUI構築メソッド =====

  Widget _buildFilterSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('フィルター',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),

            // 日付範囲
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: Text('開始日'),
                    subtitle:
                        Text(_startDate?.toString().split(' ')[0] ?? '未選択'),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _startDate = date);
                        _loadData();
                      }
                    },
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: Text('終了日'),
                    subtitle: Text(_endDate?.toString().split(' ')[0] ?? '未選択'),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _endDate = date);
                        _loadData();
                      }
                    },
                  ),
                ),
              ],
            ),

            // 顧客・ドライバー選択
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: '顧客選択'),
                    value: _selectedCustomer,
                    items: [
                      DropdownMenuItem(value: null, child: Text('全て')),
                      ..._customers.map((customer) => DropdownMenuItem(
                          value: customer, child: Text(customer))),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedCustomer = value);
                      _loadData();
                    },
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: 'ドライバー選択'),
                    value: _selectedDriver,
                    items: [
                      DropdownMenuItem(value: null, child: Text('全て')),
                      ..._drivers.map((driver) =>
                          DropdownMenuItem(value: driver, child: Text(driver))),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedDriver = value);
                      _loadData();
                    },
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // リセットボタン
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _startDate = null;
                  _endDate = null;
                  _selectedCustomer = null;
                  _selectedDriver = null;
                });
                _loadData();
              },
              child: Text('フィルターをリセット'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPDFSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PDF出力',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),

            // 請求書生成セクション
            Container(
              margin: EdgeInsets.only(bottom: 16),
              padding: EdgeInsets.all(16),
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
                      Icon(Icons.receipt_long, color: Colors.blue.shade700),
                      SizedBox(width: 8),
                      Text(
                        '請求書生成',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '顧客ごと・案件ごとの請求書を作成します',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _generateInvoicePDF,
                      icon: Icon(Icons.receipt),
                      label: Text('請求書を生成'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 支払通知書生成セクション
            Container(
              padding: EdgeInsets.all(16),
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
                      Icon(Icons.payment, color: Colors.green.shade700),
                      SizedBox(width: 8),
                      Text(
                        '支払通知書生成',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'ドライバーごとの稼働明細・支払通知書を作成します',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _generatePaymentNoticePDF,
                      icon: Icon(Icons.payment),
                      label: Text('支払通知書を生成'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),
            Text(
              '※請求書は顧客選択時、支払通知書はドライバー選択時に出力可能',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSummary() {
    // 売上集計
    final totalRevenue = _deliveries.fold<double>(
        0, (sum, delivery) => sum + (delivery['fee']?.toDouble() ?? 0));

    final totalPayments = _workReports.fold<double>(
        0, (sum, report) => sum + (report['totalAmount']?.toDouble() ?? 0));

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('集計データ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text('総売上',
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[600])),
                      Text(
                          '¥${NumberFormat('#,###').format(totalRevenue.round())}',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text('総支払額',
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[600])),
                      Text(
                          '¥${NumberFormat('#,###').format(totalPayments.round())}',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text('案件数',
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[600])),
                      Text('${_deliveries.length}',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkLogCard(Map<String, dynamic> log) {
    final workStartTime = (log['workStartTime'] as Timestamp?)?.toDate();
    final workEndTime = (log['workEndTime'] as Timestamp?)?.toDate();
    final workDate = (log['workDate'] as Timestamp?)?.toDate();

    Duration? workDuration;
    Duration? breakTime;
    Duration? actualWorkTime;

    if (workStartTime != null && workEndTime != null) {
      workDuration = workEndTime.difference(workStartTime);
      breakTime = _calculateBreakTime(workDuration);
      actualWorkTime = workDuration - breakTime;
    }

    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー行
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  log['driverName'] ?? '不明',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  workDate?.toString().split(' ')[0] ?? '不明',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),

            SizedBox(height: 12),

            // 稼働時間情報
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('開始時刻',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600])),
                      Text(
                        workStartTime != null
                            ? '${workStartTime.hour.toString().padLeft(2, '0')}:${workStartTime.minute.toString().padLeft(2, '0')}'
                            : '不明',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('終了時刻',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600])),
                      Text(
                        workEndTime != null
                            ? '${workEndTime.hour.toString().padLeft(2, '0')}:${workEndTime.minute.toString().padLeft(2, '0')}'
                            : '不明',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('総稼働時間',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600])),
                      Text(
                        workDuration != null
                            ? _formatDuration(workDuration)
                            : '不明',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),

            // 休憩時間と実働時間
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text('勤務時間',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                        Text(
                          actualWorkTime != null
                              ? _formatDuration(actualWorkTime)
                              : '不明',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[600]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: Colors.grey[300],
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text('休憩時間',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                        Text(
                          breakTime != null ? _formatDuration(breakTime) : '不明',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 12),

            // 案件と報酬情報
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('案件',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600])),
                      Text(
                        log['selectedDelivery'] ?? '不明',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('支払額',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600])),
                      Text(
                        '¥${NumberFormat('#,###').format(log['totalAmount'] ?? 0)}',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.green[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildFilterSection(),
          SizedBox(height: 16),
          _buildDataSummary(),
        ],
      ),
    );
  }

  Widget _buildWorkLogTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildFilterSection(),
          SizedBox(height: 16),

          // 稼働ログリスト
          _workReports.isEmpty
              ? Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.work_off, size: 64, color: Colors.grey[400]),
                        SizedBox(height: 16),
                        Text(
                          '稼働ログがありません',
                          style:
                              TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: _workReports
                      .map((log) => _buildWorkLogCard(log))
                      .toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildPDFTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildFilterSection(),
          SizedBox(height: 16),
          _buildPDFSection(),
          SizedBox(height: 16),
          _buildDataSummary(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('売上管理'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              icon: Icon(Icons.analytics),
              text: '売上データ',
            ),
            Tab(
              icon: Icon(Icons.schedule),
              text: '稼働ログ',
            ),
            Tab(
              icon: Icon(Icons.picture_as_pdf),
              text: 'PDF出力',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSalesTab(),
                _buildWorkLogTab(),
                _buildPDFTab(),
              ],
            ),
    );
  }
}
