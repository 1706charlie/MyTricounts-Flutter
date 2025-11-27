import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prbd_2425_a08/core/widgets/dialog_box.dart';
import 'package:prbd_2425_a08/models/security.dart';
import 'package:prbd_2425_a08/models/tricount.dart';
import 'package:prbd_2425_a08/providers/current_tricount_provider.dart';
import 'package:prbd_2425_a08/providers/security_provider.dart';
import 'package:prbd_2425_a08/providers/tricount_list_provider.dart';
import 'package:prbd_2425_a08/providers/theme_mode_provider.dart';
import 'package:prbd_2425_a08/views/widgets/data_error_widget.dart';


class MyHomePage extends ConsumerWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // securityProvider --> le when est déja géré dans login
    ref.watch(securityProvider);
    final securityNotifier = ref.read(securityProvider.notifier);

    // myTricountsProvider --> il faut gérer le when
    final myTricountsAsyncState = ref.watch(tricountListProvider);
    final myTricountsNotifier = ref.read(tricountListProvider.notifier);

    // currentTricountProvider --> pas de gestion du when car changeNotifierProvider
    final currentTricountNotifier = ref.read(currentTricountProvider.notifier);

    final user = ref.read(securityProvider).value;

    final themeNotifier = ref.read(themeModeProvider.notifier);
    final isDark       = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Scaffold(
      /* ---------------------- APP BAR ---------------------- */
      appBar: AppBar(
        backgroundColor: Colors.blue,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('Your tricounts',
            style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => myTricountsNotifier.refresh(),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(context, '/add_tricount');
            },
          ),

          const SizedBox(width: 4),
        ],
      ),

      /* ---------------------- DRAWER ----------------------- */
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.blue),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(user != null ? user.fullName : '', // user peut passer à null lorsqu'on clique sur logout (permet d'éviter une page d'erreur)
                      style:
                      const TextStyle(color: Colors.white, fontSize: 16)),
                  Text(user != null ? user.email : '',
                      style:
                      const TextStyle(color: Colors.white, fontSize: 13)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('My deleted tricounts'),
              onTap: () {
                Navigator.pushNamed(context, '/delete_tricounts');
              },
            ),
            ListTile(
              leading: Icon(
                Icons.dark_mode,
                color: isDark ? Colors.grey : Colors.grey,
              ),
              title: Text(isDark ? 'Switch to Light Mode'
                  : 'Switch to Dark Mode'),
              onTap: () => themeNotifier.toggle(),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/login');
                securityNotifier.logout();
              },
            ),
            ListTile(
              leading: const Icon(Icons.recycling),
              title: const Text('Reset Database'),
              onTap: () async {
                final action = await DialogBox(
                  title: 'Confirmation',
                  message: 'Are you sure you want to reset the database?',
                  actions: const ['Yes', 'No'],
                ).show(context);

                if (action == 'Yes') {
                  try {
                    await Security.resetDatabase();
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, '/login');
                      securityNotifier.logout();
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Reset failed: $e')),
                      );
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),

      /* ---------------------- BODY ------------------------- */
      body: myTricountsAsyncState.when(
        data: (tricounts) => data(context, tricounts, currentTricountNotifier, isLoading: false),
        loading: () => data(context, myTricountsAsyncState.value ?? SplayTreeSet(), currentTricountNotifier, isLoading: true),
        error: (err, stackTrace) => DataErrorWidget(error: err, stackTrace: stackTrace, notifier: myTricountsNotifier,
        ),
      ),
    );
  }

  Widget data(
    BuildContext context,
    SplayTreeSet<Tricount> tricounts,
    CurrentTricount currentTricountNotifier,
    { bool isLoading = false, }
  ){

    if (tricounts.isEmpty) {
      return Center(
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(horizontal: 32),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No tricounts yet!',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Create your first tricount now!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/add_tricount');
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)
                  ),
                  child: const Text('Create tricount'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // -------- liste des tricounts ------------------------------------------
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            for (final tricount in tricounts)
              if (tricount.deleteAt == null)
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      currentTricountNotifier.select(tricount); // selection d’un tricount existant
                      Navigator.pushNamed(context, '/view_tricount');
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(tricount.title,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                              ),
                              Text(
                                tricount.friendsCount == 0
                                    ? "you're alone"
                                    : 'with ${tricount.friendsCount} '
                                    '${tricount.friendsCount == 1 ? 'friend' : 'friends'}',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tricount.description?.isNotEmpty == true
                                ? tricount.description!
                                : 'No description',
                            style: TextStyle(
                                fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('by ${tricount.creator.fullName}',
                              style: TextStyle(fontSize: 14)
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ),
        if (isLoading)
          const Center(child: CircularProgressIndicator(color: Colors.black)),
      ],
    );
  }
}