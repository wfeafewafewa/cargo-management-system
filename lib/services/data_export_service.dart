// lib/services/data_export_service.dart
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;

class DataExportService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 売上データをCSVエクスポート
  static Future<void> exportSalesDataToCSV({
    String? startMonth,
    String? endMonth,
    String? driverId,
  }) async {
    try {
      // データ取得
      Query query = _firestore.collection('sales');

      if (startMonth != null) {
        query = query.where('month', isGreaterThanOrEqualTo: startMonth);
      }
      if (endMonth != null) {
        query = query.where('month', isLessThanOrEqualTo: endMonth);
      }
      if (driverId != null) {
        query = query.where('driverId', isEqualTo: driverId);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        throw Exception('エクスポートするデータがありません');
      }

      // CSVデータ作成
      List<List<String>> csvData = [];

      // ヘッダー
      csvData.add([
        '売上ID',
        '配送案件ID',
        'ドライバーID',
        'ドライバー名',
        '売上金額',
        '手数料',
        '純利益',
        '支払状況',
        '対象月',
        '作成日時',
      ]);

      // データ行
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final driverName = await _getDriverName(data['driverId']);

        csvData.add([
          doc.id,
          data['deliveryId'] ?? '',
          data['driverId'] ?? '',
          driverName,
          (data['amount'] ?? 0).toString(),
          (data['commission'] ?? 0).toString(),
          (data['netAmount'] ?? 0).toString(),
          data['paymentStatus'] ?? 'pending',
          data['month'] ?? '',
          _formatTimestamp(data['createdAt']),
        ]);
      }

      // CSV文字列生成
      String csv = const ListToCsvConverter().convert(csvData);

      // ファイル名生成
      final fileName =
          'sales_data_${DateTime.now().millisecondsSinceEpoch}.csv';

      // ダウンロード実行
      await _downloadFile(csv, fileName, 'text/csv');
    } catch (e) {
      throw Exception('CSVエクスポートエラー: $e');
    }
  }

  // 配送データをCSVエクスポート
  static Future<void> exportDeliveryDataToCSV({
    String? status,
    String? startDate,
    String? endDate,
  }) async {
    try {
      Query query = _firestore.collection('deliveries');

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        throw Exception('エクスポートするデータがありません');
      }

      List<List<String>> csvData = [];

      // ヘッダー
      csvData.add([
        '配送ID',
        '案件名',
        'クライアント',
        '集荷先住所',
        '配送先住所',
        '配送料金',
        '重量',
        'ステータス',
        '担当ドライバー',
        '作成日時',
        '完了日時',
        '備考',
      ]);

      // データ行
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final driverName = await _getDriverName(data['assignedDriverId']);

        csvData.add([
          doc.id,
          data['title'] ?? '',
          data['client'] ?? '',
          data['pickupLocation']?['address'] ?? '',
          data['deliveryLocation']?['address'] ?? '',
          (data['price'] ?? 0).toString(),
          data['weight'] ?? '',
          data['status'] ?? '',
          driverName,
          _formatTimestamp(data['createdAt']),
          _formatTimestamp(data['completedAt']),
          data['notes'] ?? '',
        ]);
      }

      String csv = const ListToCsvConverter().convert(csvData);
      final fileName =
          'delivery_data_${DateTime.now().millisecondsSinceEpoch}.csv';

      await _downloadFile(csv, fileName, 'text/csv');
    } catch (e) {
      throw Exception('配送データエクスポートエラー: $e');
    }
  }

  // ドライバーデータをCSVエクスポート
  static Future<void> exportDriverDataToCSV() async {
    try {
      final snapshot = await _firestore.collection('drivers').get();

      if (snapshot.docs.isEmpty) {
        throw Exception('エクスポートするドライバーデータがありません');
      }

      List<List<String>> csvData = [];

      // ヘッダー
      csvData.add([
        'ドライバーID',
        '氏名',
        '電話番号',
        'メールアドレス',
        '車両タイプ',
        '車両番号',
        '免許番号',
        '評価',
        '総配送数',
        '登録日',
        'ステータス',
      ]);

      // データ行
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        csvData.add([
          doc.id,
          data['name'] ?? '',
          data['phone'] ?? '',
          data['email'] ?? '',
          data['vehicleType'] ?? '',
          data['vehicleNumber'] ?? '',
          data['licenseNumber'] ?? '',
          (data['rating'] ?? 0).toString(),
          (data['totalDeliveries'] ?? 0).toString(),
          _formatTimestamp(data['createdAt']),
          data['status'] ?? 'active',
        ]);
      }

      String csv = const ListToCsvConverter().convert(csvData);
      final fileName =
          'drivers_data_${DateTime.now().millisecondsSinceEpoch}.csv';

      await _downloadFile(csv, fileName, 'text/csv');
    } catch (e) {
      throw Exception('ドライバーデータエクスポートエラー: $e');
    }
  }

  // 全データバックアップ（JSON形式）
  static Future<void> exportFullBackup() async {
    try {
      Map<String, dynamic> backupData = {};

      // 各コレクションからデータ取得
      final collections = ['sales', 'deliveries', 'drivers', 'users'];

      for (String collection in collections) {
        final snapshot = await _firestore.collection(collection).get();
        List<Map<String, dynamic>> collectionData = [];

        for (var doc in snapshot.docs) {
          Map<String, dynamic> docData = doc.data();
          docData['_id'] = doc.id; // ドキュメントIDも保存

          // Timestampを文字列に変換
          docData = _convertTimestampsToStrings(docData);

          collectionData.add(docData);
        }

        backupData[collection] = collectionData;
      }

      // メタデータ追加
      backupData['_metadata'] = {
        'exportDate': DateTime.now().toIso8601String(),
        'version': '1.0',
        'totalRecords': backupData.values
            .where((v) => v is List)
            .map((v) => (v as List).length)
            .reduce((a, b) => a + b),
      };

      // JSON文字列生成
      String jsonString =
          const JsonEncoder.withIndent('  ').convert(backupData);

      final fileName =
          'cargo_system_backup_${DateTime.now().millisecondsSinceEpoch}.json';

      await _downloadFile(jsonString, fileName, 'application/json');
    } catch (e) {
      throw Exception('バックアップエクスポートエラー: $e');
    }
  }

  // 月次レポートエクスポート（詳細CSV）
  static Future<void> exportMonthlyReport(String month) async {
    try {
      // 売上データ
      final salesSnapshot = await _firestore
          .collection('sales')
          .where('month', isEqualTo: month)
          .get();

      // 配送データ
      final deliveriesSnapshot = await _firestore
          .collection('deliveries')
          .where('status', isEqualTo: 'completed')
          .get();

      List<List<String>> csvData = [];

      // ヘッダー
      csvData.add([
        '日付',
        '配送ID',
        '案件名',
        'ドライバー名',
        '集荷先',
        '配送先',
        '配送料金',
        '手数料',
        '純利益',
        'ステータス',
      ]);

      // 売上データと配送データを結合
      for (var sale in salesSnapshot.docs) {
        final saleData = sale.data();
        final deliveryId = saleData['deliveryId'];

        // 対応する配送データを検索
        final deliveryDoc = deliveriesSnapshot.docs
            .where((doc) => doc.id == deliveryId)
            .firstOrNull;

        if (deliveryDoc != null) {
          final deliveryData = deliveryDoc.data();
          final driverName = await _getDriverName(saleData['driverId']);

          csvData.add([
            _formatTimestamp(saleData['createdAt']),
            deliveryId ?? '',
            deliveryData['title'] ?? '',
            driverName,
            deliveryData['pickupLocation']?['address'] ?? '',
            deliveryData['deliveryLocation']?['address'] ?? '',
            (saleData['amount'] ?? 0).toString(),
            (saleData['commission'] ?? 0).toString(),
            (saleData['netAmount'] ?? 0).toString(),
            saleData['paymentStatus'] ?? 'pending',
          ]);
        }
      }

      String csv = const ListToCsvConverter().convert(csvData);
      final fileName = 'monthly_report_${month.replaceAll('-', '_')}.csv';

      await _downloadFile(csv, fileName, 'text/csv');
    } catch (e) {
      throw Exception('月次レポートエクスポートエラー: $e');
    }
  }

  // ヘルパーメソッド
  static Future<String> _getDriverName(String? driverId) async {
    if (driverId == null) return '未設定';

    try {
      final doc = await _firestore.collection('drivers').doc(driverId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['name'] ?? '未設定';
      }
    } catch (e) {
      debugPrint('ドライバー名取得エラー: $e');
    }

    return '未設定';
  }

  static String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';

    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return '';
    }

    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  static Map<String, dynamic> _convertTimestampsToStrings(
      Map<String, dynamic> data) {
    Map<String, dynamic> converted = {};

    data.forEach((key, value) {
      if (value is Timestamp) {
        converted[key] = value.toDate().toIso8601String();
      } else if (value is Map<String, dynamic>) {
        converted[key] = _convertTimestampsToStrings(value);
      } else if (value is List) {
        converted[key] = value.map((item) {
          if (item is Map<String, dynamic>) {
            return _convertTimestampsToStrings(item);
          } else if (item is Timestamp) {
            return item.toDate().toIso8601String();
          }
          return item;
        }).toList();
      } else {
        converted[key] = value;
      }
    });

    return converted;
  }

  static Future<void> _downloadFile(
      String content, String fileName, String mimeType) async {
    final bytes = utf8.encode(content);
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);

    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();

    html.Url.revokeObjectUrl(url);
  }
}
