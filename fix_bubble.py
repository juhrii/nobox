import sys

filepath = r"d:\UBIG\Proyek\NoBox_Chat\nobox\lib\presentation\widgets\message_bubble_widget.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

import re

target = r"borderRadius: BorderRadius\.circular\(8\),\s*: AppTheme\.primaryColor,\s*width: 4\),\s*\),"
# Let's just find the exact block and replace it!

# Let's find _buildReplyPreview function and rebuild its decoration block.
# I will use a simple regex to replace the entire decoration block.
target_regex = r"decoration: BoxDecoration\([\s\S]*?borderRadius: BorderRadius\.circular\(8\),\s*(?:border:[\s\S]*?)?\s*\),"
replacement = """decoration: BoxDecoration(
          color: isMe
              ? Colors.black.withOpacity(0.15) // Darker overlay for blue bubble
              : (isDarkMode
                  ? Colors.black.withOpacity(0.2)
                  : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(8),
          border: isMe 
              ? null
              : const Border(
                  left: BorderSide(
                    color: AppTheme.primaryColor,
                    width: 4,
                  ),
                ),
        ),"""

content = re.sub(target_regex, replacement, content, count=1)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("Fixed message bubble widget decoration")
