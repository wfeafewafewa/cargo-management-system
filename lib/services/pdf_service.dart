// lib/services/web_pdf_service.dart - Web環境対応版
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class WebPdfService {
  static final _dateFormat = DateFormat('yyyy/MM/dd');
  static final _currencyFormat = NumberFormat('#,###');

  // Web環境専用フォント読み込み
  static Future<pw.Font?> _loadWebSafeFont() async {
    if (!kIsWeb) {
      print('⚠️ 非Web環境では使用できません');
      return null;
    }

    try {
      // Web環境では段階的フォールバック戦略を使用
      print('🌐 Web環境: PdfGoogleFonts試行中...');

      // Google Fontsから直接読み込み（最も安全）
      final font = await PdfGoogleFonts.notoSansJPRegular();
      print('✅ Web環境: PdfGoogleFonts成功');
      return font;
    } catch (e1) {
      print('❌ Web環境: PdfGoogleFonts失敗 - $e1');

      try {
        // 代替Google Font
        print('🔄 Web環境: 代替フォント試行中...');
        final font = await PdfGoogleFonts.nanumGothicRegular();
        print('✅ Web環境: 代替フォント成功');
        return font;
      } catch (e2) {
        print('❌ Web環境: 代替フォント失敗 - $e2');
        print('⚠️ Web環境: デフォルトフォント使用');
        return null;
      }
    }
  }

  // Web環境対応請求書PDF生成
  static Future<Uint8List> generateWebInvoice({
    required String customerId,
    required String customerName,
    required List<Map<String, dynamic>> deliveries,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      print('🚀 Web環境でPDF生成開始...');

      final pdf = pw.Document();

      // 合計金額計算
      final totalAmount = deliveries.fold<int>(
        0,
        (sum, delivery) => sum + ((delivery['fee'] as int?) ?? 0),
      );

      // Web環境対応フォント読み込み
      final jpFont = await _loadWebSafeFont();

      print('📝 PDF生成中... 総額: ¥${_currencyFormat.format(totalAmount)}');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          theme: jpFont != null
              ? pw.ThemeData.withFont(
                  base: jpFont,
                  bold: jpFont,
                )
              : pw.ThemeData(),
          build: (pw.Context context) {
            return [
              // Web環境ステータス表示
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  border: pw.Border.all(color: PdfColors.blue300, width: 2),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '🌐 Web環境対応版 - Vercel Production',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue700,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Generated: ${DateTime.now().toString()}',
                      style:
                          pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // 請求書ヘッダー
              _buildWebInvoiceHeader(jpFont),
              pw.SizedBox(height: 30),

              // 請求書情報
              _buildWebInvoiceInfo(customerName, startDate, endDate, jpFont),
              pw.SizedBox(height: 30),

              // 請求書テーブル
              _buildWebInvoiceTable(deliveries, jpFont),
              pw.SizedBox(height: 20),

              // 請求書サマリー
              _buildWebInvoiceSummary(totalAmount, jpFont),
              pw.SizedBox(height: 30),

              // フッター
              _buildWebInvoiceFooter(jpFont),
            ];
          },
        ),
      );

      final pdfBytes = await pdf.save();
      print('✅ Web PDF生成成功: ${pdfBytes.length} bytes');

      // Web環境でのバイト配列検証
      if (pdfBytes.isEmpty) {
        throw Exception('PDFバイト配列が空です');
      }

      if (pdfBytes.length < 1000) {
        throw Exception('PDFファイルサイズが異常に小さいです: ${pdfBytes.length} bytes');
      }

      return pdfBytes;
    } catch (e, stackTrace) {
      print('❌ Web PDF生成エラー: $e');
      print('スタックトレース: $stackTrace');

      // 緊急フォールバック
      return await _generateWebFallbackInvoice(
          customerName, deliveries, totalAmount);
    }
  }

  // Web環境対応の緊急フォールバック
  static Future<Uint8List> _generateWebFallbackInvoice(
    String customerName,
    List<Map<String, dynamic>> deliveries,
    int totalAmount,
  ) async {
    try {
      print('🚨 Web緊急フォールバック実行中...');

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
                    color: PdfColors.orange50,
                    border: pw.Border.all(color: PdfColors.orange300, width: 2),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '🚨 EMERGENCY MODE: Simple Invoice',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.orange700,
                        ),
                      ),
                      pw.Text(
                        'Web Environment Fallback - Vercel Production',
                        style: pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 30),

                // シンプルなヘッダー
                pw.Text(
                  'INVOICE / 請求書',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.SizedBox(height: 20),

                // 基本情報
                pw.Text(
                  'Bill To: $customerName',
                  style: pw.TextStyle(fontSize: 16),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Date: ${_dateFormat.format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 14),
                ),
                pw.SizedBox(height: 30),

                // アイテム一覧
                pw.Text(
                  'Items:',
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
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

                // 合計金額
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    border: pw.Border.all(color: PdfColors.blue200),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'Total Amount (税込): ¥${_currencyFormat.format((totalAmount * 1.1).round())}',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'Subtotal: ¥${_currencyFormat.format(totalAmount)} + Tax: ¥${_currencyFormat.format((totalAmount * 0.1).round())}',
                        style: pw.TextStyle(
                            fontSize: 12, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      final bytes = await pdf.save();
      print('✅ Web緊急フォールバック成功: ${bytes.length} bytes');
      return bytes;
    } catch (e) {
      print('❌ Web緊急フォールバックも失敗: $e');
      rethrow;
    }
  }

  // Web環境専用ダウンロード機能
  static void downloadWebPdf(Uint8List pdfBytes, String filename) {
    try {
      print('📥 Web環境でPDFダウンロード開始: $filename');

      // Blobを作成
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);

      // ダウンロードリンクを作成
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..style.display = 'none';

      // DOMに追加してクリック
      html.document.body!.children.add(anchor);
      anchor.click();

      // クリーンアップ
      html.document.body!.children.remove(anchor);
      html.Url.revokeObjectUrl(url);

      print('✅ Web PDFダウンロード成功');
    } catch (e) {
      print('❌ Web PDFダウンロードエラー: $e');
      rethrow;
    }
  }

  // Web環境専用プレビュー機能
  static void previewWebPdf(Uint8List pdfBytes, String title) {
    try {
      print('👁️ Web環境でPDFプレビュー開始: $title');

      // Blobを作成
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);

      // 新しいタブで開く
      html.window.open(url, '_blank');

      print('✅ Web PDFプレビュー成功');
    } catch (e) {
      print('❌ Web PDFプレビューエラー: $e');
      rethrow;
    }
  }

  // ===== Web環境専用コンポーネント =====

  static pw.Widget _buildWebInvoiceHeader(pw.Font? jpFont) {
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
                font: jpFont,
                color: PdfColors.blue800,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Web Generated Invoice',
              style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
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
                font: jpFont,
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

  static pw.Widget _buildWebInvoiceInfo(String customerName, DateTime startDate,
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

  static pw.Widget _buildWebInvoiceTable(
      List<Map<String, dynamic>> deliveries, pw.Font? jpFont) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        // ヘッダー
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildWebTableCell('No.', jpFont, isHeader: true),
            _buildWebTableCell(jpFont != null ? '案件名' : 'Project', jpFont,
                isHeader: true),
            _buildWebTableCell(jpFont != null ? '金額' : 'Amount', jpFont,
                isHeader: true),
          ],
        ),
        // データ行
        ...deliveries.asMap().entries.map((entry) {
          final index = entry.key;
          final delivery = entry.value;
          return pw.TableRow(
            children: [
              _buildWebTableCell('${index + 1}', jpFont),
              _buildWebTableCell(delivery['projectName'] ?? 'Project', jpFont),
              _buildWebTableCell(
                  '¥${_currencyFormat.format(delivery['fee'] ?? 0)}', jpFont),
            ],
          );
        }).toList(),
      ],
    );
  }

  static pw.Widget _buildWebInvoiceSummary(int totalAmount, pw.Font? jpFont) {
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
                      font: jpFont),
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

  static pw.Widget _buildWebInvoiceFooter(pw.Font? jpFont) {
    return pw.Text(
      jpFont != null
          ? 'ご不明な点がございましたらお気軽にお問い合わせください。'
          : 'Please contact us if you have any questions.',
      style: pw.TextStyle(fontSize: 10, font: jpFont),
    );
  }

  static pw.Widget _buildWebTableCell(String text, pw.Font? jpFont,
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
}
