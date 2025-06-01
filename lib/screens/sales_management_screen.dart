// lib/screens/sales_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/pdf_service.dart';
import '../services/data_export_service.dart';

class SalesManagementScreen extends StatefulWidget {
  @override
  _SalesManagementScreenState createState() => _SalesManagementScreenState();
}

class _SalesManagementScreenState extends State<SalesManagementScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  late TabController _tabController;

  String _selectedMonth = '';
  Map<String, dynamic> _monthlyStats = {};
  bool _isLoading = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final now = DateTime.now();
    _selectedMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _loadMonthlyStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('売上管理'),
        backgroundColor: Colors.orange[600],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: '月次売上', icon: Icon(Icons.calendar_month)),
            Tab(text: 'ドライバー別', icon: Icon(Icons.person)),
            Tab(text: 'レポート', icon: Icon(Icons.analytics)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadMonthlyStats,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMonthlySalesTab(),
          _buildDriverSalesTab(),
          _buildReportsTab(),
        ],
      ),
    );
  }

  Widget _buildMonthlySalesTab() {
    return Column(
      children: [
        // 月選択ヘッダー
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.orange[600]),
              SizedBox(width: 8),
              Text('対象月:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(width: 16),
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedMonth,
                  isExpanded: true,
                  items: _generateMonthOptions(),
                  onChanged: (value) {
                    setState(() {
                      _selectedMonth = value!;
                    });
                    _loadMonthlyStats();
                  },
                ),
              ),
            ],
          ),
        ),

        // 統計カード
        if (_isLoading)
          Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // 売上サマリーカード
                  _buildSalesSummaryCards(),
                  SizedBox(height: 24),

                  // 売上一覧
                  _buildSalesList(),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDriverSalesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.getDrivers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_off, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('登録されたドライバーがいません'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final driver = snapshot.data!.docs[index];
            final driverData = driver.data() as Map<String, dynamic>;
            return Column(
              children: [
                _buildDriverSalesCard(driver.id, driverData),
                SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () =>
                      _generateDriverSalesReport(driver.id, driverData),
                  icon: Icon(Icons.picture_as_pdf),
                  label: Text('個人売上明細PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
                SizedBox(height: 16),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildReportsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '売上レポート',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),

          // データエクスポート機能
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.file_download, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'データエクスポート',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text('売上データを様々な形式でエクスポートできます'),
                  SizedBox(height: 16),

                  // エクスポートボタン群
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isExporting
                              ? null
                              : () => _exportCurrentMonthCSV(),
                          icon: _isExporting
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Icon(Icons.table_chart),
                          label: Text('今月CSV'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              _isExporting ? null : () => _exportAllSalesCSV(),
                          icon: _isExporting
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Icon(Icons.download),
                          label: Text('全期間CSV'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isExporting
                              ? null
                              : () => _showCustomExportDialog(),
                          icon: Icon(Icons.tune),
                          label: Text('カスタム'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isExporting
                              ? null
                              : () => _exportMonthlyReportCSV(),
                          icon: Icon(Icons.description),
                          label: Text('月次レポート'),
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

          SizedBox(height: 16),

          // 年間推移グラフ（プレースホルダー）
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '年間推移グラフ',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bar_chart, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('グラフ機能は今後実装予定です'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // PDF生成機能
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PDF レポート生成',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('月次売上レポートをPDFで出力できます'),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _generatePDFReport(),
                          icon: Icon(Icons.picture_as_pdf),
                          label: Text('詳細PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _generateMonthlySalesInvoice(),
                          icon: Icon(Icons.receipt),
                          label: Text('請求書PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
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

  Widget _buildSalesSummaryCards() {
    final totalSales = _monthlyStats['totalSales'] ?? 0.0;
    final totalTransactions = _monthlyStats['totalTransactions'] ?? 0;
    final averageOrder =
        totalTransactions > 0 ? totalSales / totalTransactions : 0.0;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            '総売上',
            '¥${totalSales.toStringAsFixed(0)}',
            Icons.attach_money,
            Colors.green,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            '取引件数',
            '${totalTransactions}件',
            Icons.receipt,
            Colors.blue,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            '平均単価',
            '¥${averageOrder.toStringAsFixed(0)}',
            Icons.trending_up,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            SizedBox(height: 8),
            Text(title,
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesList() {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.list, color: Colors.orange[600]),
                SizedBox(width: 8),
                Text(
                  '売上明細',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Divider(height: 1),
          StreamBuilder<QuerySnapshot>(
            stream: _firestoreService.getMonthlySales(_selectedMonth),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('${_getMonthName(_selectedMonth)}の売上データがありません'),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _generateMonthlySalesInvoice(),
                                icon: Icon(Icons.picture_as_pdf),
                                label: Text('月次売上請求書PDF'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _generateSalesDetailReport(),
                                icon: Icon(Icons.description),
                                label: Text('売上明細レポート'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _generateSampleSales(),
                          icon: Icon(Icons.add),
                          label: Text('サンプルデータ生成'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final sale = snapshot.data!.docs[index];
                  final data = sale.data() as Map<String, dynamic>;
                  return _buildSalesListTile(data);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSalesListTile(Map<String, dynamic> data) {
    final amount = (data['amount'] ?? 0).toDouble();
    final commission = (data['commission'] ?? 0).toDouble();
    final netAmount = (data['netAmount'] ?? 0).toDouble();
    final paymentStatus = data['paymentStatus'] ?? 'pending';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: paymentStatus == 'paid'
            ? Colors.green.withValues(alpha: 0.2)
            : Colors.orange.withValues(alpha: 0.2),
        child: Icon(
          paymentStatus == 'paid' ? Icons.check_circle : Icons.pending,
          color: paymentStatus == 'paid' ? Colors.green : Colors.orange,
        ),
      ),
      title: Text('配送案件ID: ${data['deliveryId'] ?? '未設定'}'),
      subtitle: Text(
          '手数料: ¥${commission.toStringAsFixed(0)} | 純利益: ¥${netAmount.toStringAsFixed(0)}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '¥${amount.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: paymentStatus == 'paid' ? Colors.green : Colors.orange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              paymentStatus == 'paid' ? '支払済' : '未払',
              style: TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverSalesCard(
      String driverId, Map<String, dynamic> driverData) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orange.withValues(alpha: 0.2),
                  child: Icon(Icons.person, color: Colors.orange),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driverData['name'] ?? 'ドライバー名なし',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${driverData['vehicleType'] ?? '車両未設定'} | ${driverData['totalDeliveries'] ?? 0}件配送済',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream:
                  _firestoreService.getDriverSales(driverId, _selectedMonth),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Row(
                    children: [
                      Expanded(child: _buildDriverStatItem('売上', '¥0')),
                      Expanded(child: _buildDriverStatItem('件数', '0件')),
                      Expanded(child: _buildDriverStatItem('平均', '¥0')),
                    ],
                  );
                }

                double totalSales = 0;
                int totalCount = snapshot.data!.docs.length;

                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  totalSales += (data['amount'] ?? 0).toDouble();
                }

                double average = totalCount > 0 ? totalSales / totalCount : 0;

                return Row(
                  children: [
                    Expanded(
                        child: _buildDriverStatItem(
                            '売上', '¥${totalSales.toStringAsFixed(0)}')),
                    Expanded(
                        child: _buildDriverStatItem('件数', '${totalCount}件')),
                    Expanded(
                        child: _buildDriverStatItem(
                            '平均', '¥${average.toStringAsFixed(0)}')),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverStatItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        SizedBox(height: 4),
        Text(value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  List<DropdownMenuItem<String>> _generateMonthOptions() {
    List<DropdownMenuItem<String>> items = [];
    final now = DateTime.now();

    for (int i = 0; i < 12; i++) {
      final date = DateTime(now.year, now.month - i, 1);
      final monthString =
          '${date.year}-${date.month.toString().padLeft(2, '0')}';
      items.add(
        DropdownMenuItem(
          value: monthString,
          child: Text(_getMonthName(monthString)),
        ),
      );
    }

    return items;
  }

  String _getMonthName(String monthString) {
    final parts = monthString.split('-');
    final year = parts[0];
    final month = int.parse(parts[1]);

    const monthNames = [
      '',
      '1月',
      '2月',
      '3月',
      '4月',
      '5月',
      '6月',
      '7月',
      '8月',
      '9月',
      '10月',
      '11月',
      '12月'
    ];

    return '$year年 ${monthNames[month]}';
  }

  // エクスポート機能メソッド

  // 今月の売上データをCSVエクスポート
  Future<void> _exportCurrentMonthCSV() async {
    setState(() => _isExporting = true);

    try {
      await DataExportService.exportSalesDataToCSV(
        startMonth: _selectedMonth,
        endMonth: _selectedMonth,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_getMonthName(_selectedMonth)}の売上データをCSVエクスポートしました'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSVエクスポートエラー: $e')),
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  // 全期間の売上データをCSVエクスポート
  Future<void> _exportAllSalesCSV() async {
    setState(() => _isExporting = true);

    try {
      await DataExportService.exportSalesDataToCSV();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('全期間の売上データをCSVエクスポートしました'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSVエクスポートエラー: $e')),
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  // 月次レポートをCSVエクスポート
  Future<void> _exportMonthlyReportCSV() async {
    setState(() => _isExporting = true);

    try {
      await DataExportService.exportMonthlyReport(_selectedMonth);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('${_getMonthName(_selectedMonth)}の月次レポートをCSVエクスポートしました'),
          backgroundColor: Colors.purple,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('月次レポートエクスポートエラー: $e')),
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  // カスタムエクスポートダイアログ
  void _showCustomExportDialog() {
    String? startMonth;
    String? endMonth;
    String? selectedDriverId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('カスタムエクスポート'),
          content: Container(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('エクスポート条件を指定してください'),
                SizedBox(height: 16),

                // 開始月選択
                Text('開始月:', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  hint: Text('開始月を選択'),
                  value: startMonth,
                  isExpanded: true,
                  items: _generateMonthOptions(),
                  onChanged: (value) {
                    setDialogState(() {
                      startMonth = value;
                    });
                  },
                ),

                SizedBox(height: 12),

                // 終了月選択
                Text('終了月:', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  hint: Text('終了月を選択'),
                  value: endMonth,
                  isExpanded: true,
                  items: _generateMonthOptions(),
                  onChanged: (value) {
                    setDialogState(() {
                      endMonth = value;
                    });
                  },
                ),

                SizedBox(height: 12),

                // ドライバー選択
                Text('ドライバー:', style: TextStyle(fontWeight: FontWeight.bold)),
                StreamBuilder<QuerySnapshot>(
                  stream: _firestoreService.getDrivers(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return DropdownButton<String>(
                        hint: Text('読み込み中...'),
                        items: [],
                        onChanged: null,
                      );
                    }

                    List<DropdownMenuItem<String>> driverItems = [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text('全ドライバー'),
                      )
                    ];

                    for (var doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      driverItems.add(
                        DropdownMenuItem<String>(
                          value: doc.id,
                          child: Text(data['name'] ?? '未設定'),
                        ),
                      );
                    }

                    return DropdownButton<String>(
                      hint: Text('ドライバーを選択'),
                      value: selectedDriverId,
                      isExpanded: true,
                      items: driverItems,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedDriverId = value;
                        });
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _exportCustomSalesCSV(startMonth, endMonth, selectedDriverId);
              },
              child: Text('エクスポート'),
            ),
          ],
        ),
      ),
    );
  }

  // カスタム条件での売上データエクスポート
  Future<void> _exportCustomSalesCSV(
      String? startMonth, String? endMonth, String? driverId) async {
    setState(() => _isExporting = true);

    try {
      await DataExportService.exportSalesDataToCSV(
        startMonth: startMonth,
        endMonth: endMonth,
        driverId: driverId,
      );

      String conditionText = '';
      if (startMonth != null || endMonth != null) {
        conditionText += '期間指定';
      }
      if (driverId != null) {
        if (conditionText.isNotEmpty) conditionText += '・';
        conditionText += 'ドライバー指定';
      }
      if (conditionText.isEmpty) conditionText = '全データ';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('カスタム条件（$conditionText）で売上データをCSVエクスポートしました'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('カスタムエクスポートエラー: $e')),
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _loadMonthlyStats() async {
    setState(() => _isLoading = true);

    try {
      // 実際の実装では、選択された月の統計を計算
      final salesSnapshot = await FirebaseFirestore.instance
          .collection('sales')
          .where('month', isEqualTo: _selectedMonth)
          .get();

      double totalSales = 0;
      int totalTransactions = salesSnapshot.docs.length;

      for (var doc in salesSnapshot.docs) {
        final data = doc.data();
        totalSales += (data['amount'] ?? 0).toDouble();
      }

      setState(() {
        _monthlyStats = {
          'totalSales': totalSales,
          'totalTransactions': totalTransactions,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('データの読み込みに失敗しました: $e')),
      );
    }
  }

  Future<void> _generateSampleSales() async {
    try {
      // サンプル売上データを生成
      final deliveries = await FirebaseFirestore.instance
          .collection('deliveries')
          .where('status', isEqualTo: 'completed')
          .limit(5)
          .get();

      for (var delivery in deliveries.docs) {
        final deliveryData = delivery.data();
        final amount = (deliveryData['price'] ?? 3000).toDouble();
        final commission = amount * 0.1; // 10%手数料

        await _firestoreService.createSale(
          deliveryId: delivery.id,
          driverId: deliveryData['assignedDriverId'] ?? 'sample_driver',
          amount: amount,
          commission: commission,
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('サンプルデータを生成しました')),
      );

      _loadMonthlyStats();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('サンプルデータ生成エラー: $e')),
      );
    }
  }

  void _generatePDFReport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('PDF生成'),
        content: Text('PDF生成機能は後日実装予定です。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  // 月次売上請求書PDF生成
  Future<void> _generateMonthlySalesInvoice() async {
    try {
      // 売上データ取得
      final salesSnapshot = await FirebaseFirestore.instance
          .collection('sales')
          .where('month', isEqualTo: _selectedMonth)
          .get();

      if (salesSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${_getMonthName(_selectedMonth)}の売上データがありません')),
        );
        return;
      }

      // データ集計
      double totalSales = 0;
      double totalCommission = 0;
      List<Map<String, dynamic>> salesData = [];

      for (var doc in salesSnapshot.docs) {
        final data = doc.data();
        totalSales += (data['amount'] ?? 0).toDouble();
        totalCommission += (data['commission'] ?? 0).toDouble();

        salesData.add({
          'deliveryId': data['deliveryId'] ?? '未設定',
          'driverName': await _getDriverName(data['driverId']),
          'amount': (data['amount'] ?? 0).toDouble(),
          'commission': (data['commission'] ?? 0).toDouble(),
          'netAmount': (data['netAmount'] ?? 0).toDouble(),
        });
      }

      final summary = {
        'totalSales': totalSales,
        'totalTransactions': salesSnapshot.docs.length,
        'totalCommission': totalCommission,
      };

      // PDF生成
      await PDFService.generateMonthlySalesInvoice(
        month: _selectedMonth,
        salesData: salesData,
        summary: summary,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('月次売上請求書PDFを生成しました！'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF生成エラー: $e')),
      );
    }
  }

  // 売上明細レポート生成
  Future<void> _generateSalesDetailReport() async {
    try {
      final salesSnapshot = await FirebaseFirestore.instance
          .collection('sales')
          .where('month', isEqualTo: _selectedMonth)
          .get();

      if (salesSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('売上データがありません')),
        );
        return;
      }

      // 詳細レポート用のデータ準備
      List<Map<String, dynamic>> detailData = [];
      double totalSales = 0;
      double totalCommission = 0;

      for (var doc in salesSnapshot.docs) {
        final data = doc.data();
        totalSales += (data['amount'] ?? 0).toDouble();
        totalCommission += (data['commission'] ?? 0).toDouble();

        detailData.add({
          'deliveryId': data['deliveryId'],
          'driverName': await _getDriverName(data['driverId']),
          'amount': data['amount'],
          'commission': data['commission'],
          'netAmount': data['netAmount'],
          'createdAt': data['createdAt'],
        });
      }

      final summary = {
        'totalSales': totalSales,
        'totalTransactions': detailData.length,
        'totalCommission': totalCommission,
      };

      await PDFService.generateMonthlySalesInvoice(
        month: _selectedMonth,
        salesData: detailData,
        summary: summary,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('売上明細レポートを生成しました！'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('レポート生成エラー: $e')),
      );
    }
  }

  // ドライバー個人売上明細書生成
  Future<void> _generateDriverSalesReport(
      String driverId, Map<String, dynamic> driverInfo) async {
    try {
      // ドライバーの売上データ取得
      final salesSnapshot = await FirebaseFirestore.instance
          .collection('sales')
          .where('driverId', isEqualTo: driverId)
          .where('month', isEqualTo: _selectedMonth)
          .get();

      if (salesSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${driverInfo['name']}さんの売上データがありません')),
        );
        return;
      }

      // データ集計
      double totalSales = 0;
      double totalNetAmount = 0;
      List<Map<String, dynamic>> salesData = [];

      for (var doc in salesSnapshot.docs) {
        final data = doc.data();
        totalSales += (data['amount'] ?? 0).toDouble();
        totalNetAmount += (data['netAmount'] ?? 0).toDouble();

        // 配送案件タイトル取得
        String deliveryTitle = '未設定';
        try {
          final deliveryDoc = await FirebaseFirestore.instance
              .collection('deliveries')
              .doc(data['deliveryId'])
              .get();

          if (deliveryDoc.exists) {
            final deliveryData = deliveryDoc.data() as Map<String, dynamic>;
            deliveryTitle = deliveryData['title'] ?? '未設定';
          }
        } catch (e) {
          debugPrint('配送案件取得エラー: $e');
        }

        salesData.add({
          'deliveryTitle': deliveryTitle,
          'amount': (data['amount'] ?? 0).toDouble(),
          'netAmount': (data['netAmount'] ?? 0).toDouble(),
          'createdAt': data['createdAt'],
        });
      }

      final summary = {
        'totalDeliveries': salesSnapshot.docs.length,
        'totalSales': totalSales,
        'netAmount': totalNetAmount,
      };

      // PDF生成
      await PDFService.generateDriverSalesReport(
        month: _selectedMonth,
        driverInfo: driverInfo,
        salesData: salesData,
        summary: summary,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${driverInfo['name']}さんの売上明細書PDFを生成しました！'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF生成エラー: $e')),
      );
    }
  }

  Future<String> _getDriverName(String? driverId) async {
    if (driverId == null) return '未設定';

    try {
      final driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .get();

      if (driverDoc.exists) {
        final data = driverDoc.data() as Map<String, dynamic>;
        return data['name'] ?? '未設定';
      }
    } catch (e) {
      debugPrint('ドライバー名取得エラー: $e');
    }

    return '未設定';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
