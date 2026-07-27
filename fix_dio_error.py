import sys
import re

filepath = r"d:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\services\chat_service.dart"

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the catch block in getKanbanData
old_catch = """      } catch (e) {
        return ApiResponse.failure(e.toString(), 500);
      }"""

new_catch = """      } on DioException catch (e) {
        final serverMsg = e.response?.data?.toString() ?? e.toString();
        debugPrint('KANBAN ERROR: $serverMsg');
        return ApiResponse.failure(serverMsg, e.response?.statusCode ?? 500);
      } catch (e) {
        return ApiResponse.failure(e.toString(), 500);
      }"""

content = content.replace(old_catch, new_catch)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
