import 'package:flutter/material.dart';

class AddFunnelDialog extends StatefulWidget {
  final String? initialFunnel;
  final Function(String) onSave;

  const AddFunnelDialog({
    super.key,
    this.initialFunnel,
    required this.onSave,
  });

  @override
  State<AddFunnelDialog> createState() => _AddFunnelDialogState();
}

class _AddFunnelDialogState extends State<AddFunnelDialog> {
  String? _selectedFunnel;
  final List<String> _funnelOptionsMock = [
    'New Lead',
    'Follow Up 1',
    'Follow Up 2',
    'Negotiation',
    'Closed Won',
    'Closed Lost'
  ];

  @override
  void initState() {
    super.initState();
    _selectedFunnel = widget.initialFunnel;
    if (_selectedFunnel != null && !_funnelOptionsMock.contains(_selectedFunnel)) {
      _selectedFunnel = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Set Funnel Stage',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              value: _selectedFunnel,
              decoration: InputDecoration(
                labelText: 'Funnel Stage',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: _funnelOptionsMock.map((funnel) {
                return DropdownMenuItem(
                  value: funnel,
                  child: Text(funnel),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedFunnel = value;
                });
              },
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _selectedFunnel == null
                      ? null
                      : () {
                          widget.onSave(_selectedFunnel!);
                          Navigator.pop(context);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
