import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../models/tricount.dart';
import '../../providers/security_provider.dart';
import '../../providers/tricount_list_provider.dart';
import '../widgets/data_error_widget.dart';

class DeletedTricountsPage extends ConsumerWidget {
  const DeletedTricountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myTricountsAsyncState = ref.watch(tricountListProvider);
    final myTricountsNotifier = ref.read(tricountListProvider.notifier);

    return Scaffold(
      /* ---------------------- APP BAR ---------------------- */
      appBar: AppBar(
        backgroundColor: Colors.blue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('My Deleted Tricounts', style: TextStyle(color: Colors.white)),
      ),

      /* ---------------------- BODY ------------------------- */
      body: myTricountsAsyncState.when(
        data: (tricounts) => data(context, tricounts, ref, isLoading: false),
        loading: () => data(context, myTricountsAsyncState.value ?? SplayTreeSet(), ref, isLoading: true),
        error: (err, stackTrace) => DataErrorWidget(error: err, stackTrace: stackTrace, notifier: myTricountsNotifier,
        ),
      ),
    );
  }

  Widget data(
      BuildContext context,
      SplayTreeSet<Tricount> tricounts,
      WidgetRef ref,
      { bool isLoading = false, }
  )
  {
  final myTricountsNotifier = ref.read(tricountListProvider.notifier);
  final user = ref.read(securityProvider).value;
  var deletedTricounts = tricounts.where((t) => t.deleteAt != null);
  deletedTricounts = deletedTricounts.toList()..sort((a,b) => b.deleteAt!.compareTo(a.deleteAt!));

  if (!user!.isAdmin) { // on est pas admin
    deletedTricounts = deletedTricounts.where((t) => t.creator == user);
  }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: ListView(
              children: [
                if (deletedTricounts.isEmpty)
                  ListTile(
                    title: Text('No deleted tricounts!'),
                  ),
                for (final tricount in deletedTricounts)
                  ListTile(
                    title: Text(tricount.title),
                    subtitle: Text('deleted on ${tricount.deleteAt!.day}/${tricount.deleteAt!.month}/${tricount.deleteAt!.year} ${tricount.deleteAt!.hour}:${tricount.deleteAt!.minute}:${tricount.deleteAt!.second}'),
                    trailing: IconButton(
                      icon: Icon(Icons.undo),
                      tooltip: "Undelete",
                      onPressed: () {
                        myTricountsNotifier.restoreTricount(tricount);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
