import 'dart:collection';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prbd_2425_a08/core/tools/abstract_async_notifier.dart';
import 'package:prbd_2425_a08/models/user_balance.dart';
import 'package:prbd_2425_a08/providers/tricount_list_provider.dart';
import 'package:prbd_2425_a08/providers/security_provider.dart';
import 'current_tricount_provider.dart';


final balanceProvider =
AsyncNotifierProvider<BalanceNotifier, SplayTreeSet<UserBalance>?>( // l'état = liste user balances
      () => BalanceNotifier(),
);

class BalanceNotifier extends AbstractAsyncNotifier<SplayTreeSet<UserBalance>?> {
  @override
  Future<SplayTreeSet<UserBalance>?> build() async {
    ref.watch(securityProvider);
    ref.watch(tricountListProvider);
    ref.watch(currentTricountProvider);
    final tricount = ref.watch(currentTricountProvider).tricount;
    if (tricount == null) return null;
    final balances = await tricount.getUserBalances();
    return SplayTreeSet<UserBalance>.from(balances);
  }

  @override
  Future<void> refresh() async {
    await getUserBalances();
  }

  Future<void> getUserBalances() async {
    state = const AsyncValue.loading();
    final tricount = ref.read(currentTricountProvider).tricount;
    if (tricount == null) {
      state = AsyncData(null);
      return;
    }
    try {
      final balances = SplayTreeSet<UserBalance>.from(await tricount.getUserBalances());
      state = AsyncData(balances);
    } catch (e) {
      print(e);
      state = AsyncError("Something went wrong!\nPlease try again later.", StackTrace.current);
    }

  }


}