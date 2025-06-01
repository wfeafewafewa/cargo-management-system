// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 現在のユーザーID取得
  String? get currentUserId => _auth.currentUser?.uid;

  // 現在のユーザー情報取得
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    if (currentUserId == null) return null;

    final doc = await _firestore.collection('users').doc(currentUserId).get();
    return doc.exists ? doc.data() : null;
  }

  // ユーザー作成・更新
  Future<void> createOrUpdateUser({
    required String userId,
    required String email,
    required String role,
    required String name,
  }) async {
    await _firestore.collection('users').doc(userId).set({
      'email': email,
      'role': role,
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
      'lastLogin': FieldValue.serverTimestamp(),
      'isActive': true,
    }, SetOptions(merge: true));
  }

  // === 配送案件管理 ===

  // 配送案件作成
  Future<String> createDelivery({
    required String title,
    required String client,
    required Map<String, dynamic> pickupLocation,
    required Map<String, dynamic> deliveryLocation,
    required DateTime scheduledDate,
    required double price,
    required String priority,
    String? assignedDriverId,
    String? weight,
    String? notes,
  }) async {
    final docRef = await _firestore.collection('deliveries').add({
      'title': title,
      'client': client,
      'pickupLocation': pickupLocation,
      'deliveryLocation': deliveryLocation,
      'assignedDriverId': assignedDriverId,
      'status': 'pending',
      'priority': priority,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'price': price,
      'weight': weight ?? '',
      'notes': notes ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  // 配送案件一覧取得（インデックス不要版）
  Stream<QuerySnapshot> getDeliveries() {
    return _firestore.collection('deliveries').snapshots();
  }

  // ドライバー用：自分の配送案件取得（インデックス不要版）
  Stream<QuerySnapshot> getDriverDeliveries(String driverId) {
    return _firestore
        .collection('deliveries')
        .where('assignedDriverId', isEqualTo: driverId)
        .snapshots();
  }

  // 配送案件更新
  Future<void> updateDelivery(
      String deliveryId, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('deliveries').doc(deliveryId).update(data);
  }

  // 配送案件削除
  Future<void> deleteDelivery(String deliveryId) async {
    await _firestore.collection('deliveries').doc(deliveryId).delete();
  }

  // === ドライバー管理 ===

  // ドライバー作成
  Future<String> createDriver({
    required String userId,
    required String name,
    required String phone,
    required String licenseNumber,
    required String vehicleType,
    required String vehicleNumber,
  }) async {
    final docRef = await _firestore.collection('drivers').add({
      'userId': userId,
      'name': name,
      'phone': phone,
      'licenseNumber': licenseNumber,
      'vehicleType': vehicleType,
      'vehicleNumber': vehicleNumber,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'totalDeliveries': 0,
      'rating': 5.0,
    });
    return docRef.id;
  }

  // ドライバー一覧取得（インデックス不要版）
  Stream<QuerySnapshot> getDrivers() {
    return _firestore
        .collection('drivers')
        .where('status', isEqualTo: 'active')
        .snapshots();
  }

  // ドライバー情報取得
  Future<DocumentSnapshot?> getDriverByUserId(String userId) async {
    final querySnapshot = await _firestore
        .collection('drivers')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    return querySnapshot.docs.isNotEmpty ? querySnapshot.docs.first : null;
  }

  // ドライバー更新
  Future<void> updateDriver(String driverId, Map<String, dynamic> data) async {
    await _firestore.collection('drivers').doc(driverId).update(data);
  }

  // === 売上管理 ===

  // 売上記録作成
  Future<void> createSale({
    required String deliveryId,
    required String driverId,
    required double amount,
    required double commission,
    String paymentStatus = 'pending',
  }) async {
    final netAmount = amount - commission;
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    await _firestore.collection('sales').add({
      'deliveryId': deliveryId,
      'driverId': driverId,
      'amount': amount,
      'commission': commission,
      'netAmount': netAmount,
      'paymentStatus': paymentStatus,
      'month': month,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // 月次売上取得（インデックス不要版）
  Stream<QuerySnapshot> getMonthlySales(String month) {
    return _firestore
        .collection('sales')
        .where('month', isEqualTo: month)
        .snapshots();
  }

  // ドライバー別売上取得（インデックス不要版）
  Stream<QuerySnapshot> getDriverSales(String driverId, String month) {
    return _firestore
        .collection('sales')
        .where('driverId', isEqualTo: driverId)
        .where('month', isEqualTo: month)
        .snapshots();
  }

  // 売上データ更新
  Future<void> updateSale(String saleId, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('sales').doc(saleId).update(data);
  }

  // 支払い状況更新
  Future<void> updatePaymentStatus(String saleId, String status) async {
    await _firestore.collection('sales').doc(saleId).update({
      'paymentStatus': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // 売上統計取得
  Future<Map<String, dynamic>> getSalesStatistics(String month) async {
    final snapshot = await _firestore
        .collection('sales')
        .where('month', isEqualTo: month)
        .get();

    double totalSales = 0;
    double totalCommission = 0;
    int totalTransactions = snapshot.docs.length;
    int paidTransactions = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      totalSales += (data['amount'] ?? 0).toDouble();
      totalCommission += (data['commission'] ?? 0).toDouble();

      if (data['paymentStatus'] == 'paid') {
        paidTransactions++;
      }
    }

    return {
      'totalSales': totalSales,
      'totalCommission': totalCommission,
      'totalTransactions': totalTransactions,
      'paidTransactions': paidTransactions,
      'pendingTransactions': totalTransactions - paidTransactions,
      'averageOrder':
          totalTransactions > 0 ? totalSales / totalTransactions : 0,
    };
  }

  // ドライバー別売上統計
  Future<Map<String, dynamic>> getDriverSalesStatistics(
      String driverId, String month) async {
    final snapshot = await _firestore
        .collection('sales')
        .where('driverId', isEqualTo: driverId)
        .where('month', isEqualTo: month)
        .get();

    double totalSales = 0;
    double totalNetAmount = 0;
    int totalDeliveries = snapshot.docs.length;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      totalSales += (data['amount'] ?? 0).toDouble();
      totalNetAmount += (data['netAmount'] ?? 0).toDouble();
    }

    return {
      'totalSales': totalSales,
      'totalNetAmount': totalNetAmount,
      'totalDeliveries': totalDeliveries,
      'averageDelivery': totalDeliveries > 0 ? totalSales / totalDeliveries : 0,
    };
  }

  // === データ管理関連 ===

  // コレクション統計取得
  Future<Map<String, int>> getCollectionCounts() async {
    Map<String, int> counts = {};
    final collections = ['sales', 'deliveries', 'drivers', 'users'];

    for (String collection in collections) {
      final snapshot = await _firestore.collection(collection).get();
      counts[collection] = snapshot.docs.length;
    }

    return counts;
  }

  // データクリーンアップ（古いデータ削除）
  Future<void> cleanupOldData({int monthsToKeep = 12}) async {
    final cutoffDate =
        DateTime.now().subtract(Duration(days: monthsToKeep * 30));
    final cutoffTimestamp = Timestamp.fromDate(cutoffDate);

    // 古い売上データを削除
    final oldSalesSnapshot = await _firestore
        .collection('sales')
        .where('createdAt', isLessThan: cutoffTimestamp)
        .get();

    final batch = _firestore.batch();
    for (var doc in oldSalesSnapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // 売上データの一括作成（配送完了時に自動作成）
  Future<void> createSaleFromDelivery(String deliveryId) async {
    // 配送データを取得
    final deliveryDoc =
        await _firestore.collection('deliveries').doc(deliveryId).get();

    if (!deliveryDoc.exists) {
      throw Exception('配送データが見つかりません');
    }

    final deliveryData = deliveryDoc.data() as Map<String, dynamic>;

    // 既に売上データが作成されているかチェック
    final existingSale = await _firestore
        .collection('sales')
        .where('deliveryId', isEqualTo: deliveryId)
        .get();

    if (existingSale.docs.isNotEmpty) {
      // 既に売上データが存在する場合は何もしない
      return;
    }

    // 売上データを作成
    final amount = (deliveryData['price'] ?? 0).toDouble();
    final commission = amount * 0.1; // 10%の手数料

    await createSale(
      deliveryId: deliveryId,
      driverId: deliveryData['assignedDriverId'] ?? '',
      amount: amount,
      commission: commission,
    );
  }

  // === 統計データ ===

  // ダッシュボード統計取得
  Future<Map<String, dynamic>> getDashboardStats() async {
    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    // 今月の配送案件数
    final deliveriesSnapshot = await _firestore
        .collection('deliveries')
        .where('createdAt',
            isGreaterThan: Timestamp.fromDate(DateTime(now.year, now.month, 1)))
        .get();

    // アクティブドライバー数
    final driversSnapshot = await _firestore
        .collection('drivers')
        .where('status', isEqualTo: 'active')
        .get();

    // 今月の売上
    final salesSnapshot = await _firestore
        .collection('sales')
        .where('month', isEqualTo: currentMonth)
        .get();

    double totalSales = 0;
    for (var doc in salesSnapshot.docs) {
      totalSales += (doc.data() as Map<String, dynamic>)['amount'] ?? 0;
    }

    return {
      'totalDeliveries': deliveriesSnapshot.docs.length,
      'activeDrivers': driversSnapshot.docs.length,
      'totalSales': totalSales,
      'pendingDeliveries': deliveriesSnapshot.docs
          .where((doc) =>
              (doc.data() as Map<String, dynamic>)['status'] == 'pending')
          .length,
    };
  }

  // === 通知管理 ===

  // 通知作成
  Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? relatedId,
  }) async {
    await _firestore.collection('notifications').add({
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'relatedId': relatedId,
    });
  }

  // ユーザー通知取得
  Stream<QuerySnapshot> getUserNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots();
  }

  // 通知を既読にする
  Future<void> markNotificationAsRead(String notificationId) async {
    await _firestore
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }
}
