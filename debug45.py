import re

path = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\services\chat_service.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace getPipelines to print data
old_code = '''  Future<ApiResponse<List<Map<String, dynamic>>>> getPipelines() async {
    try {
      final requestData = {
        'Take': 100,
        'Skip': 0,
        'IncludeColumns': ['Id', 'Name', 'DisplayName', 'Title', 'Nm', 'PipelineId'],
      };
      final response = await _apiClient.post(AppConfig.pipelinesListEndpoint, data: requestData);
      if (response.statusCode == 200) {
        final List<dynamic> entities = response.data['Entities'] ?? [];'''

new_code = '''  Future<ApiResponse<List<Map<String, dynamic>>>> getPipelines() async {
    try {
      final requestData = {
        'Take': 100,
        'Skip': 0,
        // Let's ask for all columns first to see if Stages are nested
        // 'IncludeColumns': ['Id', 'Name', 'DisplayName', 'Title', 'Nm', 'PipelineId'],
      };
      final response = await _apiClient.post(AppConfig.pipelinesListEndpoint, data: requestData);
      if (response.statusCode == 200) {
        debugPrint('PIPELINES RESPONSE DATA: ${response.data}');
        final List<dynamic> entities = response.data['Entities'] ?? [];'''

content = content.replace(old_code, new_code)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Success")
