import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prbd_2425_a08/core/tools/validating_text_editing_controller.dart';
import 'package:prbd_2425_a08/core/widgets/dialog_box.dart';
import 'package:prbd_2425_a08/models/user.dart';
import 'package:prbd_2425_a08/providers/security_provider.dart';
import 'package:prbd_2425_a08/views/widgets/debug_panel.dart';


class LoginPage extends ConsumerStatefulWidget {
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  late ValidatingTextEditingController _emailController;
  late ValidatingTextEditingController _passwordController;

  @override
  void initState() {
    super.initState();

    _emailController = ValidatingTextEditingController(
      validator: UserValidator.validateEmail,
      onAfterValidated: () => setState(() {}),
    );

    _passwordController = ValidatingTextEditingController(
      validator: UserValidator.validatePassword,
      onAfterValidated: () => setState(() {}),
    );

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      // ──────────────── APP BAR ────────────────
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Text(
          'Login',
          style: TextStyle(color: Colors.white),
        ),
      ),


      // ──────────────── BODY ──────────────────
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 60, 0, 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: min(MediaQuery.of(context).size.width * 0.8, 250),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [

                      // -------- email --------
                      TextFormField(
                        autofocus: true,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        controller: _emailController,
                        onFieldSubmitted: (_) => _submitForm(context),
                        decoration: InputDecoration(
                          labelText: 'Email (*)',
                          border: OutlineInputBorder(),
                          errorText: _emailController.errorText,
                        ),
                      ),
                      SizedBox(height: 10),

                      // ------- password ---------
                      TextFormField(
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        controller: _passwordController,
                        onFieldSubmitted: (_) => _submitForm(context),
                        decoration: InputDecoration(
                          labelText: 'Password (*)',
                          border: OutlineInputBorder(),
                          errorText: _passwordController.errorText,
                        ),
                        obscureText: true,
                      ),
                      SizedBox(height: 10),

                      // ----- login button -------
                      ElevatedButton(
                        onPressed: _isButtonLoginActivated ?
                            () => _submitForm(context) :
                            null,
                        child: Text('Login'),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),

                // ----- signup button -------
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/signup'),
                  child: Text('Don\'t have an account? Sign up here!'),
                ),


                // ------ debut panel --------
                if (kDebugMode) ...[
                  SizedBox(height: 30),
                  DebugPanel(
                    loginAction: _login,
                    users: ['bepenelle@epfc.eu', 'boverhaegen@epfc.eu', 'gedielman@epfc.eu', 'admin@epfc.eu'],
                  )
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  _submitForm(BuildContext context) {
    if (!_validateForm()) return;
    _login(context, _emailController.text, password: _passwordController.text);
  }

  bool _validateForm() {
    _emailController.validate();
    _passwordController.validate();
    return _isFormValid;
  }

  bool get _isFormValid => _emailController.isValid == true && _passwordController.isValid == true;

  void _login(BuildContext context, String mail, {String? password}) async {
    await ref.read(securityProvider.notifier).login(mail, password ?? 'Password1,');
    var securityState = ref.read(securityProvider);

    if (!context.mounted) return;

    securityState.when(
      data: (_) => Navigator.pushReplacementNamed(context, '/home'),
      error: (error, _) => DialogBox(
        title: 'Error',
        message: 'Bad credentials',
        actions: ['OK'],
      ).show(context),
      loading: () {},
    );
  }

  // pour avoir le meme resultat que la video du prof : il suffit simplement de remplacer  onPressed: _isButtonLoginActivated ? ... par _isFormValid ? ...
  // et de supprimer le getter ci dessous
  bool get _isButtonLoginActivated => _isFormValid && _emailController.text != '' && _passwordController.text != '';

}
