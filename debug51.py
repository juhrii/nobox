import re

path = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\presentation\screens\chat\contact_info_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_code = '''                      // FORCE ERROR TO SHOW KEYS SO WE CAN DEBUG!
                      loadError = 'Pipe keys: ${pipelines.isNotEmpty ? pipelines.first.keys.join(", ") : "empty"}\\n\\nStage keys: ${stages.isNotEmpty ? stages.first.keys.join(", ") : "empty"}\\n\\nDeal keys: ${deals.isNotEmpty ? deals.first.keys.join(", ") : "empty"}';'''

new_code = '''                      // Everything is fine, let it show the dropdowns
                      loadError = null;'''

content = content.replace(old_code, new_code)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Success")
