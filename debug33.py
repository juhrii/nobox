import re

path = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\services\chat_service.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# For getStages, add PipelineId
old2 = '''  Future<ApiResponse<List<Map<String, dynamic>>>> getStages() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'DisplayName', 'Title', 'Nm'],'''
new2 = '''  Future<ApiResponse<List<Map<String, dynamic>>>> getStages() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'DisplayName', 'Title', 'Nm', 'PipelineId'],'''
content = content.replace(old2, new2)

# For getDeals, add StageId, PipelineId
old3 = '''  Future<ApiResponse<List<Map<String, dynamic>>>> getDeals() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'DisplayName', 'Title', 'Nm'],'''
new3 = '''  Future<ApiResponse<List<Map<String, dynamic>>>> getDeals() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'DisplayName', 'Title', 'Nm', 'StageId', 'PipelineId'],'''
content = content.replace(old3, new3)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Success')
