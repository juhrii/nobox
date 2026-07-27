import sys

filepath = r"d:\UBIG\Proyek\NoBox_Chat\nobox\lib\presentation\screens\chat\contact_info_page.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('void _showDealDialog()')
end = content.find('void _blockContact()', start)
text = content[start:end]

with open('dialog.txt', 'w', encoding='utf-8') as f:
    f.write(text)
