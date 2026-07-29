import sys
filepath = r"d:\UBIG\Proyek\NoBox_Chat\nobox\lib\presentation\screens\chat\contact_info_page.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

import re
target = r"final dealData = roomData is Map \? roomData\['Deal'\] : null;\s*if \(dealData is Map\) \{\s*_currentDeal = dealData\['Name'\]\?\.toString\(\) \?\? dealData\['Nm'\]\?\.toString\(\) \?\? _currentDeal;\s*final pipelineData = dealData\['Pipeline'\]\?\.toString\(\) \?\? dealData\['PipelineName'\]\?\.toString\(\) \?\? '';\s*if \(pipelineData\.isNotEmpty\) _currentPipeline = pipelineData;\s*final stageData = dealData\['Stage'\]\?\.toString\(\) \?\? dealData\['StageName'\]\?\.toString\(\) \?\? '';\s*if \(stageData\.isNotEmpty\) _currentStage = stageData;\s*\} else \{\s*final roomDeal = room\['Deal'\]\?\.toString\(\) \?\? '';\s*if \(roomDeal\.isNotEmpty\) _currentDeal = roomDeal;\s*final roomPipeline = room\['Pipeline'\]\?\.toString\(\) \?\? '';\s*if \(roomPipeline\.isNotEmpty\) _currentPipeline = roomPipeline;\s*final roomStage = room\['Stage'\]\?\.toString\(\) \?\? '';\s*if \(roomStage\.isNotEmpty\) _currentStage = roomStage;\s*\}"

replacement = """final contactNode = (roomData is Map) ? (roomData['ContactReal'] ?? roomData['Contact']) : null;
          final dealData = roomData is Map ? (roomData['Deal'] ?? (contactNode is Map ? contactNode['Deal'] : null)) : null;
          
          if (dealData is Map) {
            _currentDeal = dealData['Name']?.toString() ?? dealData['Nm']?.toString() ?? _currentDeal;
            final pipelineData = dealData['Pipeline']?.toString() ?? dealData['PipelineName']?.toString() ?? '';
            if (pipelineData.isNotEmpty) _currentPipeline = pipelineData;
            final stageData = dealData['Stage']?.toString() ?? dealData['StageName']?.toString() ?? '';
            if (stageData.isNotEmpty) _currentStage = stageData;
          } else {
            final roomDeal = room['Deal']?.toString() ?? (contactNode is Map ? contactNode['Deal']?.toString() : null) ?? '';
            if (roomDeal.isNotEmpty) _currentDeal = roomDeal;
            final roomPipeline = room['Pipeline']?.toString() ?? (contactNode is Map ? contactNode['Pipeline']?.toString() : null) ?? '';
            if (roomPipeline.isNotEmpty) _currentPipeline = roomPipeline;
            final roomStage = room['Stage']?.toString() ?? (contactNode is Map ? contactNode['Stage']?.toString() : null) ?? '';
            if (roomStage.isNotEmpty) _currentStage = roomStage;
          }"""

if re.search(target, content):
    content = re.sub(target, replacement, content)
    print("Patched Deal parsing logic")
else:
    print("Could not find Deal parsing regex")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

