import sys

filepath = r"d:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\services\chat_service.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

new_pipelines = """
  Future<ApiResponse<List<Map<String, dynamic>>>> getPipelines() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'Nm', 'Title'],
        'ColumnSelection': 1,
        'Take': 100,
        'Skip': 0,
      };
      final response = await _apiClient.post(AppConfig.pipelinesListEndpoint, data: requestData);
      if (response.statusCode == 200) {
        return ApiResponse.success(_parseGenericList(response.data), response.statusCode!);
      }
      return ApiResponse.failure('Failed to load pipelines: ${response.statusCode}', response.statusCode!);
    } catch (e) {
      return ApiResponse.failure(e.toString(), 500);
    }
  }
"""

new_stages = """
  Future<ApiResponse<List<Map<String, dynamic>>>> getStages() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'Nm', 'Title'],
        'ColumnSelection': 1,
        'Take': 100,
        'Skip': 0,
      };
      final response = await _apiClient.post(AppConfig.stagesListEndpoint, data: requestData);
      if (response.statusCode == 200) {
        return ApiResponse.success(_parseGenericList(response.data), response.statusCode!);
      }
      return ApiResponse.failure('Failed to load stages: ${response.statusCode}', response.statusCode!);
    } catch (e) {
      return ApiResponse.failure(e.toString(), 500);
    }
  }
"""

import re
content = re.sub(r'  Future<ApiResponse<List<Map<String, dynamic>>>> getPipelines\(\) async \{.*?\n  \}', new_pipelines.strip('\n'), content, flags=re.DOTALL)
content = re.sub(r'  Future<ApiResponse<List<Map<String, dynamic>>>> getStages\(\) async \{.*?\n  \}', new_stages.strip('\n'), content, flags=re.DOTALL)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated getPipelines and getStages to use _parseGenericList")
