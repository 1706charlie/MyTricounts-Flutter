import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prbd_2425_a08/core/tools/params.dart';
import 'package:prbd_2425_a08/models/security.dart';

import '../models/user.dart';


final securityProvider =
AsyncNotifierProvider<SecurityNotifier, User?>( // l'état : l'utilisateur connecté
      () => SecurityNotifier(),
);

class SecurityNotifier extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    final token = Params.getValue('token');
    if (token == null) return null;
    try {
      return await User.getCurrentUser();
    } catch (_) {
      return null;
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    try {
      var token = await Security.login(email, password);
      Params.setValue('token', token);
      var user = await User.getCurrentUser();
      state = AsyncData(user);
    } catch (e) {
      state = AsyncError("Something went wrong!\nPlease try again later.", StackTrace.current);
    }
  }

  Future<void> signup({
    required String email,
    required String password,
    required String fullName,
    String? iban,
  }) async {
    state = const AsyncValue.loading();
    try {
      await Security.signup(
        email: email,
        password: password,
        fullName: fullName,
        iban: iban,
      );
      await login(email, password);
      state = AsyncData(Params.getValue('token'));
    } catch (e) {
      state = AsyncValue.error("Signup failed", StackTrace.current);
    }
  }

  void logout() {
    Params.clearValue('token');
    state = AsyncData(null);
  }

  bool get isLoggedIn => state.value != null;
}
