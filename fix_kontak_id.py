import sys

# 1. Update chat_service.dart
filepath_service = r"d:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\services\chat_service.dart"
with open(filepath_service, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    'Future<ApiResponse<Map<String, dynamic>>> getKanbanData(String pipelineId) async {',
    'Future<ApiResponse<Map<String, dynamic>>> getKanbanData(String pipelineId, String contactId) async {'
)

old_payload = """      final payload = {
        "EqualityFilter": {
            "project_id": int.tryParse(pipelineId) ?? pipelineId
        },
        "Sort": [
          "Urutan ASC"
        ]
      };"""
new_payload = """      final payload = {
        "EqualityFilter": {
            "project_id": int.tryParse(pipelineId) ?? pipelineId,
            "KontakId": int.tryParse(contactId) ?? contactId
        },
        "Sort": [
          "Urutan ASC"
        ]
      };"""
content = content.replace(old_payload, new_payload)

with open(filepath_service, 'w', encoding='utf-8') as f:
    f.write(content)

# 2. Update chat_provider.dart
filepath_provider = r"d:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\providers\chat_provider.dart"
with open(filepath_provider, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    'Future<ApiResponse<Map<String, dynamic>>> getKanbanData(String pipelineId) async {',
    'Future<ApiResponse<Map<String, dynamic>>> getKanbanData(String pipelineId, String contactId) async {'
)
content = content.replace(
    'return await _chatService.getKanbanData(pipelineId);',
    'return await _chatService.getKanbanData(pipelineId, contactId);'
)

with open(filepath_provider, 'w', encoding='utf-8') as f:
    f.write(content)

# 3. Update contact_info_page.dart
filepath_ui = r"d:\UBIG\Proyek\NoBox_Chat\nobox\lib\presentation\screens\chat\contact_info_page.dart"
with open(filepath_ui, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    'final kanbanResp = await chatProvider.getKanbanData(newValue);',
    'final kanbanResp = await chatProvider.getKanbanData(newValue, widget.chat.id);'
)

with open(filepath_ui, 'w', encoding='utf-8') as f:
    f.write(content)
