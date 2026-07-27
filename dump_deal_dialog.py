import sys

filepath = r"d:\UBIG\Proyek\NoBox_Chat\nobox\lib\presentation\screens\chat\contact_info_page.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find("  void _showDealDialog() async {")
end = content.find("  void _showFormTemplateDialog() async {")

if start != -1 and end != -1:
    print(content[start:end])
else:
    print("Not found")
