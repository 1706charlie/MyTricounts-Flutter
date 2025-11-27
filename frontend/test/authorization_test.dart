/*
 * Ce fichier contient des tests destines à verifier que les endpoints
 * necessitent les autorisations appropriees. L'idee est que chaque
 * endpoint soit teste en tant qu'utilisateur anonyme, utilisateur connecte et
 * administrateur et qu'on verifie qu'il retourne le code de statut HTTP
 * approprie dans chaque cas.
 */


import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
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

  group('get_email', () {
    endpoint() => getEmail();
    test('anon', () async => await _testAsAnon(endpoint, 401));
    test('user', () async => await _testAsUser(endpoint, 200));
    test('admin', () async => await _testAsAdmin(endpoint, 200));
  });
}

//------------------------------------------------------------------------------
// Fonctions utilitaires destinees à tester un endpoint en tant qu'utilisateur
// anonyme, utilisateur connecte ou administrateur.
//------------------------------------------------------------------------------

Future<Response> _testAs(
  String? email,
  String? password,
  Future<Response> Function() callback,
  int statusCode,
) async {
  await Params.clearValue('token');
  if (email != null) {
    await loginWithToken(email: 'bepenelle@epfc.eu', password: 'Password1,');
  } else {
    await Params.clearValue('token');
  }
  final response = await callback();
  expect(response.statusCode, statusCode);
  return response;
}

Future<Response> _testAsAnon(
  Future<Response> Function() callback,
  int statusCode,
) async {
  return _testAs(null, null, callback, statusCode);
}

Future<Response> _testAsUser(
  Future<Response> Function() callback,
  int statusCode,
) async {
  return _testAs('bepenelle@epfc.eu', 'Password1,', callback, statusCode);
}

Future<Response> _testAsAdmin(
  Future<Response> Function() callback,
  int statusCode,
) async {
  return _testAs('admin@epfc.eu', 'Password1,', callback, statusCode);
}
