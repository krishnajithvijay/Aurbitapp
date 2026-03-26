import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../community/community_feed_screen.dart';
import 'create_community_screen.dart';
import '../services/community_service.dart';
import '../services/user_activity_service.dart';
import '../web/aurbit_web_theme.dart'; // AurbitWebTheme tokens

class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> {
  Set<String> _joinedCommunityIds = {};
  Set<String> _mutedCommunityIds = {};
  List<Map<String, dynamic>> _communities = [];
  bool _isLoading = true;
  
  // Search State
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Filter State
  String _selectedFilter = 'Most Popular';
  final List<String> _filterOptions = ['New', 'Most Popular', 'Most Active', 'Least Active'];

  // ── Today's Vibe state ─────────────────────────────────────────────────────
  late final DateTime _sessionStart;
  Timer? _vibeTimer;
  Duration _timeActive = Duration.zero;
  String _dominantMood = '—';
  String _dominantMoodEmoji = '😐';
  int _newConnectionsToday = 0;

  late final RealtimeChannel _communitiesChannel;

  @override
  void initState() {
    super.initState();
    _fetchCommunities();
    _subscribeToCommunities();
    _fetchVibeStats();

    _sessionStart = DateTime.now();
    _vibeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _timeActive = DateTime.now().difference(_sessionStart));
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _vibeTimer?.cancel();
    Supabase.instance.client.removeChannel(_communitiesChannel);
    super.dispose();
  }

  void _subscribeToCommunities() {
    _communitiesChannel = Supabase.instance.client
        .channel('public:communities')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'communities',
          callback: (payload) {
             // In a real app we might want to be careful about inserting if it doesn't match filter
             // For now, simpler to just re-fetch or insert at top
             _fetchCommunities();
          },
        )
        .subscribe();
  }

  Future<void> _fetchCommunities() async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      // Start the query
      var query = client.from('communities').select();

      // Apply Search Filter
      if (_searchQuery.isNotEmpty) {
        query = query.ilike('name', '%$_searchQuery%');
      }

      // Apply Sorting
      // note: .order() returns a TransformBuilder, so we need to capture that result
      // We declare a final future because we can't assign TransformBuilder back to FilterBuilder easily if typed strictly,
      // but 'var' should handle it if we don't try to re-use it as a FilterBuilder later.
      // However, the error says we ARE re-assigning.
      
      PostgrestTransformBuilder<List<Map<String, dynamic>>> sortedQuery;

      switch (_selectedFilter) {
        case 'New':
          sortedQuery = query.order('created_at', ascending: false);
          break;
        case 'Most Active':
          sortedQuery = query.order('active_count', ascending: false);
          break;
        case 'Least Active':
          sortedQuery = query.order('active_count', ascending: true);
          break;
        case 'Most Popular':
        default:
          sortedQuery = query.order('members_count', ascending: false);
          break;
      }

      // Fetch communities, memberships, and muted status in parallel
      final futures = await Future.wait([
        sortedQuery,
        if (userId != null) ...[
          client.from('community_members').select('community_id').eq('user_id', userId),
          client.from('muted_communities').select('community_id').eq('user_id', userId),
        ] else ...[
          Future.value([]),
          Future.value([]),
        ]
      ]);

      final communitiesComp = futures[0] as List<dynamic>;
      final membershipsComp = futures[1] as List<dynamic>;
      final mutedComp = futures[2] as List<dynamic>;

      // Prepare initial data
      var fetchedCommunities = List<Map<String, dynamic>>.from(communitiesComp);
      final joinedIds = membershipsComp.map((m) => m['community_id'] as String).toSet();
      final mutedIds = mutedComp.map((m) => m['community_id'] as String).toSet();

      // Fetch avatars and member counts in parallel
      final ids = fetchedCommunities.map((c) => c['id'] as String).toList();
      if (ids.isNotEmpty) {
         try {
           final avatarsFuture = client.rpc('get_community_avatars', params: {'community_ids': ids});
           
           // Fetch member counts and active counts for each community
           final countsFutures = fetchedCommunities.map((c) async {
              final count = await client
                  .from('community_members')
                  .count()
                  .eq('community_id', c['id']);
              c['real_members_count'] = count;
              
              // Fetch real active count
              final activeCount = await UserActivityService().getActiveCommunityMembers(c['id'] as String);
              c['active_count'] = activeCount;
           });

           // Run both groups of tasks in parallel
           final results = await Future.wait<dynamic>([
             avatarsFuture,
             Future.wait(countsFutures),
           ]);
           
           // Handle avatars
           final avatarsData = results[0];
           if (avatarsData is List) {
             final avatarMap = {for (var item in avatarsData) item['community_id']: item['avatar_urls']};
             for (var c in fetchedCommunities) {
               c['preview_avatars'] = avatarMap[c['id']] ?? [];
             }
           }
         } catch (e) {
           debugPrint('Error fetching metadata: $e');
         }
      }
      
      if (mounted) {
        setState(() {
          _communities = fetchedCommunities;
          _joinedCommunityIds = joinedIds;
          _mutedCommunityIds = mutedIds;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching communities: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLeaveCommunity(Map<String, dynamic> community) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    // Check if creator
    final createdBy = community['created_by'];
    if (createdBy == userId) {
       await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Leave Community'),
          content: const Text('As the creator of this community, you cannot leave it. You can only delete the community from the settings menu.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Leave ${community['name']}?'),
        content: const Text('Are you sure you want to leave this community?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (shouldLeave == true) {
       try {
        await client
          .from('community_members')
          .delete()
          .match({
            'community_id': community['id'],
            'user_id': userId,
          });

        if (mounted) {
          setState(() {
            _joinedCommunityIds.remove(community['id']);
            // Optimistically update member count loosely or re-fetch?
            // Re-fetch is safer but slower. Let's re-fetch.
          });
          _fetchCommunities();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Left ${community['name']}')),
          );
        }
       } catch (e) {
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error leaving community: $e')),
            );
         }
       }
    }
  }

  void _showCommunityOptions(Map<String, dynamic> community) async {
    final CommunityService communityService = CommunityService();
    // Check if muted
    bool isMuted = false;
    try {
       isMuted = await communityService.isCommunityMuted(community['id']);
    } catch (_) {}
    
    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Container(
                     width: 40, 
                     height: 4, 
                     margin: const EdgeInsets.only(bottom: 20),
                     decoration: BoxDecoration(
                       color: isDark ? Colors.grey[700] : Colors.grey[300],
                       borderRadius: BorderRadius.circular(2)
                     )
                   ),
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 24),
                     child: Text(
                       community['name'] ?? 'Community Options',
                       style: GoogleFonts.inter(
                         fontSize: 18, 
                         fontWeight: FontWeight.bold,
                         color: isDark ? Colors.white : Colors.black
                       ),
                       textAlign: TextAlign.center,
                     ),
                   ),
                   const SizedBox(height: 24),
                   ListTile(
                     contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                     leading: Container(
                       padding: const EdgeInsets.all(8),
                       decoration: BoxDecoration(
                         color: isDark ? Colors.grey[800] : Colors.grey[100],
                         shape: BoxShape.circle,
                       ),
                       child: Icon(
                         isMuted ? Icons.notifications_off_outlined : Icons.notifications_active_outlined,
                         color: isMuted ? Colors.red : (isDark ? Colors.white : Colors.black),
                         size: 20,
                       ),
                     ),
                     title: Text(
                       isMuted ? 'Unmute Notifications' : 'Mute Notifications',
                       style: GoogleFonts.inter(
                         fontSize: 16, 
                         fontWeight: FontWeight.w500,
                         color: isDark ? Colors.white : Colors.black
                       ),
                     ),
                     onTap: () async {
                       Navigator.pop(context); // Close sheet
                       if (isMuted) {
                         await communityService.unmuteCommunity(community['id']);
                         if (mounted) {
                            setState(() {
                              _mutedCommunityIds.remove(community['id']);
                            });
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unmuted ${community['name']}')));
                         }
                       } else {
                         await communityService.muteCommunity(community['id']);
                         if (mounted) {
                            setState(() {
                              _mutedCommunityIds.add(community['id']);
                            });
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Muted ${community['name']}')));
                         }
                       }
                     },
                   ),
                   ListTile(
                     contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                     leading: Container(
                       padding: const EdgeInsets.all(8),
                       decoration: BoxDecoration(
                         color: isDark ? Colors.grey[800] : Colors.grey[100],
                         shape: BoxShape.circle,
                       ),
                       child: Icon(
                         Icons.logout,
                         color: isDark ? Colors.white : Colors.black,
                         size: 20,
                       ),
                     ),
                     title: Text(
                       'Leave Community',
                       style: GoogleFonts.inter(
                         fontSize: 16,
                         fontWeight: FontWeight.w500,
                         color: isDark ? Colors.white : Colors.black
                       ),
                     ),
                     onTap: () {
                       Navigator.pop(context); // Close sheet
                       _handleLeaveCommunity(community);
                     },
                   ),
                   if (community['created_by'] == Supabase.instance.client.auth.currentUser?.id)
                     ListTile(
                       contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                       leading: Container(
                         padding: const EdgeInsets.all(8),
                         decoration: BoxDecoration(
                           color: isDark ? Colors.grey[800] : Colors.grey[100],
                           shape: BoxShape.circle,
                         ),
                         child: const Icon(
                           Icons.delete_outline,
                           color: Colors.red,
                           size: 20,
                         ),
                       ),
                       title: Text(
                         'Delete Community',
                         style: GoogleFonts.inter(
                           fontSize: 16,
                           fontWeight: FontWeight.w500,
                           color: Colors.red
                         ),
                       ),
                       onTap: () {
                         Navigator.pop(context); // Close sheet
                         // TODO: Implement delete community logic
                         ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text('Delete Community functionality not yet implemented.')),
                         );
                       },
                     ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchQuery = '';
        _searchController.clear();
        _fetchCommunities();
      }
    });
  }

  void _onSearchChanged(String value) {
    // Debounce could be added here
    setState(() {
      _searchQuery = value;
    });
    _fetchCommunities();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    // On Web, use the web layout logic; on mobile app, use mobile body
    final bool useWebLayout = kIsWeb;
    final bool showRightSidebar = screenWidth >= 1100;
    
    final Color textColor   = useWebLayout ? (isDark ? AurbitWebTheme.darkText    : AurbitWebTheme.lightText)    : (isDark ? Colors.white : Colors.black);
    final Color secondaryTextColor = useWebLayout ? (isDark ? AurbitWebTheme.darkSubtext : AurbitWebTheme.lightSubtext) : (isDark ? Colors.grey[400]! : Colors.grey[600]!);
    final Color cardColor   = useWebLayout ? (isDark ? AurbitWebTheme.darkCard    : AurbitWebTheme.lightCard)    : (isDark ? const Color(0xFF1E1E1E) : Colors.white);
    final Color borderColor = useWebLayout ? (isDark ? AurbitWebTheme.darkBorder  : AurbitWebTheme.lightBorder)  : (isDark ? Colors.grey[800]! : Colors.grey[200]!);
    final Color accent      = AurbitWebTheme.accentPrimary;

    return Scaffold(
      backgroundColor: useWebLayout ? (isDark ? AurbitWebTheme.darkBg : AurbitWebTheme.lightBg) : Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: (useWebLayout && !showRightSidebar) ? FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateCommunityScreen()),
          );
          if (created == true) {
            _fetchCommunities();
          }
        },
        backgroundColor: accent,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ) : null,
      body: useWebLayout 
          ? _buildWebLayout(context, isDark, textColor, secondaryTextColor, cardColor, borderColor, accent, showRightSidebar) 
          : _buildMobileBody(accent, secondaryTextColor, cardColor, borderColor, textColor),
    );
  }

  Widget _buildMobileBody(Color accent, Color secondaryTextColor, Color cardColor, Color borderColor, Color textColor) {
    return _isLoading 
        ? Center(child: CircularProgressIndicator(color: accent))
        : _communities.isEmpty
          ? Center(
              child: Text(
                _searchQuery.isNotEmpty ? 'No communities found matching "$_searchQuery"' : 'No communities found',
                style: GoogleFonts.inter(color: secondaryTextColor),
              ),
            )
          : RefreshIndicator(
            onRefresh: _fetchCommunities,
            child: ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: _communities.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) => _buildCommunityCard(_communities[index], cardColor, borderColor, textColor, secondaryTextColor),
            ),
          );
  }

  Widget _buildWebLayout(BuildContext context, bool isDark, Color textColor, Color secondaryTextColor, Color cardColor, Color borderColor, Color accent, bool showRightSidebar) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Content (Center)
        Expanded(
          flex: 7,
          child: Column(
            children: [
              if (!showRightSidebar)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AurbitWebTheme.darkTopbar : AurbitWebTheme.lightTopbar,
                    border: Border(bottom: BorderSide(color: borderColor)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_rounded, color: textColor),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Text('Communities', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
                    ],
                  ),
                ),
              Expanded(
                child: _isLoading 
                  ? Center(child: CircularProgressIndicator(color: accent))
                  : _communities.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isNotEmpty ? 'No communities found matching "$_searchQuery"' : 'No communities found',
                          style: GoogleFonts.inter(color: secondaryTextColor),
                        ),
                      )
                    : Scrollbar(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                          itemCount: _communities.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            return Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 800),
                                child: _buildCommunityCard(_communities[index], cardColor, borderColor, textColor, secondaryTextColor),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),

        // Right Sidebar
        if (showRightSidebar)
          Container(
            width: 320,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: borderColor)),
              color: isDark ? AurbitWebTheme.darkSidebar : AurbitWebTheme.lightSidebar,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sidebarCard('Create a Community', 'Build your own space for the things you love.', 
                    isDark, cardColor, borderColor, textColor, secondaryTextColor, 
                    buttonLabel: 'Create New', 
                    onBtnTap: () async {
                      final created = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CreateCommunityScreen()),
                      );
                      if (created == true) {
                        _fetchCommunities();
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _sidebarCard(
                    'Today\'s Vibe',
                    'Live session stats',
                    isDark, cardColor, borderColor, textColor, secondaryTextColor,
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        _buildVibeStatRow(
                          icon: Icons.access_time_rounded,
                          iconColor: AurbitWebTheme.accentPrimary,
                          label: 'Time Active',
                          value: _formatDuration(_timeActive),
                          isDark: isDark, textColor: textColor, subColor: secondaryTextColor,
                        ),
                        const SizedBox(height: 12),
                        _buildVibeStatRow(
                          icon: Icons.mood_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          label: 'Most Active Mood',
                          value: '$_dominantMoodEmoji $_dominantMood',
                          isDark: isDark, textColor: textColor, subColor: secondaryTextColor,
                        ),
                        const SizedBox(height: 12),
                        _buildVibeStatRow(
                          icon: Icons.group_add_rounded,
                          iconColor: const Color(0xFF10B981),
                          label: 'New Connections',
                          value: _newConnectionsToday == 0 ? 'None today' : '+$_newConnectionsToday today',
                          isDark: isDark, textColor: textColor, subColor: secondaryTextColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sidebarCard('Community Guidelines', '1. Be respectful\n2. No spam\n3. Keep it mindful', 
                    isDark, cardColor, borderColor, textColor, secondaryTextColor
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'TRENDING NOW',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: secondaryTextColor,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...[
                    ('🚀', 'Tech Enthusiasts', '12k'),
                    ('🌱', 'Sustainable Life', '8.4k'),
                    ('☕', 'Coffee Lovers', '5.1k'),
                  ].map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: borderColor.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Center(child: Text(t.$1, style: const TextStyle(fontSize: 14))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.$2, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
                              Text('${t.$3} members', style: GoogleFonts.inter(fontSize: 11, color: secondaryTextColor)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _sidebarCard(String title, String content, bool isDark, Color cardColor, Color borderColor, Color textColor, Color secondaryTextColor, {String? buttonLabel, VoidCallback? onBtnTap, Widget? child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 8),
          Text(content, style: GoogleFonts.inter(fontSize: 13, color: secondaryTextColor, height: 1.5)),
          if (child != null) child,
          if (buttonLabel != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onBtnTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AurbitWebTheme.accentPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(buttonLabel, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Vibe stats ──────────────────────────────────────────────────────────────
  Future<void> _fetchVibeStats() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final todayStart = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day)
        .toUtc()
        .toIso8601String();

    try {
      final moodLogs = await Supabase.instance.client
          .from('mood_logs')
          .select('mood')
          .eq('user_id', userId)
          .gte('created_at', todayStart);

      if (moodLogs != null && (moodLogs as List).isNotEmpty) {
        final counts = <String, int>{};
        for (final log in moodLogs) {
          final m = log['mood']?.toString() ?? 'Neutral';
          counts[m] = (counts[m] ?? 0) + 1;
        }
        final dominant = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
        if (mounted) {
          setState(() {
            _dominantMood = dominant;
            _dominantMoodEmoji = _getMoodEmojiForVibe(dominant);
          });
        }
      }

      final newConns = await Supabase.instance.client
          .from('user_orbits')
          .select('friend_id')
          .eq('user_id', userId)
          .gte('created_at', todayStart);

      if (mounted) {
        setState(() {
          _newConnectionsToday = (newConns as List).length;
          _timeActive = DateTime.now().difference(_sessionStart);
        });
      }
    } catch (e) {
      debugPrint('Error fetching vibe stats: $e');
    }
  }

  String _getMoodEmojiForVibe(String mood) {
    switch (mood) {
      case 'Happy': return '🤩';
      case 'Sad': return '😢';
      case 'Tired': return '😴';
      case 'Irritated': return '😤';
      case 'Lonely': return '😶‍🌫️';
      case 'Bored': return '😑';
      case 'Peaceful': return '😌';
      case 'Grateful': return '🙏';
      default: return '😐';
    }
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes < 1) return 'Just started';
    if (d.inHours < 1) return '${d.inMinutes}m';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  Widget _buildVibeStatRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required bool isDark,
    required Color textColor,
    required Color subColor,
  }) {
    final rowBg = isDark ? const Color(0xFF252530) : const Color(0xFFF8F9FB);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 11, color: subColor, fontWeight: FontWeight.w500),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityCard(Map<String, dynamic> community, Color cardColor, Color borderColor, Color textColor, Color secondaryTextColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AurbitWebTheme.accentPrimary;
    return GestureDetector(
      onLongPress: () => _showCommunityOptions(community),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CommunityFeedScreen(
              community: community,
            ),
          ),
        ).then((_) => _fetchCommunities()); // Refresh on return
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: Icon + Title + Trending
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Community Icon
                _buildCommunityAvatar(community['preview_avatars'] as List<dynamic>? ?? [], isDark),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  community['name'] ?? 'Unnamed',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (community['username'] != null)
                                  Text(
                                    'c/${community['username']}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AurbitWebTheme.accentPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (community['active_count'] != null && (community['active_count'] as int) > 5)
                            const Icon(Icons.trending_up, size: 16, color: Colors.green),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (community['bio'] != null && community['bio'].toString().isNotEmpty)
                        Text(
                          community['bio'],
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: secondaryTextColor,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (_mutedCommunityIds.contains(community['id']))
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(Icons.notifications_off_outlined, size: 20, color: secondaryTextColor),
                  ),
              ],
            ),
            
            const SizedBox(height: 16),

            // Stats Row
            Row(
              children: [
                Icon(Icons.people_outline, size: 14, color: secondaryTextColor),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${community['real_members_count'] ?? community['members_count'] ?? 0} members',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: secondaryTextColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if ((community['active_count'] ?? 0) > 0) ...[
                  const SizedBox(width: 12),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[400] : Colors.grey[800],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${community['active_count']} active now',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // Join/Joined Button
            SizedBox(
              height: 44,
              child: Builder(
                builder: (context) {
                  final isJoined = _joinedCommunityIds.contains(community['id']);
                  return ElevatedButton(
                    onPressed: () {
                      if (isJoined) {
                        _handleLeaveCommunity(community);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CommunityFeedScreen(
                              community: community,
                            ),
                          ),
                        ).then((_) => _fetchCommunities()); // Refresh on return
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isJoined 
                          ? Colors.transparent 
                          : accent,
                      foregroundColor: isJoined 
                          ? (isDark ? AurbitWebTheme.darkText : AurbitWebTheme.lightText)
                          : Colors.white,
                      elevation: 0,
                      side: isJoined ? BorderSide(color: borderColor) : BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isJoined ? 'Joined ✓' : 'Join Community',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isJoined 
                            ? (isDark ? AurbitWebTheme.darkText : AurbitWebTheme.lightText)
                            : Colors.white, 
                      ),
                    ),
                  );
                }
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityAvatar(List<dynamic> avatars, bool isDark) {
    if (avatars.isEmpty) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.people_outline, color: isDark ? Colors.grey[400] : Colors.grey[800], size: 24),
      );
    }

    final count = avatars.length > 4 ? 4 : avatars.length;
    
    return Container(
       width: 48,
       height: 48,
       decoration: BoxDecoration(
         color: isDark ? Colors.grey[800] : Colors.grey[200],
         borderRadius: BorderRadius.circular(12),
       ),
       clipBehavior: Clip.hardEdge,
       child: count == 1 
         ? _buildSingleAvatar(avatars[0], 48)
         : Wrap(
             children: List.generate(count, (index) {
                final double size = 24; 
                return SizedBox(
                  width: size, 
                  height: size, 
                  child: _buildSingleAvatar(avatars[index], size)
                );
             }),
           ),
    );
  }

  Widget _buildSingleAvatar(String url, double size) {
     if (url.contains('.svg') || url.contains('dicebear')) {
       return SvgPicture.network(url, width: size, height: size, fit: BoxFit.cover, excludeFromSemantics: true);
     }
     return Image.network(url, width: size, height: size, fit: BoxFit.cover);
  }
}
