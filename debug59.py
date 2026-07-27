import re

path = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\services\chat_service.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_code = '''  Future<ApiResponse<List<Map<String, dynamic>>>> getPipelines({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedPipelines != null) {
      return ApiResponse.success(_cachedPipelines!, 200);
    }
    try {
      final requestData = {
        'Take': 100,
        'Skip': 0,
      };'''

new_code = '''  Future<ApiResponse<List<Map<String, dynamic>>>> getPipelines({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedPipelines != null) {
      return ApiResponse.success(_cachedPipelines!, 200);
    }
    try {
      final requestData = {
        'Take': 100,
        'Skip': 0,
        // Removed IncludeColumns restriction so it gets ALL data!
      };'''

content = content.replace(old_code, new_code)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Success")
