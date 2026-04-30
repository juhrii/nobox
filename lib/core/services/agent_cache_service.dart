class AgentCacheService {
  static final AgentCacheService _instance = AgentCacheService._internal();
  factory AgentCacheService() => _instance;
  AgentCacheService._internal();

  List<Map<String, dynamic>>? _cachedAgents;
  DateTime? _lastFetchTime;
  
  // Cache expires after 15 minutes to ensure we don't hold stale data forever
  static const _cacheDuration = Duration(minutes: 15);

  /// Returns cached agents if available and valid, otherwise null
  List<Map<String, dynamic>>? get cachedAgents {
    if (_cachedAgents != null && _lastFetchTime != null) {
      if (DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
        return _cachedAgents;
      }
    }
    return null;
  }

  /// Updates the cache with new data
  void updateCache(List<Map<String, dynamic>> agents) {
    _cachedAgents = agents;
    _lastFetchTime = DateTime.now();
  }

  /// Clears the cache completely
  void invalidateCache() {
    _cachedAgents = null;
    _lastFetchTime = null;
  }
}
