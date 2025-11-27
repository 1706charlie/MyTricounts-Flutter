import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prbd_2425_a08/models/repartition.dart';
import '../models/operation.dart';
import '../models/tricount.dart';
import '../models/user.dart';

final currentTricountProvider =
ChangeNotifierProvider<CurrentTricount>((ref) => CurrentTricount());


class CurrentTricount extends ChangeNotifier {
  Tricount? _tricount;

  Tricount? get tricount => _tricount;

  bool get hasValue => _tricount != null;

  /// Definit un nouveau tricount actuel
  void select(Tricount tricount) {
    _tricount = tricount;
    notifyListeners();
  }

  double getMyTotal(int myUserId) {
    if (_tricount == null) return 0.0;

    double total = 0.0;
    for (final operation in _tricount!.operations) {
      Repartition? repartition;
      try {
        repartition = operation.repartitions.firstWhere((r) => r.user.id == myUserId);
      } catch(_) {
        repartition = null;
      }
    
      if (repartition != null) {
        final totalWeight = operation.repartitions.fold<int>(
          0, (sum, r) => sum + r.weight,
        );
        if (totalWeight > 0) {
          total += operation.amount * repartition.weight / totalWeight;
        }
      }
    }
    return total;
  }

  /// Ajout / édition d’une dépense dans le tricount courant
  Future<Operation?> addOperation(
    int id,  // 0 si création
    String title,
    double amount,
    DateTime operationDate,
    User initiator,
    SplayTreeSet<Repartition> repartitions
  ) async {
    if (_tricount == null) return null;
    try {
      final operation = await _tricount!.saveOperation(            // update backend
        id, title, amount, operationDate, initiator, repartitions,
      );
      if (operation != null) {                                     // update model
        _tricount!.operations
          ..removeWhere((op) => op.id == id)
          ..add(operation);
      }
      notifyListeners(); // notifie les observateurs qui sont balanceProvider et tricountListProvider
      return operation;
    } catch (e) {
      return null;
    }
  }

  /// Suppression d’une dépense dans le tricount courant
  Future<bool> deleteOperation(Operation operation) async {
    if (_tricount == null) return false;
      try {
        await tricount!.deleteOperation(operation);                // update backend
        tricount!.operations.remove(operation);                    // udpate model
        notifyListeners();
        return true;
      } catch (e) {
        return false;
      }
  }



}

/* ChangeNotifierProvider :
logique métier doit être présent dans ce provider
provider synchrone (pas d'appel au backend)

utilisation :
final currentTricount = ref.watch(currentTricoutProvider);
==> ici, currentTricount contient l'instance courante (l'objet lui même) de type CurrentTricount


// si on veut juste lire les attributs // accéder à une méthode ou une variable de ce provider on fait :
- ref.read(currentTricountProvider).tricount
- ref.read(currentTricountProvider).select(tricount)

// si on veut écouter les changements ==> on utilise watch ==> fait reconstruire le widget quand notifyListeners() est appelé
- ref.watch(currentTricountProvider)



pas de when (loading, data, erreur) ici car pas d'appel asynchrone
 */


