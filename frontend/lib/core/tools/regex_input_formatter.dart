import 'package:flutter/services.dart';

class RegexInputFormatter extends TextInputFormatter {
  final RegExp regex;

  RegexInputFormatter(this.regex);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    // Si le nouveau texte correspond à la regex, on l'accepte
    if (regex.hasMatch(newValue.text)) {
      return newValue;
    }
    // Sinon, on garde l'ancien texte
    return oldValue;
  }
}
