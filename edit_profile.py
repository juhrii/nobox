import re

with open('lib/presentation/screens/profile/profile_page.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
skip_mode = False
skip_build_info_card = False

for i, line in enumerate(lines):
    # Skip unused imports
    if 'package:provider/provider.dart' in line:
        continue
    if 'core/providers/auth_provider.dart' in line:
        continue
    if 'core/providers/chat_provider.dart' in line:
        continue
        
    # Inside build method, skip providers and header
    if 'final authProvider = context.watch<AuthProvider>();' in line:
        skip_mode = True
        continue
        
    if skip_mode:
        if '// About NoBox AI Section' in line:
            skip_mode = False
            # add a top padding instead
            new_lines.append('            const SizedBox(height: 24),\n')
            new_lines.append(line)
        continue
        
    # skip _buildInfoCard method
    if 'Widget _buildInfoCard(' in line:
        skip_build_info_card = True
        continue
        
    if skip_build_info_card:
        if line.strip() == '}' and i > 250 and lines[i+1].strip() == '@override':
            skip_build_info_card = False
            continue
        elif line.strip() == '}' and i > 250 and '@override' in ''.join(lines[i:i+3]):
            skip_build_info_card = False
            continue
        continue

    new_lines.append(line)

with open('lib/presentation/screens/profile/profile_page.dart', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
