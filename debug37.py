import re

path = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\services\chat_service.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix getPipelines
old1 = '''        return ApiResponse<List<Map<String, dynamic>>>(
            data: entities.map((e) => Map<String, dynamic>.from(e)).toList());
      }
      return ApiResponse.error("Failed to fetch pipelines");
    } catch (e) {
      return ApiResponse.error(e.toString());
    }'''

new1 = '''        return ApiResponse.success(
            entities.map((e) => Map<String, dynamic>.from(e)).toList(), response.statusCode!);
      }
      return ApiResponse.failure("Failed to fetch pipelines", response.statusCode ?? 500);
    } catch (e) {
      return ApiResponse.failure(e.toString(), 500);
    }'''

content = content.replace(old1, new1)

# Fix getStages
old2 = '''        return ApiResponse<List<Map<String, dynamic>>>(
            data: entities.map((e) => Map<String, dynamic>.from(e)).toList());
      }
      return ApiResponse.error("Failed to fetch stages");
    } catch (e) {
      return ApiResponse.error(e.toString());
    }'''

new2 = '''        return ApiResponse.success(
            entities.map((e) => Map<String, dynamic>.from(e)).toList(), response.statusCode!);
      }
      return ApiResponse.failure("Failed to fetch stages", response.statusCode ?? 500);
    } catch (e) {
      return ApiResponse.failure(e.toString(), 500);
    }'''

content = content.replace(old2, new2)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Success fixing ApiResponse")
