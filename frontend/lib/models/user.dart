import 'dart:convert';

import '/models/security.dart';
import '/core/services/api_client.dart';

class User implements Comparable<User> {
  final int id;
  final String email;
  final String fullName;
  final String? iban;
  final String role;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    this.iban,
    required this.role,
  });

  bool get isAdmin => role == 'admin';

  /* -----------------------------------------------------------------------
   * Conversion JSON vers Objet User
   * --------------------------------------------------------------------- */

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      iban: json['iban'] as String?, // nullable
      role: json['role'] as String,
    );
  }


  /* -----------------------------------------------------------------------
   * Appels endpoint : get current user
   * --------------------------------------------------------------------- */

  static Future<User> getCurrentUser() async {
    final response = await ApiClient.get('get_user_data');
    if (response.statusCode == 200) {                                           // 200 : la requête a reussi et le serveur a renvoye une reponse
      return User.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to get current user');
    }
  }

  static Future<List<User>> getAllUsers() async {
    final response = await ApiClient.get('get_all_users');
    if (response.statusCode == 200) {
      final List<dynamic> body = json.decode(response.body);
      return body.map((dynamic item) => User.fromJson(item)).toList();
    } else {
      throw Exception('Failed to get users');
    }
  }


  /* -------------------------------------------------------------
   * egalite / tri – par `createdAt` puis id
   * ----------------------------------------------------------- */

  @override // hashCode
  int get hashCode => id.hashCode;

  @override // equals
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is User && runtimeType == other.runtimeType && id == other.id;

  @override // compareTo
  int compareTo(User other) => fullName.compareTo(other.fullName);


}





class UserValidator {
  // email doit être present et avoir un format valide
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'required';
    }

    final ibanRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!ibanRegex.hasMatch(email.trim().toLowerCase())) {
      return 'not a valid email';
    } else {
      return null;
    }
  }

  // email doit être disponible
  static Future<String?> validateEmailUnicity(String? email) async {
    var res = await Security.checkEmailAvailable(
      email: email?.trim(),
    );
    return res ? null : 'not available';
  }

  // full name doit être present et avoir minimum 3 characters
  static String? validateFullName(String? fullName) {
    if (fullName == null || fullName.isEmpty) {
      return 'required';
    } else if (fullName.trim().length < 3) {
      return 'minimum 3 characters';
    } else {
      return null;
    }
  }

  // full name doit être disponible
  static Future<String?> validateFullNameUnicity(String? fullName) async {
    var res = await Security.checkFullNameAvailable(
      fullName: fullName?.trim(),
    );
    return res ? null : 'not available';
  }

  // verifier la validite de l'iban
  static String? validateIban(String? iban) {
    if (iban == null || iban.isEmpty) {
      return null;
    }

    final ibanRegex = RegExp(r'^[A-Z]{2}[0-9]{2} [0-9]{4} [0-9]{4} [0-9]{4}$');
    if (!ibanRegex.hasMatch(iban.trim())) {
      return 'not a valid IBAN';
    } else {
      return null;
    }
  }

  // password doit être present et avoir un format valide
  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'required';
    }

    final lowerCaseRegex = RegExp(r'[a-z]');
    if (!lowerCaseRegex.hasMatch(password)) {
      return 'at least one lower case';
    }

    final numberRegex = RegExp(r'\d');
    if (!numberRegex.hasMatch(password)) {
      return 'at least one number';
    }

    final specialCharRegex = RegExp(r'\W');
    if (!specialCharRegex.hasMatch(password)) {
      return 'at least one special character (@\$!%*?&,)';
    }

    if (password.length < 8) {
      return 'at least 8 characters';
    }

    return null;
  }

  // confirm password doit être present et identique au password
  static String? validateConfirmPassword(String? value, String? password) {
    String? passwordError = validatePassword(value);
    if (passwordError != null) return passwordError;
    if (value != password) return 'passwords do not match';
    return null;
  }

}







