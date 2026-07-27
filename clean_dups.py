import sys
import re

filepath = r"d:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\services\chat_service.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Let's remove everything from the first "Future<ApiResponse<List<Map<String, dynamic>>>> getPipelines() async {"
# up to "Future<ApiResponse<List<Map<String, dynamic>>>> getDeals() async {"
# because that's what I inserted.

start = content.find("  Future<ApiResponse<List<Map<String, dynamic>>>> getPipelines() async {")
end = content.find("  Future<ApiResponse<List<Map<String, dynamic>>>> getDeals() async {")

if start != -1 and end != -1 and start < end:
    content = content[:start] + content[end:]
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Cleaned up duplicates!")
else:
    print("Could not find blocks to remove.")
