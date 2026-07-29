import sys
filepath = r"d:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\services\chat_service.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

import re
match = re.search(r"getPipelines.*?return ApiResponse\.failure\('Failed to load pipelines: \$\{response\.statusCode\}', response\.statusCode!\);", content, re.DOTALL)
if match:
    print(match.group(0))
else:
    print("Not found")
