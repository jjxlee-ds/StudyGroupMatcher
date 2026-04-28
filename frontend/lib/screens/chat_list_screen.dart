import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/chat_service.dart';
import '../services/study_group_service.dart';
import 'chat_room_screen.dart';
import 'create_group_screen.dart';
import 'profile_screen.dart';
import 'calendar_screen.dart';
import 'home_screen.dart';
import 'recommendation_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  static const Color primaryColor = Color(0xFF57068C);
  static const Color backgroundLight = Colors.white;

  // Pastel colors for avatars
  static const List<Map<String, Color>> pastelColors = [
    {'bg': Color(0xFFE0F2FE), 'text': Color(0xFF0369A1)}, // Blue
    {'bg': Color(0xFFFFEDD5), 'text': Color(0xFFC2410C)}, // Peach
    {'bg': Color(0xFFDCFCE7), 'text': Color(0xFF15803D)}, // Green
    {'bg': Color(0xFFF3E8FF), 'text': Color(0xFF7E22CE)}, // Lavender
  ];

  final TextEditingController _searchController = TextEditingController();
  List<ChatItem> _chats = [];
  List<ChatItem> _filteredChats = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadChats() async {
    setState(() => _loading = true);
    // Read user ID before any await to avoid BuildContext across async gap
    final currentUserId =
        Provider.of<AuthProvider>(context, listen: false).user?.id;
    try {
      final results = await Future.wait([
        StudyGroupService.getMyStudyGroups(),
        ChatService.getRooms(),
      ]);

      final studyGroups = results[0] as List;
      final rooms = results[1] as List<Map<String, dynamic>>;

      // group_id → room 전체 매핑
      final roomMap = <String, Map<String, dynamic>>{
        for (final r in rooms) r['group_id'] as String: r,
      };

      final chats = studyGroups.asMap().entries.map((entry) {
        final index = entry.key;
        final sg = entry.value;
        final room = roomMap[sg.id];
        final lastMessageAt = room?['last_message_at'] as String?;
        return ChatItem(
          id: sg.id,
          roomId: room?['id'] as String?,
          name: sg.name,
          lastMessage: lastMessageAt != null ? 'Tap to continue the conversation' : 'No messages yet',
          timestamp: lastMessageAt != null ? _formatTimestamp(lastMessageAt) : '',
          memberCount: sg.currentMembers ?? 1,
          hasUnread: false,
          colorIndex: index % pastelColors.length,
          isAdmin: sg.adminId != null && sg.adminId == currentUserId,
        );
      }).toList();

      setState(() {
        _chats = chats;
        _filteredChats = chats;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _chats = [];
        _filteredChats = [];
        _loading = false;
      });
    }
  }

  Future<void> _openChat(ChatItem chat) async {
    String? roomId = chat.roomId;

    if (roomId == null) {
      try {
        final room = await ChatService.createRoom(chat.id);
        roomId = room['id'] as String;
        _loadChats(); // refresh list
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to open chat: $e'), backgroundColor: Colors.red),
          );
        }
        return;
      }
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            roomId: roomId!,
            groupId: chat.id,
            groupName: chat.name,
            memberCount: chat.memberCount,
            isAdmin: chat.isAdmin,
          ),
        ),
      );
    }
  }


  String _formatTimestamp(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.month}/${dt.day}';
    } catch (_) {
      return '';
    }
  }

  void _filterChats(String query) {
    if (query.isEmpty) {
      setState(() => _filteredChats = _chats);
    } else {
      setState(() {
        _filteredChats = _chats
            .where((chat) =>
                chat.name.toLowerCase().contains(query.toLowerCase()) ||
                chat.lastMessage.toLowerCase().contains(query.toLowerCase()))
            .toList();
      });
    }
  }

  String _getInitials(String name) {
    final words = name.split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name.substring(0, 2).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: primaryColor))
                  : _buildChatList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
          );
          if (created == true) _loadChats();
        },
        backgroundColor: primaryColor,
        elevation: 8,
        child: const Icon(Icons.add_comment, color: Colors.white, size: 28),
      ),
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 16),
      color: backgroundLight.withAlpha(204),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(
            'Chats',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          GestureDetector(
            onTap: () {
              // TODO: Settings
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
              ),
              child: Icon(
                Icons.settings,
                size: 26,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade200.withAlpha(128),
          borderRadius: BorderRadius.circular(16),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _filterChats,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search chats...',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            prefixIcon: Icon(
              Icons.search,
              color: Colors.grey.shade400,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatList() {
    if (_filteredChats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No chats yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Join a study group to start chatting',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredChats.length,
      itemBuilder: (context, index) {
        return _buildChatCard(_filteredChats[index]);
      },
    );
  }

  Widget _buildChatCard(ChatItem chat) {
    final colors = pastelColors[chat.colorIndex];

    return GestureDetector(
      onTap: () => _openChat(chat),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colors['bg'],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _getInitials(chat.name),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors['text'],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          chat.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        chat.timestamp.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    chat.lastMessage,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Right side - member count & unread
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.group,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${chat.memberCount}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (chat.hasUnread) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(242),
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      padding: const EdgeInsets.only(left: 8, right: 8, top: 12, bottom: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            icon: Icons.auto_awesome,
            label: 'Recs',
            isActive: false,
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const RecommendationScreen()),
              );
            },
          ),
          _buildNavItem(
            icon: Icons.chat_bubble,
            label: 'Chatting',
            isActive: true,
            onTap: () {},
          ),
          _buildNavItem(
            icon: Icons.home_outlined,
            label: 'Home',
            isActive: false,
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            },
          ),
          _buildNavItem(
            icon: Icons.calendar_today,
            label: 'Calendar',
            isActive: false,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CalendarScreen()),
              );
            },
          ),
          _buildNavItem(
            icon: Icons.person_outline,
            label: 'Profile',
            isActive: false,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final color = isActive ? primaryColor : Colors.grey.shade400;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class ChatItem {
  final String id;
  final String? roomId;
  final String name;
  final String lastMessage;
  final String timestamp;
  final int memberCount;
  final bool hasUnread;
  final int colorIndex;
  final bool isAdmin;

  ChatItem({
    required this.id,
    this.roomId,
    required this.name,
    required this.lastMessage,
    required this.timestamp,
    required this.memberCount,
    required this.hasUnread,
    required this.colorIndex,
    this.isAdmin = false,
  });
}
