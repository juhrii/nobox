import re

path = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\presentation\screens\chat\contact_info_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Make it show the keys in loadError even if it succeeds!
old_code = '''                    if (!pipeResp.isError && !stageResp.isError && !dealResp.isError) {
                      pipelines = pipeResp.data ?? [];
                      stages = stageResp.data ?? [];
                      deals = dealResp.data ?? [];
                      
                      // Pre-select if we already have a deal
                      for (final d in deals) {
                        final name = d['Name']?.toString() ?? d['Nm']?.toString() ?? d['Title']?.toString() ?? '';
                        if (name == _currentDeal && name.isNotEmpty) {
                          selectedDealId = d['Id']?.toString();
                          selectedStageId = d['StageId']?.toString();
                          selectedPipelineId = d['PipelineId']?.toString();
                          break;
                        }
                      }
                    } else {'''

new_code = '''                    if (!pipeResp.isError && !stageResp.isError && !dealResp.isError) {
                      pipelines = pipeResp.data ?? [];
                      stages = stageResp.data ?? [];
                      deals = dealResp.data ?? [];
                      
                      // Pre-select if we already have a deal
                      for (final d in deals) {
                        final name = d['Name']?.toString() ?? d['Nm']?.toString() ?? d['Title']?.toString() ?? '';
                        if (name == _currentDeal && name.isNotEmpty) {
                          selectedDealId = d['Id']?.toString();
                          selectedStageId = d['StageId']?.toString();
                          selectedPipelineId = d['PipelineId']?.toString();
                          break;
                        }
                      }
                      
                      // FORCE ERROR TO SHOW KEYS SO WE CAN DEBUG!
                      loadError = 'Pipe keys: ${pipelines.isNotEmpty ? pipelines.first.keys.join(", ") : "empty"}\\n\\nStage keys: ${stages.isNotEmpty ? stages.first.keys.join(", ") : "empty"}\\n\\nDeal keys: ${deals.isNotEmpty ? deals.first.keys.join(", ") : "empty"}';
                    } else {'''

content = content.replace(old_code, new_code)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Success")
