import sys

filepath = r"d:\UBIG\Proyek\NoBox_Chat\nobox\lib\presentation\screens\chat\contact_info_page.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    'final kanbanResp = await chatProvider.getKanbanData(newValue, widget.chat.id);',
    'final kanbanResp = await chatProvider.getKanbanData(newValue, widget.chat.contactId);'
)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
