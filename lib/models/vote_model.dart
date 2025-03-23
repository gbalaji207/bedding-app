// lib/models/vote_model.dart
class Vote {
  final String id;
  final String userId;
  final String matchId;
  final String vote; // team1 or team2
  final String status; // new, won, lost
  final double points;

  Vote({
    required this.id,
    required this.userId,
    required this.matchId,
    required this.vote,
    required this.status,
    this.points = 0,
  });

  // Factory constructor to create a Vote from JSON data
  factory Vote.fromJson(Map<String, dynamic> json) {
    return Vote(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      matchId: json['match_id'] as String,
      vote: json['vote'] as String,
      status: json['status'] as String,
      points: json['points'] as double? ?? 0,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'match_id': matchId,
      'vote': vote,
      'status': status,
      'points': points,
    };
  }

  // Create a new vote
  factory Vote.createNew({
    required String id,
    required String userId,
    required String matchId,
    required String vote,
  }) {
    return Vote(
      id: id,
      userId: userId,
      matchId: matchId,
      vote: vote,
      status: 'new',
      points: 0,
    );
  }

  // Create a copy of this Vote with some updated fields
  Vote copyWith({
    String? vote,
    String? status,
    double? points,
  }) {
    return Vote(
      id: this.id,
      userId: this.userId,
      matchId: this.matchId,
      vote: vote ?? this.vote,
      status: status ?? this.status,
      points: points ?? this.points,
    );
  }
}
