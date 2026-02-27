import 'package:flutter/material.dart';
import '../services/study_group_service.dart';
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
  static const Color backgroundLight = Color(0xFFF9FAFB);

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
    try {
      final studyGroups = await StudyGroupService.getMyStudyGroups();

      // Convert study groups to chat items with mock data
      final chats = studyGroups.asMap().entries.map((entry) {
        final index = entry.key;
        final sg = entry.value;
        return ChatItem(
          id: sg.id,
          name: sg.name,
          lastMessage: _getMockLastMessage(index),
          timestamp: _getMockTimestamp(index),
          memberCount: sg.currentMembers ?? 2,
          hasUnread: index == 0, // First chat has unread
          colorIndex: index % pastelColors.length,
        );
      }).toList();

      setState(() {
        _chats = chats;
        _filteredChats = chats;
        _loading = false;
      });
    } catch (e) {
      // Use demo data if API fails
      setState(() {
        _chats = _getDemoChats();
        _filteredChats = _chats;
        _loading = false;
      });
    }
  }

  List<ChatItem> _getDemoChats() {
    return [
      ChatItem(
        id: '1',
        name: 'CS101 Final Prep',
        lastMessage:
            "Let's meet at the library at 5 PM tomorrow for the review session.",
        timestamp: '2m ago',
        memberCount: 4,
        hasUnread: true,
        colorIndex: 0,
      ),
      ChatItem(
        id: '2',
        name: 'Intro to Psychology',
        lastMessage: 'I found a great summary for Chapter 4!',
        timestamp: '1h ago',
        memberCount: 3,
        hasUnread: false,
        colorIndex: 1,
      ),
      ChatItem(
        id: '3',
        name: 'Calculus II Buddies',
        lastMessage: 'Sarah: Does anyone understand the chain rule part?',
        timestamp: 'Yesterday',
        memberCount: 2,
        hasUnread: false,
        colorIndex: 2,
      ),
      ChatItem(
        id: '4',
        name: 'Art History Discussion',
        lastMessage: 'The Renaissance quiz was actually pretty easy.',
        timestamp: 'Tue',
        memberCount: 4,
        hasUnread: false,
        colorIndex: 3,
      ),
    ];
  }

  String _getMockLastMessage(int index) {
    final messages = [
      "Let's meet at the library at 5 PM tomorrow!",
      'I found a great summary for Chapter 4!',
      'Does anyone understand this part?',
      'The quiz was actually pretty easy.',
    ];
    return messages[index % messages.length];
  }

  String _getMockTimestamp(int index) {
    final timestamps = ['2m ago', '1h ago', 'Yesterday', 'Tue'];
    return timestamps[index % timestamps.length];
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
        onPressed: () {
          // TODO: Create new chat/group
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
      onTap: () {
        // TODO: Navigate to chat screen
      },
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
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
          const SizedBox(height: 8),
          // Home indicator
          Container(
            width: 128,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(3),
            ),
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
  final String name;
  final String lastMessage;
  final String timestamp;
  final int memberCount;
  final bool hasUnread;
  final int colorIndex;

  ChatItem({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.timestamp,
    required this.memberCount,
    required this.hasUnread,
    required this.colorIndex,
  });
}
