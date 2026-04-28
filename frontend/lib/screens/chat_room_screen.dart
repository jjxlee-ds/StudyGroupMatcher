import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/chat_message.dart';
import '../models/meeting_proposal.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/chat_service.dart';
import '../services/meeting_service.dart';
import 'join_requests_screen.dart';

class ChatRoomScreen extends StatefulWidget {
  final String roomId;
  final String groupId;
  final String groupName;
  final int memberCount;
  final bool isAdmin;

  const ChatRoomScreen({
    super.key,
    required this.roomId,
    required this.groupId,
    required this.groupName,
    required this.memberCount,
    this.isAdmin = false,
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

  WebSocket? _ws;
  bool _loading = true;
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
    _ws?.close();
    _inputController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _dot1.dispose();
    _dot2.dispose();
    _dot3.dispose();
    super.dispose();
  }

  // ─── Data ───────────────────────────────────────────────────────────────────

  Future<void> _loadHistory() async {
    try {
      final results = await Future.wait([
        ChatService.getMessages(widget.roomId),
        MeetingService.getProposals(widget.roomId),
      ]);
      if (mounted) {
        setState(() {
          _messages.addAll(results[0] as List<ChatMessage>);
          _proposals.addAll(results[1] as List<MeetingProposal>);
          _loading = false;
        });
        _scrollToBottom(jump: true);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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

    final wsBase = ApiConfig.baseUrl.replaceFirst(RegExp(r'^http'), 'ws');
    final url = '$wsBase/ws/rooms/${widget.roomId}?token=$token';

    try {
      _ws = await WebSocket.connect(url);
      _ws!.listen(
        _onWsMessage,
        onDone: () => _scheduleReconnect(),
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
    if (content.isEmpty || _ws == null || _sending) return;

    setState(() => _sending = true);
    _inputController.clear();

    try {
      _ws!.add(jsonEncode({'content': content}));
    } catch (_) {
      // 재연결 후 재전송은 UX 개선 여지
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
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.chevron_left,
            size: 30, color: Color(0xFF0F172A)),
        onPressed: () => Navigator.pop(context),
      ),
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
          icon: const Icon(Icons.search, size: 22, color: Color(0xFF0F172A)),
          onPressed: () {},
        ),
        if (widget.isAdmin)
          IconButton(
            icon: const Icon(Icons.more_vert, size: 22, color: Color(0xFF0F172A)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => JoinRequestsScreen(
                    groupId: widget.groupId,
                    groupName: widget.groupName,
                  ),
                ),
              );
            },
          )
        else
          IconButton(
            icon: const Icon(Icons.more_vert, size: 22, color: Color(0xFF0F172A)),
            onPressed: () {},
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
                  _initials(msg.senderId.substring(0, 4)),
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
                    msg.senderId.substring(0, 8), // ideally sender name
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

    // 만료까지 남은 시간
    String expiryStr = '';
    if (!expired) {
      final diff = proposal.expiresAt.difference(DateTime.now());
      if (diff.inHours > 0) {
        expiryStr = '${diff.inHours}h ${diff.inMinutes % 60}m left';
      } else {
        expiryStr = '${diff.inMinutes}m left';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 340),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: confirmed
                  ? const Color(0xFF15803D)
                  : expired
                      ? const Color(0xFFE2E8F0)
                      : const Color(0xFFDDD6FE),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF57068C).withAlpha(18),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: confirmed
                      ? const Color(0xFFF0FDF4)
                      : expired
                          ? const Color(0xFFF8FAFC)
                          : const Color(0xFFF5F3FF),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Row(
                  children: [
                    Icon(
                      confirmed
                          ? Icons.check_circle_rounded
                          : Icons.calendar_month_rounded,
                      size: 16,
                      color: confirmed
                          ? const Color(0xFF15803D)
                          : expired
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF57068C),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      confirmed
                          ? 'Meeting Confirmed!'
                          : expired
                              ? 'Meeting Proposal (Expired)'
                              : 'Meeting Proposal',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: confirmed
                            ? const Color(0xFF15803D)
                            : expired
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF57068C),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 날짜 & 시간
                    Text(
                      dateStr,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeStr,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF475569)),
                    ),

                    // 장소
                    if (proposal.location != null &&
                        proposal.location!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              proposal.location!,
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF475569)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 12),

                    // 투표 완료 배지
                    if (myVote != null) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: myVote == true
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  myVote == true
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  size: 12,
                                  color: myVote == true
                                      ? const Color(0xFF15803D)
                                      : const Color(0xFFB91C1C),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Voted',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: myVote == true
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFFB91C1C),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Attend / Not Attend 버튼
                    if (confirmed)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle,
                                size: 15, color: Color(0xFF15803D)),
                            SizedBox(width: 6),
                            Text(
                              'Confirmed Meeting',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF15803D),
                              ),
                            ),
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
                              // Attend→Not Attend 방향만 허용: Not Attend 상태에서 Attend 비활성화
                              disabled: myVote == false,
                              color: const Color(0xFF15803D),
                              onTap: () => _castVote(proposal, true),
                            ),
                          ),
                          const SizedBox(width: 8),
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
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        child: const Text(
                          'Voting period ended',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ),

                    const SizedBox(height: 10),

                    // 투표 현황 bar
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: proposal.totalMembers > 0
                                  ? proposal.attendCount /
                                      proposal.totalMembers
                                  : 0,
                              minHeight: 5,
                              backgroundColor: const Color(0xFFE2E8F0),
                              color: const Color(0xFF15803D),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${proposal.attendCount}/${proposal.totalMembers} attending',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),

                    if (expiryStr.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '⏱  $expiryStr',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                    const SizedBox(height: 12),
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
          Row(
            children: [
              Expanded(
                child: _QuickActionButton(
                  emoji: '🖼️',
                  label: 'Send Picture',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Image upload coming soon')),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionButton(
                  emoji: '📅',
                  label: 'Schedule Meeting',
                  onTap: _showScheduleMeetingSheet,
                ),
              ),
            ],
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
