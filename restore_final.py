import sys

filepath = r"d:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\services\chat_service.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

new_methods = """
  Future<ApiResponse<List<Map<String, dynamic>>>> getPipelines() async {
    try {
      final requestData = {
        "Search": "",
        "Sort": ["Id DESC"],
      };

      final response = await _apiClient.post(
        AppConfig.pipelinesListEndpoint,
        data: requestData,
      );

      final data = response.data;
      if (response.statusCode == 200 && data != null && data['ArrItem'] != null) {
        final items = List<Map<String, dynamic>>.from(data['ArrItem']);
        return ApiResponse.success(items, response.statusCode!);
      }
      return ApiResponse.failure(data?['Message'] ?? 'Failed to fetch pipelines', response.statusCode ?? 500);
    } on DioException catch (e) {
      final serverMsg = e.response?.data?.toString() ?? e.toString();
      debugPrint('PIPELINES ERROR: $serverMsg');
      return ApiResponse.failure(serverMsg, e.response?.statusCode ?? 500);
    } catch (e) {
      return ApiResponse.failure(e.toString(), 500);
    }
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> getStages() async {
    try {
      final requestData = {
        "Search": "",
        "Sort": ["Id DESC"],
      };

      final response = await _apiClient.post(
        AppConfig.stagesListEndpoint,
        data: requestData,
      );

      final data = response.data;
      if (response.statusCode == 200 && data != null && data['ArrItem'] != null) {
        final items = List<Map<String, dynamic>>.from(data['ArrItem']);
        return ApiResponse.success(items, response.statusCode!);
      }
      return ApiResponse.failure(data?['Message'] ?? 'Failed to fetch stages', response.statusCode ?? 500);
    } on DioException catch (e) {
      final serverMsg = e.response?.data?.toString() ?? e.toString();
      debugPrint('STAGES ERROR: $serverMsg');
      return ApiResponse.failure(serverMsg, e.response?.statusCode ?? 500);
    } catch (e) {
      return ApiResponse.failure(e.toString(), 500);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getKanbanData(String pipelineId, String contactId) async {
    try {
      final payload = {
        "EqualityFilter": {
            "project_id": int.tryParse(pipelineId) ?? pipelineId,
            "KontakId": int.tryParse(contactId) ?? contactId
        },
        "Sort": [
          "Urutan ASC"
        ]
      };
      
      final response = await _apiClient.post('Services/Nobox/Deals/KanbanData', data: payload);
      
      if (response.statusCode == 200) {
        return ApiResponse.success(response.data is Map ? Map<String, dynamic>.from(response.data) : {}, response.statusCode!);
      }
      return ApiResponse.failure(response.data?['Message'] ?? 'Failed to get kanban data', response.statusCode ?? 500);
    } on DioException catch (e) {
      final serverMsg = e.response?.data?.toString() ?? e.toString();
      debugPrint('KANBAN ERROR: $serverMsg');
      return ApiResponse.failure(serverMsg, e.response?.statusCode ?? 500);
    } catch (e) {
      return ApiResponse.failure(e.toString(), 500);
    }
  }
"""

target = "  Future<ApiResponse<List<Map<String, dynamic>>>> getDeals() async {"
if target in content:
    content = content.replace(target, new_methods + "\n" + target)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Methods restored successfully.")
else:
    print("Target getDeals() not found.")
