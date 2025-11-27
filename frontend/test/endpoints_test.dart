/*
 * Ce fichier contient des tests destines à verifier le fonctionnement des
 * endpoints lorsqu'on est connecte en tant que 'basic_user'.
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
  
  // Ce callback est appele avant chaque test
  setUp(() async {
    await loginWithToken(email: 'bepenelle@epfc.eu', password: 'Password1,');
  });
  
  // Ce callback est appele après chaque test
  tearDown(() {
    Params.clearValue('token');
  });
  
  test('get_email', () async {
    final response = await getEmail();
    expect(response.statusCode, 200);

    final body = json.decode(response.body);
    expect(body, 'bepenelle@epfc.eu');
  });
}
