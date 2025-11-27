import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

/*
Exécute automatiquement des tests unitaires basés sur une collection Postman.

Fonctionnalités principales :

- Charge un fichier `.json` exporté depuis Postman (version 2.1) dans lequel
  chaque requête est associée à une réponse enregistrée.
- Nettoie les éventuels commentaires `//` présents dans les `body` de requêtes/réponses. 
- Utilise la librairie `http` pour exécuter les requêtes HTTP. 
- Vérifie récursivement que les réponses du serveur correspondent exactement aux réponses 
  enregistrées dans Postman (sauf pour les champs `created_at`, testés par 
  regex sur leur format ISO, et sauf pour le login : voir ci-dessous).
- Gère automatiquement les tokens JWT : lors d’un login, le token est extrait 
  de la réponse et réutilisé comme `Authorization: Bearer ...` dans les appels suivants.
- Organise les tests dans des `group(...)` imbriqués récursivement conformément à
  la structure des dossiers de la collection Postman.
*/

void main() async {
  final runner = PostmanTestRunner(
    jsonFilePath:
        'lib/postman_tests.json',
    showUrls: true,
    showBody: true,
    validateStatusCodeOnError: false,
    validateResponseOnError: false,
    stopOnFirstError: false,
  );
  await runner.run();
}

class PostmanTestRunner {
  final String jsonFilePath;
  late Map<String, dynamic> collection;
  late Map<String, String> variables;
  String? accessToken;
  final bool showUrls;
  final bool showBody;
  final bool validateResponseOnError;
  final bool validateStatusCodeOnError;
  final bool stopOnFirstError;
  final http.Client _client = http.Client();

  /// Constructeur de la classe PostmanTestRunner.
  /// 
  /// - [jsonFilePath] Chemin vers le fichier JSON exporté depuis Postman.
  /// - [showUrls] Affiche les URLs des requêtes dans la console.
  /// - [showBody] Affiche le body des requêtes POST dans la console.
  /// - [stopOnFirstError] S'arrête au premier test échoué.
  /// - [validateResponseOnError] Valide la réponse même si le code de statut est différent de 2xx.
  /// - [validateStatusCodeOnError] Valide le code de statut même s'il est différente de 2xx.
  PostmanTestRunner({
    required this.jsonFilePath,
    this.showUrls = false,
    this.showBody = false,
    this.stopOnFirstError = false,
    this.validateResponseOnError = false,
    this.validateStatusCodeOnError = false,
  });

  Future<void> run() async {
    await _loadCollection();
    group(collection['info']['name'], () {
      _walkItems(collection['item']);
    });
  }

  Future<void> _loadCollection() async {
    final file = File(jsonFilePath);
    final rawJson = await file.readAsString();
    collection = jsonDecode(rawJson);
    // récupération des variables de la collection
    variables = {
      for (final v in collection['variable']) v['key']: v['value'],
    };
    // on ajoute manuellement un variable 'today' qui contient la date du jour
    final now = DateTime.now().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    variables['today'] = today.toIso8601String().substring(0, 10);
    print(variables);
  }

  void _walkItems(List items) {
    for (final item in items) {
      if (item.containsKey('item')) {
        group('> ${item['name']}', () {
          _walkItems(item['item']);
        });
      } else {
        _registerTest(item);
      }
    }
  }

  // on remplace les variables de la collection par leur valeur dans la string
  String _interpolateVariables(String str) {
    return variables.entries.fold(str, (s, e) => s.replaceAll('{{${e.key}}}', e.value));
  }

  void _registerTest(Map<String, dynamic> item) {
    final name = item['name'];
    final request = item['request'];
    final method = request['method'];
    final urlRaw = request['url']['raw'] as String;
    final url = _interpolateVariables(urlRaw);
    final rawBody = request['body']?['raw'];
    var body = _interpolateVariables(_cleanJson(rawBody));
    final savedResponse =
        item['response']?.isNotEmpty == true ? item['response'][0] : null;
    final int expectedStatus = savedResponse?['code'];
    final bool expectedStatusIsOk =
        expectedStatus >= 200 && expectedStatus < 300;
    var expectedBody = _interpolateVariables(_cleanJson(savedResponse?['body']));

    test('> $name', () async {
      final diffs = <String>[];
      try {
        final Map<String, dynamic> headers = {
          for (final h in request['header'] ?? []) h['key']: h['value']
        };
        if (accessToken != null) {
          headers['Authorization'] = 'Bearer $accessToken';
        }

        if (showUrls) {
          print('$method $url');
        }
        if (showBody && method == 'POST') {
          print('body: $body');
        }

        http.Response? response;
        if (method == 'GET') {
          response = await _client.get(
            Uri.parse(url),
            headers: {
              ...headers,
              'Content-Type': 'application/json; charset=UTF-8',
            },
          );
        } else if (method == 'POST') {
          response = await _client.post(
            Uri.parse(url),
            headers: {
              ...headers,
              'Content-Type': 'application/json; charset=UTF-8',
            },
            body: body.isNotEmpty ? jsonEncode(jsonDecode(body)) : null,
          );
        } else {
          throw Exception('Méthode HTTP non supportée : $method');
        }

        // print('${response.statusCode} - ${expectedStatus}');
        
        if (expectedStatusIsOk && response.statusCode >= 300) {
          print('Erreur : ${response.statusCode} - ${response.body}');
        }
        
        // vérification du code de statut
        if (expectedStatusIsOk || validateStatusCodeOnError) {
          expect(response.statusCode, expectedStatus);
        } else {
          expect(response.statusCode, greaterThanOrEqualTo(300));
        }          

        // vérification du body s'il est non vide et si le statusCode est 2xx
        if ((expectedStatusIsOk || validateResponseOnError) && expectedBody.isNotEmpty) {
          final expected = jsonDecode(expectedBody);
          final actual = jsonDecode(response.body);

          if (_isLoginResponse(name, actual)) {
            accessToken = actual['token'];
            expect(accessToken, isNotEmpty);
          } else {
            final sameResult = _deepEquals(actual, expected, diffs);
            expect(
              sameResult,
              isTrue,
              reason: 'Les réponses ne correspondent pas pour \'$name\':'
                  '\n${diffs.join('\n')}',
            );
          }
        }
      } on TestFailure catch (error, stackTrace) {
        if (stopOnFirstError) {
          // print('Les réponses ne correspondent pas pour \'$name\':'
          //     '\n${diffs.join('\n')}');
          print('Erreur détectée, arrêt immédiat.');
          print(error);
          print(stackTrace);
          exit(1);
        } else {
          rethrow;
        }
      }
    });
  }

  // nettoie le JSON en supprimant les commentaires
  String _cleanJson(String? jsonStr) {
    if (jsonStr == null) return '';
    return LineSplitter.split(jsonStr)
        .map((line) => line.contains('//') ? line.split('//')[0] : line)
        .join('\n');
  }

  bool _isLoginResponse(String name, dynamic response) {
    return name.toLowerCase().contains('login') &&
        response is Map &&
        response['token'] != null;
  }

  bool _deepEquals(dynamic a, dynamic b, List<String> diffs,
      {String path = '', bool log = true}) {
    void logDifference(String message) {
      if (!log) return;
      if (path.isEmpty) {
        diffs.add('différence : $message');
      } else {
        diffs.add('différence dans $path : $message');
      }
    }

    // si c'est un Map, on vérifie la taille et on compare les clés
    if (a is Map && b is Map) {
      if (a.length != b.length) {
        logDifference('taille différente (Map): ${a.length} vs ${b.length}');
        return false;
      }
      for (final key in a.keys) {
        final subPath = path.isEmpty ? key : '$path.$key';

        if (!b.containsKey(key)) {
          logDifference('clé absente dans b : $subPath');
          return false;
        }

        // comme il s'agit d'un timestamp, on ne le compare pas mais on vérifie
        // juste qu'il est au format ISO
        if (key == 'created_at') {
          final value = a[key];
          if (value is! String ||
              !RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?$')
                  .hasMatch(value)) {
            logDifference('format de date invalide pour $subPath : $value');
            return false;
          }
          continue;
        }

        if (!_deepEquals(a[key], b[key], diffs, path: subPath, log: log)) {
          return false;
        }
      }
      return true;
    }

    // si c'est une liste, on vérifie la taille et on compare les éléments
    // en ne tenant pas compte de l'ordre
    if (a is List && b is List) {
      if (a.length != b.length) {
        logDifference('taille différente (List): ${a.length} <> ${b.length}');
        return false;
      }

      // on crée une copie de b pour ne pas modifier l'original
      // et on retire les éléments trouvés dans a au fur et à mesure
      final unmatched = List.of(b);
      for (final item in a) {
        final index = unmatched.indexWhere(
            (e) => _deepEquals(e, item, diffs, path: '$path[*]', log: log));
        if (index == -1) {
          logDifference('élément non trouvé dans la liste : $item');
          return false;
        }
        unmatched.removeAt(index);
      }
      int i = 0;
      bool orderPreserved = true;
      for (final item in a) {
        final index = b.indexWhere(
            (e) => _deepEquals(e, item, diffs, path: '$path[*]', log: false));
        if (i != index) orderPreserved = false;
        ++i;
      }
      if (!orderPreserved) {
        print('warning: ordre différent dans la liste: $a');
      }
      return true;
    }

    if (!_looseEquals(a, b)) {
      logDifference('valeurs différentes : \'$a\' <> \'$b\'\n'
          'actual type: ${a.runtimeType} - expected type: ${b.runtimeType}');
      return false;
    }

    return true;
  }

  bool _looseEquals(dynamic a, dynamic b) {
    dynamic convert(dynamic value) {
      if (value is String) {
        final trimmed = value.trim();

        // Essaye int
        final intVal = int.tryParse(trimmed);
        if (intVal != null) return intVal;

        // Essaye double
        final doubleVal = double.tryParse(trimmed);
        if (doubleVal != null) return doubleVal;

        // Essaye bool
        final lower = trimmed.toLowerCase();
        if (lower == 'true') return true;
        if (lower == 'false') return false;

        // Essaye DateTime
        final dateVal = DateTime.tryParse(trimmed);
        if (dateVal != null) return dateVal;
      }

      return value;
    }

    final aConv = convert(a);
    final bConv = convert(b);

    if (aConv is num && bConv is num) {
      return (aConv - bConv).abs() <= 0.02;
    }

    if (aConv is DateTime && bConv is DateTime) {
      return aConv.millisecondsSinceEpoch == bConv.millisecondsSinceEpoch;
    }

    return aConv == bConv;
  }
}
