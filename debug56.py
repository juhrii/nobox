import re

path = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\services\chat_service.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_code = '''  Future<ApiResponse<List<Map<String, dynamic>>>> getStages() async {
    try {
      final requestData = {
        'Take': 100,
        'Skip': 0,
        'IncludeColumns': ['Id', 'Name', 'Nm', 'Title', 'PipelineId', 'DealPipelineId'],
      };
      final response = await _apiClient.post(AppConfig.stagesListEndpoint, data: requestData);
      if (response.statusCode == 200) {
        final List<dynamic> entities = response.data['Entities'] ?? [];
        return ApiResponse.success(
            entities.map((e) => Map<String, dynamic>.from(e)).toList(), response.statusCode!);
      }
      return ApiResponse.failure(response.data?['Message'] ?? 'Failed to get stages');
    } catch (e) {
      return ApiResponse.failure(e.toString());
    }
  }'''

new_code = '''  Future<ApiResponse<List<Map<String, dynamic>>>> getStages() async {
    final requestData = {
      'Take': 100,
      'Skip': 0,
      'IncludeColumns': ['Id', 'Name', 'Nm', 'Title', 'PipelineId', 'DealPipelineId'],
    };
    final endpoints = [
      AppConfig.stagesListEndpoint,
      'Services/Nobox/Dealpipelinestages/List',
      'Services/Nobox/DealPipelineStages/List',
      'Services/Nobox/Dealstages/List',
      'Services/Nobox/DealStages/List',
      'Services/Nobox/Pipelinestages/List',
      'Services/Nobox/PipelineStages/List',
      'Services/Nobox/Stages/List',
      'Services/Nobox/Dealstage/List',
      'Services/Nobox/DealStage/List',
      'Services/NoBoxCRM/Dealstages/List',
      'Services/NoBoxCRM/DealStages/List',
      'Services/NoBoxCRM/DealPipelineStages/List',
      'Services/NoBoxCRM/Dealpipelinestages/List',
      'Services/Chat/Dealstages/List',
    ];
    String lastError = "";
    for (var ep in endpoints) {
      try {
        final res = await _apiClient.post(ep, data: requestData);
        if (res.statusCode == 200) {
          final List<dynamic> entities = res.data['Entities'] ?? [];
          return ApiResponse.success(
            entities.map((e) => Map<String, dynamic>.from(e)).toList(), 
            res.statusCode!
          );
        }
      } catch(e) {
        lastError = e.toString();
      }
    }
    return ApiResponse.failure('Not found in any endpoint. Last error: $lastError');
  }'''

content = content.replace(old_code, new_code)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Success")
