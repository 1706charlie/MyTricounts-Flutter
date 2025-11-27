/*
 * Ce fichier contient les tests des fonctions liees à l'authentification.
 */

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:prbd_2425_a08/core/tools/params.dart';

import '_endpoints.dart';

void main() async {
  // Ce callback est appele une fois avant tous les tests du fichier
  setUpAll(() async {
    // Requis pour l'initialisation de Hive
    await Params.init();
  });

  // Ce callback est appele une fois après tous les tests du fichier
  tearDownAll(() {
    Params.clearAll();
    Params.close();
  });

  test('login: OK', () async {
    final response = await login(
      email: 'bepenelle@epfc.eu',
      password: 'Password1,',
    );
    expect(response.statusCode, 200);

    final body = json.decode(response.body);
    final token = body['token'];
    Params.setValue('token', token);

    expect(token, isNotNull);
    expect(token, isA<String>());
    expect(token, matches(RegExp(r'^[\w-]+\.[\w-]+\.[\w-]+$')));
  });

  test('login: KO', () async {
    final response = await login(
      email: '???',
      password: '???',
    );
    expect(response.statusCode, 403);
  });

  test('is_email_available: true', () async {
    final response = await isEmailAvailable(
      email: 'test@epfc.eu',
    );
    expect(response.statusCode, 200);

    final body = json.decode(response.body);
    expect(body, isTrue);
  });

  test('is_email_available: false', () async {
    final response = await isEmailAvailable(
      email: 'bepenelle@epfc.eu',
    );
    expect(response.statusCode, 200);

    final body = json.decode(response.body);
    expect(body, isFalse);
  });
}
