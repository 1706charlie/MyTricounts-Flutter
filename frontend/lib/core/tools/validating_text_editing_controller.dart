import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:prbd_2425_a08/core/tools/debounce.dart';

class ValidatingTextEditingController extends TextEditingController {
  // validateur synchrone
  String? Function(String value)? validator;

  // validateur asynchrone
  Future<String?> Function(String value)? asyncValidator;

  // callback appele après la validation
  void Function()? onAfterValidated;

  // message d'erreur
  String? _errorText;

  // la validation est en cours
  bool _isValidating = false;

  // le champ est vierge (non modifie par l'utilisateur)
  bool _isPristine = true;

  // le contrôleur a ete supprime
  bool _isDisposed = false;

  // tâche asynchrone en cours
  CancelableOperation? _task;

  // debouncer pour la validation asynchrone
  final Debouncer _debouncer = Debouncer();

  ValidatingTextEditingController({
    this.validator,
    this.asyncValidator,
    this.onAfterValidated,
    initialValue,
  }) : super(text: initialValue);

  bool get isValidating => _isValidating;

  bool get isPristine => _isPristine;

  String? get errorText => _errorText;

  bool? get isValid => _isValidating ? null : (_errorText == null);

  /// On surcharge le setter de [value] pour intercepter les changements de texte
  /// et declencher la validation.
  @override
  set value(TextEditingValue newValue) {
    if (_isDisposed) return;
    if (newValue.text != text) {
      _isPristine = false;
      super.value = newValue;
      validate();
    } else {
      super.value = newValue;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  /// On surcharge la methode [notifyListeners] pour eviter de notifier les ecouteurs
  /// si le contrôleur a ete supprime.
  @override
  notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }

  /// Cette methode permet de valider le texte actuel en executant les validateurs
  /// synchrone et asynchrone, s'ils sont definis. Le validateur asynchrone est
  /// appele de manière synchrone (avec un await).
  Future<void> validateAndWait() async {
    if (_isDisposed) return;

    if (validator == null) return;
    _errorText = validator!(text);
    if (asyncValidator != null) {
      _errorText ??= await asyncValidator!(text);
    }
    notifyListeners();
    onAfterValidated!();
  }

  /// Cette methode permet de valider le texte actuel en executant les validateurs
  /// synchrone et asynchrone, s'ils sont definis. Le validateur asynchrone est
  /// appele de manière asynchrone (sans await). La methode utilise aussi le
  /// principe de [*debouncing*](https://developer.mozilla.org/en-US/docs/Glossary/Debounce) 
  /// pour eviter de lancer plusieurs fois la validation
  /// asynchrone si l'utilisateur appelle plusieurs fois la methode avant que la
  /// validation precedente ne soit terminee.
  void validate() {
    if (_isDisposed) return;

    _isValidating = true;

    // effectuer la validation synchrone
    _errorText = validator?.call(text);
    notifyListeners();

    // si un validateur asynchrone est defini et la validation synchrone est reussie
    if (asyncValidator != null && _errorText == null) {
      // annuler la tâche en cours, s'il y en a une
      _task?.cancel();

      // utiliser le debouncer pour gerer le delai avant validation asynchrone
      _debouncer.call(() async {
        try {
          // reinitialiser l'erreur avant de valider
          _errorText = null;
          notifyListeners();

          // creer une operation annulable pour la validation asynchrone
          _task = CancelableOperation.fromFuture(
            asyncValidator!.call(text),
          );

          // attendre le resultat de la validation asynchrone
          final error = await _task?.value;
          _errorText = error;
        } finally {
          // toujours remettre l'etat de validation à false
          _isValidating = false;
          notifyListeners();
          onAfterValidated?.call();
        }
      });
    } else {
      // si aucune validation asynchrone n'est necessaire, remettre l'etat immediatement
      _isValidating = false;
      notifyListeners();
      onAfterValidated?.call();
    }
  }
}
