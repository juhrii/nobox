import re

path = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\presentation\screens\chat\contact_info_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_initial_load = '''              // Fetch deals once
              if (isLoading && pipelines.isEmpty && loadError == null) {
                Future.microtask(() async {
                  try {
                    final pipeResp = await chatProvider.getPipelinesResponse(forceRefresh: true);
                    final stageResp = await chatProvider.getStagesResponse(forceRefresh: true);
                    final dealResp = await chatProvider.getDealsResponse(forceRefresh: true);
                    
                    setDialogState(() {
                      isLoading = false;
                      if (!pipeResp.isError && !stageResp.isError && !dealResp.isError) {
                        pipelines = pipeResp.data ?? [];
                        stages = stageResp.data ?? [];
                        deals = dealResp.data ?? [];
                        
                        // Everything is fine, let it show the dropdowns
                        loadError = null;
                      } else {
                        loadError = 'Stage Err: ${stageResp.error}\\n\\nPipe keys: ${pipeResp.data?.isNotEmpty == true ? pipeResp.data!.first.keys.join(", ") : "empty"}\\n\\nDeal keys: ${dealResp.data?.isNotEmpty == true ? dealResp.data!.first.keys.join(", ") : "empty"}';
                      }
                    });
                  } catch (e) {
                    setDialogState(() {
                      isLoading = false;
                      loadError = e.toString();
                    });
                  }
                });
              }'''

new_initial_load = '''              // Fetch deals once
              if (isLoading && pipelines.isEmpty && loadError == null) {
                Future.microtask(() async {
                  try {
                    final pipeResp = await chatProvider.getPipelinesResponse(forceRefresh: true);
                    
                    setDialogState(() {
                      isLoading = false;
                      if (!pipeResp.isError) {
                        pipelines = pipeResp.data ?? [];
                        // We do NOT fetch stages and deals here anymore. We wait until a Pipeline is selected!
                        stages = [];
                        deals = [];
                        
                        // Everything is fine, let it show the dropdowns
                        loadError = null;
                      } else {
                        loadError = 'Pipe Err: ${pipeResp.error}';
                      }
                    });
                  } catch (e) {
                    setDialogState(() {
                      isLoading = false;
                      loadError = e.toString();
                    });
                  }
                });
              }'''

content = content.replace(old_initial_load, new_initial_load)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Success")
