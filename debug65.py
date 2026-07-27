import re

path = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\presentation\screens\chat\chat_detail_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_config = '''            bottomActionBarConfig: const BottomActionBarConfig(
              showBackspaceButton: true,
              showSearchViewButton: true,
              backgroundColor: Colors.blue,
              buttonColor: Colors.white,
              buttonIconColor: Colors.white,
            ),'''

new_config = '''            bottomActionBarConfig: const BottomActionBarConfig(
              showBackspaceButton: true,
              showSearchViewButton: true,
              backgroundColor: Colors.blue,
              buttonColor: Colors.transparent, // Background tombol transparan
              buttonIconColor: Colors.white, // Ikon warna putih supaya kelihatan di atas background biru
            ),'''

content = content.replace(old_config, new_config)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Success")
