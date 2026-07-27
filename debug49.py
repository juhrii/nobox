import re

path = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\services\chat_service.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_code = '''  Future<ApiResponse<List<Map<String, dynamic>>>> getPipelines() async {
    try {
      final requestData = {
        'Take': 100,
        'Skip': 0,
        // Let's ask for all columns first to see if Stages are nested
        // 'IncludeColumns': ['Id', 'Name', 'DisplayName', 'Title', 'Nm', 'PipelineId'],
      };'''

new_code = '''  Future<ApiResponse<List<Map<String, dynamic>>>> getPipelines() async {
    try {
      final requestData = {
        'Take': 100,
        'Skip': 0,
        'IncludeColumns': ['Id', 'Name', 'Nm', 'Title'],
      };'''
content = content.replace(old_code, new_code)

old_code2 = '''  Future<ApiResponse<List<Map<String, dynamic>>>> getStages() async {
    try {
      final requestData = {
        'Take': 100,
        'Skip': 0,
        'IncludeColumns': ['Id', 'Name', 'DisplayName', 'Title', 'Nm', 'PipelineId'],
      };'''

new_code2 = '''  Future<ApiResponse<List<Map<String, dynamic>>>> getStages() async {
    try {
      final requestData = {
        'Take': 100,
        'Skip': 0,
        'IncludeColumns': ['Id', 'Name', 'Nm', 'Title', 'PipelineId', 'DealPipelineId'],
      };'''
content = content.replace(old_code2, new_code2)

old_code3 = '''  Future<ApiResponse<List<Map<String, dynamic>>>> getDeals() async {
    try {
      final requestData = {
        'Take': 100,
        'Skip': 0,
        // Remove columns restriction to see all fields
        // 'IncludeColumns': ['Id', 'Name', 'DisplayName', 'Title', 'Nm', 'StageId', 'PipelineId'],
      };'''

new_code3 = '''  Future<ApiResponse<List<Map<String, dynamic>>>> getDeals() async {
    try {
      final requestData = {
        'Take': 100,
        'Skip': 0,
        'IncludeColumns': ['Id', 'Name', 'Nm', 'Title', 'StageId', 'PipelineId', 'DealStageId', 'DealPipelineId'],
      };'''
content = content.replace(old_code3, new_code3)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Success")
