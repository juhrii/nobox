import re

path = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\presentation\screens\chat\contact_info_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_code = '''                      if (selectedPipelineId != null) {
                        final stageResp = await chatProvider.getStagesResponse();
                        final dealResp = await chatProvider.getDealsResponse();
                        
                        if (!stageResp.isError && !dealResp.isError) {
                          filteredStages = stageResp.data ?? [];
                          filteredDeals = dealResp.data ?? [];
                          
                          // Filter manually
                          filteredStages = filteredStages.where((s) => s['PipelineId']?.toString() == selectedPipelineId || s['DealPipelineId']?.toString() == selectedPipelineId).toList();
                          filteredDeals = filteredDeals.where((d) => d['PipelineId']?.toString() == selectedPipelineId || d['DealPipelineId']?.toString() == selectedPipelineId).toList();
                        }
                        
                        // Everything is fine, let it show the dropdowns
                        loadError = null;
                      } else {
                        loadError = 'Pipe keys: ${pipeResp.data?.isNotEmpty == true ? pipeResp.data!.first.keys.join(", ") : "empty"}';
                      }'''

new_code = '''                      if (selectedPipelineId != null) {
                        final kanbanResp = await chatProvider.getKanbanData(selectedPipelineId!);
                        
                        if (!kanbanResp.isError && kanbanResp.data != null) {
                          final Map<String, dynamic> data = kanbanResp.data!;
                          final List<dynamic> headers = data['ArrHeader'] ?? [];
                          final List<dynamic> items = data['ArrItem'] ?? [];
                          
                          filteredStages = headers.map((e) => Map<String, dynamic>.from(e)).toList();
                          filteredDeals = items.map((e) => Map<String, dynamic>.from(e)).toList();
                        } else {
                          loadError = 'Kanban Err: ${kanbanResp.error}';
                        }
                      } else {
                        // reset if no pipeline selected
                        filteredStages = [];
                        filteredDeals = [];
                        loadError = null;
                      }'''

content = content.replace(old_code, new_code)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Success")
