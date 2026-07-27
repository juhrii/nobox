import re

path = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\presentation\screens\chat\contact_info_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Change the error block to capture the actual errors
old = '''                    if (!pipeResp.isError && !stageResp.isError && !dealResp.isError) {
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
                    } else {
                      loadError = 'Failed to load data';
                    }'''

new = '''                    if (!pipeResp.isError && !stageResp.isError && !dealResp.isError) {
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
                    } else {
                      loadError = 'Pipe: ${pipeResp.error}, Stage: ${stageResp.error}, Deal: ${dealResp.error}';
                    }'''

content = content.replace(old, new)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Success")
