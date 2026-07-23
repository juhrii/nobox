import re

path = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\core\providers\chat_provider.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace block 1: in efreshFirstPage (or similar)
old1 = '''              final isOverrideMedia = ['voice note', 'pesan suara', 'photo', 'foto', 'video', 'audio', 'sticker'].any((lbl) => override.lastMessage.toLowerCase().contains(lbl));
              final maxAge = isOverrideMedia ? 60 : 15;

              if (isIgnored || chat.lastMessage == 'Site.Inbox.DeletedMessage' || diffNow < maxAge) {'''
              
new1 = '''              final serverTimeStr = chat.time;
              final serverTime = DateTime.tryParse(serverTimeStr.endsWith('Z') ? serverTimeStr : 'Z');
              final localTimeStr = override.time;
              final localTime = DateTime.tryParse(localTimeStr.endsWith('Z') ? localTimeStr : 'Z');
              
              final serverIsNewer = (localTime != null && serverTime != null && serverTime.isAfter(localTime) && !isIgnored && chat.lastMessage != 'Site.Inbox.DeletedMessage');

              if (!serverIsNewer) {'''

# Replace block 2: in etchChats
old2 = '''                  final isOverrideMedia = ['voice note', 'pesan suara', 'photo', 'foto', 'video', 'audio', 'sticker'].any((lbl) => localChat.lastMessage.toLowerCase().contains(lbl));
                  final maxAge = isOverrideMedia ? 60 : 15;
                  
                  if (isIgnored || chat.lastMessage == 'Site.Inbox.DeletedMessage' || diffNow < maxAge) {'''
                  
new2 = '''                  final serverTimeStr = chat.time;
                  final serverTime = DateTime.tryParse(serverTimeStr.endsWith('Z') ? serverTimeStr : 'Z');
                  final localTimeStr = localChat.time;
                  final localTime = DateTime.tryParse(localTimeStr.endsWith('Z') ? localTimeStr : 'Z');
                  
                  final serverIsNewer = (localTime != null && serverTime != null && serverTime.isAfter(localTime) && !isIgnored && chat.lastMessage != 'Site.Inbox.DeletedMessage');
                  
                  if (!serverIsNewer) {'''

content = content.replace(old1, new1)
content = content.replace(old2, new2)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Success')
