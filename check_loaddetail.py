import sys

filepath = r"d:\UBIG\Proyek\NoBox_Chat\nobox\lib\presentation\screens\chat\contact_info_page.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

import re
match = re.search(r"Future<void> _loadDetailRoom\(\) async \{.*?\s*// Deal:", content, re.DOTALL)
if match:
    # Print the last 15 lines of the match to see how roomData is processed
    lines = match.group(0).split('\n')
    print('\n'.join(lines[-15:]))
else:
    print("Not found")
