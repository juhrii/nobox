import re

path = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\presentation\screens\chat\contact_info_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the broken list closing bracket
old_code = '''                                  return DropdownMenuItem<String>(
                                    value: id,
                            child: Text(name, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                                );
                              }).toList(),'''

new_code = '''                                  return DropdownMenuItem<String>(
                                    value: id,
                                    child: Text(name, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                                  );
                                }).toList()
                              ],'''

content = content.replace(old_code, new_code)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Success")
