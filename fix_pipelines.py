import sys

filepath = r"d:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\services\chat_service.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

import re

# Patch getPipelines
target_pipe = r"Future<ApiResponse<List<Map<String, dynamic>>>> getPipelines\(\) async \{\s*try \{\s*final requestData = \{\s*'IncludeColumns': \['Id', 'Name', 'Nm', 'Title'\],\s*'ColumnSelection': 1,\s*'Take': 100,\s*'Skip': 0,\s*\};\s*final response = await _apiClient\.post\(AppConfig\.pipelinesListEndpoint, data: requestData\);"
replacement_pipe = """Future<ApiResponse<List<Map<String, dynamic>>>> getPipelines() async {
    try {
      final requestData = {
        "EqualityFilter": {},
        "Sort": ["Title ASC", "Name ASC"]
      };
      final response = await _apiClient.post(AppConfig.pipelinesListEndpoint, data: requestData);"""

if re.search(target_pipe, content):
    content = re.sub(target_pipe, replacement_pipe, content)
    print("Patched getPipelines")
else:
    print("Could not find getPipelines regex")

# Patch getStages
target_stage = r"Future<ApiResponse<List<Map<String, dynamic>>>> getStages\(\) async \{\s*try \{\s*final requestData = \{\s*'IncludeColumns': \['Id', 'Name', 'Nm', 'Title'\],\s*'ColumnSelection': 1,\s*'Take': 100,\s*'Skip': 0,\s*\};\s*final response = await _apiClient\.post\(AppConfig\.stagesListEndpoint, data: requestData\);"
replacement_stage = """Future<ApiResponse<List<Map<String, dynamic>>>> getStages() async {
    try {
      final requestData = {
        "EqualityFilter": {},
        "Sort": ["Title ASC", "Name ASC"]
      };
      final response = await _apiClient.post(AppConfig.stagesListEndpoint, data: requestData);"""

if re.search(target_stage, content):
    content = re.sub(target_stage, replacement_stage, content)
    print("Patched getStages")
else:
    print("Could not find getStages regex")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

