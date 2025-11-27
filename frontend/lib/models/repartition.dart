import 'user.dart';

class Repartition implements Comparable<Repartition> {
  final User user;
  final int weight;

  Repartition({
    required this.user,
    required this.weight,
  });

  /* -----------------------------------------------------------------------
   * Conversion JSON vers Objet Repartition
   * --------------------------------------------------------------------- */
  factory Repartition.fromJson(Map<String, dynamic> json, Set<User> participants,) {
    final userId = json['user'] as int;
    final user = participants.firstWhere((u) => u.id == userId,);

    return Repartition(
      user: user,
      weight: json['weight'] as int,
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
          other is Repartition && user == other.user;

  @override // compareTo
  int compareTo(Repartition other) =>
      user.fullName.compareTo(other.user.fullName);

}
