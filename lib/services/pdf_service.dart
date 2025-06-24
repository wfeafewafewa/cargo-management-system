// lib/services/pdf_service.dart - 日本語テスト表記削除版
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart'; // PdfGoogleFonts用インポート追加
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class PdfService {
  static final _dateFormat = DateFormat('yyyy/MM/dd');
  static final _currencyFormat = NumberFormat('#,###');

  // Web環境対応日本語フォント読み込み
  static Future<pw.Font?> _loadJapaneseWebFont() async {
    if (!kIsWeb) {
      print('⚠️ この関数はWeb環境専用です');
      return null;
    }

    try {
      print('🇯🇵 Web環境: 日本語フォント読み込み試行...');

      // 段階的フォント読み込み戦略
      try {
        // 戦略1: Google Fonts Noto Sans JP（最も確実）
        print('📝 戦略1: Google Fonts試行中...');
        final font = await PdfGoogleFonts.notoSansJPRegular();
        print('✅ Google Fonts成功: 日本語表示可能');
        return font;
      } catch (e1) {
        print('❌ Google Fonts失敗: $e1');

        try {
          // 戦略2: 代替Google Font
          print('📝 戦略2: 代替フォント試行中...');
          final font = await PdfGoogleFonts.nanumGothicRegular();
          print('✅ 代替フォント成功');
          return font;
        } catch (e2) {
          print('❌ 代替フォント失敗: $e2');

          // 戦略3: フォントなしでもUTF-8対応
          print('📝 戦略3: UTF-8フォールバック');
          return null; // PDFライブラリのデフォルトUTF-8対応に任せる
        }
      }
    } catch (e) {
      print('❌ 日本語フォント読み込み全般エラー: $e');
      return null;
    }
  }

  // Web環境対応請求書PDF生成（日本語表示修正版）
  static Future<Uint8List> generateInvoice({
    required String customerId,
    required String customerName,
    required List<Map<String, dynamic>> deliveries,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      print('🚀 PDF生成開始');
      print('📊 配送データ数: ${deliveries.length}');
      print('👤 顧客名: $customerName');

      // バリデーション
      if (deliveries.isEmpty) {
        throw ArgumentError('配送データが空です');
      }

      final pdf = pw.Document();

      // 合計金額計算
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

      print('💰 合計金額: ¥${_currencyFormat.format(totalAmount)}');

      // 日本語対応フォント読み込み
      final jpFont = await _loadJapaneseWebFont();
      final fontStatus = jpFont != null ? '日本語フォント対応' : 'UTF-8フォールバック';
      print('🔤 フォント状態: $fontStatus');

      // PDF生成
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          theme: jpFont != null
              ? pw.ThemeData.withFont(base: jpFont, bold: jpFont)
              : pw.ThemeData(), // デフォルトテーマでUTF-8対応
          build: (pw.Context context) {
            return [
              // 請求書ヘッダー
              _buildJapaneseInvoiceHeader(jpFont),
              pw.SizedBox(height: 30),

              // 請求書情報
              _buildJapaneseInvoiceInfo(
                  customerName, startDate, endDate, jpFont),
              pw.SizedBox(height: 30),

              // 請求書テーブル
              _buildJapaneseInvoiceTable(deliveries, jpFont),
              pw.SizedBox(height: 20),

              // 請求書サマリー
              _buildJapaneseInvoiceSummary(totalAmount, jpFont),
              pw.SizedBox(height: 30),

              // フッター
              _buildJapaneseInvoiceFooter(jpFont),
            ];
          },
        ),
      );

      print('💾 PDF保存開始...');
      final Uint8List pdfBytes = await pdf.save();

      // バイト配列検証
      if (pdfBytes.isEmpty) {
        throw Exception('生成されたPDFが空です');
      }

      print('✅ PDF生成成功: ${pdfBytes.length} bytes');
      return pdfBytes;
    } catch (e, stackTrace) {
      print('❌ PDF生成エラー: $e');
      print('スタックトレース: $stackTrace');

      // 緊急フォールバック
      return await _generateEmergencyJapaneseInvoice(customerName, 0);
    }
  }

  // 支払通知書生成（日本語対応版）
  static Future<Uint8List> generatePaymentNotice({
    required String driverId,
    required String driverName,
    required List<Map<String, dynamic>> workReports,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      print('🚀 支払通知書生成開始');
      print('👷 ドライバー名: $driverName');

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

      // 日本語対応フォント読み込み
      final jpFont = await _loadJapaneseWebFont();

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
                  '支払通知書',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green700,
                    font: jpFont,
                  ),
                ),
                pw.SizedBox(height: 30),

                // 基本情報
                pw.Text(
                  '支払対象者: $driverName',
                  style: pw.TextStyle(fontSize: 16, font: jpFont),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  '期間: ${_dateFormat.format(startDate)} ～ ${_dateFormat.format(endDate)}',
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
                      '総支払額: ¥${_currencyFormat.format(totalPayment)}',
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

  // Web環境対応：ダウンロード機能（Web専用実装は呼び出し元で対応）
  static Future<void> printPdf(Uint8List pdfBytes, String title) async {
    if (kIsWeb) {
      print('🌐 Web環境: 印刷機能はダウンロードに変更');
      // 実際のダウンロード処理は呼び出し元で実装
    } else {
      // モバイル環境では printing パッケージ使用可能
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: title,
      );
    }
  }

  static Future<void> downloadPdf(Uint8List pdfBytes, String filename) async {
    if (kIsWeb) {
      print('📥 Web環境: ダウンロード処理（呼び出し元で実装）');
    } else {
      await Printing.sharePdf(bytes: pdfBytes, filename: filename);
    }
  }

  static Future<void> previewPdf(Uint8List pdfBytes, String title) async {
    if (kIsWeb) {
      print('👁️ Web環境: プレビュー処理（呼び出し元で実装）');
    } else {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: title,
      );
    }
  }

  // 緊急フォールバック
  static Future<Uint8List> _generateEmergencyJapaneseInvoice(
      String customerName, int totalAmount) async {
    try {
      print('🚨 緊急フォールバック実行');

      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.red50,
                    border: pw.Border.all(color: PdfColors.red300, width: 2),
                  ),
                  child: pw.Text(
                    '🚨 緊急モード - 基本請求書',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.red700,
                    ),
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Text(
                  '請求書',
                  style: pw.TextStyle(
                    fontSize: 32,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Text('請求先: $customerName',
                    style: pw.TextStyle(fontSize: 16)),
                pw.SizedBox(height: 10),
                pw.Text('発行日: ${_dateFormat.format(DateTime.now())}',
                    style: pw.TextStyle(fontSize: 14)),
                pw.Spacer(),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(20),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      border: pw.Border.all(color: PdfColors.blue200),
                    ),
                    child: pw.Text(
                      '合計: ¥${_currencyFormat.format(totalAmount)} (緊急モード)',
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold),
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
      print('❌ 緊急フォールバックも失敗: $e');
      rethrow;
    }
  }

  // ===== 日本語対応UIコンポーネント =====

  static pw.Widget _buildJapaneseInvoiceHeader(pw.Font? jpFont) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '請求書',
              style: pw.TextStyle(
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
                font: jpFont,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              '発行日: ${_dateFormat.format(DateTime.now())}',
              style: pw.TextStyle(
                  fontSize: 12, color: PdfColors.grey600, font: jpFont),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              '株式会社ダブルエッチ',
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

  static pw.Widget _buildJapaneseInvoiceInfo(String customerName,
      DateTime startDate, DateTime endDate, pw.Font? jpFont) {
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
            '請求先: $customerName',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              font: jpFont,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            '請求期間: ${_dateFormat.format(startDate)} ～ ${_dateFormat.format(endDate)}',
            style: pw.TextStyle(fontSize: 14, font: jpFont),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildJapaneseInvoiceTable(
      List<Map<String, dynamic>> deliveries, pw.Font? jpFont) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        // ヘッダー
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildJapaneseTableCell('No.', jpFont, isHeader: true),
            _buildJapaneseTableCell('案件名', jpFont, isHeader: true),
            _buildJapaneseTableCell('金額', jpFont, isHeader: true),
          ],
        ),
        // データ行
        ...deliveries.asMap().entries.map((entry) {
          final index = entry.key;
          final delivery = entry.value;

          return pw.TableRow(
            children: [
              _buildJapaneseTableCell('${index + 1}', jpFont),
              _buildJapaneseTableCell(
                  delivery['projectName']?.toString() ?? '案件', jpFont),
              _buildJapaneseTableCell(
                  '¥${_currencyFormat.format(delivery['fee'] ?? 0)}', jpFont),
            ],
          );
        }).toList(),
      ],
    );
  }

  static pw.Widget _buildJapaneseInvoiceSummary(
      int totalAmount, pw.Font? jpFont) {
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
                pw.Text(
                  '小計',
                  style: pw.TextStyle(fontSize: 14, font: jpFont),
                ),
                pw.Text('¥${_currencyFormat.format(totalAmount)}',
                    style: pw.TextStyle(fontSize: 14)),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '消費税(10%)',
                  style: pw.TextStyle(fontSize: 14, font: jpFont),
                ),
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
                  '合計金額',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    font: jpFont,
                  ),
                ),
                pw.Text(
                  '¥${_currencyFormat.format((totalAmount * 1.1).round())}',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildJapaneseInvoiceFooter(pw.Font? jpFont) {
    return pw.Text(
      'ご不明な点がございましたらお気軽にお問い合わせください。',
      style: pw.TextStyle(fontSize: 10, font: jpFont),
    );
  }

  static pw.Widget _buildJapaneseTableCell(String text, pw.Font? jpFont,
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
