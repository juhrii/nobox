import re

path = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\presentation\screens\chat\contact_info_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_code = '''                      } else {
                        loadError = 'Pipe keys: ${pipeResp.data?.isNotEmpty == true ? pipeResp.data!.first.keys.join(", ") : "empty"}\\n\\nDeal keys: ${dealResp.data?.isNotEmpty == true ? dealResp.data!.first.keys.join(", ") : "empty"}';
                      }'''

new_code = '''                      } else {
                        loadError = 'Stage Err: ${stageResp.error}\\nPipe keys: ${pipeResp.data?.isNotEmpty == true ? pipeResp.data!.first.keys.join(", ") : "empty"}\\nDeal keys: ${dealResp.data?.isNotEmpty == true ? dealResp.data!.first.keys.join(", ") : "empty"}';
                      }'''

content = content.replace(old_code, new_code)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Success")
