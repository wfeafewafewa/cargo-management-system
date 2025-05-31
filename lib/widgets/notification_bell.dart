import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({Key? key}) : super(key: key);

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _listenToNotifications();
  }

  void _listenToNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _unreadCount = snapshot.docs.length;
        });
      }
    });
  }

  void _showNotifications() {
    showDialog(
      context: context,
      builder: (context) => const NotificationDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications),
          onPressed: _showNotifications,
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                '$_unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class NotificationDialog extends StatefulWidget {
  const NotificationDialog({Key? key}) : super(key: key);

  @override
  State<NotificationDialog> createState() => _NotificationDialogState();
}

class _NotificationDialogState extends State<NotificationDialog> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return AlertDialog(
        title: const Text('通知'),
        content: const Text('ログインが必要です。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('通知'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('notifications')
              .where('userId', isEqualTo: user.uid)
              .orderBy('createdAt', descending: true)
              .limit(20)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text('通知はありません'),
              );
            }

            return ListView.builder(
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final doc = snapshot.data!.docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final isRead = data['isRead'] ?? false;
                final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

                return Card(
                  color: isRead ? null : Colors.blue.shade50,
                  child: ListTile(
                    leading: Icon(
                      _getNotificationIcon(data['type']),
                      color: isRead ? Colors.grey : Colors.blue,
                    ),
                    title: Text(
                      data['title'] ?? '',
                      style: TextStyle(
                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['message'] ?? ''),
                        if (createdAt != null)
                          Text(
                            _formatDateTime(createdAt),
                            style: const TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
                    onTap: () => _markAsRead(doc.id, isRead),
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _markAllAsRead,
          child: const Text('すべて既読'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('閉じる'),
        ),
      ],
    );
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'delivery_assigned':
        return Icons.local_shipping;
      case 'delivery_completed':
        return Icons.check_circle;
      case 'payment_received':
        return Icons.payment;
      case 'system':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _markAsRead(String notificationId, bool isCurrentlyRead) {
    if (!isCurrentlyRead) {
      FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    }
  }

  void _markAllAsRead() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        .get()
        .then((snapshot) {
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      return batch.commit();
    });
  }
}

// 通知を送信するヘルパークラス
class NotificationService {
  static Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
    String type = 'system',
    Map<String, dynamic>? data,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': userId,
        'title': title,
        'message': message,
        'type': type,
        'data': data ?? {},
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('通知送信エラー: $e');
    }
  }

  // 配送案件割り当て通知
  static Future<void> notifyDeliveryAssigned({
    required String driverId,
    required String deliveryId,
    required String pickupLocation,
    required String deliveryLocation,
  }) async {
    await sendNotification(
      userId: driverId,
      title: '新しい配送案件が割り当てられました',
      message: '$pickupLocation → $deliveryLocation',
      type: 'delivery_assigned',
      data: {'deliveryId': deliveryId},
    );
  }

  // 配送完了通知（管理者向け）
  static Future<void> notifyDeliveryCompleted({
    required String adminId,
    required String deliveryId,
    required String driverName,
    required String deliveryLocation,
  }) async {
    await sendNotification(
      userId: adminId,
      title: '配送が完了しました',
      message: '$driverName が $deliveryLocation への配送を完了しました',
      type: 'delivery_completed',
      data: {'deliveryId': deliveryId},
    );
  }

  // 売上発生通知（ドライバー向け）
  static Future<void> notifyPaymentReceived({
    required String driverId,
    required double amount,
    required String deliveryLocation,
  }) async {
    await sendNotification(
      userId: driverId,
      title: '売上が発生しました',
      message: '$deliveryLocation の配送で ¥${amount.toStringAsFixed(0)} の売上が発生しました',
      type: 'payment_received',
      data: {'amount': amount},
    );
  }

  // 全管理者に通知を送信
  static Future<void> notifyAllAdmins({
    required String title,
    required String message,
    String type = 'system',
    Map<String, dynamic>? data,
  }) async {
    try {
      final adminsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      
      for (final doc in adminsSnapshot.docs) {
        final notificationRef = FirebaseFirestore.instance
            .collection('notifications')
            .doc();
        
        batch.set(notificationRef, {
          'userId': doc.id,
          'title': title,
          'message': message,
          'type': type,
          'data': data ?? {},
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      print('管理者通知送信エラー: $e');
    }
  }
}