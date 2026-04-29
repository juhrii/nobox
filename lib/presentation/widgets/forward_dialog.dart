import 'package:flutter/material.dart';
import '../../../core/model/message.dart';

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
