import re

path_config = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\app_config.dart'
with open(path_config, 'r', encoding='utf-8') as f:
    config_content = f.read()

config_content = config_content.replace("'Services/Master/States/List'", "'Services/Nobox/Dealpipelinestages/List'")

with open(path_config, 'w', encoding='utf-8') as f:
    f.write(config_content)

path_ui = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\presentation\screens\chat\contact_info_page.dart'
with open(path_ui, 'r', encoding='utf-8') as f:
    ui_content = f.read()

# Replace Stage Dropdown
old_stage = '''              DropdownButtonFormField<String>(
                value: selectedStageId,
                decoration: const InputDecoration(labelText: 'Stage'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('-- All Stages --')),
                  ...filteredStages.map((s) {
                    return DropdownMenuItem<String>(
                      value: s['Id'].toString(),
                      child: Text(s['Name']?.toString() ?? s['Nm']?.toString() ?? 'Unnamed'),
                    );
                  }),
                ],
                onChanged: (val) {
                  setDialogState(() {
                    selectedStageId = val;
                    selectedDealId = null; // Reset deal when stage changes
                  });
                },
              ),'''

new_stage = '''              DropdownButtonFormField<String>(
                value: selectedPipelineId == null ? null : selectedStageId,
                decoration: const InputDecoration(labelText: 'Stage'),
                items: selectedPipelineId == null 
                  ? [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('-- Select Pipeline First --', style: TextStyle(color: Colors.grey)),
                      )
                    ]
                  : [
                      const DropdownMenuItem(value: null, child: Text('-- All Stages --')),
                      ...filteredStages.map((s) {
                        return DropdownMenuItem<String>(
                          value: s['Id'].toString(),
                          child: Text(s['Name']?.toString() ?? s['Nm']?.toString() ?? 'Unnamed'),
                        );
                      }),
                    ],
                onChanged: selectedPipelineId == null 
                  ? null
                  : (val) {
                      setDialogState(() {
                        selectedStageId = val;
                        selectedDealId = null; // Reset deal when stage changes
                      });
                    },
              ),'''

ui_content = ui_content.replace(old_stage, new_stage)

# Replace Deal Dropdown
old_deal = '''              DropdownButtonFormField<String>(
                value: selectedDealId,
                decoration: const InputDecoration(labelText: 'Deal'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('-- All Deals --')),
                  ...filteredDeals.map((d) {
                    return DropdownMenuItem<String>(
                      value: d['Id'].toString(),
                      child: Text(d['Name']?.toString() ?? d['Nm']?.toString() ?? d['Title']?.toString() ?? 'Unnamed'),
                    );
                  }),
                ],
                onChanged: (val) {
                  setDialogState(() => selectedDealId = val);
                },
              ),'''

new_deal = '''              DropdownButtonFormField<String>(
                value: selectedStageId == null ? null : selectedDealId,
                decoration: const InputDecoration(labelText: 'Deal'),
                items: selectedStageId == null 
                  ? [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('-- Select Stage First --', style: TextStyle(color: Colors.grey)),
                      )
                    ]
                  : [
                      const DropdownMenuItem(value: null, child: Text('-- All Deals --')),
                      ...filteredDeals.map((d) {
                        return DropdownMenuItem<String>(
                          value: d['Id'].toString(),
                          child: Text(d['Name']?.toString() ?? d['Nm']?.toString() ?? d['Title']?.toString() ?? 'Unnamed'),
                        );
                      }),
                    ],
                onChanged: selectedStageId == null 
                  ? null
                  : (val) {
                      setDialogState(() => selectedDealId = val);
                    },
              ),'''

ui_content = ui_content.replace(old_deal, new_deal)

with open(path_ui, 'w', encoding='utf-8') as f:
    f.write(ui_content)

print("Success")
