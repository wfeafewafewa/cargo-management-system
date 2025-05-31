// lib/services/notification_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 通知作成
  static Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? relatedId,
    Map<String, dynamic>? data,
  }) async {
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'relatedId': relatedId,
      'data': data,
    });
  }
  
  // ユーザーの通知取得（リアルタイム）
  Stream<QuerySnapshot> getUserNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots();
  }
  
  // 未読通知数取得（リアルタイム）
  Stream<int> getUnreadNotificationCount(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
  
  // 通知を既読にする
  Future<void> markAsRead(String notificationId) async {
    await _firestore
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }
  
  // 全通知を既読にする
  Future<void> markAllAsRead(String userId) async {
    final batch = _firestore.batch();
    
    final notifications = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    
    for (var doc in notifications.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    
    await batch.commit();
  }
  
  // 通知削除
  Future<void> deleteNotification(String notificationId) async {
    await _firestore
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }
  
  // 古い通知を一括削除（30日以上前）
  Future<void> cleanupOldNotifications(String userId) async {
    final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));
    
    final oldNotifications = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('createdAt', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
        .get();
    
    final batch = _firestore.batch();
    for (var doc in oldNotifications.docs) {
      batch.delete(doc.reference);
    }
    
    await batch.commit();
  }
  
  // システム通知の作成（全ユーザー向け）
  static Future<void> createSystemNotification({
    required String title,
    required String message,
    String? relatedId,
  }) async {
    // 全アクティブユーザーに通知
    final users = await FirebaseFirestore.instance
        .collection('users')
        .where('isActive', isEqualTo: true)
        .get();
    
    final batch = FirebaseFirestore.instance.batch();
    
    for (var user in users.docs) {
      final notificationRef = FirebaseFirestore.instance
          .collection('notifications')
          .doc();
      
      batch.set(notificationRef, {
        'userId': user.id,
        'title': title,
        'message': message,
        'type': 'system',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'relatedId': relatedId,
      });
    }
    
    await batch.commit();
  }
  
  // 配送関連通知のヘルパーメソッド
  static Future<void> notifyDeliveryAssigned({
    required String driverId,
    required String deliveryTitle,
    required String deliveryId,
  }) async {
    await createNotification(
      userId: driverId,
      title: '新しい配送案件が割り当てられました',
      message: '「$deliveryTitle」の配送案件が割り当てられました。',
      type: 'delivery',
      relatedId: deliveryId,
    );
  }
  
  static Future<void> notifyDeliveryCompleted({
    required String driverId,
    required String deliveryTitle,
    required String deliveryId,
    required double amount,
  }) async {
    await createNotification(
      userId: driverId,
      title: '配送完了しました',
      message: '「$deliveryTitle」の配送が完了しました。売上¥${amount.toStringAsFixed(0)}が記録されました。',
      type: 'delivery',
      relatedId: deliveryId,
    );
  }
  
  static Future<void> notifyPaymentProcessed({
    required String driverId,
    required double amount,
    required String month,
  }) async {
    await createNotification(
      userId: driverId,
      title: '売上が確定しました',
      message: '${month}分の売上¥${amount.toStringAsFixed(0)}が確定しました。',
      type: 'payment',
      relatedId: month,
    );
  }
  
  // 管理者向け通知
  static Future<void> notifyAdminDeliveryCompleted({
    required String adminId,
    required String driverName,
    required String deliveryTitle,
    required String deliveryId,
  }) async {
    await createNotification(
      userId: adminId,
      title: '配送が完了しました',
      message: '$driverNameさんが「$deliveryTitle」の配送を完了しました。',
      type: 'admin',
      relatedId: deliveryId,
    );
  }
  
  static Future<void> notifyAdminNewDriver({
    required String adminId,
    required String driverName,
    required String driverId,
  }) async {
    await createNotification(
      userId: adminId,
      title: '新しいドライバーが登録されました',
      message: '$driverNameさんが新規登録されました。',
      type: 'admin',
      relatedId: driverId,
    );
  }
}