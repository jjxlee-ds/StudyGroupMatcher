class MeetingVote {
  final String userId;
  final bool vote;

  MeetingVote({required this.userId, required this.vote});

  factory MeetingVote.fromJson(Map<String, dynamic> json) => MeetingVote(
        userId: json['user_id'] as String,
        vote: json['vote'] as bool,
      );
}

class MeetingProposal {
  final String id;
  final String roomId;
  final String proposedBy;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final DateTime expiresAt;
  final bool isConfirmed;
  final int attendCount;
  final int totalMembers;
  final List<MeetingVote> votes;

  MeetingProposal({
    required this.id,
    required this.roomId,
    required this.proposedBy,
    required this.startTime,
    required this.endTime,
    this.location,
    required this.expiresAt,
    required this.isConfirmed,
    required this.attendCount,
    required this.totalMembers,
    required this.votes,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// 내 투표 결과 (null = 미투표)
  bool? myVote(String currentUserId) {
    for (final v in votes) {
      if (v.userId == currentUserId) return v.vote;
    }
    return null;
  }

  MeetingProposal copyWithVote(String userId, bool vote) {
    final updated = votes.where((v) => v.userId != userId).toList()
      ..add(MeetingVote(userId: userId, vote: vote));
    final newAttend = updated.where((v) => v.vote).length;
    return MeetingProposal(
      id: id,
      roomId: roomId,
      proposedBy: proposedBy,
      startTime: startTime,
      endTime: endTime,
      location: location,
      expiresAt: expiresAt,
      isConfirmed: isConfirmed,
      attendCount: newAttend,
      totalMembers: totalMembers,
      votes: updated,
    );
  }

  factory MeetingProposal.fromJson(Map<String, dynamic> json) {
    return MeetingProposal(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      proposedBy: json['proposed_by'] as String,
      startTime: DateTime.parse(json['start_time'] as String).toLocal(),
      endTime: DateTime.parse(json['end_time'] as String).toLocal(),
      location: json['location'] as String?,
      expiresAt: DateTime.parse(json['expires_at'] as String).toLocal(),
      isConfirmed: json['is_confirmed'] as bool,
      attendCount: json['attend_count'] as int? ?? 0,
      totalMembers: json['total_members'] as int? ?? 0,
      votes: (json['votes'] as List<dynamic>? ?? [])
          .map((e) => MeetingVote.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
