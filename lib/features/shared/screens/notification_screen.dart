import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import 'package:intl/intl.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifikasi"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: NotificationService().getMyNotificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final data = snapshot.data ?? [];
          if (data.isEmpty) {
            return const Center(child: Text("Belum ada notifikasi."));
          }

          return ListView.builder(
            itemCount: data.length,
            itemBuilder: (context, index) {
              final item = data[index];
              return Card(
                color: item.isRead ? Colors.white : Colors.blue[50], // Warna beda kalau belum baca
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: _getIcon(item.type),
                  title: Text(item.title, style: TextStyle(fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.body),
                      const SizedBox(height: 5),
                      Text(DateFormat('dd MMM HH:mm').format(item.createdAt), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                  onTap: () {
                    // Tandai sudah dibaca
                    NotificationService().markAsRead(item.id);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Icon _getIcon(String type) {
    if (type == 'error') return const Icon(Icons.error, color: Colors.red);
    if (type == 'warning') return const Icon(Icons.warning, color: Colors.orange);
    if (type == 'success') return const Icon(Icons.check_circle, color: Colors.green);
    return const Icon(Icons.notifications, color: Colors.blue);
  }
}