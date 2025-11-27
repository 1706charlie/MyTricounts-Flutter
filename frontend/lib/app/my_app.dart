import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prbd_2425_a08/providers/security_provider.dart';
import 'package:prbd_2425_a08/providers/theme_mode_provider.dart';
import 'package:prbd_2425_a08/views/pages/add_operation_page.dart';
import 'package:prbd_2425_a08/views/pages/balance_page.dart';
import 'package:prbd_2425_a08/views/pages/deleted_tricounts_page.dart';
import 'package:prbd_2425_a08/views/pages/login_page.dart';
import 'package:prbd_2425_a08/views/pages/signup_page.dart';
import 'package:prbd_2425_a08/views/pages/my_home_page.dart';
import 'package:prbd_2425_a08/views/pages/view_tricount.dart';
import 'package:prbd_2425_a08/views/pages/add_tricount_page.dart';
import '../models/operation.dart';
import '../views/pages/edit_operation_page.dart';
import '../views/pages/edit_tricount_page.dart';


class MyApp extends ConsumerWidget {

  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final securityNotifier = ref.read(securityProvider.notifier);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Tricount',
      themeMode: themeMode,
      theme: _light,
      darkTheme: _dark,

      initialRoute: securityNotifier.isLoggedIn ? '/home' : '/login',
      routes: {
        '/login': (context) => LoginPage(),
        '/home': (context) => MyHomePage(),
        '/signup': (context) => SignupPage(),
        '/view_tricount': (context) => ViewTricountPage(),
        '/balance': (context) => BalancePage(),
        '/add_tricount': (context) => AddTricountPage(),
        '/edit_tricount': (context) => EditTricountPage(),
        '/add_operation': (context) => AddOperationPage(),
        '/delete_tricounts': (context) => DeletedTricountsPage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/edit_operation') {
          final operation = settings.arguments as Operation;
          return MaterialPageRoute(
            builder: (_) => EditOperationPage(operation: operation),
          );
        }
        return null;
      },
    );
  }
}

final _light = ThemeData(
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
  bottomAppBarTheme: const BottomAppBarTheme(
    color: Colors.white,
    elevation: 0,
  ),
);

final _dark = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: Colors.black,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.blue,
    brightness: Brightness.dark,
  ),
  textTheme: ThemeData.dark().textTheme.apply(
    bodyColor: Colors.white,
    displayColor: Colors.white,
  ),
  bottomAppBarTheme: const BottomAppBarTheme(
    color: Colors.black, 
    elevation: 0,
  ),
);