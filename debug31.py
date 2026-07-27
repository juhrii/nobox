import re

path = r'd:\UBIG\Proyek\NoBox_Chat\nobox\lib\presentation\screens\chat\contact_info_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_block = '''  void _showDealDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String localPipeline = _currentPipeline;
    String localStage = _currentStage;
    String localDeal = _currentDeal;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isSaveEnabled = localPipeline.isNotEmpty && localStage.isNotEmpty && localDeal.isNotEmpty;
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
                          hint: Text('--select--', style: TextStyle(color: Colors.grey.shade500)),
                          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
                          value: localPipeline.isEmpty ? null : localPipeline,
                          dropdownColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
                          items: ['Sales', 'Marketing'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setDialogState(() {
                              localPipeline = newValue!;
                              localStage = '';
                              localDeal = '';
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
                          hint: Text('--select pipeline first--', style: TextStyle(color: Colors.grey.shade500)),
                          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
                          value: localStage.isEmpty ? null : localStage,
                          dropdownColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
                          items: localPipeline.isEmpty ? [] : ['Stage 1', 'Stage 2'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setDialogState(() {
                              localStage = newValue!;
                              localDeal = '';
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
                          hint: Text('--select pipeline & stage first--', style: TextStyle(color: Colors.grey.shade500)),
                          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
                          value: localDeal.isEmpty ? null : localDeal,
                          dropdownColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
                          items: localStage.isEmpty ? [] : ['Deal A', 'Deal B'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setDialogState(() => localDeal = newValue!);
                          },
                        ),
                      ),
                    ),
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
                        backgroundColor: isSaveEnabled ? Colors.blue : Colors.grey.shade300,
                        foregroundColor: isSaveEnabled ? Colors.white : Colors.grey.shade500,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: isSaveEnabled ? () async {
                        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
                        final success = await chatProvider.updateContactDeal(widget.chat.id, localPipeline, localStage, localDeal);
                        if (success) {
                          setState(() {
                            _currentPipeline = localPipeline;
                            _currentStage = localStage;
                            _currentDeal = localDeal;
                          });
                        } else {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save deal')));
                        }
                        if (mounted) Navigator.pop(context);
                      } : null,
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

new_block = '''  void _showDealDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    // UI states
    bool isLoading = true;
    String? loadError;
    List<Map<String, dynamic>> deals = [];
    String? selectedDealId;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Fetch deals once
            if (isLoading && deals.isEmpty && loadError == null) {
              Future.microtask(() async {
                try {
                  final resp = await chatProvider.getDealsResponse(forceRefresh: true);
                  setDialogState(() {
                    isLoading = false;
                    if (!resp.isError && resp.data != null) {
                      deals = resp.data!;
                      // find matching ID if we already have a name
                      for (final d in deals) {
                        final name = d['Name']?.toString() ?? d['Nm']?.toString() ?? d['Title']?.toString() ?? '';
                        if (name == _currentDeal && name.isNotEmpty) {
                          selectedDealId = d['Id']?.toString();
                          break;
                        }
                      }
                    } else {
                      loadError = resp.error ?? 'Unknown error';
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
                    Text('Deal', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 8),
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
                    else
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
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('-- No Deal --'),
                              ),
                              ...deals.map((Map<String, dynamic> item) {
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
                        final success = await chatProvider.updateContactDeal(widget.chat.id, '', '', selectedDealId ?? '');
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
if idx == -1:
    print("Could not find _showDealDialog")
else:
    # replace using string replace
    content = content.replace(old_block, new_block)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Success replacing _showDealDialog")
