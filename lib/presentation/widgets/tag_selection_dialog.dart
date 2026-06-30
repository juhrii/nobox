import 'package:flutter/material.dart';
import '../../core/services/filter_api_service.dart';
import '../../core/services/tag_service.dart';

// =====================================================================
// FITUR: Dialog Pemilihan Label (Tag)
// FILE: lib/presentation/widgets/tag_selection_dialog.dart
// BARIS AWAL: 5 (setelah komentar ini)
// FUNGSI: Menampilkan pop-up untuk menambahkan, menghapus, dan mencari label (tag) pada suatu obrolan/kontak.
// =====================================================================
class TagSelectionDialog extends StatefulWidget {
  final String roomId;
  final List<String> initialSelectedTags;
  final Function(List<String>)? onSave;

  const TagSelectionDialog({
    super.key,
    required this.roomId,
    required this.initialSelectedTags,
    this.onSave,
  });

  @override
  State<TagSelectionDialog> createState() => _TagSelectionDialogState();
}

class _TagSelectionDialogState extends State<TagSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FilterApiService _filterApiService = FilterApiService();
  final TagService _tagService = TagService();

  List<String> _selectedTags = [];
  List<Map<String, dynamic>> _allTags = [];
  List<Map<String, dynamic>> _filteredTags = [];

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedTags = List.from(widget.initialSelectedTags);
    _fetchTags();

    _searchController.addListener(() {
      final query = _searchController.text.toLowerCase();
      setState(() {
        _filteredTags = _allTags
            .where((tag) => _getTagName(tag).toLowerCase().contains(query))
            .toList();
      });
    });
  }

  String _getTagId(Map<String, dynamic> tag) {
    return tag['Id']?.toString() ?? tag['id']?.toString() ?? '';
  }

  String _getTagName(Map<String, dynamic> tag) {
    return tag['Nm']?.toString() ?? tag['Name']?.toString() ?? tag['name']?.toString() ?? 'Unknown';
  }

  Future<void> _fetchTags() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _filterApiService.getTags();
      if (!mounted) return;

      if (!response.isError && response.data != null) {
        setState(() {
          _allTags = response.data!;
          _filteredTags = _allTags;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response.error ?? 'Failed to load tags';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('TagSelectionDialog: Error fetching tags: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An error occurred while loading tags.';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSave() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // Ensure we are passing Tag IDs to the API, even if initialSelectedTags contained names.
      final List<String> tagIdsToSave = _selectedTags.map((selectedVal) {
        final foundByName = _allTags.firstWhere(
          (tag) => _getTagName(tag) == selectedVal,
          orElse: () => <String, dynamic>{},
        );
        if (foundByName.isNotEmpty) {
          return _getTagId(foundByName);
        }
        return selectedVal;
      }).toSet().toList();

      final response = await _tagService.updateContactTags(widget.roomId, tagIdsToSave);

      if (!mounted) return;

      if (!response.isError) {
        if (widget.onSave != null) {
          widget.onSave!(tagIdsToSave);
        }
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.error ?? 'Failed to update tags')),
        );
        setState(() {
          _isSaving = false;
        });
      }
    } catch (e) {
      debugPrint('TagSelectionDialog: Error saving tags: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An error occurred while saving tags.')),
      );
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 500),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Select Tags',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search tags...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              enabled: !_isLoading && !_isSaving,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _buildContent(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: (_isLoading || _isSaving) ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _fetchTags,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredTags.isEmpty) {
      return const Center(child: Text('No tags found.'));
    }

    return ListView.builder(
      itemCount: _filteredTags.length,
      itemBuilder: (context, index) {
        final tag = _filteredTags[index];
        final tagId = _getTagId(tag);
        final tagName = _getTagName(tag);

        final isSelected = _selectedTags.contains(tagId) || _selectedTags.contains(tagName);

        return CheckboxListTile(
          title: Text(tagName),
          value: isSelected,
          activeColor: Colors.blue,
          onChanged: _isSaving
              ? null
              : (bool? value) {
                  setState(() {
                    if (value == true) {
                      _selectedTags.add(tagId);
                    } else {
                      _selectedTags.remove(tagId);
                      _selectedTags.remove(tagName);
                    }
                  });
                },
        );
      },
    );
  }
}
