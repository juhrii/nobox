import re

path = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\providers\chat_provider.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add getKanbanData
new_method = '''  Future<ApiResponse<Map<String, dynamic>>> getKanbanData(String pipelineId) async {
    return await _chatService.getKanbanData(pipelineId);
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> getPipelinesResponse'''

content = content.replace("  Future<ApiResponse<List<Map<String, dynamic>>>> getPipelinesResponse", new_method)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Success")
