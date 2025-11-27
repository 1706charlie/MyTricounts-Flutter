import 'dart:collection';
import 'dart:convert';
import 'package:prbd_2425_a08/models/repartition.dart';
import 'package:prbd_2425_a08/models/user.dart';
import 'package:prbd_2425_a08/models/user_balance.dart';
import '/core/services/api_client.dart';
import 'operation.dart';

class Tricount implements Comparable<Tricount> {
  final int id;
  final String title;
  final String? description;
  final User creator;
  final DateTime createdAt;
  DateTime? deleteAt;

  final SplayTreeSet<User> participants;
  final SplayTreeSet<Operation> operations;

  Tricount({
    required this.id,
    required this.title,
    this.description,
    required this.creator,
    required this.createdAt,
    this.deleteAt,
    required this.participants,
    required this.operations,
  });

  int get friendsCount => participants.length - 1;

  bool isCreator(User user) {
    return creator == user;
  }

  // Impliqué dans une dépense ?
  // (initiateur OU présent dans au moins une répartition)
  bool isInvolved(User user) {
    for (final operation in operations) { // Parcours de toutes les dépenses du tricount

      // Le user est-il l’initiateur de la dépense ?
      if (operation.initiator == user) return true;

      // Le user est-il impliqué dans une répartition ?
      for (final repartition in operation.repartitions) { // Parcours des répartitions de cette dépense
        if (repartition.user == user) return true;
      }
    }

    return false; // l'utilisateur n'est pas impliqué
  }

  bool canRemoveParticipant(User user) {
    return !isCreator(user) && !isInvolved(user);
  }



  /* -----------------------------------------------------------------------
   * Conversion JSON vers Objet Tricount
   * --------------------------------------------------------------------- */

  factory Tricount.fromJson(Map<String, dynamic> json) {
    final rawParticipants = json['participants'] as List<dynamic>;              // raw en français signifie "brut" // liste de participants au format JSON // Chaque element de la liste represente un participant sous forme de dictionnaire
    final rawOperations = json['operations'] as List<dynamic>;

    final participants = SplayTreeSet<User>.from(
      rawParticipants.map((e) => User.fromJson(e as Map<String, dynamic>)),
    );

    final creatorId = json['creator'] as int;
    final creator = participants.firstWhere((u) => u.id == creatorId);

    final operations = SplayTreeSet<Operation>.from(
      rawOperations.map((e) => Operation.fromJson(e as Map<String, dynamic>, participants)),
    );


    return Tricount(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      creator: creator,
      createdAt: DateTime.parse(json['created_at'] as String),
      deleteAt: json['delete_at'] != null ? DateTime.parse(json['delete_at'] as String) : null,
      participants: participants,
      operations: operations,
    );
  }

  /* -----------------------------------------------------------------------
   * Appel endpoint : get my tricounts
   * --------------------------------------------------------------------- */

  static Future<List<Tricount>> getMyTricounts() async {
    final response = await ApiClient.get('get_my_tricounts');
    if (response.statusCode != 200) {
      throw Exception('Failed to get tricounts (status ${response.statusCode})');
    }

    final List<dynamic> body = json.decode(response.body) as List<dynamic>;
    return body
        .map((dynamic item) => Tricount.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /* -----------------------------------------------------------------------
   * Appel endpoint : get tricount balance
   * --------------------------------------------------------------------- */

  Future<List<UserBalance>> getUserBalances() async {
    final response = await ApiClient.post(
      'get_tricount_balance',
      body: json.encode({
        'tricount_id': id
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to get tricount balance (status ${response.statusCode})');
    }

    final List<User> users = participants.toList();

    final List<dynamic> body = json.decode(response.body) as List<dynamic>;
    return body
          .map((dynamic item) => UserBalance.fromJson(item as Map<String, dynamic>, users))
          .toList();
  }

  /* -----------------------------------------------------------------------
   * Appel endpoint : save tricount
   * --------------------------------------------------------------------- */

  static Future<Tricount> saveTricount(int id, String title, String description, SplayTreeSet<User> participants) async {
    final response = await ApiClient.post(
      'save_tricount',
      body: json.encode({
        'id': id,
        'title': title.trim(),
        'description': description.trim().isEmpty ? null : description.trim(),
        'participants': participants.map((u) => u.id).toList(), // on convertit en liste d'ids pour l'envoi
      }),
    );
    if (response.statusCode == 200) {
      return Tricount.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to save tricount');
    }
  }

  /* -----------------------------------------------------------------------
   * Appel endpoint : delete tricount
   * --------------------------------------------------------------------- */

  Future<void> deleteTricount() async {
    final response = await ApiClient.post(
      'delete_tricount',
      body: json.encode({'tricount_id': id}),
    );
    print(response.body);
    if (response.statusCode != 204) {
      throw Exception('Failed to delete tricount');
    }
  }

  /* -----------------------------------------------------------------------
   * Appel endpoint : restore tricount
   * --------------------------------------------------------------------- */

  Future<void> restoreTricount() async {
    final response = await ApiClient.post(
      'restore_tricount',
      body: json.encode({'tricount_id': id}),
    );
    print(response.body);
    if (response.statusCode != 204) {
      throw Exception('Failed to delete tricount');
    }
  }

  /* -----------------------------------------------------------------------
   * Appel endpoint : save operation
   * --------------------------------------------------------------------- */

  Future<Operation?> saveOperation(int id, String title, double amount, DateTime operationDate, User initiator, SplayTreeSet<Repartition> repartitions) async {
    final response = await ApiClient.post(
      'save_operation',
      body: json.encode({
        'id': id,
        'title': title.trim(),
        'amount': amount,
        'operation_date': operationDate.toIso8601String().split('T').first,
        'tricount_id': this.id,
        'initiator': initiator.id,
        'repartitions':
            [
              for (final repartition in repartitions)
                {'user': repartition.user.id, 'weight': repartition.weight},
            ],
      }),
    );

    if (response.statusCode == 200) {
      return Operation.fromJson(json.decode(response.body), participants);
    } else {
      throw Exception('Failed to save operation');
    }
  }

  /* -----------------------------------------------------------------------
   * Appel endpoint : delete operation
   * --------------------------------------------------------------------- */

  Future<void> deleteOperation(Operation operation) async {
    final response = await ApiClient.post(
      'delete_operation',
      body: json.encode({'id': operation.id}),
    );
    if (response.statusCode != 204) {
      throw Exception('Failed to delete operation');
    }

    // mise à jour du modèle
    operations.remove(operation); // operations.removeWhere((op) => op == operation); // fait la même chose
  }


/* -------------------------------------------------------------
 * Egalite / tri – par `createdAt` puis id
 * ----------------------------------------------------------- */

  @override // hashCode
  int get hashCode => id.hashCode;

  @override // equals
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Tricount && runtimeType == other.runtimeType && id == other.id;


  /* -------------------------
   * comparte to
   * -------------------- */

    /* "Les tricounts doivent être triés par ordre décroissant de date de leur dernière opération.
    S'il y a plusieurs opérations ayant la même date la plus récente,
    le tri doit se faire par ordre décroissant d'identifiant d'opération.
    Si un tricount n'a pas d'opération, le tri doit se faire sur la date/heure de création du tricount." */

  // Renvoie l’opération la plus récente d’un set,
  // si  même date : renvoie l'opération avec l'id le plus grand
  Operation? _latestOperation(SplayTreeSet<Operation> operations) {
    if (operations.isEmpty) return null;

    return operations.reduce((a, b) {
      if (a.createdAt.isAfter(b.createdAt)) return a;
      if (a.createdAt.isBefore(b.createdAt)) return b;
      // même date : on garde celle qui a le plus grand id
      return a.id > b.id ? a : b;
    });
  }

  @override
  int compareTo(Tricount other) {
    // on extrait la dernière opération (ou null)
    final Operation? lastOperation      = _latestOperation(operations);
    final Operation? otherLastOperation = _latestOperation(other.operations);

    // on détermine la date à comparer
    final DateTime operationDate      = lastOperation?.createdAt      ?? createdAt;
    final DateTime otherOperationDate = otherLastOperation?.createdAt ?? other.createdAt;

    // ----- date décroissante -----
    final int dateCmp = otherOperationDate.compareTo(operationDate); // décroissant
    if (dateCmp != 0) return dateCmp;

    // ----- id d'opération décroissant -----
    if (lastOperation != null && otherLastOperation != null) {
      final int opIdCmp = otherLastOperation.id.compareTo(lastOperation.id); // décroissant
      if (opIdCmp != 0) return opIdCmp;
    }

    // sinon...
    // ----- id de tricount décroissant -----
    return other.id.compareTo(id); // décroissant
  }


}




class TricountValidator {
  // le titre doit être disponible
  static Future<String?> validateTricountUnicity({
    String? title,
    required int tricountId,
  }) async {
    var res = await checkTitleAvailable(
      title: title?.trim(),
      tricountId: tricountId,
    );
    return res ? null : 'not available';
  }

  static Future<bool> checkTitleAvailable({
    String? title,
    required int tricountId,
  }) async {
    final response = await ApiClient.post(
      'check_tricount_title_available',
      body: json.encode({
        'title': title,
        'tricount_id': tricountId,
      }),
      anonymous: false,
    );
    final dynamic body = json.decode(response.body);
    if (response.statusCode != 200) {
      throw Exception('Failed to validate tricout title\n\n${body['message']}');
    }
    return body;
  }

  // le titre doit être present et avoir minimum 3 characters
  static String? validateTitle(String? title) {
    if (title == null || title.isEmpty) {
      return 'required';
    } else if (title.trim().length < 3) {
      return 'minimum 3 characters';
    } else {
      return null;
    }
  }

  // la description si presente doit avoir minimum 3 characters
  static String? validateDescription(String? description) {
    if (description == null || description.isEmpty) {
      return null;
    }

    if (description.trim().length < 3) {
      return 'minimum 3 characters';
    }

    return null;
  }
}