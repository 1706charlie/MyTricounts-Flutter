import 'dart:collection';
import 'package:intl/intl.dart';
import 'package:prbd_2425_a08/models/repartition.dart';
import 'package:prbd_2425_a08/models/user.dart';

class Operation implements Comparable<Operation> { // Operation = depense
  final int id;
  final String title;
  final double amount;
  final User initiator;
  final DateTime operationDate;
  final DateTime createdAt;

  final SplayTreeSet<Repartition> repartitions;

  Operation({
    required this.id,
    required this.title,
    required this.amount,
    required this.initiator,
    required this.operationDate,
    required this.createdAt,
    required this.repartitions,
  });

  /* -----------------------------------------------------------------------
   * Conversion JSON vers Objet Operation
   * --------------------------------------------------------------------- */

  factory Operation.fromJson(
      Map<String, dynamic> json,
      Set<User> participants,
  ) {
    final initiatorId = json['initiator'] as int;
    final initiator = participants.firstWhere((u) => u.id == initiatorId);
    final rawRepartitions = json['repartitions'] as List<dynamic>? ?? [];
    final repartitions = SplayTreeSet<Repartition>.from(
      rawRepartitions.map(
          (e) => Repartition.fromJson(e as Map<String, dynamic>, participants),
      ),
    );

    return Operation(
      id: json['id'] as int,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      initiator: initiator,
      operationDate: DateTime.parse(json['operation_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      repartitions: repartitions,
    );
  }

  /* -------------------------------------------------------------
   * egalite / tri – par `createdAt` puis id
   * ----------------------------------------------------------- */

  @override // hashCode
  int get hashCode => id.hashCode;

  @override // equals
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Operation && runtimeType == other.runtimeType && id == other.id;

  @override // compareTo
  int compareTo(Operation other) {
    // date d’opération DESC, puis id DESC
    final cmp = other.operationDate.compareTo(operationDate);
    return cmp != 0 ? cmp : other.id.compareTo(id);
  }


}

class OperationValidator {
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

  // le montant doit être present et au moins 0.01
  static String? validateAmount(String? value) {
    final amount = double.tryParse(value ?? '');
    if (amount == null) {
      return 'required';
    } else if (amount < 0.01) {
      return 'minimum 0.01 €';
    } else {
      return null;
    }
  }

  // validation de la date d’opération
  static String? validateDate(String? text, DateTime tricountCreatedAt) {
    if (text == null || text.isEmpty) return 'dd/MM/yyyy';
    final date = _tryParseDate(text);
    if (date == null) return 'dd/MM/yyyy';
    if (date.isBefore(tricountCreatedAt)) return 'may not be before the tricount creation date';
    if (date.isAfter(DateTime.now())) return 'may not be in the future';
    return null;
  }
  
  static DateTime? tryParseDate(String text) => _tryParseDate(text);
  
  static DateTime? _tryParseDate(String text) {
    try {
      return DateFormat('dd/MM/yyyy').parseStrict(text);
    } catch (_) {
      return null;
    }
  }

}
