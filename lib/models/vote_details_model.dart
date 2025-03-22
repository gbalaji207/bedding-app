// lib/models/vote_details_model.dart
import 'package:voting_app/models/user_profile.dart';
import 'package:voting_app/models/vote_model.dart';

class VoteDetails {
  final Vote vote;
  final UserProfile? userProfile;

  VoteDetails({
    required this.vote,
    this.userProfile,
  });

  String get displayName => userProfile?.displayName ?? vote.userId;
}