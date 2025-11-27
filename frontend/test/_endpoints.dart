import 'dart:convert';

import 'package:http/http.dart';
import 'package:prbd_2425_a08/core/services/api_client.dart';
import 'package:prbd_2425_a08/core/tools/params.dart';

/// Appel du endpoint 'login'
Future<Response> login({
  required String email,
  required String password,
}) async {
  return await ApiClient.post('login',
      body: json.encode({
        'email': email,
        'password': password,
      }),
      anonymous: true);
}

/// Appel du endpoint 'login' et stocke le token dans les paramètres
Future<void> loginWithToken({
  required String email,
  required String password,
}) async {
  Params.clearValue('token');
  final response = await login(email: email, password: password);
  if (response.statusCode == 200) {
    Params.setValue('token', json.decode(response.body)['token']); 
  } else {
    throw Exception('Failed to login\n\n${response.body}');
  }
}

/// Appel du endpoint 'is_email_available'
Future<Response> isEmailAvailable({
  required String email,
}) async {
  return await ApiClient.post('is_email_available',
      body: json.encode({
        'email': email,
      }),
      anonymous: true);
}

/// Appel du endpoint 'get_email'
Future<Response> getEmail() async {
  return await ApiClient.get('get_email');
}
