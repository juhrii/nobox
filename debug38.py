import re

path = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\presentation\screens\chat\contact_info_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("child: Text('Error: ', style: const TextStyle(color: Colors.red)),", "child: Text('Error: ${loadError}', style: const TextStyle(color: Colors.red)),")

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Success")
