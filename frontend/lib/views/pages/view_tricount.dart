import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:prbd_2425_a08/models/tricount.dart';
import 'package:prbd_2425_a08/providers/current_tricount_provider.dart';
import 'package:prbd_2425_a08/providers/tricount_list_provider.dart';
import 'package:prbd_2425_a08/providers/security_provider.dart';
import '../../core/widgets/dialog_box.dart';


class ViewTricountPage extends ConsumerWidget {
  const ViewTricountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTricountProv = ref.watch(currentTricountProvider);
    final myTricountsProv = ref.watch(tricountListProvider.notifier);
    final tricount = currentTricountProv.tricount;
    final currentUser = ref.read(securityProvider).value;

    final myTotal = currentTricountProv.getMyTotal(currentUser!.id);
    final operations = tricount!.operations;
    final hasOperations = operations.isNotEmpty;

    return Scaffold(
      /* ---------------------- APP BAR ---------------------- */
      appBar: AppBar(
        backgroundColor: Colors.blue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
            tricount.title,
            style: TextStyle(color: Colors.white)),
        actions: [
          /* ---------------- Refresh --------------- */
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () async {
              // 1) rafraîchir la liste des tricounts
              await myTricountsProv.refresh();
              final tricounts = ref.read(tricountListProvider).value;
              if (tricounts == null) return;   // problème de chargement
              // 2) récupérer tricount courant rafraîchi
              Tricount? updatedTricount;
              for (final t in tricounts) {
                if (t.id == tricount.id) {
                  updatedTricount = t;  // on a trouvé le tricount courant rafraîchi
                  break;
                }
              }
              // 3) remplace la tricount courant avec le tricount rafraîchi
              if (updatedTricount != null) {
                ref.read(currentTricountProvider.notifier).select(updatedTricount); // va déclencher la reconstruction du widget
              }
            },
          ),
          /* ---------------- Edit ---------------- */
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(context, '/edit_tricount');
            },
          ),

          /* ---------------- Delete ---------------- */
          if (currentUser.isAdmin || tricount.isCreator(currentUser))
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: () async {
                final action = await DialogBox(
                  title: 'Confirm deletion',
                  message: 'Do you really want to delete this tricount ?',
                  actions: const ['Yes', 'No'],
                ).show(context);

                if (action == 'Yes') {
                  await myTricountsProv.deleteTricount(tricount);
                  if (context.mounted) {
                    Navigator.pushNamed(context, '/home');
                  }
                }
              },
            ),
        ],
      ),

      /* ---------------------- BODY ------------------------- */
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -------- View Balance Button ------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: hasOperations
                    ? () => Navigator.pushNamed(context, '/balance')
                    : null,
                icon: const Icon(Icons.compare_arrows_outlined),
                label: const Text("View Balance"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasOperations ? Colors.green : Colors.grey.shade300,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 25.0),
                ),
              ),
            ),
          ),
          if (tricount.friendsCount == 0 && operations.isEmpty)
          // -------- Card You' re alone ------------------------------------------
            Expanded(
              child: Center(
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 60),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("You' re alone",
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('Click below to add your friends!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/edit_tricount');
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)
                          ),
                          child: const Text('Add friends'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )

          else if (!hasOperations)
            // -------- Card Your tricount is empty ------------------------------------------
            Expanded(
              child: Center(
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 60),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Your tricount is empty!',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('Click below to add your first expense!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/add_operation');
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)
                          ),
                          child: const Text('Add an expense'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )

          // -------- liste des opérations ------------------------------------------
          else
            Expanded(
              child: ListView(
                children: [
                  for (final operation in operations)
                    Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                      child: ListTile(
                        title: Text(operation.title),
                        subtitle: Text("Paid by ${operation.initiator.fullName}"),
                        trailing: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("${operation.amount.toStringAsFixed(2)} €",
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(DateFormat('dd/MM/yyyy').format(operation.operationDate),
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/edit_operation',
                            arguments: operation,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),

      /* ---------------------- BOTTOM BAR ---------------------- */
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MY TOTAL',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '${myTotal.toStringAsFixed(2)} €',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 56),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'TOTAL EXPENSES',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '${tricount.operations.fold(0.0, (s, op) => s + op.amount).toStringAsFixed(2)} €',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/add_operation');
        },
        tooltip: 'Add an expense',
        backgroundColor: Colors.blue,
        foregroundColor:  Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size : 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );

  }
}