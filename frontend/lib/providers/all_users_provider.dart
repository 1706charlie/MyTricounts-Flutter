import 'dart:collection';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prbd_2425_a08/models/user.dart';
import 'package:prbd_2425_a08/providers/security_provider.dart';

final allUsersProvider = FutureProvider<SplayTreeSet<User>>((ref) async { // l'etat : tous les utilisateurs
  ref.watch(securityProvider);

  return SplayTreeSet<User>.from(await User.getAllUsers());

});


/* Future Provider : AsyncValue<T>
permet de gérer un état unique basé sur le retour d'une opération asynchrone
c'est donc un provider qui permet uniquement de renvoyer une information (aucune logique métier ne doit se faire à part peut être un filtrage)

opération asynchrone : on l'utilise avec le when (loading, data, erreur) // when s’utilise toujours dans le build() (ou dans un widget enfant de build())

pour rafraichir l'état de FutureProvider, on utilise le ref.refresh(allUsersProvider) ou ref.invalidate(allUsersProvider)

utilisation :
final asyncValue = ref.watch(allUsersProvider); // asyncValue représente l'état du provider : ici : les utilisateurs
pas de ref.read(allUsersProvider) -> allUsersProvider suffit !

 */






/* --------- où peut on placer les ref.read() et ref.watch() --------------------------------



rappel sur le ref.read() et ref.watch() :
ref.watch --> se fait toujours dans le build() ou dans un widget enfant de build() => ref.watch : lorsque l'état change de valeur la méthode build() est reconstruite

ref.read --> se fait partout (dans le build() ou en dehors du build())

ref.watch et ref.read peuvent ils se trouver dans initState() ??
  ref.read : oui
  ref.watch : non
 */



/* --------------------- quand et où utlilser le when() ?----------------------------------
à utiliser uniquement en cas où on renvoie une AsyncValue<T>  :  FutureProvider et AsyncNotifierProvider


dans quels cas peut on se passer du when ?
- Code non-UI : ex : final users = await ref.read(allUsersProvider.future);
- UI déjà protégée en amont. Ex : lors du login on va gérer les 3 cas du SecurityProvider, après ce n'est plus nécessaire.

Où : uniquement dans le build() ou dans un widget enfant de build()

 */



/* ------------- si j'ai plusieurs asyncValue<T> à gérer dans mon widget ? -------------------
 2 stratégies :

 - 1) Découper en sous-widgets (chaque widget ne gère qu’un seul AsyncValue avec son propre when)

 - 2) when imbriqués :

    return userAsync.when(
      loading: _loader,
      error  : _error,
      data   : (user) {
        return statsAsync.when(
          loading: _loader,
          error  : _error,
          data   : (stats) => Dashboard(user, stats),
        );
      },
  );

 */


