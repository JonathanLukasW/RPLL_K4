import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      title: json['title'],
      body: json['body'],
      type: json['type'] ?? 'info',
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class NotificationService {
  final _supabase = Supabase.instance.client;

  // 1. KIRIM NOTIFIKASI (Dipanggil oleh Service Lain)
  Future<void> sendNotification({
    required String recipientId,
    required String title,
    required String body,
    String type = 'info',
    String? relatedId,
  }) async {
    try {
      await _supabase.from('notifications').insert({
        'user_id': recipientId,
        'title': title,
        'body': body,
        'type': type,
        'related_id': relatedId,
      });
    } catch (e) {
      print("Gagal kirim notif: $e");
    }
  }

  // 2. AMBIL STREAM NOTIFIKASI (Realtime)
  Stream<List<NotificationModel>> getMyNotificationsStream() {
    final myId = _supabase.auth.currentUser!.id;
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', myId)
        .order('created_at', ascending: false)
        .map(
          (data) =>
              data.map((json) => NotificationModel.fromJson(json)).toList(),
        );
  }

  // 3. TANDAI SUDAH DIBACA
  Future<void> markAsRead(String notificationId) async {
    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  // 4. HITUNG BELUM DIBACA (Untuk Badge Lonceng)
  Future<int> getUnreadCount() async {
    final myId = _supabase.auth.currentUser!.id;

    // Di Supabase terbaru, ini langsung mengembalikan angka (int)
    final count = await _supabase
        .from('notifications')
        .count(CountOption.exact)
        .eq('user_id', myId)
        .eq('is_read', false);

    return count; // <-- JANGAN PAKAI .count LAGI
  }
}
