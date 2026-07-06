import 'package:flutter/material.dart';
import '../../core/services/filter_api_service.dart';
import '../../core/services/chat_service.dart';

// =====================================================================
// FITUR: Dialog Ubah Status Funnel
// FILE: lib/presentation/widgets/add_funnel_dialog.dart
// BARIS AWAL: 5 (setelah komentar ini)
// FUNGSI: Menampilkan pop-up untuk memilih dan mengubah status pipeline/funnel pelanggan.
// =====================================================================
class AddFunnelDialog extends StatefulWidget {
  final String roomId;
  final String? initialFunnel;
  final Function(String funnelName, String funnelId) onSave;

  const AddFunnelDialog({
    super.key,
    required this.roomId,
    this.initialFunnel,
    required this.onSave,
  });

  @override
  State<AddFunnelDialog> createState() => _AddFunnelDialogState();
}

class _AddFunnelDialogState extends State<AddFunnelDialog> {
  final FilterApiService _filterApiService = FilterApiService();
  final ChatService _chatService = ChatService();

  List<Map<String, String>> _funnelOptions = [];
  String? _selectedFunnelId;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchFunnels();
  }

  Future<void> _fetchFunnels() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _filterApiService.getFunnels();
      if (!mounted) return;

      if (!response.isError && response.data != null) {
        final List<Map<String, String>> parsed = [];
        for (final item in response.data!) {
          final String name = item['Name']?.toString() ??
              item['Nm']?.toString() ??
              '';
          final String id = item['Id']?.toString() ?? '';
          if (name.isNotEmpty && id.isNotEmpty) {
            parsed.add({'name': name, 'id': id});
          }
        }

        // Match initialFunnel to pre-select the correct dropdown value
        String? matchedId;
        if (widget.initialFunnel != null && widget.initialFunnel!.isNotEmpty) {
          for (final option in parsed) {
            if (option['name'] == widget.initialFunnel ||
                option['id'] == widget.initialFunnel) {
              matchedId = option['id'];
              break;
            }
          }
        }

        setState(() {
          _funnelOptions = parsed;
          _selectedFunnelId = matchedId;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response.error ?? 'Failed to load funnel stages';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('AddFunnelDialog: Error fetching funnels: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An error occurred while loading funnel stages.';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSave() async {
    if (_selectedFunnelId == null || _isSaving) return;

    final selectedOption = _funnelOptions.firstWhere(
      (f) => f['id'] == _selectedFunnelId,
      orElse: () => <String, String>{},
    );

    if (selectedOption.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final response = await _chatService.updateContactFunnel(
        widget.roomId,
        _selectedFunnelId!,
      );
      if (!mounted) return;

      if (!response.isError && response.data == true) {
        if (!context.mounted) return;
        Navigator.pop(context);
        widget.onSave(selectedOption['name']!, selectedOption['id']!);
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.error ?? 'Failed to update funnel stage'),
            backgroundColor: Colors.red.shade700,
          ),
        );
        setState(() => _isSaving = false);
      }
    } catch (e) {
      debugPrint('AddFunnelDialog: Error saving funnel: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Network error. Please try again.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Set Funnel Stage',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.blue),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildContent(isDark),
            const SizedBox(height: 24),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_isLoading) {
      return const SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _fetchFunnels,
            child: const Text('Retry'),
          ),
        ],
      );
    }

    if (_funnelOptions.isEmpty) {
      return const SizedBox(
        height: 56,
        child: Center(
          child: Text(
            'No funnel stages available.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedFunnelId,
      dropdownColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15),
      decoration: InputDecoration(
        labelText: 'Funnel Stage',
        labelStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: _funnelOptions.map((funnel) {
        return DropdownMenuItem(
          value: funnel['id'],
          child: Text(funnel['name']!),
        );
      }).toList(),
      onChanged: _isSaving
          ? null
          : (value) {
              setState(() {
                _selectedFunnelId = value;
              });
            },
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.blue),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Cancel', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: (_selectedFunnelId == null || _isLoading || _isSaving)
                ? null
                : _handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}
