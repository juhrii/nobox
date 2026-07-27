import re

path = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\providers\chat_provider.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# getDealsResponse
old = '''  Future<ApiResponse<List<Map<String, dynamic>>>> getDealsResponse() async {
    if (_cachedDealsResponse != null) return _cachedDealsResponse!;'''
new = '''  Future<ApiResponse<List<Map<String, dynamic>>>> getDealsResponse({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedDealsResponse != null) return _cachedDealsResponse!;'''
content = content.replace(old, new)

# getPipelinesResponse
old2 = '''  Future<ApiResponse<List<Map<String, dynamic>>>> getPipelinesResponse() async {
    if (_cachedPipelinesResponse != null) return _cachedPipelinesResponse!;'''
new2 = '''  Future<ApiResponse<List<Map<String, dynamic>>>> getPipelinesResponse({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedPipelinesResponse != null) return _cachedPipelinesResponse!;'''
content = content.replace(old2, new2)

# getStagesResponse
old3 = '''  Future<ApiResponse<List<Map<String, dynamic>>>> getStagesResponse() async {
    if (_cachedStagesResponse != null) return _cachedStagesResponse!;'''
new3 = '''  Future<ApiResponse<List<Map<String, dynamic>>>> getStagesResponse({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedStagesResponse != null) return _cachedStagesResponse!;'''
content = content.replace(old3, new3)

# getCampaignsResponse
old4 = '''  Future<ApiResponse<List<Map<String, dynamic>>>> getCampaignsResponse() async {
    if (_cachedCampaignsResponse != null) return _cachedCampaignsResponse!;'''
new4 = '''  Future<ApiResponse<List<Map<String, dynamic>>>> getCampaignsResponse({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedCampaignsResponse != null) return _cachedCampaignsResponse!;'''
content = content.replace(old4, new4)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Success provider')
