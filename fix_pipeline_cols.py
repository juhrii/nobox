import sys

filepath = r"d:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\services\chat_service.dart"

with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if "'IncludeColumns': ['Id', 'Name', 'DisplayName', 'Title', 'Nm']," in line:
        new_lines.append("          'IncludeColumns': ['Id', 'PlId', 'Name', 'DisplayName', 'Title', 'Nm'],\n")
    else:
        new_lines.append(line)

with open(filepath, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
