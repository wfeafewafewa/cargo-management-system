// lib/services/pdf_service.dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';

class PDFService {
  // 月次売上請求書生成
  static Future<void> generateMonthlySalesInvoice({
    required String month,
    required List<Map<String, dynamic>> salesData,
    required Map<String, dynamic> summary,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildInvoiceHeader(),
            pw.SizedBox(height: 20),
            _buildCompanyInfo(),
            pw.SizedBox(height: 30),
            _buildInvoiceTitle('月次売上請求書', month),
            pw.SizedBox(height: 20),
            _buildSalesSummary(summary),
            pw.SizedBox(height: 30),
            _buildSalesTable(salesData),
            pw.SizedBox(height: 30),
            _buildInvoiceFooter(),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  // 配送明細書生成
  static Future<void> generateDeliveryInvoice({
    required Map<String, dynamic> deliveryData,
    required Map<String, dynamic> driverData,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildInvoiceHeader(),
              pw.SizedBox(height: 20),
              _buildCompanyInfo(),
              pw.SizedBox(height: 30),
              _buildDeliveryTitle(),
              pw.SizedBox(height: 20),
              _buildDeliveryDetails(deliveryData, driverData),
              pw.SizedBox(height: 30),
              _buildDeliveryMap(),
              pw.Spacer(),
              _buildInvoiceFooter(),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  // ドライバー別売上明細書
  static Future<void> generateDriverSalesReport({
    required String month,
    required Map<String, dynamic> driverInfo,
    required List<Map<String, dynamic>> salesData,
    required Map<String, dynamic> summary,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildInvoiceHeader(),
            pw.SizedBox(height: 20),
            _buildDriverInfo(driverInfo),
            pw.SizedBox(height: 30),
            _buildInvoiceTitle('ドライバー売上明細書', month),
            pw.SizedBox(height: 20),
            _buildDriverSummary(summary),
            pw.SizedBox(height: 20),
            _buildDriverSalesTable(salesData),
            pw.SizedBox(height: 30),
            _buildPaymentInfo(summary),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  // ヘッダー部分
  static pw.Widget _buildInvoiceHeader() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '軽貨物業務管理システム',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              'Cargo Management System',
              style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
            ),
          ],
        ),
        pw.Container(
          width: 80,
          height: 80,
          decoration: pw.BoxDecoration(
            color: PdfColors.blue100,
            borderRadius: pw.BorderRadius.circular(40),
          ),
          child: pw.Center(
            child: pw.Text(
              '🚛',
              style: pw.TextStyle(fontSize: 40),
            ),
          ),
        ),
      ],
    );
  }

  // 会社情報
  static pw.Widget _buildCompanyInfo() {
    return pw.Container(
      padding: pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '株式会社ダブルエッチ',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text('〒000-0000 東京都○○区○○ 1-2-3'),
          pw.Text('TEL: 03-1234-5678'),
          pw.Text('Email: info@doubletech.co.jp'),
        ],
      ),
    );
  }

  // 請求書タイトル
  static pw.Widget _buildInvoiceTitle(String title, String month) {
    final monthNames = {
      '01': '1月',
      '02': '2月',
      '03': '3月',
      '04': '4月',
      '05': '5月',
      '06': '6月',
      '07': '7月',
      '08': '8月',
      '09': '9月',
      '10': '10月',
      '11': '11月',
      '12': '12月'
    };

    final parts = month.split('-');
    final year = parts[0];
    final monthNum = parts[1];
    final monthName = monthNames[monthNum] ?? monthNum;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          '対象期間: ${year}年${monthName}',
          style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
        ),
        pw.Text(
          '作成日: ${DateTime.now().year}年${DateTime.now().month}月${DateTime.now().day}日',
          style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
        ),
      ],
    );
  }

  // 売上サマリー
  static pw.Widget _buildSalesSummary(Map<String, dynamic> summary) {
    return pw.Container(
      padding: pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.blue200),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
              '総売上', '¥${(summary['totalSales'] ?? 0).toStringAsFixed(0)}'),
          _buildSummaryItem('配送件数', '${summary['totalTransactions'] ?? 0}件'),
          _buildSummaryItem('手数料総額',
              '¥${(summary['totalCommission'] ?? 0).toStringAsFixed(0)}'),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(label,
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800),
        ),
      ],
    );
  }

  // 売上テーブル
  static pw.Widget _buildSalesTable(List<Map<String, dynamic>> salesData) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(1.5),
        4: pw.FlexColumnWidth(1.5),
      },
      children: [
        // ヘッダー
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableHeader('配送案件ID'),
            _buildTableHeader('ドライバー'),
            _buildTableHeader('売上金額'),
            _buildTableHeader('手数料'),
            _buildTableHeader('純利益'),
          ],
        ),
        // データ行
        ...salesData.map((sale) => pw.TableRow(
              children: [
                _buildTableCell(
                    sale['deliveryId']?.toString().substring(0, 8) ?? '未設定'),
                _buildTableCell(sale['driverName'] ?? '未設定'),
                _buildTableCell('¥${(sale['amount'] ?? 0).toStringAsFixed(0)}'),
                _buildTableCell(
                    '¥${(sale['commission'] ?? 0).toStringAsFixed(0)}'),
                _buildTableCell(
                    '¥${(sale['netAmount'] ?? 0).toStringAsFixed(0)}'),
              ],
            )),
      ],
    );
  }

  static pw.Widget _buildTableHeader(String text) {
    return pw.Container(
      padding: pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildTableCell(String text) {
    return pw.Container(
      padding: pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 9),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  // 配送詳細
  static pw.Widget _buildDeliveryDetails(
      Map<String, dynamic> delivery, Map<String, dynamic> driver) {
    return pw.Container(
      padding: pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildDetailRow('案件名', delivery['title'] ?? '未設定'),
          _buildDetailRow('クライアント', delivery['client'] ?? '未設定'),
          _buildDetailRow('ドライバー', driver['name'] ?? '未設定'),
          _buildDetailRow('車両',
              '${driver['vehicleType'] ?? '未設定'} (${driver['vehicleNumber'] ?? '未設定'})'),
          pw.SizedBox(height: 10),
          _buildDetailRow(
              '集荷先', delivery['pickupLocation']?['address'] ?? '未設定'),
          _buildDetailRow(
              '配送先', delivery['deliveryLocation']?['address'] ?? '未設定'),
          pw.SizedBox(height: 10),
          _buildDetailRow(
              '配送料金', '¥${(delivery['price'] ?? 0).toStringAsFixed(0)}'),
          _buildDetailRow('重量', delivery['weight'] ?? '未設定'),
          if (delivery['notes']?.isNotEmpty ?? false)
            _buildDetailRow('備考', delivery['notes']),
        ],
      ),
    );
  }

  static pw.Widget _buildDetailRow(String label, String value) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value, style: pw.TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  // ドライバー情報
  static pw.Widget _buildDriverInfo(Map<String, dynamic> driver) {
    return pw.Container(
      padding: pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.orange50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'ドライバー情報',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          _buildDetailRow('氏名', driver['name'] ?? '未設定'),
          _buildDetailRow('電話番号', driver['phone'] ?? '未設定'),
          _buildDetailRow('車両',
              '${driver['vehicleType'] ?? '未設定'} (${driver['vehicleNumber'] ?? '未設定'})'),
        ],
      ),
    );
  }

  // ドライバー売上テーブル
  static pw.Widget _buildDriverSalesTable(
      List<Map<String, dynamic>> salesData) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(1.5),
      },
      children: [
        // ヘッダー
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.orange100),
          children: [
            _buildTableHeader('配送日'),
            _buildTableHeader('案件名'),
            _buildTableHeader('売上金額'),
            _buildTableHeader('純利益'),
          ],
        ),
        // データ行
        ...salesData.map((sale) => pw.TableRow(
              children: [
                _buildTableCell(_formatDate(sale['createdAt'])),
                _buildTableCell(sale['deliveryTitle'] ?? '未設定'),
                _buildTableCell('¥${(sale['amount'] ?? 0).toStringAsFixed(0)}'),
                _buildTableCell(
                    '¥${(sale['netAmount'] ?? 0).toStringAsFixed(0)}'),
              ],
            )),
      ],
    );
  }

  // ドライバーサマリー
  static pw.Widget _buildDriverSummary(Map<String, dynamic> summary) {
    return pw.Container(
      padding: pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.orange50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.orange200),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('総配送数', '${summary['totalDeliveries'] ?? 0}件'),
          _buildSummaryItem(
              '総売上', '¥${(summary['totalSales'] ?? 0).toStringAsFixed(0)}'),
          _buildSummaryItem(
              '純利益', '¥${(summary['netAmount'] ?? 0).toStringAsFixed(0)}'),
        ],
      ),
    );
  }

  // 支払い情報
  static pw.Widget _buildPaymentInfo(Map<String, dynamic> summary) {
    return pw.Container(
      padding: pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.green200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '支払い情報',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text('支払予定額: ¥${(summary['netAmount'] ?? 0).toStringAsFixed(0)}'),
          pw.Text(
              '支払予定日: ${DateTime.now().add(Duration(days: 30)).year}年${DateTime.now().add(Duration(days: 30)).month}月${DateTime.now().add(Duration(days: 30)).day}日'),
          pw.Text('振込先: ○○銀行 ○○支店 普通 1234567'),
        ],
      ),
    );
  }

  // 配送マップ（プレースホルダー）
  static pw.Widget _buildDeliveryMap() {
    return pw.Container(
      height: 150,
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Center(
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text('🗺️', style: pw.TextStyle(fontSize: 40)),
            pw.Text('配送ルートマップ', style: pw.TextStyle(color: PdfColors.grey600)),
          ],
        ),
      ),
    );
  }

  // 配送タイトル
  static pw.Widget _buildDeliveryTitle() {
    return pw.Text(
      '配送完了明細書',
      style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
    );
  }

  // フッター
  static pw.Widget _buildInvoiceFooter() {
    return pw.Container(
      padding: pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            'この明細書に関するお問い合わせ',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text('株式会社ダブルエッチ 業務管理部'),
          pw.Text('TEL: 03-1234-5678 Email: billing@doubletech.co.jp'),
        ],
      ),
    );
  }

  // 日付フォーマット
  static String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '未設定';

    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return '未設定';
    }

    return '${date.month}/${date.day}';
  }
}
