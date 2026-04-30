import 'package:flutter/foundation.dart';

class NewConversationCacheProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _channels = [];
  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _links = [];
  List<Map<String, dynamic>> _campaigns = [];
  
  bool _isDataLoaded = false;
  
  // Getters
  List<Map<String, dynamic>> get contacts => _contacts;
  List<Map<String, dynamic>> get groups => _groups;
  List<Map<String, dynamic>> get channels => _channels;
  List<Map<String, dynamic>> get accounts => _accounts;
  List<Map<String, dynamic>> get links => _links;
  List<Map<String, dynamic>> get campaigns => _campaigns;
  bool get isDataLoaded => _isDataLoaded;

  /// Update all conversation setup data at once and notify listeners
  void updateConversationData({
    required List<Map<String, dynamic>> contacts,
    required List<Map<String, dynamic>> groups,
    required List<Map<String, dynamic>> channels,
    required List<Map<String, dynamic>> accounts,
    required List<Map<String, dynamic>> links,
    required List<Map<String, dynamic>> campaigns,
  }) {
    _contacts = contacts;
    _groups = groups;
    _channels = channels;
    _accounts = accounts;
    _links = links;
    _campaigns = campaigns;
    _isDataLoaded = true;
    notifyListeners();
  }

  /// Clear the cache
  void invalidateCache() {
    _contacts = [];
    _groups = [];
    _channels = [];
    _accounts = [];
    _links = [];
    _campaigns = [];
    _isDataLoaded = false;
    notifyListeners();
  }
}
