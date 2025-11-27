import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prbd_2425_a08/core/tools/validating_text_editing_controller.dart';

import 'package:prbd_2425_a08/providers/security_provider.dart';
import 'package:prbd_2425_a08/models/user.dart';

class SignupPage extends ConsumerStatefulWidget {
  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  late ValidatingTextEditingController _emailController;
  late ValidatingTextEditingController _fullNameController;
  late ValidatingTextEditingController _ibanController;
  late ValidatingTextEditingController _passwordController;
  late ValidatingTextEditingController _confirmPasswordController;

  @override
  void initState() {
    super.initState();

    _emailController = ValidatingTextEditingController(
      validator: UserValidator.validateEmail,
      asyncValidator: UserValidator.validateEmailUnicity,
      onAfterValidated: () => setState(() {}),
    );

    _fullNameController = ValidatingTextEditingController(
      validator: UserValidator.validateFullName,
      asyncValidator: UserValidator.validateFullNameUnicity,
      onAfterValidated: () => setState(() {}),
    );

    _ibanController = ValidatingTextEditingController(
      validator: UserValidator.validateIban,
      onAfterValidated: () => setState(() {}),
    );

    _passwordController = ValidatingTextEditingController(
      validator: UserValidator.validatePassword,
      onAfterValidated: () => setState(() {}),
    );

    _confirmPasswordController = ValidatingTextEditingController(
      validator: (value) => UserValidator.validateConfirmPassword(value, _passwordController.text),
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
          'Signup',
          style: TextStyle(color: Colors.white),
        ),
      ),

      // ──────────────── BODY ──────────────────
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 60, 0, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
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
                        keyboardType: TextInputType.emailAddress,
                        controller: _emailController,
                        onFieldSubmitted: (_) => _submitForm(context),
                        decoration: InputDecoration(
                          labelText: 'Email (*)',
                          border: OutlineInputBorder(),
                          errorText: _emailController.errorText,
                        ),
                      ),
                      SizedBox(height: 10),

                      // ------- full name ---------
                      TextFormField(
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        keyboardType: TextInputType.name,
                        controller: _fullNameController,
                        onFieldSubmitted: (_) => _submitForm(context),
                        decoration: InputDecoration(
                          labelText: 'Full Name (*)',
                          border: OutlineInputBorder(),
                          errorText: _fullNameController.errorText,
                        ),
                      ),
                      SizedBox(height: 10),

                      // ------- IBAN ---------
                      TextFormField(
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        keyboardType: TextInputType.name,
                        controller: _ibanController,
                        onFieldSubmitted: (_) => _submitForm(context),
                        decoration: InputDecoration(
                          labelText: 'IBAN',
                          border: OutlineInputBorder(),
                          errorText: _ibanController.errorText,
                        ),
                      ),
                      SizedBox(height: 10),

                      // ------- password ---------
                      TextFormField(
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        keyboardType: TextInputType.visiblePassword,
                        obscureText: true,
                        controller: _passwordController,
                        onFieldSubmitted: (_) => _submitForm(context),
                        decoration: InputDecoration(
                          labelText: 'Password (*)',
                          border: OutlineInputBorder(),
                          errorText: _passwordController.errorText,
                        ),
                      ),
                      SizedBox(height: 10),

                      // ----- confirm password -------
                      TextFormField(
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        keyboardType: TextInputType.visiblePassword,
                        obscureText: true,
                        controller: _confirmPasswordController,
                        onFieldSubmitted: (_) => _submitForm(context),
                        decoration: InputDecoration(
                          labelText: 'Confirm your password (*)',
                          border: OutlineInputBorder(),
                          errorText: _confirmPasswordController.errorText,
                        ),
                      ),
                      SizedBox(height: 10),
                    ],
                  ),
                ),

                // ----- signup button -------
                ElevatedButton(
                  onPressed: _isButtonSignupActivated ?
                          () async => await _submitForm(context) :
                          null,
                  child: Text('Signup'),
                ),
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
    _fullNameController.dispose();
    _ibanController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm(BuildContext context) async {
    if (!await _validateForm()) return;
    await ref.read(securityProvider.notifier).signup(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _fullNameController.text.trim(),
          iban: _ibanController.text.trim(),
        );

    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(
          context, '/home', (route) => false);
    }
  }

  Future<bool> _validateForm() async {
    await _emailController.validateAndWait();
    await _fullNameController.validateAndWait();
    await _ibanController.validateAndWait();
    await _passwordController.validateAndWait();
    await _confirmPasswordController.validateAndWait();
    return _isFormValid;
  }

  bool get _isFormValid =>
      _emailController.isValid == true &&
      _fullNameController.isValid == true &&
      _ibanController.isValid == true &&
      _passwordController.isValid == true &&
      _confirmPasswordController.isValid == true;

  // pour avoir le meme resultat que la video du prof : il suffit simplement de remplacer  onPressed: _isButtonSignupActivated ? ... par _isFormValid ? ...
  // et de supprimer le getter ci dessous
  bool get _isButtonSignupActivated =>
      _isFormValid &&
      _fullNameController.text != '' &&
      _passwordController.text != '' &&
      _confirmPasswordController.text != '';
}
