import re

path = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\presentation\screens\chat\contact_info_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_filter = '''              final availableStages = stages.where((s) {
                if (selectedPipelineId == null) return true;
                return s['PipelineId']?.toString() == selectedPipelineId;
              }).toList();
  
              final availableDeals = deals.where((d) {
                if (selectedStageId != null) {
                  return d['StageId']?.toString() == selectedStageId;
                } else if (selectedPipelineId != null) {
                  return d['PipelineId']?.toString() == selectedPipelineId;
                }
                return true;
              }).toList();'''

new_filter = '''              final availableStages = stages.where((s) {
                if (selectedPipelineId == null) return true;
                return s['PipelineId']?.toString() == selectedPipelineId || s['project_id']?.toString() == selectedPipelineId;
              }).toList();
  
              final availableDeals = deals.where((d) {
                if (selectedStageId != null) {
                  return d['StageId']?.toString() == selectedStageId || d['piplinetypes']?.toString() == selectedStageId;
                } else if (selectedPipelineId != null) {
                  return d['PipelineId']?.toString() == selectedPipelineId || d['PlId']?.toString() == selectedPipelineId;
                }
                return true;
              }).toList();'''

content = content.replace(old_filter, new_filter)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Success")
