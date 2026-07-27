import re

path = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\providers\chat_provider.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add _cachedPipelinesResponse and _cachedStagesResponse variables
old_vars = '''  ApiResponse<List<Map<String, dynamic>>>? _cachedCampaignsResponse;
  ApiResponse<List<Map<String, dynamic>>>? _cachedDealsResponse;'''
new_vars = '''  ApiResponse<List<Map<String, dynamic>>>? _cachedCampaignsResponse;
  ApiResponse<List<Map<String, dynamic>>>? _cachedPipelinesResponse;
  ApiResponse<List<Map<String, dynamic>>>? _cachedStagesResponse;
  ApiResponse<List<Map<String, dynamic>>>? _cachedDealsResponse;'''

if old_vars in content:
    content = content.replace(old_vars, new_vars)

# Add the methods
old_method = '''  Future<ApiResponse<List<Map<String, dynamic>>>> getDealsResponse({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedDealsResponse != null) return _cachedDealsResponse!;
    _cachedDealsResponse = await _chatService.getDeals();
    return _cachedDealsResponse!;
  }'''
  
new_methods = '''  Future<ApiResponse<List<Map<String, dynamic>>>> getPipelinesResponse({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedPipelinesResponse != null) return _cachedPipelinesResponse!;
    _cachedPipelinesResponse = await _chatService.getPipelines();
    return _cachedPipelinesResponse!;
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> getStagesResponse({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedStagesResponse != null) return _cachedStagesResponse!;
    _cachedStagesResponse = await _chatService.getStages();
    return _cachedStagesResponse!;
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> getDealsResponse({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedDealsResponse != null) return _cachedDealsResponse!;
    _cachedDealsResponse = await _chatService.getDeals();
    return _cachedDealsResponse!;
  }'''

if old_method in content:
    content = content.replace(old_method, new_methods)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Success')
