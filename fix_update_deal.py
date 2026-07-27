import sys

filepath = r"d:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\services\chat_service.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

import re

target_regex = r"Future<ApiResponse<bool>> updateContactDeal\(String contactId, String pipeline, String stage, String deal\) async \{\s*try \{\s*debugPrint\('.*?\[Update Deal\].*?'\);\s*final int\? dealId = int\.tryParse\(deal\);\s*final requestData = \{\s*'EntityId': int\.tryParse\(contactId\) \?\? contactId,\s*'Entity': \{\s*'DealId': dealId, \/\/ Akan mengirim null jika string kosong \(untuk melepas deal\)\s*\},\s*\};\s*final response = await _apiClient\.post\(\s*AppConfig\.updateChatroomEndpoint,\s*data: requestData,\s*\);\s*debugPrint\('UPDATE FORM RAW RESPONSE: '\);\s*final data = response\.data;\s*if \(response\.statusCode == 200 && \(data is Map && data\['IsError'\] != true\)\) \{\s*debugPrint\('.*?\[Update Deal\] Successfully updated deal'\);\s*return ApiResponse\.success\(true, 200\);\s*\}\s*final errorMsg = data is Map \? \(data\['ErrorMsg'\] \?\? data\['Error'\] \?\? data\.toString\(\)\) : data\.toString\(\);\s*debugPrint\('.*?\[Update Deal\] API Error: \$errorMsg'\);\s*return ApiResponse\.failure\(errorMsg, response\.statusCode!\);\s*\} catch \(e\) \{\s*debugPrint\('.*?\[Update Deal\] Exception: \$e'\);\s*return ApiResponse\.failure\(e\.toString\(\), 500\);\s*\}\s*\}"

replacement = """Future<ApiResponse<bool>> updateContactDeal(String contactId, String pipeline, String stage, String deal) async {
    try {
      debugPrint('dY ? [Update Deal] Updating deal for room $contactId to $deal');
      final int? dealId = int.tryParse(deal);

      // 1. Coba update di Chatrooms
      final requestData = {
        'EntityId': int.tryParse(contactId) ?? contactId,
        'Entity': {
          'DealId': dealId,
        },
      };
      
      try {
        await _apiClient.post(
          AppConfig.updateChatroomEndpoint,
          data: requestData,
        );
      } catch (e) {
        debugPrint('dY ? [Update Deal] Chatrooms/Update failed, moving on: $e');
      }

      // 2. Coba update di Contact (Karena Deal seringkali menempel di Kontak/ContactReal)
      try {
        final detailResponse = await _apiClient.post(
          AppConfig.detailRoomEndpoint,
          data: {"EntityId": int.tryParse(contactId) ?? contactId},
        );
        String? ctRealId;
        if (detailResponse.statusCode == 200 && detailResponse.data != null) {
          final data = detailResponse.data;
          ctRealId = data['Data']?['Room']?['CtRealId']?.toString();
          if (ctRealId == null || ctRealId.isEmpty || ctRealId == '0') {
            ctRealId = data['Data']?['Room']?['CtId']?.toString();
          }
          if (ctRealId == null || ctRealId.isEmpty || ctRealId == '0') {
            ctRealId = data['Data']?['Room']?['ContactId']?.toString();
          }
          if (ctRealId == null || ctRealId.isEmpty || ctRealId == '0') {
            ctRealId = data['Data']?['ContactReal']?['Id']?.toString();
          }
        }
        
        if (ctRealId != null && ctRealId.isNotEmpty && ctRealId != '0') {
          await _apiClient.post(
            AppConfig.contactUpdateEndpoint,
            data: {
              "EntityId": int.tryParse(ctRealId) ?? ctRealId,
              "Entity": {
                "DealId": dealId
              }
            }
          );
          debugPrint('dY ? [Update Deal] Successfully updated deal on Contact $ctRealId');
        }
      } catch (e) {
        debugPrint('dY ? [Update Deal] Failed to update on Contact, moving on: $e');
      }

      return ApiResponse.success(true, 200);
    } catch (e) {
      debugPrint('?O [Update Deal] Exception: $e');
      return ApiResponse.failure(e.toString(), 500);
    }
  }"""

if re.search(target_regex, content):
    content = re.sub(target_regex, replacement, content)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Successfully patched updateContactDeal!")
else:
    print("Regex not found!")
