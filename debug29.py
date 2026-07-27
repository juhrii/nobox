import re

path = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\services\chat_service.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace Take: 100 with Take: 0 and add Sort: ["Name ASC"] for metadata endpoints
old = '''  Future<ApiResponse<List<Map<String, dynamic>>>> getPipelines() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'DisplayName', 'Title', 'Nm'],
        'ColumnSelection': 1,
        'Take': 100,
        'Skip': 0,
      };'''

new = '''  Future<ApiResponse<List<Map<String, dynamic>>>> getPipelines() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'DisplayName', 'Title', 'Nm'],
        'ColumnSelection': 1,
        'Take': 0,
        'Skip': 0,
        'Sort': ['Name ASC'],
      };'''
content = content.replace(old, new)

old2 = '''  Future<ApiResponse<List<Map<String, dynamic>>>> getStages() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'DisplayName', 'Title', 'Nm'],
        'ColumnSelection': 1,
        'Take': 100,
        'Skip': 0,
      };'''

new2 = '''  Future<ApiResponse<List<Map<String, dynamic>>>> getStages() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'DisplayName', 'Title', 'Nm'],
        'ColumnSelection': 1,
        'Take': 0,
        'Skip': 0,
        'Sort': ['Name ASC'],
      };'''
content = content.replace(old2, new2)

old3 = '''  Future<ApiResponse<List<Map<String, dynamic>>>> getDeals() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'DisplayName', 'Title', 'Nm'],
        'ColumnSelection': 1,
        'Take': 100,
        'Skip': 0,
      };'''

new3 = '''  Future<ApiResponse<List<Map<String, dynamic>>>> getDeals() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'DisplayName', 'Title', 'Nm'],
        'ColumnSelection': 1,
        'Take': 0,
        'Skip': 0,
        'Sort': ['Name ASC', 'Id DESC'],
      };'''
content = content.replace(old3, new3)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Success')
