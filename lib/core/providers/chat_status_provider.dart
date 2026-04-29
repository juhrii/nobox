import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

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
    _userStatus[sender] = 'Last seen $timeString';
    notifyListeners();
  }
}
