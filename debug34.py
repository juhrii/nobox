import re

path = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\presentation\screens\chat\contact_info_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# I will replace the new _showDealDialog with a version that fetches and shows Pipeline, Stage, and Deal.
new_block = '''  void _showDealDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    // UI states
    bool isLoading = true;
    String? loadError;
    List<Map<String, dynamic>> pipelines = [];
    List<Map<String, dynamic>> stages = [];
    List<Map<String, dynamic>> deals = [];
    
    String? selectedPipelineId;
    String? selectedStageId;
    String? selectedDealId;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Fetch deals once
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
                      
                      // Pre-select if we already have a deal
                      for (final d in deals) {
                        final name = d['Name']?.toString() ?? d['Nm']?.toString() ?? d['Title']?.toString() ?? '';
                        if (name == _currentDeal && name.isNotEmpty) {
                          selectedDealId = d['Id']?.toString();
                          selectedStageId = d['StageId']?.toString();
                          selectedPipelineId = d['PipelineId']?.toString();
                          break;
                        }
                      }
                    } else {
                      loadError = 'Failed to load data';
                    }
                  });
                } catch (e) {
                  setDialogState(() {
                    isLoading = false;
                    loadError = e.toString();
                  });
                }
              });
            }

            // Filtering
            final availableStages = stages.where((s) {
              if (selectedPipelineId == null) return true;
              return s['PipelineId']?.toString() == selectedPipelineId;
            }).toList();

            final availableDeals = deals.where((d) {
              if (selectedStageId != null) {
                return d['StageId']?.toString() == selectedStageId;
              } else if (selectedPipelineId != null) {
                return d['PipelineId']?.toString() == selectedPipelineId;
              }
              return true;
            }).toList();

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              actionsPadding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.handshake, color: Colors.blue.shade600, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Text('Select Deal', style: TextStyle(color: Colors.blue.shade600, fontWeight: FontWeight.w600, fontSize: 18)),
                    ],
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close, color: Colors.blue.shade600, size: 24),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isLoading)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 50),
                        child: const Center(child: CircularProgressIndicator()),
                      )
                    else if (loadError != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text('Error: ', style: const TextStyle(color: Colors.red)),
                      )
                    else ...[
                      Text('Pipeline', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            hint: Text('--select pipeline--', style: TextStyle(color: Colors.grey.shade500)),
                            icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
                            value: selectedPipelineId,
                            dropdownColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
                            items: [
                              const DropdownMenuItem<String>(value: null, child: Text('-- All Pipelines --')),
                              ...pipelines.map((Map<String, dynamic> item) {
                                final id = item['Id']?.toString();
                                final name = item['Name']?.toString() ?? item['Nm']?.toString() ?? item['Title']?.toString() ?? '';
                                return DropdownMenuItem<String>(
                                  value: id,
                                  child: Text(name, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                                );
                              }).toList()
                            ],
                            onChanged: (newValue) {
                              setDialogState(() {
                                selectedPipelineId = newValue;
                                selectedStageId = null;
                                selectedDealId = null;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Stage', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            hint: Text('--select stage--', style: TextStyle(color: Colors.grey.shade500)),
                            icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
                            value: selectedStageId,
                            dropdownColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
                            items: [
                              const DropdownMenuItem<String>(value: null, child: Text('-- All Stages --')),
                              ...availableStages.map((Map<String, dynamic> item) {
                                final id = item['Id']?.toString();
                                final name = item['Name']?.toString() ?? item['Nm']?.toString() ?? item['Title']?.toString() ?? '';
                                return DropdownMenuItem<String>(
                                  value: id,
                                  child: Text(name, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                                );
                              }).toList()
                            ],
                            onChanged: (newValue) {
                              setDialogState(() {
                                selectedStageId = newValue;
                                selectedDealId = null;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Deal', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            hint: Text('--select deal--', style: TextStyle(color: Colors.grey.shade500)),
                            icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
                            value: selectedDealId,
                            dropdownColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
                            items: [
                              const DropdownMenuItem<String>(value: null, child: Text('-- No Deal --')),
                              ...availableDeals.map((Map<String, dynamic> item) {
                                final id = item['Id']?.toString();
                                final name = item['Name']?.toString() ?? item['Nm']?.toString() ?? item['Title']?.toString() ?? '';
                                return DropdownMenuItem<String>(
                                  value: id,
                                  child: Text(name, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                                );
                              }).toList()
                            ],
                            onChanged: (newValue) {
                              setDialogState(() {
                                selectedDealId = newValue;
                              });
                            },
                          ),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel', style: TextStyle(color: Colors.blue.shade600, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (!isLoading) ? Colors.blue : Colors.grey.shade300,
                        foregroundColor: (!isLoading) ? Colors.white : Colors.grey.shade500,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: isLoading ? null : () async {
                        final success = await chatProvider.updateContactDeal(widget.chat.id, selectedPipelineId ?? '', selectedStageId ?? '', selectedDealId ?? '');
                        if (success) {
                          setState(() {
                            // find the name of the selected deal
                            if (selectedDealId == null) {
                              _currentDeal = '';
                            } else {
                              final d = deals.firstWhere((element) => element['Id']?.toString() == selectedDealId, orElse: () => {});
                              _currentDeal = d['Name']?.toString() ?? d['Nm']?.toString() ?? d['Title']?.toString() ?? '';
                            }
                          });
                          _loadDetailRoom();
                        } else {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save deal')));
                        }
                        if (mounted) Navigator.pop(context);
                      },
                      child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }'''

idx = content.find("  void _showDealDialog() {")
end_idx = content.find("  void _showFormTemplateDialog() async {", idx)

if idx == -1 or end_idx == -1:
    print("Could not find blocks")
else:
    # replace using substring
    content = content[:idx] + new_block + "\n\n" + content[end_idx:]
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Success replacing _showDealDialog with Pipeline/Stage/Deal")
