import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cardflow/services/connection_service.dart';
import 'package:cardflow/services/messaging_service.dart';
import '../widgets/animated_gradient_container.dart';

class ChatScreen extends StatefulWidget {
  final Connection connection;

  const ChatScreen({
    Key? key,
    required this.connection,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final MessagingService _messagingService = MessagingService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _showEmojiPicker = false;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    // Mark messages as read when opening chat
    _messagingService.markMessagesAsRead(widget.connection.id);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    // Clear typing status on exit
    _messagingService.setTyping(widget.connection.id, false);
    super.dispose();
  }

  String get _otherUserName {
    return widget.connection.getOtherUserName(_messagingService.currentUserId!);
  }

  String? get _otherUserPhoto {
    return widget.connection
        .getOtherUserPhoto(_messagingService.currentUserId!);
  }

  String get _otherUserId {
    return widget.connection.getOtherUserId(_messagingService.currentUserId!);
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final success = await _messagingService.sendMessage(
      connectionId: widget.connection.id,
      recipientId: _otherUserId,
      text: text,
      type: MessageType.text,
    );

    if (success) {
      _messageController.clear();
      _messagingService.setTyping(widget.connection.id, false);
      setState(() {
        _isTyping = false;
      });

      // Scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _onEmojiSelected(Emoji emoji) {
    _messageController.text += emoji.emoji;
    _onTypingChanged(_messageController.text);
  }

  void _onTypingChanged(String text) {
    final isTyping = text.trim().isNotEmpty;
    if (isTyping != _isTyping) {
      setState(() {
        _isTyping = isTyping;
      });
      _messagingService.setTyping(widget.connection.id, isTyping);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // Properly handle keyboard
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.arrow_back, color: Colors.grey.shade800),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Hero(
              tag: 'avatar_${widget.connection.id}',
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundImage: _otherUserPhoto != null
                      ? NetworkImage(_otherUserPhoto!)
                      : null,
                  child: _otherUserPhoto == null
                      ? Text(
                          _otherUserName[0].toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
                  backgroundColor: const Color(0xFF667eea),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _otherUserName,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  StreamBuilder<bool>(
                    stream: _messagingService.getTypingIndicator(
                        widget.connection.id, _otherUserId),
                    builder: (context, snapshot) {
                      final isOtherTyping = snapshot.data ?? false;
                      return Text(
                        isOtherTyping ? 'typing...' : 'Connected',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontStyle: isOtherTyping
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  Icon(Icons.more_vert, color: Colors.grey.shade800, size: 20),
            ),
            onPressed: () => _showChatOptions(),
          ),
        ],
      ),
      body: ProfessionalAnimatedGradient(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              SizedBox(
                  height: MediaQuery.of(context).padding.top + kToolbarHeight),
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: _messagingService.getMessages(widget.connection.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return _buildEmptyState();
                    }

                    final messages = snapshot.data!;

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(20),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe =
                            message.senderId == _messagingService.currentUserId;
                        final showAvatar = index == messages.length - 1 ||
                            messages[index + 1].senderId != message.senderId;

                        return _buildMessageBubble(
                          message,
                          isMe,
                          showAvatar,
                        );
                      },
                    );
                  },
                ),
              ),
              _buildInputArea(),
              if (_showEmojiPicker)
                SizedBox(
                  height: 250,
                  child: EmojiPicker(
                    onEmojiSelected: (category, emoji) {
                      _onEmojiSelected(emoji);
                    },
                    config: Config(
                      emojiSet: defaultEmojiSet,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe, bool showAvatar) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && showAvatar)
            CircleAvatar(
              radius: 16,
              backgroundImage: _otherUserPhoto != null
                  ? NetworkImage(_otherUserPhoto!)
                  : null,
              child: _otherUserPhoto == null
                  ? Text(
                      _otherUserName[0].toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                  : null,
              backgroundColor: const Color(0xFF667eea),
            )
          else if (!isMe)
            const SizedBox(width: 32),
          if (!isMe) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF667eea) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: isMe
                      ? const Radius.circular(20)
                      : const Radius.circular(4),
                  bottomRight: isMe
                      ? const Radius.circular(4)
                      : const Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.type == MessageType.text)
                    Text(
                      message.text,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: isMe ? Colors.white : Colors.grey.shade800,
                      ),
                    )
                  else if (message.type == MessageType.system)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            message.text,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeago.format(message.timestamp),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: isMe
                              ? Colors.white.withOpacity(0.8)
                              : Colors.grey.shade500,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 6),
                        Icon(
                          message.read ? Icons.done_all : Icons.done,
                          size: 14,
                          color: message.read
                              ? const Color(0xFF2ebf91)
                              : Colors.white.withOpacity(0.8),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  _showEmojiPicker
                      ? Icons.keyboard
                      : Icons.emoji_emotions_outlined,
                  color: const Color(0xFF667eea),
                ),
                onPressed: () {
                  setState(() {
                    _showEmojiPicker = !_showEmojiPicker;
                  });
                  if (!_showEmojiPicker) {
                    FocusScope.of(context).requestFocus(FocusNode());
                  }
                },
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  onChanged: _onTypingChanged,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  onTap: () {
                    if (_showEmojiPicker) {
                      setState(() {
                        _showEmojiPicker = false;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              color: Colors.white,
              size: 50,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Start the conversation!',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Say hi to ${_otherUserName} and start building your professional relationship',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.search, color: Color(0xFF667eea)),
                title: Text(
                  'Search Messages',
                  style: GoogleFonts.poppins(),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement search
                },
              ),
              ListTile(
                leading: const Icon(Icons.link_off, color: Colors.orange),
                title: Text(
                  'Disconnect',
                  style: GoogleFonts.poppins(color: Colors.orange),
                ),
                subtitle: Text(
                  'Remove connection & delete all messages',
                  style: GoogleFonts.poppins(fontSize: 11),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Disconnect?', style: GoogleFonts.poppins()),
                      content: Text(
                        'This will permanently disconnect you from ${_otherUserName} and delete all chat messages. You can reconnect by sharing your card again.',
                        style: GoogleFonts.poppins(),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text('Cancel', style: GoogleFonts.poppins()),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(
                            'Disconnect',
                            style: GoogleFonts.poppins(color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    final success = await ConnectionService()
                        .disconnect(widget.connection.id);
                    if (success && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Disconnected from ${_otherUserName}'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      Navigator.pop(context);
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(
                  'Delete Conversation',
                  style: GoogleFonts.poppins(color: Colors.red),
                ),
                subtitle: Text(
                  'Keep connection, only delete messages',
                  style: GoogleFonts.poppins(fontSize: 11),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Delete Conversation?',
                          style: GoogleFonts.poppins()),
                      content: Text(
                        'This will permanently delete all messages but keep your connection with ${_otherUserName}.',
                        style: GoogleFonts.poppins(),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text('Cancel', style: GoogleFonts.poppins()),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(
                            'Delete',
                            style: GoogleFonts.poppins(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    final success = await _messagingService
                        .deleteConversation(widget.connection.id);
                    if (success && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Conversation deleted'),
                        ),
                      );
                      Navigator.pop(context);
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
