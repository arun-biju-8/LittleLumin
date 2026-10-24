// lib/widgets/specialist_messaging_panel.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/specialist_case_model.dart';
import '../models/message_model.dart';
import '../services/messaging_service.dart';
import '../services/specialist_case_service.dart';

class SpecialistMessagingPanel extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final SpecialistCaseModel? initialCase;
  final String? contextualActivityTitle;
  final String? contextualRecommendationTitle;
  final void Function(SpecialistCaseModel caseModel)? onOpenChildProfile;
  final void Function(SpecialistCaseModel caseModel)? onRecordConsultation;
  final MessagingService? messagingService;
  final SpecialistCaseService? caseService;
  final FirebaseAuth? auth;

  const SpecialistMessagingPanel({
    super.key,
    required this.isOpen,
    required this.onClose,
    this.initialCase,
    this.contextualActivityTitle,
    this.contextualRecommendationTitle,
    this.onOpenChildProfile,
    this.onRecordConsultation,
    this.messagingService,
    this.caseService,
    this.auth,
  });

  @override
  State<SpecialistMessagingPanel> createState() => _SpecialistMessagingPanelState();
}

class _SpecialistMessagingPanelState extends State<SpecialistMessagingPanel> {
  late final MessagingService _messagingService;
  late final SpecialistCaseService _caseService;
  FirebaseAuth? _auth;

  SpecialistCaseModel? _activeCase;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _conversationSearchQuery = '';
  bool _isSending = false;
  bool _showTemplates = false;

  // Colors matching the portal identity
  static const Color colorNavy = Color(0xFF0F172A);
  static const Color colorSlate = Color(0xFF1E293B);
  static const Color colorCard = Color(0xFF1E293B);
  static const Color colorBorder = Color(0xFF334155);
  static const Color colorTeal = Color(0xFF0EA5E9);
  static const Color colorAmber = Color(0xFFF59E0B);
  static const Color colorEmerald = Color(0xFF10B981);
  static const Color colorTextMuted = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    _messagingService = widget.messagingService ?? MessagingService();
    _caseService = widget.caseService ?? SpecialistCaseService();
    try {
      _auth = widget.auth ?? FirebaseAuth.instance;
    } catch (_) {
      _auth = null;
    }

    _activeCase = widget.initialCase;
    if (_activeCase != null) {
      _markRead(_activeCase!);
    }
  }

  @override
  void didUpdateWidget(SpecialistMessagingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCase != null && widget.initialCase?.caseId != _activeCase?.caseId) {
      setState(() {
        _activeCase = widget.initialCase;
      });
      if (_activeCase != null) {
        _markRead(_activeCase!);
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _markRead(SpecialistCaseModel c) {
    final user = _auth?.currentUser;
    if (user != null) {
      _messagingService.markMessagesAsRead(c.caseId, user.uid);
    }
  }

  void _applyQuickReplyTemplate(String templateKey) {
    if (_activeCase == null) return;
    final parent = _activeCase!.parentName.isNotEmpty ? _activeCase!.parentName : 'Parent';
    final child = _activeCase!.childName;
    final activity = widget.contextualActivityTitle ?? 'the recommended';

    String templateText = '';
    switch (templateKey) {
      case 'activity_followup':
        templateText = 'Hello $parent, I noticed $child has been working on $activity activity. How did they find the pacing and materials?';
        break;
      case 'request_observations':
        templateText = 'Hello $parent, could you please share your observations on how $child is responding to our home guidance routine this week?';
        break;
      case 'progress_update':
        templateText = 'Hello $parent, I am pleased to share a positive milestone update regarding $child\'s recent developmental progress!';
        break;
      case 'schedule_consultation':
        templateText = 'Hello $parent, I would like to schedule a 15-minute follow-up consultation to review $child\'s developmental milestones and care plan.';
        break;
      case 'clarify_instruction':
        templateText = 'Hello $parent, regarding our latest guidance activity: feel free to break the exercise into 5-minute play segments if $child needs gentle pacing.';
        break;
      case 'concern_followup':
        templateText = 'Hello $parent, I am following up on the developmental observation note we documented recently to see how $child is progressing at home.';
        break;
    }

    setState(() {
      _textController.text = templateText;
      _showTemplates = false;
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending || _activeCase == null) return;

    if (!_activeCase!.canAccessChildData) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot send message: Active DPDP consultation consent is required.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSending = true);
    final user = _auth?.currentUser;
    final currentUserId = user?.uid ?? 'specialist';
    final currentUserName = _activeCase!.specialistName.isNotEmpty ? _activeCase!.specialistName : 'Specialist';

    try {
      await _messagingService.sendMessage(
        caseId: _activeCase!.caseId,
        childId: _activeCase!.childId,
        senderId: currentUserId,
        senderName: currentUserName,
        senderRole: 'llg',
        recipientId: _activeCase!.parentId,
        content: text,
      );

      _textController.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;
    final panelWidth = isMobile ? screenWidth : 420.0;

    return Stack(
      children: [
        // Subtle Backdrop overlay on mobile / tablet
        if (isMobile)
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onClose,
              child: Container(color: Colors.black54),
            ),
          ),

        // Slide-in Panel from Right
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: panelWidth,
            height: double.infinity,
            decoration: const BoxDecoration(
              color: colorNavy,
              border: Border(left: BorderSide(color: colorBorder, width: 1.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 16,
                  offset: Offset(-4, 0),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Top Panel Header
                  _buildPanelHeader(),

                  // Body (Active Chat or Conversations List)
                  Expanded(
                    child: _activeCase != null
                        ? _buildActiveConversationView()
                        : _buildConversationsListView(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPanelHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: colorSlate,
        border: Border(bottom: BorderSide(color: colorBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                if (_activeCase != null) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        _activeCase = null;
                        _showTemplates = false;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                ],
                const Icon(Icons.chat_bubble_outline, color: colorTeal, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _activeCase != null ? 'Consultation Chat' : 'Direct Messages',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              if (_activeCase != null && widget.onRecordConsultation != null)
                IconButton(
                  tooltip: 'Record Consultation Summary',
                  icon: const Icon(Icons.assignment_turned_in_outlined, color: colorAmber, size: 20),
                  onPressed: () => widget.onRecordConsultation?.call(_activeCase!),
                ),
              IconButton(
                tooltip: 'Close Messages',
                icon: const Icon(Icons.close, color: colorTextMuted, size: 20),
                onPressed: widget.onClose,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConversationsListView() {
    final user = _auth?.currentUser;
    final specialistId = user?.uid ?? '';

    return StreamBuilder<List<SpecialistCaseModel>>(
      stream: _caseService.getSpecialistCasesStream(specialistId: specialistId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var cases = snapshot.data ?? [];
        cases = cases.where((c) => c.status != CaseStatus.revoked).toList();

        if (_conversationSearchQuery.isNotEmpty) {
          cases = cases.where((c) {
            final p = c.parentName.toLowerCase();
            final ch = c.childName.toLowerCase();
            return p.contains(_conversationSearchQuery) || ch.contains(_conversationSearchQuery);
          }).toList();
        }

        return Column(
          children: [
            // Search Input
            Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: colorCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorBorder),
                ),
                child: TextField(
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                  onChanged: (val) => setState(() => _conversationSearchQuery = val.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search parents or children...',
                    hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 18, color: colorTextMuted),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),

            // Cases list
            Expanded(
              child: cases.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.forum_outlined, size: 40, color: colorTextMuted.withOpacity(0.5)),
                          const SizedBox(height: 10),
                          Text(
                            'No active conversations found',
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Accepted parent cases appear here automatically.',
                            style: GoogleFonts.inter(color: colorTextMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      itemCount: cases.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final c = cases[index];
                        return _buildConversationListItem(c);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConversationListItem(SpecialistCaseModel c) {
    final user = _auth?.currentUser;
    final parentInitial = c.parentName.isNotEmpty ? c.parentName[0].toUpperCase() : 'P';

    return InkWell(
      onTap: () {
        setState(() {
          _activeCase = c;
          _showTemplates = false;
        });
        _markRead(c);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorBorder),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colorTeal.withOpacity(0.2),
              child: Text(parentInitial, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: colorTeal)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          c.parentName.isNotEmpty ? c.parentName : 'Parent',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorEmerald.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Child: ${c.childName}',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: colorEmerald),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Focus: ${c.purpose.isNotEmpty ? c.purpose : 'Child Development Guidance'}',
                    style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StreamBuilder<int>(
              stream: _messagingService.getUnreadCountStream(c.caseId, user?.uid ?? ''),
              builder: (context, snapshot) {
                final unread = snapshot.data ?? 0;
                if (unread <= 0) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: colorTeal,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveConversationView() {
    final c = _activeCase!;
    final user = _auth?.currentUser;
    final currentUserId = user?.uid ?? 'specialist';
    final isPermitted = c.canAccessChildData;

    return Column(
      children: [
        // Conversation Subheader Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: const BoxDecoration(
            color: colorCard,
            border: Border(bottom: BorderSide(color: colorBorder)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.parentName.isNotEmpty ? c.parentName : 'Parent',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'For: ${c.childName} • DPDP Notice v${c.consentNoticeVersion}',
                      style: GoogleFonts.inter(fontSize: 10, color: colorTextMuted),
                    ),
                  ],
                ),
              ),
              if (widget.onOpenChildProfile != null)
                TextButton.icon(
                  onPressed: () => widget.onOpenChildProfile?.call(c),
                  icon: const Icon(Icons.person_outline, size: 14, color: colorTeal),
                  label: Text('Profile', style: GoogleFonts.inter(fontSize: 11, color: colorTeal, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                ),
            ],
          ),
        ),

        // DPDP Consent Warning if not permitted
        if (!isPermitted)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: Colors.redAccent.withOpacity(0.15),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: Colors.redAccent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Active parental consent required under DPDP to message.',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          ),

        // Contextual Tag (if opened from activity or recommendation)
        if (widget.contextualActivityTitle != null || widget.contextualRecommendationTitle != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            color: colorTeal.withOpacity(0.1),
            child: Row(
              children: [
                const Icon(Icons.link_outlined, size: 14, color: colorTeal),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Context: ${widget.contextualActivityTitle ?? widget.contextualRecommendationTitle}',
                    style: GoogleFonts.inter(fontSize: 11, color: colorTeal, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

        // Messages Stream
        Expanded(
          child: StreamBuilder<List<MessageModel>>(
            stream: _messagingService.getMessagesStream(c.caseId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final messages = snapshot.data ?? [];
              if (messages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_outlined, size: 36, color: colorTextMuted.withOpacity(0.5)),
                      const SizedBox(height: 8),
                      Text('No messages in this case yet', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Use Quick Replies below to initiate guidance.', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 11)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isMe = msg.senderId == currentUserId;
                  return _buildMessageBubble(msg, isMe);
                },
              );
            },
          ),
        ),

        // Quick Reply Templates Drawer
        if (_showTemplates) _buildTemplatesDrawer(),

        // Composer & Quick Actions Bar
        _buildMessageComposer(isPermitted),
      ],
    );
  }

  Widget _buildMessageBubble(MessageModel msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? colorTeal : colorSlate,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isMe ? 12 : 2),
            bottomRight: Radius.circular(isMe ? 2 : 12),
          ),
          border: isMe ? null : Border.all(color: colorBorder),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              msg.content,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white, height: 1.35),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat.jm().format(msg.timestamp),
                  style: GoogleFonts.inter(fontSize: 9, color: isMe ? Colors.white70 : colorTextMuted),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    msg.status == MessageStatus.read ? Icons.done_all : Icons.done,
                    size: 11,
                    color: msg.status == MessageStatus.read ? Colors.lightBlueAccent : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplatesDrawer() {
    final templates = [
      {'key': 'activity_followup', 'title': 'Activity Follow-up', 'icon': Icons.sports_esports_outlined},
      {'key': 'request_observations', 'title': 'Request Observations', 'icon': Icons.visibility_outlined},
      {'key': 'progress_update', 'title': 'Progress Milestone Update', 'icon': Icons.trending_up},
      {'key': 'schedule_consultation', 'title': 'Schedule Consultation', 'icon': Icons.calendar_today_outlined},
      {'key': 'clarify_instruction', 'title': 'Clarify Activity Pacing', 'icon': Icons.help_outline},
      {'key': 'concern_followup', 'title': 'Follow Up on Concern', 'icon': Icons.flag_outlined},
    ];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        color: colorSlate,
        border: Border(top: BorderSide(color: colorBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Professional Quick Reply Templates',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: colorTextMuted),
              ),
              InkWell(
                onTap: () => setState(() => _showTemplates = false),
                child: const Icon(Icons.close, size: 14, color: colorTextMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: templates.map((t) {
              return ActionChip(
                avatar: Icon(t['icon'] as IconData, size: 13, color: colorTeal),
                label: Text(t['title'] as String),
                labelStyle: GoogleFonts.inter(fontSize: 11, color: Colors.white),
                backgroundColor: colorCard,
                side: const BorderSide(color: colorBorder),
                onPressed: () => _applyQuickReplyTemplate(t['key'] as String),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageComposer(bool isPermitted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        color: colorSlate,
        border: Border(top: BorderSide(color: colorBorder)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Insert Quick Reply Template',
            icon: Icon(
              Icons.bolt_outlined,
              color: _showTemplates ? colorAmber : colorTeal,
              size: 22,
            ),
            onPressed: isPermitted ? () => setState(() => _showTemplates = !_showTemplates) : null,
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: colorNavy,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colorBorder),
              ),
              child: TextField(
                controller: _textController,
                enabled: isPermitted && !_isSending,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                maxLines: 3,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: isPermitted ? 'Type consultation message...' : 'Consent paused',
                  hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: _isSending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: colorTeal))
                : const Icon(Icons.send_rounded, color: colorTeal, size: 20),
            onPressed: isPermitted && !_isSending ? _sendMessage : null,
          ),
        ],
      ),
    );
  }
}
