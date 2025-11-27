# Tests unitaires

Le fichier `_endpoints.dart` contient des fonctions qui permettent de faire des requêtes HTTP vers les differents endpoints de l'API. Lorsque vous aurez implemente les endpoints dans votre modèle, vous pourrez les tester en utilisant ces fonctions et supprimer ce fichier.

**Remarque** : L'accès concurrenciel à Hive n'est pas supporte. Il est donc necessaire de donner instruction à dart d'executer les tests de manière sequentielle. Pour ce faire, il suffit de rajouter le paramètre `--concurrency=1` à la commande flutter test dans la configuration.
