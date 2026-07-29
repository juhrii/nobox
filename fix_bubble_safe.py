import sys

filepath = r"d:\UBIG\Proyek\NoBox_Chat\nobox\lib\presentation\widgets\message_bubble_widget.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

import re

target = r"border: Border\(\s*left: BorderSide\(\s*color: isMe\s*\?\s*Colors\.white\.withOpacity\(0\.8\)\s*:\s*AppTheme\.primaryColor,\s*width: 4\),\s*\),"
replacement = """border: isMe 
              ? null
              : const Border(
                  left: BorderSide(
                      color: AppTheme.primaryColor,
                      width: 4),
                ),"""

if re.search(target, content):
    content = re.sub(target, replacement, content)
    print("Replaced border safely")
else:
    print("Target not found")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

