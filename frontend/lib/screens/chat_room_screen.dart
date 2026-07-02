import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/api_config.dart';
import '../models/chat_message.dart';
import '../models/meeting_proposal.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/chat_service.dart';
import '../services/meeting_service.dart';
import '../services/study_group_service.dart';

class ChatRoomScreen extends StatefulWidget {
  final String roomId;
  final String groupId;
  final String groupName;
  final int memberCount;
  final bool isAdmin;
  final bool isEmbedded;
  final VoidCallback? onLeft;

  const ChatRoomScreen({
    super.key,
    required this.roomId,
    required this.groupId,
    required this.groupName,
    required this.memberCount,
    this.isAdmin = false,
    this.isEmbedded = false,
    this.onLeft,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen>
    with TickerProviderStateMixin {
  static const Color primaryColor = Color(0xFF57068C);
  static const Color bubbleReceived = Color(0xFFF1F5F9);
  static const Color textReceived = Color(0xFF0F172A);

  final List<ChatMessage> _messages = [];
  final List<MeetingProposal> _proposals = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  WebSocketChannel? _channel;
  StreamSubscription? _wsSubscription;
  Map<String, String> _memberNames = {};
  bool _loading = true;
  bool _loadError = false;
  bool _sending = false;
  bool _someoneTyping = false;
  String _typingName = '';
  Timer? _typingTimer;
  final Set<String> _votingInProgress = {};

  late AnimationController _dot1, _dot2, _dot3;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _dot1 = _makeDotController(0);
    _dot2 = _makeDotController(160);
    _dot3 = _makeDotController(320);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _currentUserId =
          Provider.of<AuthProvider>(context, listen: false).user?.id;
      _loadHistory();
      _loadMembers();
      _connectWebSocket();
    });
  }

  AnimationController _makeDotController(int delayMs) {
    final ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) ctrl.repeat();
    });
    return ctrl;
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _channel?.sink.close();
    _inputController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _dot1.dispose();
    _dot2.dispose();
    _dot3.dispose();
    super.dispose();
  }

  // ─── Data ───────────────────────────────────────────────────────────────────

  Future<void> _loadMembers() async {
    try {
      final names = await StudyGroupService.getMemberNames(widget.groupId);
      if (mounted) setState(() => _memberNames = names);
    } catch (_) {
      // member names are supplemental — chat still works without them
    }
  }

  void _showGroupInfoPanel(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
        child: SizedBox(
          width: 420,
          child: _GroupInfoPanel(
            groupId: widget.groupId,
            groupName: widget.groupName,
            memberCount: widget.memberCount,
            isAdmin: widget.isAdmin,
            memberNames: _memberNames,
            onLeave: () {
              if (!widget.isEmbedded && mounted && Navigator.canPop(context)) {
                Navigator.pop(context);
              }
              widget.onLeft?.call();
            },
          ),
        ),
      ),
    );
  }

  Future<void> _loadHistory() async {
    if (mounted) setState(() { _loading = true; _loadError = false; });
    try {
      final results = await Future.wait([
        ChatService.getMessages(widget.roomId),
        MeetingService.getProposals(widget.roomId),
      ]);
      if (mounted) {
        setState(() {
          _messages.clear();
          _proposals.clear();
          _messages.addAll(results[0] as List<ChatMessage>);
          _proposals.addAll(results[1] as List<MeetingProposal>);
          _loading = false;
        });
        _scrollToBottom(jump: true);
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _loadError = true; });
    }
  }

  Future<void> _castVote(MeetingProposal proposal, bool attend) async {
    if (_votingInProgress.contains(proposal.id)) return;
    setState(() => _votingInProgress.add(proposal.id));

    // 낙관적 업데이트
    final idx = _proposals.indexWhere((p) => p.id == proposal.id);
    if (idx != -1 && _currentUserId != null) {
      setState(() =>
          _proposals[idx] = proposal.copyWithVote(_currentUserId!, attend));
    }

    try {
      await MeetingService.vote(proposal.id, attend);
    } catch (e) {
      final msg = e.toString();
      if (mounted) {
        if (msg.contains('already confirmed') || msg.contains('expired')) {
          // Proposal is no longer voteable — remove it from the list
          setState(() => _proposals.removeWhere((p) => p.id == proposal.id));
        } else {
          // Other errors: roll back optimistic update
          if (idx != -1) setState(() => _proposals[idx] = proposal);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _votingInProgress.remove(proposal.id));
    }
  }

  Future<void> _connectWebSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) return;

    final url = '${ApiConfig.wsBaseUrl}/ws/rooms/${widget.roomId}?token=$token';

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _wsSubscription = _channel!.stream.listen(
        _onWsMessage,
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onWsMessage(dynamic raw) {
    if (!mounted) return;
    final data = jsonDecode(raw as String) as Map<String, dynamic>;

    // 채팅 메시지
    if (data.containsKey('sender_id')) {
      final msg = ChatMessage.fromJson(data);
      setState(() => _messages.add(msg));
      _scrollToBottom();
      return;
    }

    // 투표 업데이트 — 카드 실시간 갱신
    if (data['type'] == 'vote_update') {
      _onVoteUpdate(data);
      return;
    }

    // 미팅 확정 — 카드 제거 + 다이얼로그
    if (data['type'] == 'meeting_confirmed') {
      _onMeetingConfirmed(data);
      return;
    }

    // 타이핑 이벤트 (서버 확장 시 활용)
    if (data['type'] == 'typing') {
      _showTypingIndicator(data['user_name'] as String? ?? '');
    }
  }

  void _showTypingIndicator(String name) {
    setState(() {
      _someoneTyping = true;
      _typingName = name;
    });
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _someoneTyping = false);
    });
  }

  void _scheduleReconnect() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _connectWebSocket();
    });
  }

  Future<void> _sendMessage() async {
    final content = _inputController.text.trim();
    if (content.isEmpty || _channel == null || _sending) return;

    setState(() => _sending = true);
    _inputController.clear();

    try {
      _channel!.sink.add(jsonEncode({'content': content}));
    } catch (_) {
      // reconnect on next attempt
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      if (jump) {
        _scrollController.jumpTo(max);
      } else {
        _scrollController.animateTo(
          max,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─── Snackbars / Dialogs ────────────────────────────────────────────────────

  void _onVoteUpdate(Map<String, dynamic> data) {
    if (!mounted) return;
    final proposalId = data['proposal_id'] as String;
    final attend = data['attend_count'] as int;
    final total = data['total_members'] as int;
    final rawVotes = data['votes'] as List<dynamic>? ?? [];

    final idx = _proposals.indexWhere((p) => p.id == proposalId);
    if (idx != -1) {
      final old = _proposals[idx];
      setState(() {
        _proposals[idx] = MeetingProposal(
          id: old.id,
          roomId: old.roomId,
          proposedBy: old.proposedBy,
          startTime: old.startTime,
          endTime: old.endTime,
          location: old.location,
          expiresAt: old.expiresAt,
          isConfirmed: old.isConfirmed,
          attendCount: attend,
          totalMembers: total,
          votes: rawVotes
              .map((e) => MeetingVote.fromJson(e as Map<String, dynamic>))
              .toList(),
        );
      });
    }
  }

  void _onMeetingConfirmed(Map<String, dynamic> data) {
    if (!mounted) return;
    final proposalId = data['proposal_id'] as String;
    setState(() {
      // 확정되지 않은 후보들만 제거
      _proposals.removeWhere((p) => p.id != proposalId);
      // 확정된 proposal isConfirmed → true 로 업데이트
      final idx = _proposals.indexWhere((p) => p.id == proposalId);
      if (idx != -1) {
        final old = _proposals[idx];
        _proposals[idx] = MeetingProposal(
          id: old.id,
          roomId: old.roomId,
          proposedBy: old.proposedBy,
          startTime: old.startTime,
          endTime: old.endTime,
          location: old.location,
          expiresAt: old.expiresAt,
          isConfirmed: true,
          attendCount: old.attendCount,
          totalMembers: old.totalMembers,
          votes: old.votes,
        );
      }
    });

    final start = _formatDateTime(data['start_time'] as String?);
    final location = data['location'] as String?;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Text('🎉 ', style: TextStyle(fontSize: 20)),
          Text('Meeting Confirmed!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📅  $start',
                style: const TextStyle(fontSize: 14, color: Color(0xFF475569))),
            if (location != null && location.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('📍  $location',
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF475569))),
            ],
            const SizedBox(height: 8),
            Text(
              data['confirmation_type'] == 'unanimous'
                  ? 'Everyone voted to attend!'
                  : 'Auto-confirmed after voting period.',
              style:
                  const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it', style: TextStyle(color: primaryColor)),
          ),
        ],
      ),
    );
  }

  // ─── Schedule Meeting Screen ─────────────────────────────────────────────────

  void _showScheduleMeetingSheet() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScheduleMeetingScreen(
          roomId: widget.roomId,
          onProposalsCreated: () {
            // 제출 후 proposal 목록 다시 로드
            MeetingService.getProposals(widget.roomId).then((proposals) {
              if (mounted) {
                setState(() {
                  _proposals.clear();
                  _proposals.addAll(proposals);
                });
              }
            });
          },
        ),
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  String _formatTime(DateTime dt) => DateFormat('h:mm a').format(dt);

  String _formatDateTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.parse(iso).toLocal();
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  bool _isMe(ChatMessage msg) => msg.senderId == _currentUserId;

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          if (_someoneTyping) _buildTypingIndicator(),
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleSpacing: widget.isEmbedded ? 20.0 : 0,
      leading: widget.isEmbedded
          ? null
          : IconButton(
              icon: const Icon(Icons.chevron_left,
                  size: 30, color: Color(0xFF0F172A)),
              onPressed: () => Navigator.pop(context),
            ),
      automaticallyImplyLeading: !widget.isEmbedded,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.groupName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          Text(
            '${widget.memberCount} members',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert, size: 22, color: Color(0xFF0F172A)),
          onPressed: () => _showGroupInfoPanel(context),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFF1F5F9)),
      ),
    );
  }

  Widget _buildMessageList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: primaryColor),
      );
    }
    if (_loadError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('Failed to load messages',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loadHistory,
              child: const Text('Try again', style: TextStyle(color: primaryColor)),
            ),
          ],
        ),
      );
    }
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No messages yet',
                style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text('Say hello to your study group!',
                style:
                    TextStyle(color: Colors.grey.shade400, fontSize: 13)),
          ],
        ),
      );
    }

    final totalCount = _messages.length + _proposals.length;
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      itemCount: totalCount,
      itemBuilder: (_, i) {
        if (i < _messages.length) {
          final msg = _messages[i];
          final showName = i == 0 || _messages[i - 1].senderId != msg.senderId;
          return _isMe(msg)
              ? _buildSentBubble(msg)
              : _buildReceivedBubble(msg, showName);
        }
        // proposals는 메시지 아래에 순서대로
        final proposal = _proposals[i - _messages.length];
        return _buildProposalCard(proposal);
      },
    );
  }

  Widget _buildReceivedBubble(ChatMessage msg, bool showName) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar
          if (showName)
            Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 8, bottom: 2),
              decoration: const BoxDecoration(
                color: Color(0xFFE2E8F0),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _initials(msg.senderName ?? _memberNames[msg.senderId] ?? '?'),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF475569)),
                ),
              ),
            )
          else
            const SizedBox(width: 44),

          // Bubble
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showName)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Text(
                    msg.senderName ?? _memberNames[msg.senderId] ?? 'Member',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                        maxWidth:
                            MediaQuery.of(context).size.width * 0.62),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: const BoxDecoration(
                        color: bubbleReceived,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(20),
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: Text(
                        msg.content,
                        style: const TextStyle(
                            fontSize: 14,
                            color: textReceived,
                            height: 1.4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatTime(msg.createdAt),
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSentBubble(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(msg.createdAt),
            style:
                const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.68),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Text(
                msg.content,
                style: const TextStyle(
                    fontSize: 14, color: Colors.white, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(_dot1, 0),
                const SizedBox(width: 4),
                _buildDot(_dot2, 1),
                const SizedBox(width: 4),
                _buildDot(_dot3, 2),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_typingName.isNotEmpty)
            Text(
              '$_typingName is typing...',
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF94A3B8)),
            ),
        ],
      ),
    );
  }

  Widget _buildDot(AnimationController ctrl, int index) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, child) {
        final t = ctrl.value;
        // scale: 0 → 1 → 0 in the range 0.0–0.57 of the cycle
        final scale = (t < 0.285)
            ? (t / 0.285)
            : (t < 0.57)
                ? (1 - (t - 0.285) / 0.285)
                : 0.0;
        return Transform.scale(
          scale: scale.clamp(0.0, 1.0),
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF94A3B8),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildProposalCard(MeetingProposal proposal) {
    final myVote = _currentUserId != null ? proposal.myVote(_currentUserId!) : null;
    final isVoting = _votingInProgress.contains(proposal.id);
    final confirmed = proposal.isConfirmed;
    final expired = proposal.isExpired;

    final dateStr = DateFormat('EEE, MMM d').format(proposal.startTime);
    final timeStr =
        '${DateFormat('h:mm a').format(proposal.startTime)} – ${DateFormat('h:mm a').format(proposal.endTime)}';

    String expiryStr = '';
    if (!expired && !confirmed) {
      final diff = proposal.expiresAt.difference(DateTime.now());
      expiryStr = diff.inHours > 0
          ? '${diff.inHours}h ${diff.inMinutes % 60}m left'
          : '${diff.inMinutes}m left';
    }

    final accentColor = confirmed
        ? const Color(0xFF15803D)
        : expired
            ? const Color(0xFF94A3B8)
            : const Color(0xFF57068C);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withAlpha(50)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Compact header row
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(12),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                ),
                child: Row(
                  children: [
                    Icon(
                      confirmed ? Icons.check_circle_rounded : Icons.calendar_month_rounded,
                      size: 14,
                      color: accentColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      confirmed ? 'Meeting Confirmed' : expired ? 'Proposal Expired' : 'Meeting Proposal',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: accentColor),
                    ),
                    const Spacer(),
                    if (expiryStr.isNotEmpty)
                      Text('⏱ $expiryStr',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    if (myVote != null && !confirmed) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: myVote == true ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          myVote == true ? '✓ Voted' : '✗ Voted',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: myVote == true ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date / time / location in one compact block
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Text('$dateStr  ·  $timeStr',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                      ],
                    ),
                    if (proposal.location != null && proposal.location!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 6),
                          Text(proposal.location!,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),

                    // Vote buttons (hidden if confirmed or expired)
                    if (confirmed)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, size: 13, color: Color(0xFF15803D)),
                            SizedBox(width: 5),
                            Text('Confirmed', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF15803D))),
                          ],
                        ),
                      )
                    else if (!expired)
                      Row(
                        children: [
                          Expanded(
                            child: _VoteButton(
                              label: 'Attend',
                              icon: Icons.check_circle_outline,
                              selected: myVote == true,
                              loading: isVoting,
                              disabled: myVote == false,
                              color: const Color(0xFF15803D),
                              onTap: () => _castVote(proposal, true),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _VoteButton(
                              label: 'Not Attend',
                              icon: Icons.cancel_outlined,
                              selected: myVote == false,
                              loading: isVoting,
                              color: const Color(0xFFB91C1C),
                              onTap: () => _castVote(proposal, false),
                            ),
                          ),
                        ],
                      )
                    else
                      const Text('Voting ended', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),

                    const SizedBox(height: 8),

                    // Compact attendance bar
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: proposal.totalMembers > 0
                                  ? proposal.attendCount / proposal.totalMembers
                                  : 0,
                              minHeight: 4,
                              backgroundColor: const Color(0xFFE2E8F0),
                              color: const Color(0xFF15803D),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${proposal.attendCount}/${proposal.totalMembers}',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Text input row
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _inputController,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle:
                          TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: _sending
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Quick Actions
          if (widget.isAdmin)
            _QuickActionButton(
              emoji: '📅',
              label: 'Schedule Meeting',
              onTap: _showScheduleMeetingSheet,
            ),
        ],
      ),
    );
  }
}

// ─── Quick Action Button ───────────────────────────────────────────────────────

// ─── Vote Button ──────────────────────────────────────────────────────────────

class _VoteButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool loading;
  final bool disabled;
  final Color color;
  final VoidCallback onTap;

  const _VoteButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.loading,
    required this.color,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final inactive = disabled && !selected;
    return GestureDetector(
      onTap: (loading || disabled) ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: inactive
              ? const Color(0xFFF1F5F9)
              : selected
                  ? color.withAlpha(26)
                  : const Color(0xFFF8FAFC),
          border: Border.all(
            color: inactive
                ? const Color(0xFFE2E8F0)
                : selected
                    ? color
                    : const Color(0xFFE2E8F0),
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: color),
              )
            else
              Icon(icon,
                  size: 15,
                  color: inactive
                      ? const Color(0xFFCBD5E1)
                      : selected
                          ? color
                          : const Color(0xFF94A3B8)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: inactive
                    ? const Color(0xFFCBD5E1)
                    : selected
                        ? color
                        : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Quick Action Button ───────────────────────────────────────────────────────

class _QuickActionButton extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Schedule Meeting Screen (방장 전용) ──────────────────────────────────────

class ScheduleMeetingScreen extends StatefulWidget {
  final String roomId;
  final VoidCallback onProposalsCreated;

  const ScheduleMeetingScreen({
    super.key,
    required this.roomId,
    required this.onProposalsCreated,
  });

  @override
  State<ScheduleMeetingScreen> createState() => _ScheduleMeetingScreenState();
}

class _ScheduleMeetingScreenState extends State<ScheduleMeetingScreen> {
  static const Color primaryColor = Color(0xFF57068C);

  // 3개 옵션 각각의 상태
  final List<DateTime?> _startTimes = [null, null, null];
  final List<TextEditingController> _locationCtrls = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  bool _notifyMembers = true;
  bool _submitting = false;

  // 각 옵션의 left-border opacity
  static const List<double> _cardOpacities = [1.0, 0.6, 0.3];

  @override
  void dispose() {
    for (final c in _locationCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDateTime(int index) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: primaryColor),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 14, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: primaryColor),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;

    setState(() {
      _startTimes[index] =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    // 적어도 1개는 시간이 설정돼야 함
    final filledOptions = <int>[];
    for (int i = 0; i < 3; i++) {
      if (_startTimes[i] != null) filledOptions.add(i);
    }
    if (filledOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one time option is required')),
      );
      return;
    }

    setState(() => _submitting = true);
    int successCount = 0;
    String? lastError;

    for (final i in filledOptions) {
      final start = _startTimes[i]!;
      final end = start.add(const Duration(hours: 2)); // end = start + 2h
      final location = _locationCtrls[i].text.trim();
      try {
        final res = await ApiClient.post('/meetings/proposals', body: {
          'room_id': widget.roomId,
          'start_time': start.toUtc().toIso8601String(),
          'end_time': end.toUtc().toIso8601String(),
          if (location.isNotEmpty) 'location': location,
        });
        if (res.statusCode == 201) {
          successCount++;
        } else {
          final body = jsonDecode(res.body);
          lastError = body['detail'] as String? ?? 'Failed';
        }
      } catch (e) {
        lastError = e.toString();
      }
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    if (successCount > 0) {
      widget.onProposalsCreated();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '📅 $successCount proposal${successCount > 1 ? 's' : ''} created! Members can now vote.'),
          backgroundColor: const Color(0xFF15803D),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lastError ?? 'Failed to create proposals')),
      );
    }
  }

  String _fmtDt(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('MMM d, yyyy · h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF475569)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Schedule Meeting',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: primaryColor,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE2E8F0)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Intro
            const Text(
              'Propose Times',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Select up to three potential time slots for your group to vote on.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),

            // 3개 옵션 카드
            for (int i = 0; i < 3; i++) ...[
              _buildOptionCard(i),
              const SizedBox(height: 20),
            ],

            // Notify toggle
            _buildNotifyToggle(),
            const SizedBox(height: 32),

            // Create Vote 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.how_to_vote_outlined, size: 20),
                label: Text(
                  _submitting ? 'Creating...' : 'Create Vote',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: primaryColor.withAlpha(100),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 6,
                  shadowColor: primaryColor.withAlpha(60),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard(int index) {
    final opacity = _cardOpacities[index];
    final isSet = _startTimes[index] != null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left accent bar
            Container(
              width: 4,
              color: primaryColor.withValues(alpha: opacity),
            ),
            // Card content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Option badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'OPTION ${index + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Date & Time
                    const Text(
                      'DATE & TIME',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => _pickDateTime(index),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSet
                                ? primaryColor.withAlpha(80)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 16,
                              color: isSet
                                  ? primaryColor
                                  : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isSet
                                    ? _fmtDt(_startTimes[index])
                                    : 'Select date & time',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSet
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                  color: isSet
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFFCBD5E1),
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: isSet
                                  ? primaryColor
                                  : const Color(0xFFCBD5E1),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Location
                    const Text(
                      'LOCATION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 14),
                            child: Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _locationCtrls[index],
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: _locationHints[index],
                                hintStyle: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFCBD5E1),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotifyToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_outlined,
              size: 20, color: primaryColor),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Notify all members',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Switch(
            value: _notifyMembers,
            onChanged: (v) => setState(() => _notifyMembers = v),
            activeThumbColor: primaryColor,
            activeTrackColor: primaryColor.withAlpha(180),
          ),
        ],
      ),
    );
  }
}

const List<String> _locationHints = [
  'e.g. Bobst Library, 4th Floor',
  'e.g. Kimmel Center Lounge',
  'e.g. Tandon MakerSpace',
];

// ─── Group Info Panel ─────────────────────────────────────────────────────────

class _GroupInfoPanel extends StatefulWidget {
  final String groupId;
  final String groupName;
  final int memberCount;
  final bool isAdmin;
  final Map<String, String> memberNames;
  final VoidCallback? onLeave;

  const _GroupInfoPanel({
    required this.groupId,
    required this.groupName,
    required this.memberCount,
    required this.isAdmin,
    required this.memberNames,
    this.onLeave,
  });

  @override
  State<_GroupInfoPanel> createState() => _GroupInfoPanelState();
}

class _GroupInfoPanelState extends State<_GroupInfoPanel> {
  static const _primary = Color(0xFF57068C);

  List<Map<String, dynamic>> _pendingRequests = [];
  bool _loadingRequests = true;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.isAdmin) _loadRequests();
  }

  Future<void> _leaveGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Leave Group', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to leave "${widget.groupName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave', style: TextStyle(color: Color(0xFFDC2626))),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _leaving = true);
    try {
      await StudyGroupService.leave(widget.groupId);
      if (mounted) {
        Navigator.pop(context);
        widget.onLeave?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _leaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')),
              backgroundColor: const Color(0xFFDC2626)),
        );
      }
    }
  }

  Future<void> _loadRequests() async {
    try {
      final response = await ApiClient.get('/study-groups/${widget.groupId}/requests');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) setState(() { _pendingRequests = data.cast<Map<String, dynamic>>(); _loadingRequests = false; });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingRequests = false);
  }

  Future<void> _handleRequest(String requestId, String action) async {
    try {
      final response = await ApiClient.post('/study-groups/${widget.groupId}/requests/$requestId/$action', body: {});
      if (response.statusCode == 200) {
        _loadRequests();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: ${response.statusCode}'), backgroundColor: const Color(0xFFDC2626)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: _primary.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.group, color: _primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.groupName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${widget.memberCount} members',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),

        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Members section
                const Text('MEMBERS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: Color(0xFF94A3B8), letterSpacing: 1.2)),
                const SizedBox(height: 10),
                widget.memberNames.isEmpty
                    ? Text('No member data', style: TextStyle(color: Colors.grey.shade400, fontSize: 13))
                    : Column(
                        children: widget.memberNames.values.map((name) => _MemberRow(name: name)).toList(),
                      ),

                // Admin section: pending join requests
                if (widget.isAdmin) ...[
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Text('JOIN REQUESTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8), letterSpacing: 1.2)),
                      if (_pendingRequests.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: Colors.orange.withAlpha(30), borderRadius: BorderRadius.circular(20)),
                          child: Text('${_pendingRequests.length}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.orange)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  _loadingRequests
                      ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: _primary, strokeWidth: 2)))
                      : _pendingRequests.isEmpty
                          ? Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: const Text('No pending requests', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                            )
                          : Column(
                              children: _pendingRequests.map((req) => _RequestRow(
                                request: req,
                                onAccept: () => _handleRequest(req['id'], 'accept'),
                                onDecline: () => _handleRequest(req['id'], 'decline'),
                              )).toList(),
                            ),
                ],

                // Leave group button (all users)
                const SizedBox(height: 24),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _leaving ? null : _leaveGroup,
                    icon: _leaving
                        ? const SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDC2626)))
                        : const Icon(Icons.exit_to_app_rounded, size: 16, color: Color(0xFFDC2626)),
                    label: Text(_leaving ? 'Leaving...' : 'Leave Group',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFDC2626), width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  final String name;
  const _MemberRow({required this.name});

  static const _primary = Color(0xFF57068C);

  String _initials(String n) {
    final p = n.trim().split(' ');
    if (p.length >= 2) return '${p[0][0]}${p[1][0]}'.toUpperCase();
    return n.substring(0, n.length.clamp(0, 2)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: _primary.withAlpha(20), shape: BoxShape.circle),
            child: Center(child: Text(_initials(name),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _primary))),
          ),
          const SizedBox(width: 10),
          Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  const _RequestRow({required this.request, required this.onAccept, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    final userObj = request['user'] as Map<String, dynamic>?;
    final name = userObj?['name'] ?? request['user_name'] ?? 'Applicant';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withAlpha(40)),
      ),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: Colors.orange.withAlpha(20), shape: BoxShape.circle),
            child: const Center(child: Icon(Icons.person_outline, size: 18, color: Colors.orange)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF0F172A))),
          ),
          GestureDetector(
            onTap: onDecline,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(8)),
              child: const Text('Decline', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ),
          ),
          GestureDetector(
            onTap: onAccept,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: const Color(0xFF57068C), borderRadius: BorderRadius.circular(8)),
              child: const Text('Accept', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
