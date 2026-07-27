import sys

filepath = r"d:\UBIG\Proyek\NoBox_Chat\nobox\lib\presentation\screens\chat\contact_info_page.dart"

with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_dialog_code = """  void _showDealDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    bool isLoading = true;
    String? loadError;
    
    List<Map<String, dynamic>> pipelines = [];
    List<Map<String, dynamic>> stages = [];
    List<Map<String, dynamic>> deals = [];

    String? selectedPipelineId;
    String? selectedStageId;
    String? selectedDealId;

    // We will show dialog first, then load pipelines.
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            
            // Initial load of pipelines
            if (isLoading && pipelines.isEmpty && loadError == null) {
              Future.microtask(() async {
                try {
                  final pipeResp = await chatProvider.getPipelinesResponse();
                  setDialogState(() {
                    isLoading = false;
                    if (!pipeResp.isError && pipeResp.data != null) {
                      pipelines = pipeResp.data!;
                    } else {
                      loadError = 'Failed to load pipelines: ${pipeResp.error}';
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

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF0B141A) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
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
                    if (isLoading && pipelines.isEmpty)
                      const Center(child: CircularProgressIndicator())
                    else if (loadError != null)
                      Text(loadError!, style: const TextStyle(color: Colors.red))
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
                              const DropdownMenuItem<String>(value: null, child: Text('-- None --')),
                              ...pipelines.map((Map<String, dynamic> p) {
                                final id = p['Id']?.toString();
                                final name = p['Nm']?.toString() ?? p['Name']?.toString() ?? p['Title']?.toString() ?? '';
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
                                stages = [];
                                deals = [];
                                
                                if (newValue != null) {
                                  isLoading = true;
                                  Future.microtask(() async {
                                    try {
                                      final kanbanResp = await chatProvider.getKanbanData(newValue);
                                      setDialogState(() {
                                        isLoading = false;
                                        if (!kanbanResp.isError && kanbanResp.data != null) {
                                          final data = kanbanResp.data!;
                                          final List<dynamic> headers = data['ArrHeader'] ?? [];
                                          final List<dynamic> items = data['ArrItem'] ?? [];
                                          
                                          stages = headers.map((e) => Map<String, dynamic>.from(e)).toList();
                                          deals = items.map((e) => Map<String, dynamic>.from(e)).toList();
                                        } else {
                                          loadError = 'Kanban Err: ${kanbanResp.error}';
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
                              ...stages.map((Map<String, dynamic> item) {
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
                              ...deals.where((d) => selectedStageId == null || d['piplinetypes']?.toString() == selectedStageId).map((Map<String, dynamic> item) {
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
                            // Find the names
                            if (selectedPipelineId != null) {
                              final p = pipelines.firstWhere((e) => e['Id']?.toString() == selectedPipelineId, orElse: () => {});
                              _currentPipeline = p['Nm']?.toString() ?? p['Name']?.toString() ?? p['Title']?.toString() ?? selectedPipelineId!;
                            }
                            if (selectedStageId != null) {
                              final s = stages.firstWhere((e) => e['Id']?.toString() == selectedStageId, orElse: () => {});
                              _currentStage = s['Name']?.toString() ?? s['Nm']?.toString() ?? s['Title']?.toString() ?? selectedStageId!;
                            } else {
                              _currentStage = '';
                            }
                            if (selectedDealId != null) {
                              final d = deals.firstWhere((e) => e['Id']?.toString() == selectedDealId, orElse: () => {});
                              _currentDeal = d['Name']?.toString() ?? d['Nm']?.toString() ?? d['Title']?.toString() ?? selectedDealId!;
                            } else {
                              _currentDeal = '';
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
  }
"""

new_lines = []
in_deal_dialog = False

for i, line in enumerate(lines):
    if line.startswith('  void _showDealDialog() {') or line.startswith('  void _showDealDialog() async {'):
        in_deal_dialog = True
        new_lines.append(new_dialog_code)
        continue
        
    if in_deal_dialog:
        if line.startswith('  void _showFormTemplateDialog()') or line.startswith('  void _showFormTemplateDialog() async {'):
            in_deal_dialog = False
            new_lines.append(line)
        continue
        
    if not in_deal_dialog:
        new_lines.append(line)

with open(filepath, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
