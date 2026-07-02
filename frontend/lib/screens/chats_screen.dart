import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/chat_service.dart';
import '../services/study_group_service.dart';
import '../theme/app_theme.dart';
import 'chat_room_screen.dart';

class ChatsScreen extends StatefulWidget {
  final String? initialGroupId;
  final void Function(String?) onGroupSelected;
  final VoidCallback onGroupsChanged;

  const ChatsScreen({
    super.key,
    this.initialGroupId,
    required this.onGroupSelected,
    required this.onGroupsChanged,
  });

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  List<_ChatItem> _chats = [];
  bool _loading = true;
  String? _selectedGroupId;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  static const _pastelColors = AppColors.avatarPalette;

  @override
  void initState() {
    super.initState();
    _selectedGroupId = widget.initialGroupId;
    _loadChats();
  }

  @override
  void didUpdateWidget(ChatsScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialGroupId != old.initialGroupId &&
        widget.initialGroupId != null) {
      setState(() => _selectedGroupId = widget.initialGroupId);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadChats() async {
    setState(() => _loading = true);
    final userId = context.read<AuthProvider>().user?.id;
    try {
      final results = await Future.wait([
        StudyGroupService.getMyStudyGroups(),
        ChatService.getRooms(),
      ]);
      final groups = results[0] as List;
      final rooms = results[1] as List<Map<String, dynamic>>;
      final roomMap = <String, Map<String, dynamic>>{
        for (final r in rooms) r['group_id'] as String: r,
      };

      final chats = groups.asMap().entries.map((e) {
        final i = e.key;
        final sg = e.value;
        final room = roomMap[sg.id];
        return _ChatItem(
          groupId: sg.id,
          roomId: room?['id'] as String?,
          name: sg.name,
          lastMessageAt: room?['last_message_at'] as String?,
          memberCount: sg.currentMembers ?? 1,
          maxMembers: sg.maxMembers,
          colorIndex: i % _pastelColors.length,
          isAdmin: sg.adminId == userId,
        );
      }).toList();

      chats.sort((a, b) {
        if (a.lastMessageAt == null && b.lastMessageAt == null) return 0;
        if (a.lastMessageAt == null) return 1;
        if (b.lastMessageAt == null) return -1;
        return b.lastMessageAt!.compareTo(a.lastMessageAt!);
      });

      if (mounted) setState(() { _chats = chats; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_ChatItem> get _filtered {
    if (_searchQuery.isEmpty) return _chats;
    final q = _searchQuery.toLowerCase();
    return _chats.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  _ChatItem? get _selectedChat =>
      _chats.where((c) => c.groupId == _selectedGroupId).firstOrNull;

  void _selectChat(String groupId) {
    setState(() => _selectedGroupId = groupId);
    widget.onGroupSelected(groupId);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 300, child: _buildList()),
        Container(width: 1, color: AppColors.border),
        Expanded(child: _buildRoomPanel()),
      ],
    );
  }

  Widget _buildList() {
    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          _buildListHeader(),
          _buildSearchBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
                : _filtered.isEmpty
                    ? _buildEmptyList()
                    : ListView.builder(
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) => _ChatRow(
                          item: _filtered[i],
                          isSelected: _filtered[i].groupId == _selectedGroupId,
                          onTap: () => _selectChat(_filtered[i].groupId),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildListHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        children: [
          const Text('Chats', style: AppText.headingMedium),
          const Spacer(),
          IconButton(
            onPressed: _loadChats,
            icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.textMuted),
            tooltip: 'Refresh',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            const SizedBox(width: 10),
            const Icon(Icons.search, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Search groups...',
                  hintStyle: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyList() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text('No chats yet', style: AppText.headingSmall),
            const SizedBox(height: 6),
            const Text(
              'Join a study group to start chatting',
              style: AppText.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomPanel() {
    final chat = _selectedChat;
    if (chat == null || chat.roomId == null) {
      return _buildEmptyRoom();
    }

    return ChatRoomScreen(
      key: ValueKey(chat.roomId),
      roomId: chat.roomId!,
      groupId: chat.groupId,
      groupName: chat.name,
      memberCount: chat.memberCount,
      isAdmin: chat.isAdmin,
      isEmbedded: true,
      onLeft: () {
        setState(() => _selectedGroupId = null);
        _loadChats();
        widget.onGroupsChanged();
      },
    );
  }

  Widget _buildEmptyRoom() {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64, height: 64,
              decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
              child: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary, size: 30),
            ),
            const SizedBox(height: 20),
            const Text('Select a chat', style: AppText.headingMedium),
            const SizedBox(height: 8),
            const Text('Choose a study group from the list to start chatting.', style: AppText.bodyMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─── Chat row in the list panel ───────────────────────────────────────────────

class _ChatRow extends StatefulWidget {
  final _ChatItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChatRow({required this.item, required this.isSelected, required this.onTap});

  @override
  State<_ChatRow> createState() => _ChatRowState();
}

class _ChatRowState extends State<_ChatRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.avatarPalette[widget.item.colorIndex];

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          color: widget.isSelected
              ? AppColors.primaryLight
              : _hovered
                  ? AppColors.background
                  : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: palette[0],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    widget.item.name.substring(0, 1).toUpperCase(),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette[1]),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: widget.isSelected ? AppColors.primary : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.item.lastMessageAt != null
                          ? '${widget.item.memberCount} members · ${_fmtRelative(widget.item.lastMessageAt!)}'
                          : '${widget.item.memberCount} members',
                      style: AppText.bodySmall.copyWith(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (widget.item.isAdmin)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Admin',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _fmtRelative(String iso) {
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${(diff.inDays / 7).floor()}w ago';
}

// ─── Internal data class ──────────────────────────────────────────────────────

class _ChatItem {
  final String groupId;
  final String? roomId;
  final String name;
  final String? lastMessageAt;
  final int memberCount;
  final int maxMembers;
  final int colorIndex;
  final bool isAdmin;

  const _ChatItem({
    required this.groupId,
    this.roomId,
    required this.name,
    this.lastMessageAt,
    required this.memberCount,
    required this.maxMembers,
    required this.colorIndex,
    required this.isAdmin,
  });
}
