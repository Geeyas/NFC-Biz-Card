import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:badges/badges.dart' as badges;
import 'package:timeago/timeago.dart' as timeago;
import 'package:cardflow/services/connection_service.dart';
import 'package:cardflow/services/messaging_service.dart';
import 'package:cardflow/screens/chat_screen.dart';
import '../widgets/animated_gradient_container.dart';

class MyConnectionsScreen extends StatefulWidget {
  const MyConnectionsScreen({Key? key}) : super(key: key);

  @override
  State<MyConnectionsScreen> createState() => _MyConnectionsScreenState();
}

class _MyConnectionsScreenState extends State<MyConnectionsScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final ConnectionService _connectionService = ConnectionService();
  final MessagingService _messagingService = MessagingService();

  late TabController _tabController;
  String _searchQuery = '';

  // Cache streams to prevent recreation
  late Stream<List<Connection>> _myConnectionsStream;
  late Stream<List<Connection>> _pendingRequestsStream;
  late Stream<List<Connection>> _sentRequestsStream;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Initialize streams once
    _myConnectionsStream =
        _connectionService.getMyConnections().asBroadcastStream();
    _pendingRequestsStream =
        _connectionService.getPendingRequests().asBroadcastStream();
    _sentRequestsStream =
        _connectionService.getSentRequests().asBroadcastStream();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
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
        title: Text(
          'My Connections',
          style: GoogleFonts.poppins(
            color: Colors.grey.shade800,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              onPressed: () {
                // Settings or filter - show bottom sheet
                showModalBottomSheet(
                  context: context,
                  builder: (context) => Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Filter Options',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ListTile(
                          leading: const Icon(Icons.sort),
                          title: const Text('Sort by Name'),
                          onTap: () => Navigator.pop(context),
                        ),
                        ListTile(
                          leading: const Icon(Icons.access_time),
                          title: const Text('Sort by Recent'),
                          onTap: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                );
              },
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
                child: Icon(Icons.tune, color: Colors.grey.shade800, size: 20),
              ),
            ),
          ),
        ],
      ),
      body: ProfessionalAnimatedGradient(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20), // Space after AppBar
              _buildStatsCard(),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMyConnectionsTab(),
                    _buildPendingRequestsTab(),
                    _buildSentRequestsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return FutureBuilder<Map<String, int>>(
      future: _connectionService.getConnectionStats(),
      builder: (context, snapshot) {
        final stats =
            snapshot.data ?? {'total': 0, 'pending': 0, 'thisMonth': 0};

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GlassmorphicContainer(
            width: double.infinity,
            height: 130, // Increased from 120 to fix overflow
            borderRadius: 20,
            blur: 20,
            alignment: Alignment.center,
            border: 2,
            linearGradient: LinearGradient(
              colors: [
                const Color(0xFF667eea).withOpacity(0.1),
                const Color(0xFF764ba2).withOpacity(0.05),
              ],
            ),
            borderGradient: LinearGradient(
              colors: [
                const Color(0xFF667eea).withOpacity(0.5),
                const Color(0xFF764ba2).withOpacity(0.3),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 15), // Adjusted padding
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.people,
                      label: 'Total',
                      value: '${stats['total']}',
                      color: const Color(0xFF667eea),
                    ),
                  ),
                  Container(width: 1, height: 50, color: Colors.grey.shade300),
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.hourglass_empty,
                      label: 'Pending',
                      value: '${stats['pending']}',
                      color: const Color(0xFFf39c12),
                    ),
                  ),
                  Container(width: 1, height: 50, color: Colors.grey.shade300),
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.trending_up,
                      label: 'This Month',
                      value: '${stats['thisMonth']}',
                      color: const Color(0xFF2ebf91),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 28), // Slightly smaller icon
        const SizedBox(height: 4), // Reduced spacing
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 22, // Slightly smaller font
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 2), // Added spacing between value and label
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11, // Slightly smaller font
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF667eea),
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: const Color(0xFF667eea),
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Connected'),
          Tab(text: 'Requests'),
          Tab(text: 'Sent'),
        ],
      ),
    );
  }

  Widget _buildMyConnectionsTab() {
    return KeepAlive(
      child: StreamBuilder<List<Connection>>(
        stream: _myConnectionsStream, // Use cached stream
        builder: (context, snapshot) {
          // Show loading only on initial load (no data yet)
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Show empty state if no data after loading
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState(
              icon: Icons.people_outline,
              title: 'No Connections Yet',
              subtitle: 'Start connecting with people you meet!',
            );
          }

          // Filter connections based on search query
          final connections = snapshot.data!.where((conn) {
            if (_searchQuery.isEmpty) return true;
            final name =
                conn.getOtherUserName(_connectionService.currentUserId!);
            return name.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();

          return Column(
            children: [
              _buildSearchBar(),
              Expanded(
                child: connections.isEmpty && _searchQuery.isNotEmpty
                    ? _buildEmptyState(
                        icon: Icons.search_off,
                        title: 'No Results',
                        subtitle: 'Try a different search term',
                      )
                    : AnimationLimiter(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: connections.length,
                          itemBuilder: (context, index) {
                            return AnimationConfiguration.staggeredList(
                              position: index,
                              duration: const Duration(milliseconds: 375),
                              child: SlideAnimation(
                                verticalOffset: 50.0,
                                child: FadeInAnimation(
                                  child:
                                      _buildConnectionCard(connections[index]),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPendingRequestsTab() {
    return KeepAlive(
      child: StreamBuilder<List<Connection>>(
        stream: _pendingRequestsStream, // Use cached stream
        builder: (context, snapshot) {
          // Show loading only on initial load (no data yet)
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState(
              icon: Icons.inbox,
              title: 'No Pending Requests',
              subtitle: 'You\'ll see connection requests here',
            );
          }

          return AnimationLimiter(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                return AnimationConfiguration.staggeredList(
                  position: index,
                  duration: const Duration(milliseconds: 375),
                  child: SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(
                      child: _buildRequestCard(snapshot.data![index]),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSentRequestsTab() {
    return KeepAlive(
      child: StreamBuilder<List<Connection>>(
        stream: _sentRequestsStream, // Use cached stream
        builder: (context, snapshot) {
          // Show loading only on initial load (no data yet)
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState(
              icon: Icons.send,
              title: 'No Sent Requests',
              subtitle: 'Connection requests you send will appear here',
            );
          }

          return AnimationLimiter(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                return AnimationConfiguration.staggeredList(
                  position: index,
                  duration: const Duration(milliseconds: 375),
                  child: SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(
                      child: _buildSentRequestCard(snapshot.data![index]),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search connections...',
          hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildConnectionCard(Connection connection) {
    final currentUserId = _connectionService.currentUserId!;

    // Get the other user's name and photo from connection
    // These are now populated from the business card data
    String otherUserName = connection.getOtherUserName(currentUserId);
    String? otherUserPhoto = connection.getOtherUserPhoto(currentUserId);

    // Debug logging
    debugPrint('🔍 [ConnectionCard] Connection ID: ${connection.id}');
    debugPrint(
        '🔍 [ConnectionCard] Initiator: ${connection.initiatorName} (${connection.initiatorId})');
    debugPrint(
        '🔍 [ConnectionCard] Recipient: ${connection.recipientName} (${connection.recipientId})');
    debugPrint('🔍 [ConnectionCard] Current User: $currentUserId');
    debugPrint('🔍 [ConnectionCard] Other User Name: $otherUserName');
    debugPrint('🔍 [ConnectionCard] Other User Photo: $otherUserPhoto');

    // Fallback for empty names (shouldn't happen with card-based approach)
    if (otherUserName.isEmpty) {
      otherUserName = 'Business Card';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: GlassmorphicContainer(
        width: double.infinity,
        height: 100,
        borderRadius: 20,
        blur: 20,
        alignment: Alignment.center,
        border: 2,
        linearGradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.9),
            Colors.white.withOpacity(0.8),
          ],
        ),
        borderGradient: LinearGradient(
          colors: [
            const Color(0xFF667eea).withOpacity(0.3),
            const Color(0xFF764ba2).withOpacity(0.2),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              // Avatar with online status
              Stack(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage:
                        otherUserPhoto != null && otherUserPhoto.isNotEmpty
                            ? NetworkImage(otherUserPhoto)
                            : null,
                    backgroundColor: const Color(0xFF667eea),
                    child: otherUserPhoto == null || otherUserPhoto.isEmpty
                        ? Text(
                            otherUserName.isNotEmpty
                                ? otherUserName[0].toUpperCase()
                                : '?',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  // Online status indicator (placeholder)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2ebf91),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 15),
              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      otherUserName.isNotEmpty ? otherUserName : 'Unknown User',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      connection.connectedAt != null
                          ? 'Connected ${timeago.format(connection.connectedAt!)}'
                          : 'Connected recently',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              // Action buttons with unread badge
              StreamBuilder<int>(
                stream: _messagingService.getUnreadCount(connection.id),
                builder: (context, snapshot) {
                  final unreadCount = snapshot.data ?? 0;

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                connection: connection,
                              ),
                            ),
                          );
                        },
                        icon: unreadCount > 0
                            ? badges.Badge(
                                badgeContent: Text(
                                  '$unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                                child: const Icon(Icons.chat_bubble_outline),
                              )
                            : const Icon(Icons.chat_bubble_outline),
                        color: const Color(0xFF667eea),
                      ),
                      IconButton(
                        onPressed: () => _showDisconnectDialog(connection),
                        icon: const Icon(Icons.link_off),
                        color: Colors.orange,
                        tooltip: 'Disconnect',
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDisconnectDialog(Connection connection) async {
    final otherUserName =
        connection.getOtherUserName(_connectionService.currentUserId!);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Disconnect from $otherUserName?',
            style: GoogleFonts.poppins()),
        content: Text(
          'This will permanently remove your connection with $otherUserName and delete all chat messages. You can reconnect by sharing your card again.',
          style: GoogleFonts.poppins(fontSize: 14),
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
              style: GoogleFonts.poppins(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _connectionService.disconnect(connection.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Disconnected from $otherUserName'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to disconnect. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Widget _buildRequestCard(Connection connection) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GlassmorphicContainer(
            width: double.infinity,
            height: 200, // Increased fixed height
            borderRadius: 20,
            blur: 20,
            alignment: Alignment.center,
            border: 2,
            linearGradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.9),
                Colors.white.withOpacity(0.8),
              ],
            ),
            borderGradient: LinearGradient(
              colors: [
                const Color(0xFFf39c12).withOpacity(0.3),
                const Color(0xFFe67e22).withOpacity(0.2),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: connection.initiatorPhoto != null
                            ? NetworkImage(connection.initiatorPhoto!)
                            : null,
                        child: connection.initiatorPhoto == null
                            ? Text(
                                connection.initiatorName[0].toUpperCase(),
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                        backgroundColor: const Color(0xFFf39c12),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              connection.initiatorName,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              timeago.format(connection.requestedAt),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (connection.requestNote != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      connection.requestNote!,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final success = await _connectionService
                                .acceptConnectionRequest(connection.id);
                            if (success && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Connected with ${connection.initiatorName}!'),
                                  backgroundColor: const Color(0xFF2ebf91),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Accept'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2ebf91),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final success = await _connectionService
                                .declineConnectionRequest(connection.id);
                            if (success && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Request declined'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Decline'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(color: Colors.grey.shade400),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSentRequestCard(Connection connection) {
    // Debug logging
    debugPrint('🔍 [SentRequestCard] Connection ID: ${connection.id}');
    debugPrint('🔍 [SentRequestCard] Recipient ID: ${connection.recipientId}');
    debugPrint(
        '🔍 [SentRequestCard] Recipient Name: ${connection.recipientName}');
    debugPrint(
        '🔍 [SentRequestCard] Recipient Photo: ${connection.recipientPhoto}');

    // Get name and photo from connection (populated from business card)
    String recipientName = connection.recipientName.isNotEmpty
        ? connection.recipientName
        : 'Business Card';
    String? recipientPhoto = connection.recipientPhoto;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: GlassmorphicContainer(
        width: double.infinity,
        height: 90,
        borderRadius: 20,
        blur: 20,
        alignment: Alignment.center,
        border: 2,
        linearGradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.9),
            Colors.white.withOpacity(0.8),
          ],
        ),
        borderGradient: LinearGradient(
          colors: [
            Colors.grey.shade400.withOpacity(0.3),
            Colors.grey.shade300.withOpacity(0.2),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage:
                    recipientPhoto != null && recipientPhoto.isNotEmpty
                        ? NetworkImage(recipientPhoto)
                        : null,
                child: recipientPhoto == null || recipientPhoto.isEmpty
                    ? Text(
                        recipientName.isNotEmpty
                            ? recipientName[0].toUpperCase()
                            : '?',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : null,
                backgroundColor: Colors.grey.shade600,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      recipientName,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.hourglass_empty,
                            size: 12, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          'Pending',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                timeago.format(connection.requestedAt),
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 20),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// KeepAlive wrapper widget to preserve tab state
class KeepAlive extends StatefulWidget {
  final Widget child;

  const KeepAlive({Key? key, required this.child}) : super(key: key);

  @override
  State<KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
