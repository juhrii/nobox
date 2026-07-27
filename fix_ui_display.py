import sys

filepath = r"d:\UBIG\Proyek\NoBox_Chat\nobox\lib\presentation\screens\chat\contact_info_page.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

target = """                  if (_currentDeal.isNotEmpty)
                    InkWell(
                      onTap: _showDealDialog,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pipeline: $_currentPipeline',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Stage: $_currentStage',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                            ),
                            const SizedBox(height: 4),
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

replacement = """                  if (_currentPipeline.isNotEmpty || _currentStage.isNotEmpty || _currentDeal.isNotEmpty)
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

if target in content:
    content = content.replace(target, replacement)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("UI Display condition updated!")
else:
    print("Target not found in UI code!")
