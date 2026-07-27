import sys

filepath = r"d:\UBIG\Proyek\NoBox_Chat\nobox\lib\presentation\screens\chat\contact_info_page.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find("Future<void> _loadDetailRoom() async {")
end = content.find("void _showNotesDialog()")

if start != -1 and end != -1:
    lines = content[start:end].split('\n')
    for i, line in enumerate(lines):
        if "Pipeline" in line or "Stage" in line or "Deal" in line or "_current" in line:
            print(f"{i}: {line}")
