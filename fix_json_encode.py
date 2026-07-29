import sys

filepath = r"d:\UBIG\Proyek\NoBox_Chat\nobox\lib\presentation\screens\chat\contact_info_page.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

import re
content = content.replace("jsonEncode(data)", "data.toString()")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("Replaced jsonEncode with toString")
