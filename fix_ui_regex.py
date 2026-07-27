import sys

filepath = r"d:\UBIG\Proyek\NoBox_Chat\nobox\lib\presentation\screens\chat\contact_info_page.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

import re

target_regex = r"if \(_currentDeal\.isNotEmpty\)\s*InkWell\(\s*onTap: _showDealDialog,\s*child: Padding\(\s*padding: const EdgeInsets\.fromLTRB\(16, 0, 16, 12\),\s*child: Column\([\s\S]*?else\s*InkWell\(\s*onTap: _showDealDialog,\s*child: _buildPlaceholderValue\(isDark: isDark, text: 'Not Set'\),\s*\),"

replacement = """if (_currentPipeline.isNotEmpty || _currentStage.isNotEmpty || _currentDeal.isNotEmpty)
                    InkWell(
                      onTap: _showDealDialog,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_currentPipeline.isNotEmpty)
                              Text(
                                'Pipeline: $_currentPipeline',
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                              ),
                            if (_currentPipeline.isNotEmpty)
                              const SizedBox(height: 2),
                            if (_currentStage.isNotEmpty)
                              Text(
                                'Stage: $_currentStage',
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                              ),
                            if (_currentStage.isNotEmpty)
                              const SizedBox(height: 4),
                            if (_currentDeal.isNotEmpty)
                              Text(
                                _currentDeal,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                  else
                    InkWell(
                      onTap: _showDealDialog,
                      child: _buildPlaceholderValue(isDark: isDark, text: 'Not Set'),
                    ),"""

if re.search(target_regex, content):
    content = re.sub(target_regex, replacement, content)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Successfully replaced UI logic using regex!")
else:
    print("Target regex not found!")
