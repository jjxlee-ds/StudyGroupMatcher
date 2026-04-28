import 'dart:convert';
import '../models/meeting_proposal.dart';
import 'api_client.dart';

class MeetingService {
  static Future<List<MeetingProposal>> getProposals(String roomId) async {
    final res = await ApiClient.get('/meetings/proposals/$roomId');
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);
      return data
          .map((e) => MeetingProposal.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load proposals (${res.statusCode})');
  }

  static Future<void> vote(String proposalId, bool attend) async {
    final res = await ApiClient.post(
      '/meetings/votes',
      body: {'proposal_id': proposalId, 'vote': attend},
    );
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      throw Exception(body['detail'] ?? 'Vote failed');
    }
  }
}
