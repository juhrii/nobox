import re

path = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\app_config.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add endpoints
old = "static const String dealsListEndpoint = 'Services/Nobox/Deals/List';"
new = "static const String dealsListEndpoint = 'Services/Nobox/Deals/List';\n  static const String pipelinesListEndpoint = 'Services/Nobox/Pipeline/List';\n  static const String stagesListEndpoint = 'Services/Nobox/Stage/List';"

if old in content:
    content = content.replace(old, new)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Success AppConfig")
else:
    print("Failed AppConfig")

path2 = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\services\chat_service.dart'
with open(path2, 'r', encoding='utf-8') as f:
    content2 = f.read()

method = '''
  Future<ApiResponse<List<Map<String, dynamic>>>> getPipelines() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'DisplayName', 'Title', 'Nm'],
        'ColumnSelection': 1,
        'Take': 2000,
        'Skip': 0,
        'Sort': ['Name ASC'],
      };
      final response = await _apiClient.post(AppConfig.pipelinesListEndpoint, data: requestData);
      
      if (response.statusCode == 200) {
        final List<dynamic> entities = response.data['Entities'] ?? [];
        return ApiResponse<List<Map<String, dynamic>>>(
            data: entities.map((e) => Map<String, dynamic>.from(e)).toList());
      }
      return ApiResponse.error("Failed to fetch pipelines");
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> getStages() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'DisplayName', 'Title', 'Nm', 'PipelineId'],
        'ColumnSelection': 1,
        'Take': 2000,
        'Skip': 0,
        'Sort': ['Name ASC'],
      };
      final response = await _apiClient.post(AppConfig.stagesListEndpoint, data: requestData);
      
      if (response.statusCode == 200) {
        final List<dynamic> entities = response.data['Entities'] ?? [];
        return ApiResponse<List<Map<String, dynamic>>>(
            data: entities.map((e) => Map<String, dynamic>.from(e)).toList());
      }
      return ApiResponse.error("Failed to fetch stages");
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }
'''

idx = content2.find("  Future<ApiResponse<List<Map<String, dynamic>>>> getDeals() async {")
if idx != -1:
    content2 = content2[:idx] + method + "\n" + content2[idx:]
    with open(path2, 'w', encoding='utf-8') as f:
        f.write(content2)
    print("Success ChatService")
else:
    print("Failed ChatService")
