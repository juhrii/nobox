import sys
filepath = r"d:\UBIG\Proyek\NoBox_Chat\nobox\lib\presentation\screens\chat\contact_info_page.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

import re
# The injected code is:
#           try {
#             import 'dart:convert';
#             import 'dart:io';
#             File('C:\\Users\\LENOVO\\room_data.txt').writeAsStringSync(jsonEncode(response.data));
#           } catch(e) {}
# Let's remove it completely and put back the original.
content = re.sub(r"try \{\s*import 'dart:convert';\s*import 'dart:io';\s*File\('C:\\\\Users\\\\LENOVO\\\\room_data\.txt'\)\.writeAsStringSync\(jsonEncode\(response\.data\)\);\s*\} catch\(e\) \{\}", "", content)

# And remove the other one if it exists
content = re.sub(r"try \{\s*File\('C:\\\\Users\\\\LENOVO\\\\room_data\.txt'\)\.writeAsStringSync\(jsonEncode\(data\)\);\s*\} catch\(e\) \{\}", "", content)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("Restored.")
