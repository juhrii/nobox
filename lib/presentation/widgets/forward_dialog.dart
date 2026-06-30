import 'package:flutter/material.dart';
import '../../../core/model/message.dart';

// =====================================================================
// FITUR: Dialog Teruskan Pesan
// FILE: lib/presentation/widgets/forward_dialog.dart
// BARIS AWAL: 5 (setelah komentar ini)
// FUNGSI: Menampilkan pop-up peringatan bahwa fitur meneruskan (forward) pesan belum diimplementasikan.
// =====================================================================
class ForwardDialog extends StatelessWidget {
  final Message message;

  const ForwardDialog({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Forward Message'),
      content: const Text('This feature will allow forwarding messages to other contacts. Pending implementation.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Send'),
        ),
      ],
    );
  }
}
