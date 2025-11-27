import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:prbd_2425_a08/core/tools/params.dart';

const throttleDuration = Duration(seconds: 0);

String get baseUrl => kIsWeb || !Platform.isAndroid
    ? 'http://localhost:3000/rpc'
    : 'http://10.0.2.2:3000/rpc';

class ApiClient {
  static final http.Client _client = http.Client();

  static Future<http.Response> get(
    String endpoint, {
    Map<String, String>? headers,
    bool anonymous = false,
  }) async {
    await Future.delayed(throttleDuration);
    final Uri url = Uri.parse('$baseUrl/$endpoint');
    return await _client.get(
      url,
      headers: {
        ...?headers,
        'Content-Type': 'application/json; charset=UTF-8',
        if (!anonymous) 'Authorization': 'Bearer ${Params.getValue('token')}'
      },
    );
  }

  static Future<http.Response> post(
    String endpoint, {
    Map<String, String>? headers,
    dynamic body,
    bool anonymous = false,
  }) async {
    await Future.delayed(throttleDuration);
    final Uri url = Uri.parse('$baseUrl/$endpoint');
    return await _client.post(
      url,
      headers: {
        ...?headers,
        'Content-Type': 'application/json; charset=UTF-8',
        if (!anonymous) 'Authorization': 'Bearer ${Params.getValue('token')}'
      },
      body: body,
    );
  }
}