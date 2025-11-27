import 'package:flutter/material.dart';

class DialogBox extends StatelessWidget {
  final String title;
  final String message;
  final List<String> actions;

  const DialogBox({
    required this.title,
    required this.message,
    required this.actions,
  });

  Future<String?> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => this,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: actions
          .map((action) => TextButton(
                onPressed: () => Navigator.of(context).pop(action),
                child: Text(action),
              ))
          .toList(),
    );
  }
}
