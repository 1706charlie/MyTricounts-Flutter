import 'dart:async';
import 'dart:collection';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prbd_2425_a08/core/tools/abstract_async_notifier.dart';
import 'package:prbd_2425_a08/models/tricount.dart';
import 'package:prbd_2425_a08/providers/security_provider.dart';
import '../models/user.dart';
import 'current_tricount_provider.dart';

final tricountListProvider =
AsyncNotifierProvider<TricountListNotifier, SplayTreeSet<Tricount>>( // l'état = liste des tricounts de user connected
      () => TricountListNotifier(),
);

class TricountListNotifier extends AbstractAsyncNotifier<SplayTreeSet<Tricount>> {
  @override
  Future<SplayTreeSet<Tricount>> build() async {
    ref.watch(securityProvider);
    ref.watch(currentTricountProvider);
    state = AsyncData(SplayTreeSet<Tricount>());
    state = AsyncLoading();
    try {
      return SplayTreeSet<Tricount>.from(await Tricount.getMyTricounts());
    } catch (e) {
      throw "Something went wrong!\nPlease try again later.";
    }
  }

  @override
  Future<void> refresh() async {
    await getMyTricounts();
  }

  Future<void> getMyTricounts() async {
    state = const AsyncValue.loading();
    try {
      final pairs = SplayTreeSet<Tricount>.from(
          await Tricount.getMyTricounts());
      state = AsyncData(pairs);
    } catch (e) {
      print(e);
      state = AsyncValue.error(
          "Something went wrong!\nPlease try again later.", StackTrace.current);
    }
  }

  Future<Tricount?> saveTricount(int id, String title, String description,
      SplayTreeSet<User> participants) async {
    state = const AsyncValue.loading();
    try {
      final newTricount = await Tricount.saveTricount(
          id, title, description, participants); // on s'occupe de la db
      final tricounts = state.value!;
      if (id == 0) { // création d'un tricount
        tricounts.add(newTricount);
      } else { // modification de tricount
        tricounts.removeWhere((element) => element.id == id);
        tricounts.add(newTricount);
      }
      state = AsyncData(
          tricounts); // appel réussi // state vaut le nouvel état : la nouvelle liste my tricounts
      ref.read(currentTricountProvider).select(newTricount);
      return newTricount;
    } catch (e) {
      state = AsyncValue.error("Something went wrong!\nPlease try again later.",
          StackTrace.current); // erreur
      return null;
    }
  }

  Future<bool> deleteTricount(Tricount tricount) async {
    state = const AsyncValue.loading(); // chargement
    try {
      await tricount.deleteTricount(); // on s'occupe de la db
      final tricounts = state.value!; // on récupère le set de tricounts
      tricounts.remove(tricount);
      tricount.deleteAt = DateTime.now();
      tricounts.add(tricount);
      state = AsyncData(tricounts); // appel réussi // state vaut le nouvel état : le set de tricounts
      return true;
    } catch (e) {
      state = AsyncValue.error("Something went wrong!\nPlease try again later.",
          StackTrace.current); // erreur
      return false;
    }
  }

  Future<bool> restoreTricount(Tricount tricount) async {
    state = const AsyncValue.loading(); // chargement
    try {
      await tricount.restoreTricount(); // on s'occupe de la db
      final tricounts = state.value!; // on récupère le set de tricounts
      tricounts.remove(tricount);
      tricount.deleteAt = null;
      tricounts.add(tricount);
      state = AsyncData(tricounts); // appel réussi // state vaut le nouvel état : le set de tricounts
      return true;
    } catch (e) {
      state = AsyncValue.error("Something went wrong!\nPlease try again later.",
          StackTrace.current); // erreur
      return false;
    }
  }
}

/* AsyncNotifierProvider : AsyncValue<T>
logique métier
asynchrone
possède un état : ici liste my tricounts

gestion de l'état avec when se fait toujours dans le build() (ou dans un widget enfant de build())
final myTricounts = ref.watch(myTricountsProvider); // pour récupérer l'état du provider
final myTricounts = ref.read(myTricountsProvider); // pour récupérer l'état du provider
final notifier = ref.read(myTricountsProvider.notifier); // pour récupérer le notifier du provider et pour appeler ses méthodes

 */

