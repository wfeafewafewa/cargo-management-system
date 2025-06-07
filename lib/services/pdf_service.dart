// lib/services/pdf_service.dart - フォントデバッグ強化版
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

  // フォント読み込みテスト関数
  static Future<Map<String, dynamic>> testFontLoading() async {
    final results = <String, dynamic>{};

    // テスト1: アセットフォントの存在確認
    try {
      print('🔍 テスト1: アセットフォント存在確認開始');
      final fontData =
          await rootBundle.load('assets/fonts/NotoSansJP-Regular.ttf');
      print('✅ アセットフォント読み込み成功: ${fontData.lengthInBytes} bytes');
      results['assetFont'] = 'SUCCESS';
      results['assetFontSize'] = fontData.lengthInBytes;
    } catch (e) {
      print('❌ アセットフォント読み込み失敗: $e');
      results['assetFont'] = 'FAILED';
      results['assetFontError'] = e.toString();
    }

    // テスト2: PdfGoogleFonts確認
    try {
      print('🔍 テスト2: PdfGoogleFonts確認開始');
      final googleFont = await PdfGoogleFonts.notoSansJPRegular();
      print('✅ PdfGoogleFonts成功');
      results['googleFonts'] = 'SUCCESS';
    } catch (e) {
      print('❌ PdfGoogleFonts失敗: $e');
      results['googleFonts'] = 'FAILED';
      results['googleFontsError'] = e.toString();
    }

    // テスト3: 代替フォント確認
    try {
      print('🔍 テスト3: 代替フォント確認開始');
      final altFont = await PdfGoogleFonts.nanumGothicRegular();
      print('✅ 代替フォント成功');
      results['altFont'] = 'SUCCESS';
    } catch (e) {
      print('❌ 代替フォント失敗: $e');
      results['altFont'] = 'FAILED';
      results['altFontError'] = e.toString();
    }

    return results;
  }

  // 請求書PDF生成（完全フォント対応版）
  static Future<Uint8List> generateInvoice({
    required String customerId,
    required String customerName,
    required List<Map<String, dynamic>> deliveries,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final pdf = pw.Document();

    // 合計金額計算
    final totalAmount = deliveries.fold<int>(
      0,
      (sum, delivery) => sum + ((delivery['fee'] as int?) ?? 0),
    );

    // 段階的フォント読み込み戦略
    pw.Font? jpFont;
    pw.Font? jpBoldFont;
    String fontStatus = '';

    // フォント読み込みテスト実行
    final fontTests = await testFontLoading();

    // 戦略1: アセットフォント（最優先）
    if (fontTests['assetFont'] == 'SUCCESS') {
      try {
        print('📁 戦略1: アセットフォント使用開始');
        final fontData =
            await rootBundle.load('assets/fonts/NotoSansJP-Regular.ttf');
        jpFont = pw.Font.ttf(fontData);

        final boldFontData =
            await rootBundle.load('assets/fonts/NotoSansJP-Bold.ttf');
        jpBoldFont = pw.Font.ttf(boldFontData);

        fontStatus = 'アセットフォント成功';
        print('✅ アセットフォント適用完了');
      } catch (e) {
        print('❌ アセットフォント変換失敗: $e');
        jpFont = null;
        jpBoldFont = null;
      }
    }

    // 戦略2: PdfGoogleFonts（フォールバック）
    if (jpFont == null && fontTests['googleFonts'] == 'SUCCESS') {
      try {
        print('🌐 戦略2: PdfGoogleFonts使用開始');
        jpFont = await PdfGoogleFonts.notoSansJPRegular();
        jpBoldFont = await PdfGoogleFonts.notoSansJPBold();
        fontStatus = 'PdfGoogleFonts成功';
        print('✅ PdfGoogleFonts適用完了');
      } catch (e) {
        print('❌ PdfGoogleFonts変換失敗: $e');
        jpFont = null;
        jpBoldFont = null;
      }
    }

    // 戦略3: 代替フォント（最終手段）
    if (jpFont == null && fontTests['altFont'] == 'SUCCESS') {
      try {
        print('🔄 戦略3: 代替フォント使用開始');
        jpFont = await PdfGoogleFonts.nanumGothicRegular();
        jpBoldFont = jpFont; // 同じフォントを使用
        fontStatus = '代替フォント成功';
        print('✅ 代替フォント適用完了');
      } catch (e) {
        print('❌ 代替フォント変換失敗: $e');
        jpFont = null;
        jpBoldFont = null;
      }
    }

    // 戦略4: フォントなし（英語のみ）
    if (jpFont == null) {
      fontStatus = '全フォント失敗 - 英語のみ';
      print('⚠️ 全フォント読み込み失敗 - 英語のみで継続');
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: jpFont != null
            ? pw.ThemeData.withFont(
                base: jpFont,
                bold: jpBoldFont ?? jpFont,
                italic: jpFont,
                boldItalic: jpBoldFont ?? jpFont,
              )
            : pw.ThemeData(),
        build: (pw.Context context) {
          return [
            // 詳細デバッグ情報ボックス
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: jpFont != null ? PdfColors.green50 : PdfColors.red50,
                border: pw.Border.all(
                    color:
                        jpFont != null ? PdfColors.green300 : PdfColors.red300,
                    width: 2),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    jpFont != null ? '🎉 日本語フォント読み込み成功！' : '⚠️ 日本語フォント読み込み失敗',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: jpFont != null
                          ? PdfColors.green700
                          : PdfColors.red700,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'フォント状態: $fontStatus',
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.black),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'アセット: ${fontTests['assetFont']} | GoogleFonts: ${fontTests['googleFonts']} | 代替: ${fontTests['altFont']}',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // 日本語テスト（フォントが使用可能な場合のみ）
            if (jpFont != null) ...[
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  border: pw.Border.all(color: PdfColors.blue200, width: 2),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '🇯🇵 日本語表示テスト',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'ひらがな: あいうえお かきくけこ',
                      style: pw.TextStyle(
                          fontSize: 14, font: jpFont, color: PdfColors.black),
                    ),
                    pw.Text(
                      'カタカナ: アイウエオ カキクケコ',
                      style: pw.TextStyle(
                          fontSize: 14, font: jpFont, color: PdfColors.black),
                    ),
                    pw.Text(
                      '漢字: 株式会社 請求書 配送 管理',
                      style: pw.TextStyle(
                          fontSize: 14, font: jpFont, color: PdfColors.black),
                    ),
                    pw.Text(
                      '顧客名テスト: 山田商事 佐藤商事 田中物流',
                      style: pw.TextStyle(
                          fontSize: 14, font: jpFont, color: PdfColors.black),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),
            ],

            // 実際の請求書内容（日本語フォント対応）
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

    return pdf.save();
  }

  // 支払通知書PDF生成（同様にフォント対応）
  static Future<Uint8List> generatePaymentNotice({
    required String driverId,
    required String driverName,
    required List<Map<String, dynamic>> workReports,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final pdf = pw.Document();

    // 合計支払額計算
    final totalPayment = workReports.fold<int>(
      0,
      (sum, report) => sum + ((report['totalAmount'] as int?) ?? 0),
    );

    // フォント読み込み（請求書と同じ戦略）
    pw.Font? jpFont;
    pw.Font? jpBoldFont;

    try {
      final fontData =
          await rootBundle.load('assets/fonts/NotoSansJP-Regular.ttf');
      jpFont = pw.Font.ttf(fontData);

      final boldFontData =
          await rootBundle.load('assets/fonts/NotoSansJP-Bold.ttf');
      jpBoldFont = pw.Font.ttf(boldFontData);
    } catch (e1) {
      try {
        jpFont = await PdfGoogleFonts.notoSansJPRegular();
        jpBoldFont = await PdfGoogleFonts.notoSansJPBold();
      } catch (e2) {
        try {
          jpFont = await PdfGoogleFonts.nanumGothicRegular();
          jpBoldFont = jpFont;
        } catch (e3) {
          print('支払通知書: 全フォント読み込み失敗');
        }
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: jpFont != null
            ? pw.ThemeData.withFont(
                base: jpFont,
                bold: jpBoldFont ?? jpFont,
              )
            : pw.ThemeData(),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ヘッダー（日本語対応）
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '支払通知書',
                        style: pw.TextStyle(
                          fontSize: 28,
                          fontWeight: pw.FontWeight.bold,
                          font: jpBoldFont ?? jpFont,
                          color: PdfColors.green700,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'PAYMENT NOTICE',
                        style: pw.TextStyle(
                          fontSize: 14,
                          color: PdfColors.grey600,
                        ),
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
                          font: jpBoldFont ?? jpFont,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'TEL: 000-0000-0000',
                        style: pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // 基本情報（日本語対応）
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.green200),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '支払対象者: $driverName',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        font: jpBoldFont ?? jpFont,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      '対象期間: ${_dateFormat.format(startDate)} ～ ${_dateFormat.format(endDate)}',
                      style: pw.TextStyle(fontSize: 14, font: jpFont),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      '発行日: ${_dateFormat.format(DateTime.now())}',
                      style: pw.TextStyle(fontSize: 14, font: jpFont),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // 稼働明細
              pw.Text(
                '稼働明細',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  font: jpBoldFont ?? jpFont,
                ),
              ),
              pw.SizedBox(height: 15),

              // 稼働データ表
              _buildPaymentNoticeTable(workReports, jpFont),
              pw.Spacer(),

              // 総支払額
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 250,
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    border: pw.Border.all(color: PdfColors.green200),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text(
                    '総支払額: ¥${_currencyFormat.format(totalPayment)}',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      font: jpBoldFont ?? jpFont,
                      color: PdfColors.green700,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ===== コンポーネント（日本語フォント対応版） =====

  static pw.Widget _buildInvoiceHeader(pw.Font? jpFont, pw.Font? jpBoldFont) {
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
                font: jpBoldFont ?? jpFont,
                color: PdfColors.blue800,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'INVOICE',
              style: pw.TextStyle(
                fontSize: 14,
                color: PdfColors.grey600,
              ),
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
                font: jpBoldFont ?? jpFont,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              '〒000-0000 東京都○○区○○',
              style: pw.TextStyle(fontSize: 10, font: jpFont),
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
    final invoiceNumber =
        'INV-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '請求先',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey600,
                      font: jpFont,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    customerName,
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      font: jpFont,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    '請求書番号',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey600,
                      font: jpFont,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    invoiceNumber,
                    style: pw.TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '請求期間',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey600,
                      font: jpFont,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '${_dateFormat.format(startDate)} ～ ${_dateFormat.format(endDate)}',
                    style: pw.TextStyle(fontSize: 14, font: jpFont),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    '発行日',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey600,
                      font: jpFont,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    _dateFormat.format(DateTime.now()),
                    style: pw.TextStyle(fontSize: 14, font: jpFont),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildInvoiceTable(
      List<Map<String, dynamic>> deliveries, pw.Font? jpFont) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FixedColumnWidth(60),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FixedColumnWidth(80),
        4: const pw.FixedColumnWidth(100),
      },
      children: [
        // ヘッダー
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableCell('No.', jpFont, isHeader: true),
            _buildTableCell('案件名', jpFont, isHeader: true),
            _buildTableCell('配送区間', jpFont, isHeader: true),
            _buildTableCell('単価', jpFont, isHeader: true),
            _buildTableCell('金額', jpFont, isHeader: true),
          ],
        ),
        // データ行
        ...deliveries.asMap().entries.map((entry) {
          final index = entry.key;
          final delivery = entry.value;
          return pw.TableRow(
            children: [
              _buildTableCell('${index + 1}', jpFont),
              _buildTableCell(delivery['projectName'] ?? '', jpFont),
              _buildTableCell(
                  '${delivery['pickupLocation'] ?? ''} → ${delivery['deliveryLocation'] ?? ''}',
                  jpFont),
              _buildTableCell(
                  '¥${_currencyFormat.format(delivery['unitPrice'] ?? 0)}',
                  jpFont),
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
        width: 250,
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
                pw.Text(
                  '¥${_currencyFormat.format(totalAmount)}',
                  style: pw.TextStyle(fontSize: 14),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '消費税 (10%)',
                  style: pw.TextStyle(fontSize: 14, font: jpFont),
                ),
                pw.Text(
                  '¥${_currencyFormat.format((totalAmount * 0.1).round())}',
                  style: pw.TextStyle(fontSize: 14),
                ),
              ],
            ),
            pw.Divider(color: PdfColors.blue300),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '合計金額',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    font: jpBoldFont ?? jpFont,
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

  static pw.Widget _buildInvoiceFooter(pw.Font? jpFont) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'お支払い条件',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            font: jpFont,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          '• 請求書発行日より30日以内にお支払いください\n• 振込手数料はお客様負担となります\n• ご不明な点がございましたらお気軽にお問い合わせください',
          style: pw.TextStyle(fontSize: 10, font: jpFont),
        ),
      ],
    );
  }

  static pw.Widget _buildPaymentNoticeTable(
      List<Map<String, dynamic>> workReports, pw.Font? jpFont) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        // ヘッダー
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableCell('作業日', jpFont, isHeader: true),
            _buildTableCell('案件名', jpFont, isHeader: true),
            _buildTableCell('稼働時間', jpFont, isHeader: true),
            _buildTableCell('支払額', jpFont, isHeader: true),
          ],
        ),
        // データ行
        ...workReports.map((report) {
          final workDate = (report['workDate'] as Timestamp?)?.toDate();
          final workStart = (report['workStartTime'] as Timestamp?)?.toDate();
          final workEnd = (report['workEndTime'] as Timestamp?)?.toDate();

          String workHours = '---';
          if (workStart != null && workEnd != null) {
            final duration = workEnd.difference(workStart);
            final hours = duration.inMinutes / 60;
            workHours = '${hours.toStringAsFixed(1)}h';
          }

          return pw.TableRow(
            children: [
              _buildTableCell(
                  workDate != null ? _dateFormat.format(workDate) : '', jpFont),
              _buildTableCell(report['selectedDelivery'] ?? '', jpFont),
              _buildTableCell(workHours, jpFont),
              _buildTableCell(
                  '¥${_currencyFormat.format(report['totalAmount'] ?? 0)}',
                  jpFont),
            ],
          );
        }).toList(),
      ],
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
