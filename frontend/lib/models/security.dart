import 'dart:convert';

import '/core/services/api_client.dart';

class Security {

  /* -----------------------------------------------------------------------
   * Appel endpoint : login
   * --------------------------------------------------------------------- */

  static Future<String?> login(String email, String password) async {          // ici les paramètres sont positionnels et obligatoires
    final response = await ApiClient.post(
      'login',
      body: json.encode({'email': email, 'password': password}),
      anonymous: true,
    );
    if (response.statusCode != 200) {                                           // 200 signifie que la requête a reussi et que le serveur a renvoye une reponse // en effet, nous attendons un jeton JWT
      throw Exception('Failed to login');
    }
    final dynamic body = json.decode(response.body);
    String token = body['token'];
    return token;
  }

  /* -----------------------------------------------------------------------
   * Appel endpoint : signup
   * --------------------------------------------------------------------- */

  static Future<void> signup({                                                  // ici les paramètres sont nommees // lorsque les paramètres sont nommes, on peut les appeler dans n'importe quel ordre et ils sont optionnels // afin de les rendre obligatoires, on utilise required
    required String email,
    required String password,
    required String fullName,
    String? iban,
  }) async {
    final response = await ApiClient.post(
      'signup',
      body: json.encode({'email': email, 'password': password, 'full_name': fullName, 'iban': iban}),
      anonymous: true,
    );
    if (response.statusCode != 204) {                                           // 204 signifie que la requête a reussi et que le serveur n'a renvoye aucune reponse // en effet, nous n'attendons pas de reponse du serveur
      throw Exception('Failed to signup\n\n${response.body}');
    }
  }

  static Future<bool> checkEmailAvailable({
    String? email,
  }) async {
    final response = await ApiClient.post(
      'check_email_available',
      body: json.encode({
        'email': email,
        'user_id' : 0, // 0 pour un nouvel utilisateur
      }),
      anonymous: true,
    );
    final dynamic body = json.decode(response.body);
    if (response.statusCode != 200) {
      throw Exception('Failed to validate email\n\n${body['message']}');
    }
    return body;
  }

  /* -----------------------------------------------------------------------
   * Appel endpoint : check full name available
   * --------------------------------------------------------------------- */

  static Future<bool> checkFullNameAvailable({
    String? fullName,
  }) async {
    final response = await ApiClient.post(
      'check_full_name_available',
      body: json.encode({
        'full_name': fullName,
        'user_id' : 0, // 0 pour un nouvel utilisateur
      }),
      anonymous: true,
    );
    final dynamic body = json.decode(response.body);
    if (response.statusCode != 200) {
      throw Exception('Failed to validate email\n\n${body['message']}');
    }
    return body;
  }

  /* -----------------------------------------------------------------------
   * Appel endpoint : reset data base
   * --------------------------------------------------------------------- */

  static Future<void> resetDatabase() async {
    final response = await ApiClient.post(
      'reset_database',
      anonymous: true,
    );
    if (response.statusCode != 204) {
      throw Exception('Failed to reset data base \n\n${response.body}');
    }
  }
}