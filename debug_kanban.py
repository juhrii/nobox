import sys

filepath = r"d:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\services\chat_service.dart"

with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if "final response = await _apiClient.post('Services/Nobox/Deals/KanbanData', data: payload);" in line:
        new_lines.append("        debugPrint('KANBAN PAYLOAD: $payload');\n")
        new_lines.append(line)
    else:
        new_lines.append(line)

with open(filepath, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
