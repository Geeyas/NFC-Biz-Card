import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/animated_gradient_container.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _selectedPeriod = 'Week';
  bool _isLoading = true;

  // Real-time data from Firebase
  Map<String, dynamic> _analyticsData = {
    'totalViews': 0,
    'uniqueViews': 0,
    'totalShares': 0,
    'totalScans': 0,
    'emailClicks': 0,
    'phoneClicks': 0,
    'websiteClicks': 0,
    'viewsGrowth': 0.0,
    'sharesGrowth': 0.0,
  };

  List<Map<String, dynamic>> _topCards = [];
  List<int> _weeklyViews = [0, 0, 0, 0, 0, 0, 0];

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ [Analytics] No user authenticated');
        setState(() => _isLoading = false);
        return;
      }

      final database = FirebaseDatabase.instance;
      final userId = user.uid;
      print('📋 [Analytics] Loading analytics for user ID: $userId');

      // Load global analytics from users/{userId}/analytics/globalStats
      final globalStatsRef =
          database.ref('users/$userId/analytics/globalStats');
      final globalSnapshot = await globalStatsRef.get();
      print(
          '📊 [Analytics] Global stats snapshot exists: ${globalSnapshot.exists}');

      if (globalSnapshot.exists) {
        final data = Map<String, dynamic>.from(globalSnapshot.value as Map);
        print('📊 [Analytics] Global stats data: $data');
        setState(() {
          _analyticsData = {
            'totalViews': data['totalViews'] ?? 0,
            'uniqueViews': data['uniqueViews'] ?? 0,
            'totalShares': data['totalShares'] ?? 0,
            'totalScans': data['totalScans'] ?? 0,
            'emailClicks': data['emailClicks'] ?? 0,
            'phoneClicks': data['phoneClicks'] ?? 0,
            'websiteClicks': data['websiteClicks'] ?? 0,
            'viewsGrowth': (data['viewsGrowth'] ?? 0.0).toDouble(),
            'sharesGrowth': (data['sharesGrowth'] ?? 0.0).toDouble(),
            'uniqueViewsGrowth': (data['uniqueViewsGrowth'] ?? 0.0).toDouble(),
            'scansGrowth': (data['scansGrowth'] ?? 0.0).toDouble(),
          };

          // Load weekly views
          if (data['weeklyViews'] != null) {
            _weeklyViews = List<int>.from(data['weeklyViews']);
          }
        });
      }

      // Load card stats from users/{userId}/analytics/cardStats
      final cardStatsRef = database.ref('users/$userId/analytics/cardStats');
      final cardStatsSnapshot = await cardStatsRef.get();
      print(
          '📊 [Analytics] Card stats snapshot exists: ${cardStatsSnapshot.exists}');

      List<Map<String, dynamic>> cardsList = [];

      if (cardStatsSnapshot.exists) {
        final cardStatsData =
            Map<String, dynamic>.from(cardStatsSnapshot.value as Map);
        print(
            '📊 [Analytics] Total cards with stats: ${cardStatsData.keys.length}');

        // Load card details from createdCards folder
        final createdCardsRef = database.ref('users/$userId/createdCards');
        final cardsSnapshot = await createdCardsRef.get();

        if (cardsSnapshot.exists) {
          final cardsData =
              Map<String, dynamic>.from(cardsSnapshot.value as Map);

          cardStatsData.forEach((cardId, statsValue) {
            if (statsValue is Map) {
              final stats = Map<String, dynamic>.from(statsValue);
              final cardData = cardsData[cardId];

              final businessName = cardData != null && cardData is Map
                  ? (cardData as Map)['businessName'] ?? 'Unknown'
                  : 'Unknown';

              final views = stats['views'] ?? 0;
              final shares = stats['shares'] ?? 0;
              final scans = stats['scans'] ?? 0;

              print(
                  '📊 [Analytics] Card: $businessName - Views: $views, Shares: $shares, Scans: $scans');

              cardsList.add({
                'id': cardId,
                'businessName': businessName,
                'views': views,
                'shares': shares,
                'scans': scans,
              });
            }
          });
        }

        print('📊 [Analytics] Total cards loaded: ${cardsList.length}');

        // Sort by views and take top 3
        cardsList
            .sort((a, b) => (b['views'] as int).compareTo(a['views'] as int));
        setState(() {
          _topCards = cardsList.take(3).toList();
        });
      }
    } catch (e) {
      print('❌ [Analytics] Error loading analytics: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ProfessionalAnimatedGradient(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              color: Colors.grey.shade800,
                              strokeWidth: 3,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Loading analytics...',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadAnalyticsData,
                        color: const Color(0xFF667eea),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildPeriodSelector(),
                              const SizedBox(height: 24),
                              _buildOverviewCards(),
                              const SizedBox(height: 24),
                              _buildViewsChart(),
                              const SizedBox(height: 24),
                              _buildEngagementStats(),
                              const SizedBox(height: 24),
                              _buildTopPerformingCards(),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: Colors.grey.shade800,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analytics',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Track your card performance',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final periods = ['Day', 'Week', 'Month', 'Year'];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: periods.map((period) {
          final isSelected = _selectedPeriod == period;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = period),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  period,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF6B7280),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOverviewCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Total Views',
                value: _analyticsData['totalViews'].toString(),
                icon: Icons.visibility,
                growth: _analyticsData['viewsGrowth'],
                gradientColors: [
                  const Color(0xFF667eea),
                  const Color(0xFF764ba2),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'Unique Views',
                value: _analyticsData['uniqueViews'].toString(),
                icon: Icons.person,
                growth: _analyticsData['uniqueViewsGrowth'] ?? 0.0,
                gradientColors: [
                  const Color(0xFF2ebf91),
                  const Color(0xFF8360c3),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Total Shares',
                value: _analyticsData['totalShares'].toString(),
                icon: Icons.share,
                growth: _analyticsData['sharesGrowth'],
                gradientColors: [
                  const Color(0xFFf093fb),
                  const Color(0xFFF5576C),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'QR Scans',
                value: _analyticsData['totalScans'].toString(),
                icon: Icons.qr_code,
                growth: _analyticsData['scansGrowth'] ?? 0.0,
                gradientColors: [
                  const Color(0xFF4facfe),
                  const Color(0xFF00f2fe),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required double growth,
    required List<Color> gradientColors,
  }) {
    // Ensure growth is a valid number
    final safeGrowth = growth.isFinite ? growth : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: safeGrowth >= 0
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      safeGrowth >= 0 ? Icons.trending_up : Icons.trending_down,
                      size: 14,
                      color: safeGrowth >= 0 ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${safeGrowth.abs()}%',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: safeGrowth >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewsChart() {
    final viewsData =
        _weeklyViews.isNotEmpty ? _weeklyViews : [0, 0, 0, 0, 0, 0, 0];
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxDataValue = viewsData.reduce((a, b) => a > b ? a : b).toDouble();
    final maxValue = maxDataValue > 0 ? maxDataValue * 1.2 + 10 : 100.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Views Over Time',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(viewsData.length, (index) {
                final value = viewsData[index];
                final heightPercent = value / maxValue;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          value.toString(),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF667eea),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: heightPercent * 130,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF667eea).withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          days[index],
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Engagement Breakdown',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 20),
          _buildEngagementItem(
            icon: Icons.email,
            label: 'Email Clicks',
            value: _analyticsData['emailClicks'],
            total: _analyticsData['emailClicks'] +
                _analyticsData['phoneClicks'] +
                _analyticsData['websiteClicks'],
            color: const Color(0xFF667eea),
          ),
          const SizedBox(height: 16),
          _buildEngagementItem(
            icon: Icons.phone,
            label: 'Phone Clicks',
            value: _analyticsData['phoneClicks'],
            total: _analyticsData['emailClicks'] +
                _analyticsData['phoneClicks'] +
                _analyticsData['websiteClicks'],
            color: const Color(0xFF2ebf91),
          ),
          const SizedBox(height: 16),
          _buildEngagementItem(
            icon: Icons.language,
            label: 'Website Clicks',
            value: _analyticsData['websiteClicks'],
            total: _analyticsData['emailClicks'] +
                _analyticsData['phoneClicks'] +
                _analyticsData['websiteClicks'],
            color: const Color(0xFF4facfe),
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementItem({
    required IconData icon,
    required String label,
    required int value,
    required int total,
    required Color color,
  }) {
    final percentage = total > 0 ? (value / total * 100).toInt() : 0;

    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$value clicks',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '$percentage%',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildTopPerformingCards() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Performing Cards',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          if (_topCards.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.analytics_outlined,
                      size: 48,
                      color: const Color(0xFF6B7280),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No cards yet',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Create your first card to see analytics',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF6B7280),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ...List.generate(_topCards.length, (index) {
              final card = _topCards[index];
              return Column(
                children: [
                  if (index > 0) const Divider(height: 24),
                  _buildCardPerformanceItem(
                    cardName: card['businessName'],
                    views: card['views'],
                    shares: card['shares'],
                    rank: index + 1,
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildCardPerformanceItem({
    required String cardName,
    required int views,
    required int shares,
    required int rank,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: rank == 1
                  ? [Color(0xFFFFD700), Color(0xFFFFA500)]
                  : rank == 2
                      ? [Color(0xFFC0C0C0), Color(0xFF808080)]
                      : [Color(0xFFCD7F32), Color(0xFF8B4513)],
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$rank',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cardName,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.visibility,
                      size: 14, color: const Color(0xFF6B7280)),
                  const SizedBox(width: 4),
                  Text(
                    '$views views',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.share, size: 14, color: const Color(0xFF6B7280)),
                  const SizedBox(width: 4),
                  Text(
                    '$shares shares',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
