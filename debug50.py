import re

path = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\presentation\screens\chat\contact_info_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_code = '''              // Filter stages by selected pipeline
              final filteredStages = stages.where((s) {
                if (selectedPipelineId == null) return true;
                return s['PipelineId']?.toString() == selectedPipelineId;
              }).toList();

              // Filter deals by selected stage
              final filteredDeals = deals.where((d) {
                if (selectedStageId != null) {
                  return d['StageId']?.toString() == selectedStageId;
                } else if (selectedPipelineId != null) {
                  return d['PipelineId']?.toString() == selectedPipelineId;
                }
                return true;
              }).toList();'''

new_code = '''              // Filter stages by selected pipeline
              final filteredStages = stages.where((s) {
                if (selectedPipelineId == null) return true;
                return s['PipelineId']?.toString() == selectedPipelineId || s['DealPipelineId']?.toString() == selectedPipelineId;
              }).toList();

              // Filter deals by selected stage
              final filteredDeals = deals.where((d) {
                if (selectedStageId != null) {
                  return d['StageId']?.toString() == selectedStageId || d['DealStageId']?.toString() == selectedStageId;
                } else if (selectedPipelineId != null) {
                  return d['PipelineId']?.toString() == selectedPipelineId || d['DealPipelineId']?.toString() == selectedPipelineId;
                }
                return true;
              }).toList();'''

content = content.replace(old_code, new_code)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Success")
