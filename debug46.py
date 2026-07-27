import re

path = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\services\chat_service.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_code = '''  Future<ApiResponse<List<Map<String, dynamic>>>> getDeals() async {
    try {
      final requestData = {
        'Take': 100,
        'Skip': 0,
        'IncludeColumns': ['Id', 'Name', 'DisplayName', 'Title', 'Nm', 'StageId', 'PipelineId'],
      };
      final response = await _apiClient.post(AppConfig.dealsListEndpoint, data: requestData);
      if (response.statusCode == 200) {
        final List<dynamic> entities = response.data['Entities'] ?? [];'''

new_code = '''  Future<ApiResponse<List<Map<String, dynamic>>>> getDeals() async {
    try {
      final requestData = {
        'Take': 100,
        'Skip': 0,
        // Remove columns restriction to see all fields
        // 'IncludeColumns': ['Id', 'Name', 'DisplayName', 'Title', 'Nm', 'StageId', 'PipelineId'],
      };
      final response = await _apiClient.post(AppConfig.dealsListEndpoint, data: requestData);
      if (response.statusCode == 200) {
        debugPrint('DEALS RESPONSE DATA: ${response.data}');
        final List<dynamic> entities = response.data['Entities'] ?? [];'''

content = content.replace(old_code, new_code)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Success")
