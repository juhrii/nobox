import sys
filepath = r"d:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\app_config.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("'Services/Nobox/Dealpipelinetypes/List'", "'Services/Nobox/Dealpipelines/List'")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated pipelinesListEndpoint to Dealpipelines/List")
