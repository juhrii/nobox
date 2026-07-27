import sys

filepath = r"d:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\services\chat_service.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Let's see if we can find Pipeline or Stage in getDetailRoom
print("Found Pipeline in chat_service.dart: ", "Pipeline" in content)
print("Found Stage in chat_service.dart: ", "Stage" in content)
