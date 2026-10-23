// lib/screens/chat/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/message_model.dart';
import '../../models/specialist_case_model.dart';
import '../../services/messaging_service.dart';

class ChatScreen extends StatefulWidget {
  final SpecialistCaseModel specialistCase;
  final String currentUserId;
  final String currentUserName;
  final String currentUserRole; // 'parent', 'llg', 'clinical_specialist'
  final String otherParticipantName;
  final String otherParticipantRole;
  final MessagingService? messagingService;

  const ChatScreen({
    super.key,
    required this.specialistCase,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserRole,
    required this.otherParticipantName,
    required this.otherParticipantRole,
    this.messagingService,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final MessagingService _messagingService;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  bool get _canSendMessage {
    return widget.specialistCase.canAccessChildData;
  }

  @override
  void initState() {
    super.initState();
    _messagingService = widget.messagingService ?? MessagingService();
    _markRead();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _markRead() {
    _messagingService.markMessagesAsRead(
      widget.specialistCase.caseId,
      widget.currentUserId,
    );
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    if (!_canSendMessage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot send message: Active consultation consent is required.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final recipientId = widget.currentUserRole == 'parent'
          ? widget.specialistCase.specialistId
          : widget.specialistCase.parentId;

      await _messagingService.sendMessage(
        caseId: widget.specialistCase.caseId,
        childId: widget.specialistCase.childId,
        senderId: widget.currentUserId,
        senderName: widget.currentUserName,
        senderRole: widget.currentUserRole,
        recipientId: recipientId,
        content: text,
      );

      _textController.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF0EA5E9).withOpacity(0.15),
              child: Text(
                widget.otherParticipantName.isNotEmpty
                    ? widget.otherParticipantName[0].toUpperCase()
                    : 'U',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0284C7),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherParticipantName,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${widget.otherParticipantRole.replaceAll('_', ' ').toUpperCase()} • For ${widget.specialistCase.childName}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildStatusBanner(),
          Expanded(child: _buildMessagesList()),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    final status = widget.specialistCase.status;
    Color bgColor;
    Color textColor;
    IconData icon;
    String label;

    if (status == CaseStatus.revoked) {
      bgColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFFB91C1C);
      icon = Icons.lock_outline;
      label = 'Consent has been withdrawn. Communication is paused.';
    } else if (status == CaseStatus.pending) {
      bgColor = const Color(0xFFFEF3C7);
      textColor = const Color(0xFFB45309);
      icon = Icons.hourglass_top;
      label = 'Consultation request is pending acceptance.';
    } else if (status == CaseStatus.declined) {
      bgColor = const Color(0xFFF1F5F9);
      textColor = const Color(0xFF475569);
      icon = Icons.block_outlined;
      label = 'Consultation was declined.';
    } else {
      bgColor = const Color(0xFFECFDF5);
      textColor = const Color(0xFF047857);
      icon = Icons.verified_user_outlined;
      label = 'Active & Secure Consultation • DPDP Consent Protected';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: bgColor,
      child: Row(
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return StreamBuilder<List<MessageModel>>(
      stream: _messagingService.getMessagesStream(widget.specialistCase.caseId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final messages = snapshot.data ?? [];
        if (messages.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline,
                      size: 40,
                      color: Color(0xFF0EA5E9),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No messages yet',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Send a message to discuss ${widget.specialistCase.childName}\'s milestones, activities, and recommendations.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg = messages[index];
            final isMe = msg.senderId == widget.currentUserId;
            return _buildMessageBubble(msg, isMe);
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(MessageModel msg, bool isMe) {
    final bg = isMe ? const Color(0xFF0EA5E9) : Colors.white;
    final textColor = isMe ? Colors.white : const Color(0xFF0F172A);
    final timeStr = DateFormat.jm().format(msg.timestamp);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMe ? 14 : 2),
            bottomRight: Radius.circular(isMe ? 2 : 14),
          ),
          border: isMe ? null : Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              msg.content,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: textColor,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: isMe
                        ? Colors.white.withOpacity(0.7)
                        : const Color(0xFF94A3B8),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    msg.isRead ? Icons.done_all : Icons.done,
                    size: 13,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    if (!_canSendMessage) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: const Color(0xFFF1F5F9),
        alignment: Alignment.center,
        child: Text(
          'Messaging is currently locked for this case.',
          style: GoogleFonts.inter(
            color: const Color(0xFF64748B),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _textController,
                  maxLines: 4,
                  minLines: 1,
                  maxLength: 2000,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: 'Type your message...',
                    hintStyle: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF94A3B8)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0EA5E9),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 18),
                onPressed: _isSending ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
