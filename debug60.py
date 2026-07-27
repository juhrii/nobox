import re

path = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\services\chat_service.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add getKanbanData
new_method = '''  Future<ApiResponse<Map<String, dynamic>>> getKanbanData(String pipelineId) async {
    try {
      final payload = {
        "EqualityFilter": {
          "project_id": pipelineId
        },
        "Sort": [
          "Urutan ASC"
        ]
      };
      
      final response = await _apiClient.post('Services/Nobox/Deals/KanbanData', data: payload);
      
      if (response.statusCode == 200) {
        return ApiResponse.success(response.data is Map ? Map<String, dynamic>.from(response.data) : {}, response.statusCode!);
      }
      return ApiResponse.failure(response.data?['Message'] ?? 'Failed to get kanban data');
    } catch (e) {
      return ApiResponse.failure(e.toString());
    }
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> getPipelines'''

content = content.replace("  Future<ApiResponse<List<Map<String, dynamic>>>> getPipelines", new_method)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Success")
