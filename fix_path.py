import sys

filepath = r"d:\UBIG\Proyek\NoBox_Chat\nobox\lib\presentation\screens\chat\contact_info_page.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

import re

target = r"File\('C:\\Users\\LENOVO\\room_data_dump\.txt'\)\.writeAsStringSync\(jsonEncode\(data\)\);"
replacement = "File('C:/Users/LENOVO/room_data_dump.txt').writeAsStringSync(jsonEncode(data));"

content = content.replace("File('C:\\Users\\LENOVO\\room_data_dump.txt').writeAsStringSync(jsonEncode(data));", replacement)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("Fixed path")
