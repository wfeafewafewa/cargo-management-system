// lib/debug/pdf_debug_test.dart - エラー診断用（完全版）
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart'; // PdfGoogleFonts用
import 'package:flutter/foundation.dart';
import 'dart:html' as html;

class PdfDebugTest {
  static Future<void> runDiagnostics() async {
    print('🔍 PDF診断開始...');

    // テスト1: 基本的なPDF生成
    try {
      print('📝 テスト1: 最小限PDF生成');
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          build: (context) => pw.Center(
            child: pw.Text('Test PDF', style: pw.TextStyle(fontSize: 24)),
          ),
        ),
      );

      final bytes = await pdf.save();
      print('✅ テスト1成功: ${bytes.length} bytes');

      // テスト2: Web環境でのダウンロード
      if (kIsWeb) {
        print('🌐 テスト2: Webダウンロード');
        _testWebDownload(bytes);
      }
    } catch (e, stack) {
      print('❌ テスト1失敗: $e');
      print('スタック: $stack');
    }

    // テスト3: フォント読み込み
    try {
      print('🔤 テスト3: フォント読み込み');
      final font = await PdfGoogleFonts.notoSansJPRegular();
      print('✅ テスト3成功: フォント読み込みOK');
    } catch (e) {
      print('❌ テスト3失敗: $e');
    }

    // テスト4: データ型確認
    print('📊 テスト4: データ型確認');
    final testDeliveries = [
      {'projectName': 'テスト案件', 'fee': 10000},
      {'projectName': 'Test Project', 'fee': 20000},
    ];

    for (int i = 0; i < testDeliveries.length; i++) {
      final delivery = testDeliveries[i];
      print(
          '配送$i: ${delivery['projectName']} - ${delivery['fee']} (${delivery['fee'].runtimeType})');
    }

    print('🔍 PDF診断完了');
  }

  static void _testWebDownload(Uint8List bytes) {
    try {
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);

      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'test.pdf')
        ..style.display = 'none';

      html.document.body!.appendChild(anchor);
      anchor.click();
      html.document.body!.removeChild(anchor);
      html.Url.revokeObjectUrl(url);

      print('✅ テスト2成功: Webダウンロード完了');
    } catch (e) {
      print('❌ テスト2失敗: $e');
    }
  }

  // PDF生成の各段階をテスト
  static Future<void> stepByStepTest() async {
    print('🔬 段階別PDF生成テスト開始...');

    try {
      // Step 1: Document作成
      print('Step 1: Document作成');
      final pdf = pw.Document();
      print('✅ Document作成成功');

      // Step 2: ページ追加
      print('Step 2: ページ追加');
      pdf.addPage(
        pw.Page(
          build: (context) {
            print('Step 2.1: Page build関数実行中');
            return pw.Text('Hello');
          },
        ),
      );
      print('✅ ページ追加成功');

      // Step 3: PDF保存
      print('Step 3: PDF保存');
      final bytes = await pdf.save();
      print('✅ PDF保存成功: ${bytes.length} bytes');

      // Step 4: バイト配列検証
      print('Step 4: バイト配列検証');
      print('- バイト配列の長さ: ${bytes.length}');
      print('- 最初の10バイト: ${bytes.take(10).toList()}');
      print('- 型: ${bytes.runtimeType}');

      if (bytes.isNotEmpty && bytes.length > 100) {
        print('✅ バイト配列検証成功');
      } else {
        print('❌ バイト配列異常');
      }
    } catch (e, stack) {
      print('❌ 段階別テスト失敗: $e');
      print('詳細スタック: $stack');
    }
  }
}
