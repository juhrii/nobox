import sys

with open('lib/presentation/screens/chat/chat_list_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('ðŸŒŸ Sticker', '✨ Sticker')
content = content.replace('ðŸŽ¬ Sticker', '✨ Sticker')
content = content.replace('ðŸŽ¤', '🎤')
content = content.replace('ðŸ“·', '📷')
content = content.replace('ðŸŽ¥', '🎥')
content = content.replace('ðŸŽ¬', '🎬')
content = content.replace('ðŸŒŸ', '🌟')

with open('lib/presentation/screens/chat/chat_list_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Done")
