import sys

filepath = r"d:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\services\chat_service.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
'''      final requestData = {
        "Search": "",
        "Sort": ["Id DESC"],
      };''',
'''      final requestData = {
        "Sort": ["Id DESC"],
      };'''
)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("Fixed Search payload")
