import sys

filepath = r"d:\UBIG\Proyek\NoBox_Chat\nobox\lib\presentation\screens\chat\contact_info_page.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

import re

# Add imports to top if they don't exist
if "import 'dart:io';" not in content:
    content = "import 'dart:io';\n" + content
if "import 'dart:convert';" not in content:
    content = "import 'dart:convert';\n" + content

# Inject dump
target = r"final roomData = response\.data\['Data'\];"
replacement = """final roomData = response.data['Data'];
          try {
            File('C:\\\\Users\\\\LENOVO\\\\room_data_dump.txt').writeAsStringSync(jsonEncode(response.data));
          } catch(e) {
             print("Error writing dump: $e");
          }"""

if re.search(target, content):
    content = re.sub(target, replacement, content)
    print("Injected JSON dump")
else:
    print("Could not find target")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
