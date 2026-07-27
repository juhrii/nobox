import sys

filepath = r"d:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\services\chat_service.dart"

with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_methods = """
  Future<ApiResponse<List<Map<String, dynamic>>>> getPipelines() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'PlId', 'Name', 'DisplayName', 'Title', 'Nm'],
        'ColumnSelection': 1,
        'Take': 2000,
        'Skip': 0,
        'Sort': ['Name ASC'],
      };
      final response = await _apiClient.post(AppConfig.pipelinesListEndpoint, data: requestData);
      
      if (response.statusCode == 200) {
        final List<dynamic> entities = response.data['Entities'] ?? [];
        return ApiResponse.success(
            entities.map((e) => Map<String, dynamic>.from(e)).toList(), response.statusCode!);
      }
      return ApiResponse.failure('Failed to load pipelines: ${response.statusCode}', response.statusCode!);
    } catch (e) {
      return ApiResponse.failure(e.toString(), 500);
    }
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> getStages() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'DisplayName', 'Title', 'Nm'],
        'ColumnSelection': 1,
        'Take': 2000,
        'Skip': 0,
        'Sort': ['Name ASC'],
      };
      final response = await _apiClient.post(AppConfig.stagesListEndpoint, data: requestData);
      
      if (response.statusCode == 200) {
        final List<dynamic> entities = response.data['Entities'] ?? [];
        return ApiResponse.success(
            entities.map((e) => Map<String, dynamic>.from(e)).toList(), response.statusCode!);
      }
      return ApiResponse.failure('Failed to load stages: ${response.statusCode}', response.statusCode!);
    } catch (e) {
      return ApiResponse.failure(e.toString(), 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getKanbanData(String pipelineId) async {
    try {
      final payload = {
        "EqualityFilter": {
            "project_id": int.tryParse(pipelineId) ?? pipelineId
        },
        "Sort": [
          "Urutan ASC"
        ]
      };
      
      final response = await _apiClient.post('Services/Nobox/Deals/KanbanData', data: payload);
      
      if (response.statusCode == 200) {
        return ApiResponse.success(response.data is Map ? Map<String, dynamic>.from(response.data) : {}, response.statusCode!);
      }
      return ApiResponse.failure(response.data?['Message'] ?? 'Failed to get kanban data', response.statusCode ?? 500);
    } on DioException catch (e) {
      final serverMsg = e.response?.data?.toString() ?? e.toString();
      debugPrint('KANBAN ERROR: $serverMsg');
      return ApiResponse.failure(serverMsg, e.response?.statusCode ?? 500);
    } catch (e) {
      return ApiResponse.failure(e.toString(), 500);
    }
  }
"""

new_lines = []
for line in lines:
    new_lines.append(line)
    if line.strip() == "Future<ApiResponse<List<Map<String, dynamic>>>> getDeals() async {":
        # Insert before getDeals
        new_lines.insert(len(new_lines)-1, new_methods)

with open(filepath, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
