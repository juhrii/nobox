import re

path = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\presentation\screens\chat\contact_info_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix Deal dropdown to filter by Stage correctly based on Kanban data structure
old_deal = '''                      ...filteredDeals.map((d) {
                        return DropdownMenuItem<String>(
                          value: d['Id'].toString(),
                          child: Text(d['Name']?.toString() ?? d['Nm']?.toString() ?? d['Title']?.toString() ?? 'Unnamed'),
                        );
                      }),'''

new_deal = '''                      ...filteredDeals.where((d) => d['piplinetypes']?.toString() == selectedStageId || d['StageId']?.toString() == selectedStageId).map((d) {
                        return DropdownMenuItem<String>(
                          value: d['Id'].toString(),
                          child: Text(d['Name']?.toString() ?? d['Nm']?.toString() ?? d['Title']?.toString() ?? 'Unnamed'),
                        );
                      }),'''

content = content.replace(old_deal, new_deal)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Success")
