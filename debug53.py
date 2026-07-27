import re

path = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\presentation\screens\chat\contact_info_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_code = '''                      } else {
                        loadError = 'Pipe keys: ${pipeResp.data?.isNotEmpty == true ? pipeResp.data!.first.keys.join(", ") : "empty"}\\n\\nDeal keys: ${dealResp.data?.isNotEmpty == true ? dealResp.data!.first.keys.join(", ") : "empty"}';
                      }'''

new_code = '''                      } else {
                        // Let's guess the endpoint!
                        String workingEndpoint = "None";
                        final endpoints = [
                          'Services/Nobox/Dealstage/List',
                          'Services/Nobox/DealStage/List',
                          'Services/Nobox/Dealstages/List',
                          'Services/Nobox/DealStages/List',
                          'Services/Nobox/PipelineStage/List',
                          'Services/Nobox/Pipelinestages/List',
                          'Services/Nobox/Stages/List',
                          'Services/Nobox/Stage/List',
                        ];
                        for(var ep in endpoints) {
                          try {
                            final res = await chatProvider.apiClient.post(ep, data: {'Take': 1, 'Skip': 0});
                            if (res.statusCode == 200) {
                              workingEndpoint = ep;
                              break;
                            }
                          } catch(e) {}
                        }
                        loadError = 'Found Stage API: $workingEndpoint';
                      }'''

content = content.replace(old_code, new_code)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Success")
