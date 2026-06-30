import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

// =====================================================================
// FITUR: Provider Status Chat
// FILE: lib/core/providers/chat_status_provider.dart
// BARIS AWAL: 5 (setelah komentar ini)
// FUNGSI: Mengelola status pengguna seperti 'Online', 'Offline', 'Typing', dan 'Last seen'
// =====================================================================
class ChatStatusProvider with ChangeNotifier {
  final Map<String, String> _userStatus = {};
  final Set<String> _typingUsers = {};

  String getStatus(String sender) {
    return _userStatus[sender] ?? 'Offline';
  }

  bool isTyping(String sender) {
    return _typingUsers.contains(sender);
  }

  void setOnline(String sender) {
    _userStatus[sender] = 'Online';
    notifyListeners();
  }

  void setTyping(String sender, bool typing) {
    if (typing) {
      _typingUsers.add(sender);
    } else {
      _typingUsers.remove(sender);
    }
    notifyListeners();
  }

  void setLastSeen(String sender) {
    final now = DateTime.now();
    final timeString = DateFormat('HH:mm').format(now);
    _userStatus[sender] = 'Terakhir dilihat $timeString'; // Diterjemahkan dari 'Last seen'
    notifyListeners();
  }
}
