import sys
import re

filepath = r"d:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\services\chat_service.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Use regex to find and remove getKanbanData blocks
pattern = r"  Future<ApiResponse<Map<String, dynamic>>> getKanbanData\(.*?\) async \{.*?\n  \}"
content = re.sub(pattern, "", content, flags=re.DOTALL)

new_kanban = """
  Future<ApiResponse<Map<String, dynamic>>> getKanbanData(String pipelineId, String contactId) async {
    try {
      final payload = {
        "EqualityFilter": {
            "project_id": int.tryParse(pipelineId) ?? pipelineId,
            "KontakId": int.tryParse(contactId) ?? contactId
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

content = content.replace(
    'Future<ApiResponse<List<Map<String, dynamic>>>> getDeals() async {',
    new_kanban.lstrip('\n') + '\n  Future<ApiResponse<List<Map<String, dynamic>>>> getDeals() async {'
)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("Cleaned chat_service.dart")
