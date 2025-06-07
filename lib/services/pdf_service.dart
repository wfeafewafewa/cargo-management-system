// lib/services/pdf_service.dart - 本番環境対応版
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class PdfService {
  static final _dateFormat = DateFormat('yyyy/MM/dd');
  static final _currencyFormat = NumberFormat('#,###');

  // 本番環境対応フォント読み込み
  static Future<pw.Font?> _loadProductionSafeFont() async {
    // 本番環境では段階的フォールバック戦略を使用
    try {
      // 戦略1: PdfGoogleFonts（最も安全）
      print('🌐 本番環境: PdfGoogleFonts試行中...');
      final font = await PdfGoogleFonts.notoSansJPRegular();
      print('✅ 本番環境: PdfGoogleFonts成功');
      return font;
    } catch (e1) {
      print('❌ 本番環境: PdfGoogleFonts失敗 - $e1');

      try {
        // 戦略2: 代替Google Font
        print('🔄 本番環境: 代替フォント試行中...');
        final font = await PdfGoogleFonts.nanumGothicRegular();
        print('✅ 本番環境: 代替フォント成功');
        return font;
      } catch (e2) {
        print('❌ 本番環境: 代替フォント失敗 - $e2');

        try {
          // 戦略3: アセットフォント（エラーハンドリング強化）
          print('📁 本番環境: アセットフォント試行中...');
          final fontData =
              await rootBundle.load('assets/fonts/NotoSansJP-Regular.ttf');

          // データ検証
          if (fontData.lengthInBytes < 1000) {
            throw Exception(
                'フォントファイルサイズが小さすぎます: ${fontData.lengthInBytes} bytes');
          }

          final font = pw.Font.ttf(fontData);
          print('✅ 本番環境: アセットフォント成功');
          return font;
        } catch (e3) {
          print('❌ 本番環境: アセットフォント失敗 - $e3');

          // 戦略4: 最終フォールバック（フォントなし）
          print('⚠️ 本番環境: 全フォント失敗 - デフォルトフォント使用');
          return null;
        }
      }
    }
  }

  // 請求書PDF生成（本番環境対応版）
  static Future<Uint8List> generateInvoice({
    required String customerId,
    required String customerName,
    required List<Map<String, dynamic>> deliveries,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final pdf = pw.Document();

      // 合計金額計算
      final totalAmount = deliveries.fold<int>(
        0,
        (sum, delivery) => sum + ((delivery['fee'] as int?) ?? 0),
      );

      // 本番環境対応フォント読み込み
      final jpFont = await _loadProductionSafeFont();
      final jpBoldFont = jpFont; // 同じフォントを使用

      final fontStatus = jpFont != null ? '日本語フォント成功' : '英語のみ（フォント失敗）';
      print('📋 本番環境PDF生成: $fontStatus');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          theme: jpFont != null
              ? pw.ThemeData.withFont(
                  base: jpFont,
                  bold: jpBoldFont,
                  italic: jpFont,
                  boldItalic: jpBoldFont,
                )
              : pw.ThemeData(),
          build: (pw.Context context) {
            return [
              // 本番環境ステータス表示
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color:
                      jpFont != null ? PdfColors.green50 : PdfColors.orange50,
                  border: pw.Border.all(
                      color: jpFont != null
                          ? PdfColors.green300
                          : PdfColors.orange300,
                      width: 2),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      jpFont != null ? '🎉 本番環境: 日本語対応完了' : '⚠️ 本番環境: 英語モード',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: jpFont != null
                            ? PdfColors.green700
                            : PdfColors.orange700,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Version: v1.1-pdf-complete | Environment: Production',
                      style:
                          pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // 日本語テスト（成功時のみ）
              if (jpFont != null) ...[
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    border: pw.Border.all(color: PdfColors.blue200),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text(
                    '🇯🇵 本番環境日本語テスト: 株式会社ダブルエッチ 請求書 山田商事',
                    style: pw.TextStyle(
                        fontSize: 14, font: jpFont, color: PdfColors.blue800),
                  ),
                ),
                pw.SizedBox(height: 30),
              ],

              // 実際の請求書内容
              _buildInvoiceHeader(jpFont, jpBoldFont),
              pw.SizedBox(height: 30),
              _buildInvoiceInfo(customerName, startDate, endDate, jpFont),
              pw.SizedBox(height: 30),
              _buildInvoiceTable(deliveries, jpFont),
              pw.SizedBox(height: 20),
              _buildInvoiceSummary(totalAmount, jpFont, jpBoldFont),
              pw.SizedBox(height: 30),
              _buildInvoiceFooter(jpFont),
            ];
          },
        ),
      );

      final pdfBytes = await pdf.save();
      print('✅ 本番環境PDF生成成功: ${pdfBytes.length} bytes');
      return pdfBytes;
    } catch (e, stackTrace) {
      print('❌ 本番環境PDF生成エラー: $e');
      print('スタックトレース: $stackTrace');

      // 緊急フォールバック: 最小限の英語PDF
      return await _generateFallbackInvoice(customerName, deliveries,
          totalAmount: deliveries.fold<int>(
              0, (sum, delivery) => sum + ((delivery['fee'] as int?) ?? 0)));
    }
  }

  // 緊急フォールバック: 英語のみPDF
  static Future<Uint8List> _generateFallbackInvoice(
    String customerName,
    List<Map<String, dynamic>> deliveries, {
    required int totalAmount,
  }) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // 緊急モード表示
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.red50,
                    border: pw.Border.all(color: PdfColors.red300, width: 2),
                  ),
                  child: pw.Text(
                    '🚨 EMERGENCY MODE: Fallback English-Only Invoice',
                    style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red700),
                  ),
                ),
                pw.SizedBox(height: 30),

                // シンプルなヘッダー
                pw.Text(
                  'INVOICE',
                  style: pw.TextStyle(
                      fontSize: 32,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800),
                ),
                pw.SizedBox(height: 20),

                // 基本情報
                pw.Text('Bill To: $customerName',
                    style: pw.TextStyle(fontSize: 16)),
                pw.SizedBox(height: 10),
                pw.Text('Date: ${DateTime.now().toString().split(' ')[0]}',
                    style: pw.TextStyle(fontSize: 14)),
                pw.SizedBox(height: 30),

                // 簡易テーブル
                pw.Text('Items:',
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                ...deliveries.asMap().entries.map((entry) {
                  final index = entry.key;
                  final delivery = entry.value;
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 5),
                    child: pw.Text(
                      '${index + 1}. ${delivery['projectName'] ?? 'Project'} - ¥${_currencyFormat.format(delivery['fee'] ?? 0)}',
                      style: pw.TextStyle(fontSize: 12),
                    ),
                  );
                }).toList(),

                pw.Spacer(),

                // 合計
                pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    border: pw.Border.all(color: PdfColors.blue200),
                  ),
                  child: pw.Text(
                    'Total Amount: ¥${_currencyFormat.format((totalAmount * 1.1).round())} (inc. tax)',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        ),
      );

      return await pdf.save();
    } catch (e) {
      print('❌ 緊急フォールバックも失敗: $e');
      rethrow;
    }
  }

  // 支払通知書PDF生成（本番環境対応版）
  static Future<Uint8List> generatePaymentNotice({
    required String driverId,
    required String driverName,
    required List<Map<String, dynamic>> workReports,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final pdf = pw.Document();
      final totalPayment = workReports.fold<int>(
          0, (sum, report) => sum + ((report['totalAmount'] as int?) ?? 0));

      // 本番環境対応フォント読み込み
      final jpFont = await _loadProductionSafeFont();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          theme: jpFont != null
              ? pw.ThemeData.withFont(base: jpFont, bold: jpFont)
              : pw.ThemeData(),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // ヘッダー
                pw.Text(
                  jpFont != null ? '支払通知書' : 'PAYMENT NOTICE',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    font: jpFont,
                    color: PdfColors.green700,
                  ),
                ),
                pw.SizedBox(height: 30),

                // 基本情報
                pw.Text(
                  jpFont != null
                      ? '支払対象者: $driverName'
                      : 'Payment To: $driverName',
                  style: pw.TextStyle(fontSize: 16, font: jpFont),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  jpFont != null
                      ? '期間: ${_dateFormat.format(startDate)} ～ ${_dateFormat.format(endDate)}'
                      : 'Period: ${_dateFormat.format(startDate)} - ${_dateFormat.format(endDate)}',
                  style: pw.TextStyle(fontSize: 14, font: jpFont),
                ),

                pw.Spacer(),

                // 総支払額
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(20),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green50,
                      border: pw.Border.all(color: PdfColors.green200),
                    ),
                    child: pw.Text(
                      jpFont != null
                          ? '総支払額: ¥${_currencyFormat.format(totalPayment)}'
                          : 'Total Payment: ¥${_currencyFormat.format(totalPayment)}',
                      style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          font: jpFont),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

      return await pdf.save();
    } catch (e) {
      print('❌ 支払通知書生成エラー: $e');
      rethrow;
    }
  }

  // ===== 共通コンポーネント =====

  static pw.Widget _buildInvoiceHeader(pw.Font? jpFont, pw.Font? jpBoldFont) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              jpFont != null ? '請求書' : 'INVOICE',
              style: pw.TextStyle(
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
                font: jpBoldFont ?? jpFont,
                color: PdfColors.blue800,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'INVOICE',
              style: pw.TextStyle(fontSize: 14, color: PdfColors.grey600),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              jpFont != null ? '株式会社ダブルエッチ' : 'Double-H Corporation',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                font: jpBoldFont ?? jpFont,
              ),
            ),
            pw.Text(
              'TEL: 000-0000-0000',
              style: pw.TextStyle(fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildInvoiceInfo(String customerName, DateTime startDate,
      DateTime endDate, pw.Font? jpFont) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            jpFont != null ? '請求先: $customerName' : 'Bill To: $customerName',
            style: pw.TextStyle(
                fontSize: 16, fontWeight: pw.FontWeight.bold, font: jpFont),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            jpFont != null
                ? '請求期間: ${_dateFormat.format(startDate)} ～ ${_dateFormat.format(endDate)}'
                : 'Billing Period: ${_dateFormat.format(startDate)} - ${_dateFormat.format(endDate)}',
            style: pw.TextStyle(fontSize: 14, font: jpFont),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildInvoiceTable(
      List<Map<String, dynamic>> deliveries, pw.Font? jpFont) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        // ヘッダー
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableCell('No.', jpFont, isHeader: true),
            _buildTableCell(jpFont != null ? '案件名' : 'Project', jpFont,
                isHeader: true),
            _buildTableCell(jpFont != null ? '金額' : 'Amount', jpFont,
                isHeader: true),
          ],
        ),
        // データ行
        ...deliveries.asMap().entries.map((entry) {
          final index = entry.key;
          final delivery = entry.value;
          return pw.TableRow(
            children: [
              _buildTableCell('${index + 1}', jpFont),
              _buildTableCell(delivery['projectName'] ?? 'Project', jpFont),
              _buildTableCell(
                  '¥${_currencyFormat.format(delivery['fee'] ?? 0)}', jpFont),
            ],
          );
        }).toList(),
      ],
    );
  }

  static pw.Widget _buildInvoiceSummary(
      int totalAmount, pw.Font? jpFont, pw.Font? jpBoldFont) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 200,
        padding: const pw.EdgeInsets.all(20),
        decoration: pw.BoxDecoration(
          color: PdfColors.blue50,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: PdfColors.blue200),
        ),
        child: pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(jpFont != null ? '小計' : 'Subtotal',
                    style: pw.TextStyle(fontSize: 14, font: jpFont)),
                pw.Text('¥${_currencyFormat.format(totalAmount)}',
                    style: pw.TextStyle(fontSize: 14)),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(jpFont != null ? '消費税(10%)' : 'Tax(10%)',
                    style: pw.TextStyle(fontSize: 14, font: jpFont)),
                pw.Text(
                    '¥${_currencyFormat.format((totalAmount * 0.1).round())}',
                    style: pw.TextStyle(fontSize: 14)),
              ],
            ),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  jpFont != null ? '合計金額' : 'Total',
                  style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      font: jpBoldFont ?? jpFont),
                ),
                pw.Text(
                  '¥${_currencyFormat.format((totalAmount * 1.1).round())}',
                  style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildInvoiceFooter(pw.Font? jpFont) {
    return pw.Text(
      jpFont != null
          ? 'ご不明な点がございましたらお気軽にお問い合わせください。'
          : 'Please contact us if you have any questions.',
      style: pw.TextStyle(fontSize: 10, font: jpFont),
    );
  }

  static pw.Widget _buildTableCell(String text, pw.Font? jpFont,
      {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 12 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          font: jpFont,
        ),
        textAlign: isHeader ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }

  // ===== PDF表示・印刷・ダウンロード機能 =====

  static Future<void> printPdf(Uint8List pdfBytes, String title) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: title,
    );
  }

  static Future<void> downloadPdf(Uint8List pdfBytes, String filename) async {
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: filename,
    );
  }

  static Future<void> previewPdf(Uint8List pdfBytes, String title) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: title,
    );
  }
}
