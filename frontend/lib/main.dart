import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prbd_2425_a08/app/my_app.dart';
import 'package:prbd_2425_a08/core/tools/params.dart';

import 'core/tools/my_provider_observer.dart';

void main() async {
  await Params.init();
  runApp(
    ProviderScope(
      // observers: [MyProviderObserver()],
      child: MyApp(),
    ),
  );
}