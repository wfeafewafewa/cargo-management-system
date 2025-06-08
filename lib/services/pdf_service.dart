// lib/services/pdf_service.dart - Web環境エラー修正版
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

// Web環境用の条件付きインポート
import 'dart:html' as html' if (dart.library.io) 'dart:io';

class PdfService {
  static final _dateFormat = DateFormat('yyyy/MM/dd');
  static final _currencyFormat = NumberFormat('#,###');

  // Web環境対応フォント読み込み（エラー修正版）
  static Future<pw.Font?> _loadWebSafeFont() async {
    try {
      if (kIsWeb) {
        print('🌐 Web環境: 安全なフォント読み込み開始');
        
        // Web環境では PdfGoogleFonts のみ使用（最も安全）
        try {
          final font = await PdfGoogleFonts.notoSansJPRegular();
          print('✅ Web環境: PdfGoogleFonts成功');
          return font;
        } catch (e) {
          print('⚠️ Web環境: フォント読み込み失敗、デフォルト使用 - $e');
          return null;
        }
      } else {
        // モバイル環境でのフォント読み込み
        print('📱 モバイル環境: アセットフォント読み込み');
        try {
          final fontData = await rootBundle.load('assets/fonts/NotoSansJP-Regular.ttf');
          return pw.Font.ttf(fontData);
        } catch (e) {
          print('⚠️ モバイル環境: フォント読み込み失敗 - $e');
          return null;
        }
      }
    } catch (e) {
      print('❌ フォント読み込み全般エラー: $e');
      return null;
    }
  }

  // 請求書PDF生成（Web環境エラー修正版）
  static Future<Uint8List> generateInvoice({
    required String customerId,
    required String customerName,
    required List<Map<String, dynamic>> deliveries,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      print('🚀 PDF生成開始 - 環境: ${kIsWeb ? "Web" : "Mobile"}');
      
      // バリデーション
      if (deliveries.isEmpty) {
        throw ArgumentError('配送データが空です');
      }

      final pdf = pw.Document();

      // 合計金額計算（安全な計算）
      int totalAmount = 0;
      for (final delivery in deliveries) {
        final fee = delivery['fee'];
        if (fee is int) {
          totalAmount += fee;
        } else if (fee is double) {
          totalAmount += fee.round();
        } else if (fee is String) {
          totalAmount += int.tryParse(fee) ?? 0;
        }
      }

      print('💰 合計金額計算完了: ¥${_currencyFormat.format(totalAmount)}');

      // フォント読み込み
      final jpFont = await _loadWebSafeFont();
      final fontStatus = jpFont != null ? '日本語対応' : '英語のみ';
      print('🔤 フォント状態: $fontStatus');

      // PDF生成（エラー対策版）
      try {
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(40),
            theme: jpFont != null
                ? pw.ThemeData.withFont(base: jpFont, bold: jpFont)
                : pw.ThemeData(),
            build: (pw.Context context) {
              return _buildInvoiceContent(
                customerName, 
                deliveries, 
                totalAmount, 
                startDate, 
                endDate, 
                jpFont,
                kIsWeb
              );
            },
          ),
        );

        print('📄 PDFページ作成完了');

        // PDF保存（エラー対策版）
        final Uint8List pdfBytes;
        try {
          pdfBytes = await pdf.save();
          print('💾 PDF保存完了: ${pdfBytes.length} bytes');
        } catch (saveError) {
          print('❌ PDF保存エラー: $saveError');
          throw Exception('PDF保存に失敗しました: $saveError');
        }

        // バイト配列検証
        if (pdfBytes.isEmpty) {
          throw Exception('生成されたPDFが空です');
        }

        if (pdfBytes.length < 100) {
          throw Exception('PDFサイズが異常に小さいです: ${pdfBytes.length} bytes');
        }

        print('✅ PDF生成成功: ${pdfBytes.length} bytes');
        return pdfBytes;

      } catch (pdfError) {
        print('❌ PDF生成処理エラー: $pdfError');
        // 緊急フォールバック実行
        return await _generateSimpleInvoice(customerName, totalAmount);
      }

    } catch (e, stackTrace) {
      print('❌ PDF生成全般エラー: $e');
      print('スタックトレース: $stackTrace');
      
      // 最終フォールバック
      try {
        return await _generateMinimalInvoice(customerName);
      } catch (fallbackError) {
        print('❌ 最終フォールバックも失敗: $fallbackError');
        rethrow;
      }
    }
  }

  // Web環境対応PDF表示・ダウンロード
  static Future<void> printPdf(Uint8List pdfBytes, String title) async {
    try {
      if (kIsWeb) {
        // Web環境: ダウンロード実行
        print('🌐 Web環境: PDFダウンロード開始');
        _downloadWebPdf(pdfBytes, title);
      } else {
        // モバイル環境: 既存の printing パッケージ使用
        print('📱 モバイル環境: PDF印刷開始');
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
          name: title,
        );
      }
    } catch (e) {
      print('❌ PDF表示エラー: $e');
      if (kIsWeb) {
        // Web環境でのフォールバック
        _showWebPdfError();
      } else {
        rethrow;
      }
    }
  }

  // Web環境専用ダウンロード（修正版）
  static void _downloadWebPdf(Uint8List pdfBytes, String filename) {
    try {
      if (!kIsWeb) return;
      
      print('📥 Web PDFダウンロード実行: $filename');
      
      // ファイル名を安全な形式に
      final safeFilename = filename.replaceAll(RegExp(r'[^\w\-_\.]'), '_');
      final finalFilename = safeFilename.endsWith('.pdf') 
          ? safeFilename 
          : '$safeFilename.pdf';

      // Web環境でのダウンロード実装
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', finalFilename)
        ..style.display = 'none';
      
      html.document.body!.appendChild(anchor);
      anchor.click();
      html.document.body!.removeChild(anchor);
      
      // メモリクリーンアップ
      html.Url.revokeObjectUrl(url);
      
      print('✅ Web PDFダウンロード成功');
      
    } catch (e) {
      print('❌ Web PDFダウンロードエラー: $e');
      _showWebPdfError();
    }
  }

  // Web環境エラー表示
  static void _showWebPdfError() {
    if (kIsWeb) {
      html.window.alert('PDFの生成中にエラーが発生しました。ページをリロードして再試行してください。');
    }
  }

  // 緊急フォールバック: シンプル請求書
  static Future<Uint8List> _generateSimpleInvoice(String customerName, int totalAmount) async {
    try {
      print('🚨 緊急フォールバック: シンプル請求書生成');
      
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
                    border: pw.Border.all(color: PdfColors.orange300),
                  ),
                  child: pw.Text(
                    '🚨 EMERGENCY MODE - Simple Invoice',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.orange700,
                    ),
                  ),
                ),
                pw.SizedBox(height: 30),

                // シンプルヘッダー
                pw.Text(
                  'INVOICE',
                  style: pw.TextStyle(
                    fontSize: 32,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.SizedBox(height: 30),

                // 基本情報
                pw.Text('Bill To: $customerName', style: pw.TextStyle(fontSize: 16)),
                pw.SizedBox(height: 10),
                pw.Text('Date: ${_dateFormat.format(DateTime.now())}', style: pw.TextStyle(fontSize: 14)),
                
                pw.Spacer(),

                // 合計のみ表示
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(20),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      border: pw.Border.all(color: PdfColors.blue200),
                    ),
                    child: pw.Text(
                      'Total: ¥${_currencyFormat.format((totalAmount * 1.1).round())} (inc. tax)',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
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
      print('❌ 緊急フォールバック失敗: $e');
      rethrow;
    }
  }

  // 最終フォールバック: 最小限請求書
  static Future<Uint8List> _generateMinimalInvoice(String customerName) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text('INVOICE', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 20),
                pw.Text('Bill To: $customerName', style: pw.TextStyle(fontSize: 16)),
                pw.SizedBox(height: 20),
                pw.Text('Date: ${_dateFormat.format(DateTime.now())}', style: pw.TextStyle(fontSize: 14)),
                pw.SizedBox(height: 40),
                pw.Text(
                  'PDF generation error occurred.\nPlease contact support.',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );

    return await pdf.save();
  }

  // PDF内容構築（共通）
  static List<pw.Widget> _buildInvoiceContent(
    String customerName,
    List<Map<String, dynamic>> deliveries,
    int totalAmount,
    DateTime startDate,
    DateTime endDate,
    pw.Font? jpFont,
    bool isWeb,
  ) {
    return [
      // 環境表示
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(15),
        decoration: pw.BoxDecoration(
          color: isWeb ? PdfColors.blue50 : PdfColors.green50,
          border: pw.Border.all(
            color: isWeb ? PdfColors.blue300 : PdfColors.green300,
            width: 2,
          ),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Text(
          isWeb 
              ? '🌐 Web環境生成 - エラー修正版'
              : '📱 モバイル環境生成',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: isWeb ? PdfColors.blue700 : PdfColors.green700,
          ),
        ),
      ),
      pw.SizedBox(height: 20),

      // ヘッダー
      _buildInvoiceHeader(jpFont),
      pw.SizedBox(height: 30),
      
      // 請求情報
      _buildInvoiceInfo(customerName, startDate, endDate, jpFont),
      pw.SizedBox(height: 30),
      
      // テーブル
      _buildInvoiceTable(deliveries, jpFont),
      pw.SizedBox(height: 20),
      
      // 合計
      _buildInvoiceSummary(totalAmount, jpFont),
      pw.SizedBox(height: 30),
      
      // フッター
      _buildInvoiceFooter(jpFont),
    ];
  }

  // 支払通知書生成（エラー修正版）
  static Future<Uint8List> generatePaymentNotice({
    required String driverId,
    required String driverName,
    required List<Map<String, dynamic>> workReports,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final pdf = pw.Document();
      
      // 安全な合計計算
      int totalPayment = 0;
      for (final report in workReports) {
        final amount = report['totalAmount'];
        if (amount is int) {
          totalPayment += amount;
        } else if (amount is double) {
          totalPayment += amount.round();
        }
      }

      final jpFont = await _loadWebSafeFont();

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

                pw.Text(
                  jpFont != null ? '支払対象者: $driverName' : 'Payment To: $driverName',
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
                        font: jpFont,
                      ),
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

  // ===== 共通コンポーネント（既存のまま） =====

  static pw.Widget _buildInvoiceHeader(pw.Font? jpFont) {
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

  static pw.Widget _buildInvoiceInfo(String customerName, DateTime startDate, DateTime endDate, pw.Font? jpFont) {
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
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, font: jpFont),
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

  static pw.Widget _buildInvoiceTable(List<Map<String, dynamic>> deliveries, pw.Font? jpFont) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableCell('No.', jpFont, isHeader: true),
            _buildTableCell(jpFont != null ? '案件名' : 'Project', jpFont, isHeader: true),
            _buildTableCell(jpFont != null ? '金額' : 'Amount', jpFont, isHeader: true),
          ],
        ),
        ...deliveries.asMap().entries.map((entry) {
          final index = entry.key;
          final delivery = entry.value;
          return pw.TableRow(
            children: [
              _buildTableCell('${index + 1}', jpFont),
              _buildTableCell(delivery['projectName'] ?? 'Project', jpFont),
              _buildTableCell('¥${_currencyFormat.format(delivery['fee'] ?? 0)}', jpFont),
            ],
          );
        }).toList(),
      ],
    );
  }

  static pw.Widget _buildInvoiceSummary(int totalAmount, pw.Font? jpFont) {
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
                pw.Text(jpFont != null ? '小計' : 'Subtotal', style: pw.TextStyle(fontSize: 14, font: jpFont)),
                pw.Text('¥${_currencyFormat.format(totalAmount)}', style: pw.TextStyle(fontSize: 14)),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(jpFont != null ? '消費税(10%)' : 'Tax(10%)', style: pw.TextStyle(fontSize: 14, font: jpFont)),
                pw.Text('¥${_currencyFormat.format((totalAmount * 0.1).round())}', style: pw.TextStyle(fontSize: 14)),
              ],
            ),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  jpFont != null ? '合計金額' : 'Total',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, font: jpFont),
                ),
                pw.Text(
                  '¥${_currencyFormat.format((totalAmount * 1.1).round())}',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700),
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

  static pw.Widget _buildTableCell(String text, pw.Font? jpFont, {bool isHeader = false}) {
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

  // 既存メソッド（互換性のため）
  static Future<void> downloadPdf(Uint8List pdfBytes, String filename) async {
    await printPdf(pdfBytes, filename);
  }

  static Future<void> previewPdf(Uint8List pdfBytes, String title) async {
    await printPdf(pdfBytes, title);
  }
}