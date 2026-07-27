import re

path_config = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\app_config.dart'
with open(path_config, 'r', encoding='utf-8') as f:
    config_content = f.read()

config_content = config_content.replace("'Services/Nobox/Dealpipelinestages/List'", "'Services/Nobox/DealStages/List'")

with open(path_config, 'w', encoding='utf-8') as f:
    f.write(config_content)
print("Success")
