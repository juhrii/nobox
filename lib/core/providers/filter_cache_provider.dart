import 'package:flutter/foundation.dart';

class FilterCacheProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _tags = [];
  List<Map<String, dynamic>> _funnels = [];
  List<Map<String, dynamic>> _channels = [];
  List<Map<String, dynamic>> _accounts = [];
  
  bool _isDataLoaded = false;
  
  // Getters
  List<Map<String, dynamic>> get tags => _tags;
  List<Map<String, dynamic>> get funnels => _funnels;
  List<Map<String, dynamic>> get channels => _channels;
  List<Map<String, dynamic>> get accounts => _accounts;
  bool get isDataLoaded => _isDataLoaded;

  /// Update all filter data at once and notify listeners
  void updateFilterData({
    required List<Map<String, dynamic>> tags,
    required List<Map<String, dynamic>> funnels,
    required List<Map<String, dynamic>> channels,
    required List<Map<String, dynamic>> accounts,
  }) {
    _tags = tags;
    _funnels = funnels;
    _channels = channels;
    _accounts = accounts;
    _isDataLoaded = true;
    notifyListeners();
  }

  /// Clear the cache
  void invalidateCache() {
    _tags = [];
    _funnels = [];
    _channels = [];
    _accounts = [];
    _isDataLoaded = false;
    notifyListeners();
  }
}
