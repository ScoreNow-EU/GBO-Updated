import 'package:flutter/material.dart';
import '../models/team.dart';
import '../models/club.dart';
import '../services/team_service.dart';
import '../services/club_service.dart';
import '../utils/responsive_helper.dart';
import '../widgets/team_avatar.dart';
import '../data/german_cities.dart';
import 'club_management_screen.dart';
import 'team_club_migration_screen.dart';

class TeamManagementScreen extends StatefulWidget {
  const TeamManagementScreen({super.key});

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  final TeamService _teamService = TeamService();
  final ClubService _clubService = ClubService();
  
  List<Club> _clubs = [];
  Map<String, List<Team>> _teamsByClub = {};
  List<Team> _orphanedTeams = [];
  String _searchQuery = '';
  String _filterDivision = 'Alle';
  Club? _selectedClub;
  bool _isLoading = true;
  bool _showOrphanedTeams = false;

  // Available divisions
  final List<String> _divisions = [
    'Women\'s U14',
    'Women\'s U16',
    'Women\'s U18',
    'Women\'s Seniors',
    'Women\'s FUN',
    'Men\'s U14',
    'Men\'s U16',
    'Men\'s U18',
    'Men\'s Seniors',
    'Men\'s FUN',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final clubs = await _clubService.getClubs().first;
      final teams = await _teamService.getTeams().first;
      
      Map<String, List<Team>> teamsByClub = {};
      List<Team> orphanedTeams = [];
      
      // Group teams by club
      for (final team in teams) {
        if (team.clubId != null) {
          if (!teamsByClub.containsKey(team.clubId)) {
            teamsByClub[team.clubId!] = [];
          }
          teamsByClub[team.clubId!]!.add(team);
        } else {
          orphanedTeams.add(team);
        }
      }
      
          setState(() {
        _clubs = clubs;
        _teamsByClub = teamsByClub;
        _orphanedTeams = orphanedTeams;
        _isLoading = false;
          });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Fehler beim Laden der Daten: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveHelper.isMobile(screenWidth);
    
    if (isMobile) {
      return _buildMobileLayout();
    } else {
      return _buildDesktopLayout();
    }
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _selectedClub != null
              ? _buildClubTeamsView()
              : _buildClubsListView(),
    );
  }

  Widget _buildDesktopLayout() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with management buttons
          Row(
            children: [
              const Text(
                'Teams & Vereine verwalten',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ClubManagementScreen()),
                  );
                },
                icon: const Icon(Icons.business),
                label: const Text('Vereine verwalten'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TeamClubMigrationScreen()),
                  );
                },
                icon: const Icon(Icons.transfer_within_a_station),
                label: const Text('Migration'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _buildDesktopContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopContent() {
    return Row(
      children: [
        // Left side - Clubs list
        Expanded(
          flex: 2,
          child: _buildClubsList(),
        ),
        const SizedBox(width: 24),
        // Right side - Teams for selected club
        Expanded(
          flex: 3,
          child: _selectedClub != null 
              ? _buildTeamsForClub(_selectedClub!)
              : _buildWelcomeMessage(),
        ),
      ],
    );
  }

  Widget _buildClubsListView() {
    return CustomScrollView(
      slivers: [
        // App Bar
        SliverAppBar(
          expandedHeight: 120,
          pinned: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
            title: Text(
              'Teams & Vereine',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          actions: [
            // Management menu for mobile
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'clubs':
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ClubManagementScreen()),
                    );
                    break;
                  case 'migration':
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const TeamClubMigrationScreen()),
                    );
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'clubs',
                  child: Row(
                    children: [
                      Icon(Icons.business, size: 18),
                      SizedBox(width: 8),
                      Text('Vereine verwalten'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'migration', 
                  child: Row(
                    children: [
                      Icon(Icons.transfer_within_a_station, size: 18),
                      SizedBox(width: 8),
                      Text('Migration'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        
        // Search and filters
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // Search
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Verein oder Team suchen...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                
                // Filters row
                Row(
                  children: [
                    // Division filter
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _filterDivision,
                            isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                        value: 'Alle',
                                child: Text('Alle Divisionen'),
                      ),
                      ..._divisions.map((division) => DropdownMenuItem(
                        value: division,
                                child: Text(division),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _filterDivision = value!;
                      });
                    },
                  ),
                ),
              ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Orphaned teams toggle
                    if (_orphanedTeams.isNotEmpty)
                      FilterChip(
                        label: Text('Teams ohne Verein (${_orphanedTeams.length})'),
                        selected: _showOrphanedTeams,
                        onSelected: (value) {
                          setState(() {
                            _showOrphanedTeams = value;
                          });
                        },
                        selectedColor: Colors.orange.shade100,
                        checkmarkColor: Colors.orange,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        // Content
        _showOrphanedTeams ? _buildOrphanedTeamsList() : _buildClubsGrid(),
      ],
    );
  }

  Widget _buildClubTeamsView() {
    final club = _selectedClub!;
    final clubTeams = _teamsByClub[club.id] ?? [];
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(club.name),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
                 leading: IconButton(
           icon: Icon(Icons.arrow_back_ios),
           onPressed: () {
             setState(() {
               _selectedClub = null;
             });
           },
         ),
       ),
       body: clubTeams.isEmpty
           ? _buildEmptyTeamsView(club)
           : ListView.builder(
               padding: const EdgeInsets.all(16),
               itemCount: clubTeams.length,
               itemBuilder: (context, index) {
                 final team = clubTeams[index];
                 return _buildTeamCard(team, isMobile: true);
               },
             ),
       floatingActionButton: FloatingActionButton(
         onPressed: () => _addTeamToClub(club),
         backgroundColor: Colors.blue,
         child: Icon(Icons.add),
       ),
     );
   }

   Widget _buildClubsList() {
     List<Club> filteredClubs = _clubs;
     
     if (_searchQuery.isNotEmpty) {
       filteredClubs = _clubs.where((club) =>
         club.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
         club.city.toLowerCase().contains(_searchQuery.toLowerCase())
       ).toList();
     }

     return Container(
       decoration: BoxDecoration(
         color: Colors.white,
         borderRadius: BorderRadius.circular(12),
         border: Border.all(color: Colors.grey.shade300),
       ),
       child: Column(
         children: [
           Container(
             padding: const EdgeInsets.all(16),
             decoration: BoxDecoration(
               border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
             ),
             child: Row(
               children: [
                 Icon(Icons.business, color: Colors.blue),
                 const SizedBox(width: 8),
                 Text(
                   'Vereine',
                   style: TextStyle(
                     fontSize: 18,
                     fontWeight: FontWeight.bold,
                   ),
                 ),
               ],
             ),
           ),
           Expanded(
             child: filteredClubs.isEmpty
                 ? _buildEmptyClubsView()
                 : ListView.builder(
                     padding: const EdgeInsets.all(16),
                     itemCount: filteredClubs.length,
                     itemBuilder: (context, index) {
                       final club = filteredClubs[index];
                       return _buildClubListItem(club);
                     },
                   ),
           ),
         ],
                    ),
                  );
                }

   Widget _buildClubsGrid() {
     List<Club> filteredClubs = _clubs;
     
     if (_searchQuery.isNotEmpty) {
       filteredClubs = _clubs.where((club) =>
         club.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
         club.city.toLowerCase().contains(_searchQuery.toLowerCase())
       ).toList();
     }

     if (filteredClubs.isEmpty) {
       return SliverToBoxAdapter(child: _buildEmptyClubsView());
     }

     return SliverPadding(
       padding: const EdgeInsets.all(16),
       sliver: SliverGrid(
         gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
           crossAxisCount: 2,
           childAspectRatio: 0.9,
           crossAxisSpacing: 12,
           mainAxisSpacing: 12,
         ),
         delegate: SliverChildBuilderDelegate(
           (context, index) {
             final club = filteredClubs[index];
             return _buildClubCard(club);
           },
           childCount: filteredClubs.length,
         ),
                    ),
                  );
                }

   Widget _buildOrphanedTeamsList() {
     List<Team> filteredTeams = _orphanedTeams;
     
                if (_filterDivision != 'Alle') {
       filteredTeams = _orphanedTeams.where((team) => team.division == _filterDivision).toList();
     }
     
     if (_searchQuery.isNotEmpty) {
       filteredTeams = filteredTeams.where((team) =>
         team.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
         team.city.toLowerCase().contains(_searchQuery.toLowerCase())
       ).toList();
     }

     return SliverList(
       delegate: SliverChildBuilderDelegate(
         (context, index) {
           final team = filteredTeams[index];
           return Padding(
             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
             child: _buildTeamCard(team, isMobile: true, showOrphanedWarning: true),
           );
         },
         childCount: filteredTeams.length,
      ),
    );
  }

   Widget _buildClubCard(Club club) {
     final clubTeams = _teamsByClub[club.id] ?? [];
     
     return Card(
       elevation: 2,
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
       child: InkWell(
         onTap: () {
           setState(() {
             _selectedClub = club;
           });
         },
              borderRadius: BorderRadius.circular(12),
         child: Padding(
           padding: const EdgeInsets.all(16),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               // Club logo/avatar
               Container(
                 width: double.infinity,
                 height: 60,
                 decoration: BoxDecoration(
                   color: Colors.blue.shade100,
                   borderRadius: BorderRadius.circular(8),
                 ),
                 child: club.logoUrl != null && club.logoUrl!.isNotEmpty
                     ? ClipRRect(
                         borderRadius: BorderRadius.circular(8),
                         child: Image.network(
                           club.logoUrl!,
                           fit: BoxFit.cover,
                           errorBuilder: (context, error, stackTrace) {
                             return Icon(Icons.business, color: Colors.blue, size: 30);
                           },
                         ),
                       )
                     : Icon(Icons.business, color: Colors.blue, size: 30),
               ),
               const SizedBox(height: 12),
               
               // Club name
               Text(
                 club.name,
                        style: TextStyle(
                   fontSize: 16,
                          fontWeight: FontWeight.bold,
                   color: Colors.black87,
                 ),
                 maxLines: 2,
                 overflow: TextOverflow.ellipsis,
               ),
               const SizedBox(height: 4),
               
               // Location
               Text(
                 '${club.city}, ${club.bundesland}',
                 style: TextStyle(
                   color: Colors.grey[600],
                   fontSize: 12,
                 ),
                 maxLines: 1,
                 overflow: TextOverflow.ellipsis,
               ),
               
               const Spacer(),
               
               // Teams count
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                 decoration: BoxDecoration(
                   color: clubTeams.isEmpty ? Colors.grey.shade200 : Colors.blue.shade100,
                   borderRadius: BorderRadius.circular(12),
                 ),
                      child: Text(
                   clubTeams.isEmpty 
                       ? 'Keine Teams' 
                       : '${clubTeams.length} Team${clubTeams.length != 1 ? 's' : ''}',
                        style: TextStyle(
                     color: clubTeams.isEmpty ? Colors.grey[600] : Colors.blue[700],
                     fontSize: 11,
                     fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
             ],
           ),
         ),
       ),
     );
   }

   Widget _buildClubListItem(Club club) {
     final clubTeams = _teamsByClub[club.id] ?? [];
     final isSelected = _selectedClub?.id == club.id;
     
     return Container(
       margin: const EdgeInsets.only(bottom: 8),
       child: Material(
         color: isSelected ? Colors.blue.shade50 : Colors.transparent,
         borderRadius: BorderRadius.circular(8),
         child: InkWell(
           onTap: () {
             setState(() {
               _selectedClub = club;
             });
           },
           borderRadius: BorderRadius.circular(8),
           child: Padding(
             padding: const EdgeInsets.all(12),
             child: Row(
               children: [
                 // Club avatar
                 Container(
                   width: 40,
                   height: 40,
                   decoration: BoxDecoration(
                     color: Colors.blue.shade100,
                     borderRadius: BorderRadius.circular(8),
                   ),
                   child: club.logoUrl != null && club.logoUrl!.isNotEmpty
                       ? ClipRRect(
                           borderRadius: BorderRadius.circular(8),
                           child: Image.network(
                             club.logoUrl!,
                             fit: BoxFit.cover,
                             errorBuilder: (context, error, stackTrace) {
                               return Icon(Icons.business, color: Colors.blue, size: 20);
                             },
                           ),
                         )
                       : Icon(Icons.business, color: Colors.blue, size: 20),
                 ),
                 const SizedBox(width: 12),
                 
                 // Club info
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(
                         club.name,
                        style: TextStyle(
                           fontSize: 14,
                          fontWeight: FontWeight.bold,
                           color: Colors.black87,
                         ),
                       ),
                       Text(
                         '${club.city}, ${club.bundesland}',
                         style: TextStyle(
                           color: Colors.grey[600],
                           fontSize: 12,
                         ),
                       ),
                     ],
                   ),
                 ),
                 
                 // Teams count
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                   decoration: BoxDecoration(
                     color: clubTeams.isEmpty ? Colors.grey.shade200 : Colors.blue.shade100,
                     borderRadius: BorderRadius.circular(10),
                   ),
                      child: Text(
                     '${clubTeams.length}',
                        style: TextStyle(
                       color: clubTeams.isEmpty ? Colors.grey[600] : Colors.blue[700],
                       fontSize: 10,
                       fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
               ],
             ),
                        ),
                      ),
                    ),
     );
   }

   Widget _buildTeamCard(Team team, {required bool isMobile, bool showOrphanedWarning = false}) {
     return Container(
       margin: const EdgeInsets.only(bottom: 8),
       decoration: BoxDecoration(
         color: showOrphanedWarning ? Colors.orange.shade50 : Colors.white,
         borderRadius: BorderRadius.circular(12),
         border: Border.all(
           color: showOrphanedWarning ? Colors.orange.shade200 : Colors.grey.shade300,
           width: 1,
         ),
       ),
       child: Padding(
         padding: const EdgeInsets.all(16),
         child: Row(
           children: [
             // Team avatar
             TeamAvatar(
               teamName: team.name,
               size: isMobile ? 45 : 40,
             ),
             const SizedBox(width: 12),
             
             // Team info
             Expanded(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Row(
                     children: [
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text(
                               team.name, // Beach handball call name
                        style: TextStyle(
                                 fontSize: isMobile ? 16 : 14,
                          fontWeight: FontWeight.bold,
                                 color: Colors.black87,
                               ),
                             ),
                             if (team.secondaryName != null && team.secondaryName!.isNotEmpty)
                               Text(
                                 team.secondaryName!, // Official handball name
                                 style: TextStyle(
                                   fontSize: isMobile ? 13 : 12,
                                   color: Colors.grey[700],
                                   fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                         ),
                       ),
                       if (showOrphanedWarning)
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                           decoration: BoxDecoration(
                             color: Colors.orange,
                             borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                             'Ohne Verein',
                            style: TextStyle(
                               color: Colors.white,
                               fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                     ],
                   ),
                   const SizedBox(height: 4),
                   Text(
                     '${team.city}, ${team.bundesland}',
                     style: TextStyle(
                       color: Colors.grey[600],
                       fontSize: isMobile ? 14 : 12,
                     ),
                   ),
                   Text(
                            team.division,
                            style: TextStyle(
                       color: Colors.blue[600],
                       fontSize: isMobile ? 12 : 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                 ],
               ),
             ),
             
             // Actions
             if (isMobile)
               PopupMenuButton<String>(
                 onSelected: (value) => _handleTeamAction(value, team),
                 itemBuilder: (context) => [
                   PopupMenuItem(
                     value: 'edit',
                     child: Row(
                       children: [
                         Icon(Icons.edit, size: 18),
                         SizedBox(width: 8),
                         Text('Bearbeiten'),
                       ],
                     ),
                   ),
                   if (showOrphanedWarning)
                     PopupMenuItem(
                       value: 'assign',
                       child: Row(
                         children: [
                           Icon(Icons.business_center, size: 18),
                           SizedBox(width: 8),
                           Text('Verein zuordnen'),
                         ],
                       ),
                     ),
                   PopupMenuItem(
                     value: 'delete',
                     child: Row(
                       children: [
                         Icon(Icons.delete, size: 18, color: Colors.red),
                         SizedBox(width: 8),
                         Text('Löschen', style: TextStyle(color: Colors.red)),
                       ],
                     ),
                   ),
                 ],
               ),
           ],
         ),
       ),
     );
   }

   Widget _buildTeamsForClub(Club club) {
     final clubTeams = _teamsByClub[club.id] ?? [];
     
     return Container(
       decoration: BoxDecoration(
         color: Colors.white,
         borderRadius: BorderRadius.circular(12),
         border: Border.all(color: Colors.grey.shade300),
       ),
       child: Column(
         children: [
           // Header
           Container(
             padding: const EdgeInsets.all(16),
             decoration: BoxDecoration(
               border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                          ),
                          child: Row(
                            children: [
                 // Club info
                 Container(
                   width: 40,
                   height: 40,
                   decoration: BoxDecoration(
                     color: Colors.blue.shade100,
                     borderRadius: BorderRadius.circular(8),
                   ),
                   child: club.logoUrl != null && club.logoUrl!.isNotEmpty
                       ? ClipRRect(
                           borderRadius: BorderRadius.circular(8),
                           child: Image.network(
                             club.logoUrl!,
                             fit: BoxFit.cover,
                             errorBuilder: (context, error, stackTrace) {
                               return Icon(Icons.business, color: Colors.blue, size: 20);
                             },
                           ),
                         )
                       : Icon(Icons.business, color: Colors.blue, size: 20),
                 ),
                 const SizedBox(width: 12),
                 
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(
                         club.name,
                         style: TextStyle(
                           fontSize: 18,
                           fontWeight: FontWeight.bold,
                           color: Colors.black87,
                         ),
                       ),
                       Text(
                         '${club.city}, ${club.bundesland}',
                         style: TextStyle(
                           color: Colors.grey[600],
                           fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                 ),
                 
                 // Add team button
                 ElevatedButton.icon(
                   onPressed: () => _addTeamToClub(club),
                   icon: Icon(Icons.add, size: 18),
                   label: Text('Team hinzufügen'),
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.blue,
                     foregroundColor: Colors.white,
                     padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
             ),
           ),
           
           // Teams list
           Expanded(
             child: clubTeams.isEmpty
                 ? _buildEmptyTeamsView(club)
                 : ListView.builder(
                     padding: const EdgeInsets.all(16),
                     itemCount: clubTeams.length,
                     itemBuilder: (context, index) {
                       final team = clubTeams[index];
                       return _buildTeamCard(team, isMobile: false);
                     },
                   ),
           ),
         ],
       ),
     );
   }

   Widget _buildWelcomeMessage() {
     return Container(
       decoration: BoxDecoration(
         color: Colors.white,
         borderRadius: BorderRadius.circular(12),
         border: Border.all(color: Colors.grey.shade300),
       ),
       child: Center(
         child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
                children: [
                      Icon(
               Icons.business_outlined,
               size: 80,
               color: Colors.grey[400],
             ),
             const SizedBox(height: 24),
                    Text(
               'Verein auswählen',
                      style: TextStyle(
                 fontSize: 24,
                 fontWeight: FontWeight.bold,
                 color: Colors.grey[600],
               ),
             ),
             const SizedBox(height: 16),
             Text(
               'Wählen Sie einen Verein aus der Liste\num dessen Teams zu verwalten.',
               style: TextStyle(
                 fontSize: 16,
                 color: Colors.grey[500],
               ),
               textAlign: TextAlign.center,
             ),
           ],
         ),
       ),
     );
   }

   Widget _buildEmptyClubsView() {
     return Center(
                    child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
                      children: [
           Icon(
             Icons.business_outlined,
             size: 64,
             color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
           Text(
             'Keine Vereine gefunden',
             style: TextStyle(
               fontSize: 18,
               color: Colors.grey[600],
             ),
           ),
           const SizedBox(height: 8),
           Text(
             'Erstellen Sie Ihren ersten Verein',
             style: TextStyle(color: Colors.grey[500]),
           ),
         ],
       ),
     );
   }

   Widget _buildEmptyTeamsView(Club club) {
     return Center(
       child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           Icon(
             Icons.group_outlined,
             size: 64,
             color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
           Text(
             'Keine Teams',
             style: TextStyle(
               fontSize: 18,
               color: Colors.grey[600],
             ),
           ),
           const SizedBox(height: 8),
           Text(
             'Fügen Sie das erste Team zu ${club.name} hinzu',
             style: TextStyle(color: Colors.grey[500]),
             textAlign: TextAlign.center,
           ),
           const SizedBox(height: 24),
           ElevatedButton.icon(
             onPressed: () => _addTeamToClub(club),
             icon: Icon(Icons.add),
             label: Text('Team hinzufügen'),
             style: ElevatedButton.styleFrom(
               backgroundColor: Colors.blue,
               foregroundColor: Colors.white,
             ),
           ),
         ],
       ),
     );
   }

   void _handleTeamAction(String action, Team team) {
     switch (action) {
       case 'edit':
         _editTeam(team);
         break;
       case 'assign':
         _assignTeamToClub(team);
         break;
       case 'delete':
         _deleteTeam(team);
         break;
     }
   }

   void _addTeamToClub(Club club) {
     _showTeamDialog(club: club);
   }

   void _editTeam(Team team) {
     _showTeamDialog(team: team);
   }

   void _assignTeamToClub(Team team) {
     showModalBottomSheet(
       context: context,
       builder: (context) => _buildClubSelectionSheet(team),
     );
   }

   void _deleteTeam(Team team) async {
     final confirmed = await showDialog<bool>(
       context: context,
       builder: (context) => AlertDialog(
         title: const Text('Team löschen'),
         content: Text('Möchten Sie das Team "${team.name}" wirklich löschen?'),
              actions: [
                TextButton(
             onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Abbrechen'),
                ),
                ElevatedButton(
             onPressed: () => Navigator.of(context).pop(true),
             style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
             child: const Text('Löschen', style: TextStyle(color: Colors.white)),
           ),
         ],
       ),
     );

     if (confirmed == true) {
       final success = await _teamService.deleteTeam(team.id);
       if (success) {
         _loadData();
         _showSuccess('Team erfolgreich gelöscht!');
       } else {
         _showError('Fehler beim Löschen des Teams');
       }
     }
   }

   void _showTeamDialog({Club? club, Team? team}) {
     // Implement team creation/editing dialog
     // This would open a detailed form for team management
   }

   Widget _buildClubSelectionSheet(Team team) {
     return Container(
       height: 400,
       padding: const EdgeInsets.all(16),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Text(
             'Verein für "${team.name}" auswählen',
             style: TextStyle(
               fontSize: 18,
               fontWeight: FontWeight.bold,
             ),
           ),
           const SizedBox(height: 16),
           Expanded(
             child: ListView.builder(
               itemCount: _clubs.length,
               itemBuilder: (context, index) {
                 final club = _clubs[index];
                 return ListTile(
                   leading: Icon(Icons.business),
                   title: Text(club.name),
                   subtitle: Text('${club.city}, ${club.bundesland}'),
                   onTap: () => _assignTeamToClubAction(team, club),
                 );
               },
             ),
           ),
         ],
       ),
     );
   }

   void _assignTeamToClubAction(Team team, Club club) async {
     Navigator.pop(context);
     
     final updatedTeam = Team(
       id: team.id,
       name: team.name,
       secondaryName: team.secondaryName,
       teamManager: team.teamManager,
       logoUrl: team.logoUrl,
       city: team.city,
       bundesland: team.bundesland,
       division: team.division,
       clubId: club.id,
       createdAt: team.createdAt,
     );

     final teamSuccess = await _teamService.updateTeam(team.id, updatedTeam);
     final clubSuccess = await _clubService.addTeamToClub(club.id, team.id);
     
     if (teamSuccess && clubSuccess) {
       _loadData();
       _showSuccess('Team erfolgreich zu ${club.name} hinzugefügt!');
        } else {
       _showError('Fehler beim Zuordnen des Teams');
     }
        }

   void _showSuccess(String message) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
         content: Text(message),
            backgroundColor: Colors.green,
          ),
        );
   }

   void _showError(String message) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
         content: Text(message),
                      backgroundColor: Colors.red,
                    ),
     );
   }

  @override
  void dispose() {
    super.dispose();
  }
} 