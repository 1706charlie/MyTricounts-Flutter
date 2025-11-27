import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prbd_2425_a08/core/tools/abstract_async_notifier.dart';

class DataErrorWidget extends ConsumerWidget {
  final Object error;
  final StackTrace? stackTrace;
  // AsyncNotifierProvider
  final AbstractAsyncNotifier? notifier;
  // FutureProvider
  final ProviderOrFamily? provider;

  const DataErrorWidget({
    required this.error,
    this.stackTrace,
    this.notifier,
    this.provider,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center( // centre le contenu horizontalement et verticalement
      child: Column( // colonne pour empiler les widgets verticalement
        mainAxisAlignment: MainAxisAlignment.center, // centre les widgets de la colonne verticalement
        children: [
          Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.red,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10), // espace entre le texte d'erreur et le bouton Retry
          ElevatedButton( // juste un texte
            onPressed: () {
              if (notifier != null) {
                notifier!.refresh(); // grâce à la classe abstraite, on peut appeler la methode refresh() qui est redefinie dans les enfants de cette classe
              } else if (provider != null) {
                ref.invalidate(provider!);      // ou ref.refresh(provider!)
              }
            },
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }
}