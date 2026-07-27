import sys
filepath = r"d:\UBIG\Proyek\NoBox_Chat\nobox\lib\presentation\screens\chat\contact_info_page.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

import re
target_regex = r"// Deal: dari Data\s*(.*?)\s*final dealData = roomData is Map \? roomData\['Deal'\] : null;\s*if \(dealData is Map\) \{\s*_currentDeal = dealData\['Name'\]\?\.toString\(\) \?\? dealData\['Nm'\]\?\.toString\(\) \?\? _currentDeal;\s*\} else \{\s*final roomDeal = room\['Deal'\]\?\.toString\(\) \?\? '';\s*if \(roomDeal\.isNotEmpty\) _currentDeal = roomDeal;\s*\}"

replacement = """// Deal: dari Data -> Deal atau Room
          final dealData = roomData is Map ? roomData['Deal'] : null;
          if (dealData is Map) {
            _currentDeal = dealData['Name']?.toString() ?? dealData['Nm']?.toString() ?? _currentDeal;
            final pipelineData = dealData['Pipeline']?.toString() ?? dealData['PipelineName']?.toString() ?? '';
            if (pipelineData.isNotEmpty) _currentPipeline = pipelineData;
            final stageData = dealData['Stage']?.toString() ?? dealData['StageName']?.toString() ?? '';
            if (stageData.isNotEmpty) _currentStage = stageData;
          } else {
            final roomDeal = room['Deal']?.toString() ?? '';
            if (roomDeal.isNotEmpty) _currentDeal = roomDeal;
            final roomPipeline = room['Pipeline']?.toString() ?? '';
            if (roomPipeline.isNotEmpty) _currentPipeline = roomPipeline;
            final roomStage = room['Stage']?.toString() ?? '';
            if (roomStage.isNotEmpty) _currentStage = roomStage;
          }"""

if re.search(target_regex, content):
    content = re.sub(target_regex, replacement, content)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Successfully patched _loadDetailRoom using regex!")
else:
    print("Regex not found!")
