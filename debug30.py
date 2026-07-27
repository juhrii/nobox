import re

path = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\services\chat_service.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace Take: 0 with Take: 2000
content = content.replace("'Take': 0,", "'Take': 2000,")

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Success')
