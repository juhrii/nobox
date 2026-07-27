import sys

filepath = r"d:\UBIG\Proyek\NoBox_Chat\nobox\lib\presentation\screens\chat\contact_info_page.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

target = """          // Deal: dari Data -> Deal atau Room
          final dealData = roomData is Map ? roomData['Deal'] : null;
          if (dealData is Map) {
            _currentDeal = dealData['Name']?.toString() ?? dealData['Nm']?.toString() ?? _currentDeal;
          } else {
            final roomDeal = room['Deal']?.toString() ?? '';
            if (roomDeal.isNotEmpty) _currentDeal = roomDeal;
          }"""

replacement = """          // Deal: dari Data -> Deal atau Room
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

if target in content:
    content = content.replace(target, replacement)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Successfully patched _loadDetailRoom for Pipeline and Stage!")
else:
    print("Target not found!")
