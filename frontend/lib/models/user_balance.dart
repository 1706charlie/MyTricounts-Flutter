import 'package:prbd_2425_a08/models/user.dart';

class UserBalance implements Comparable<UserBalance> {
  final User   user;
  final double paid;
  final double due;
  final double balance;

  UserBalance({
    required this.user,
    required this.paid,
    required this.due,
    required this.balance,
  });

  /* -----------------------------------------------------------------------
   * Conversion JSON vers Objet UserBalance
   * --------------------------------------------------------------------- */
  factory UserBalance.fromJson(Map<String, dynamic> json, List<User> users) {
    final userId = json['user'] as int;
    final user = users.firstWhere((u) => u.id == userId);

    return UserBalance(
      user:    user,
      paid:    (json['paid']    as num).toDouble(),
      due:     (json['due']     as num).toDouble(),
      balance: (json['balance'] as num).toDouble(),
    );
  }

  /* -------------------------------------------------------------
   *  Egalite / tri
   * ----------------------------------------------------------- */

  @override // hashCode
  int get hashCode => user.hashCode;

  @override // equals
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is UserBalance && runtimeType == other.runtimeType && user == other.user;

  @override // compareTo
  int compareTo(UserBalance other) => user.fullName.compareTo(other.user.fullName); // Tri alphabétique sur fullName
}