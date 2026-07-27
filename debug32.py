import re

path = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\services\chat_service.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# I need to see what fields are available in Pipeline, Stage, and Deal APIs
# Wait, let's just make a script to fetch one deal, one pipeline, one stage and print their keys!
