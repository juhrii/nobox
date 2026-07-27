import re

path = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\presentation\screens\chat\contact_info_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# update _showDealDialog
old = '''      final pipelinesData = await chatProvider.getPipelinesResponse();
      final stagesData = await chatProvider.getStagesResponse();
      final dealsData = await chatProvider.getDealsResponse();'''
new = '''      final pipelinesData = await chatProvider.getPipelinesResponse(forceRefresh: true);
      final stagesData = await chatProvider.getStagesResponse(forceRefresh: true);
      final dealsData = await chatProvider.getDealsResponse(forceRefresh: true);'''
content = content.replace(old, new)

# update _showCampaignDialog
old2 = '''                    final resp = await chatProvider.getCampaignsResponse();'''
new2 = '''                    final resp = await chatProvider.getCampaignsResponse(forceRefresh: true);'''
content = content.replace(old2, new2)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Success ui')
