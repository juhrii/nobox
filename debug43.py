import re

path = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\app_config.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("Services/Nobox/Dealstages/List", "Services/Master/States/List")

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Success")
