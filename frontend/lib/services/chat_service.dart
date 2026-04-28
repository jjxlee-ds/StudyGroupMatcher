import 'dart:convert';
import '../models/chat_message.dart';
import 'api_client.dart';

class ChatService {
  static Future<List<Map<String, dynamic>>> getRooms() async {
    final res = await ApiClient.get('/rooms');
    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    }
    throw Exception('Failed to load rooms (${res.statusCode})');
  }

  static Future<Map<String, dynamic>> createRoom(String groupId) async {
    final res = await ApiClient.post('/rooms', body: {'group_id': groupId});
    if (res.statusCode == 201 || res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to create room (${res.statusCode})');
  }

  static Future<List<ChatMessage>> getMessages(
    String roomId, {
    int limit = 50,
    String? before,
  }) async {
    var path = '/rooms/$roomId/messages?limit=$limit';
    if (before != null) path += '&before=$before';

    final res = await ApiClient.get(path);
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);
      return data.map((e) => ChatMessage.fromJson(e)).toList();
    }
    throw Exception('Failed to load messages (${res.statusCode})');
  }
}
