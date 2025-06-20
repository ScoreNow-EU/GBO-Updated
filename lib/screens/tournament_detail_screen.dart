import 'package:flutter/material.dart';
import '../models/tournament.dart';
import '../widgets/responsive_layout.dart';

class TournamentDetailScreen extends StatefulWidget {
  final Tournament tournament;

  const TournamentDetailScreen({
    super.key,
    required this.tournament,
  });

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> {
  String selectedCategory = 'Alle';
  String selectedRound = 'Alle';
  String selectedTeams = 'Alle';
  String selectedResultTab = 'U16-Weiblich';
  String selectedSection = 'turniere'; // Current section

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      selectedSection: selectedSection,
      onSectionChanged: (section) {
        if (section != 'turniere') {
          // Navigate back to home with selected section
          Navigator.of(context).pop();
          // You could add additional navigation logic here if needed
        }
      },
      title: widget.tournament.name,
      showBackButton: true,
      onBackPressed: () => Navigator.of(context).pop(),
      body: _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTournamentHeader(),
          const SizedBox(height: 32),
          _buildMatchesSection(),
          const SizedBox(height: 32),
          _buildResultsSection(),
          const SizedBox(height: 32),
          _buildCriteriaSection(),
          const SizedBox(height: 32),
          _buildOrganizationSection(),
        ],
      ),
    );
  }

  Widget _buildTournamentHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tournament Logo
          Container(
            width: 180,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200, width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: widget.tournament.imageUrl != null && widget.tournament.imageUrl!.isNotEmpty
                  ? Image.network(
                      widget.tournament.imageUrl!,
                      width: 180,
                      height: 120,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 180,
                          height: 120,
                          color: Colors.grey.shade100,
                          child: Center(
                            child: SizedBox(
                              width: 30,
                              height: 30,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / 
                                      loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        // If network image fails, show placeholder
                        return Container(
                          width: 180,
                          height: 120,
                          color: Colors.grey.shade200,
                          child: Icon(
                            Icons.sports_volleyball,
                            color: Colors.grey.shade400,
                            size: 40,
                          ),
                        );
                      },
                    )
                  : Container(
                      width: 180,
                      height: 120,
                      color: Colors.grey.shade200,
                      child: Icon(
                        Icons.sports_volleyball,
                        color: Colors.grey.shade400,
                        size: 40,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 24),
          
          // Tournament Details (middle section)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.tournament.dateString,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _downloadAGBs,
                  child: Row(
                    children: [
                      const Icon(Icons.download, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Ausschreibung/AGBs',
                        style: TextStyle(
                          color: Colors.blue[600],
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.blue[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.tournament.location,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${widget.tournament.points}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Punkte',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Social Media (right side, stacked vertically)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Social Media',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _buildSocialButton('Facebook', Colors.blue[600]!, Icons.facebook),
              const SizedBox(height: 8),
              _buildSocialButton('Instagram', Colors.purple[400]!, Icons.camera_alt),
              const SizedBox(height: 8),
              _buildSocialButton('Homepage', Colors.blue[400]!, Icons.language),
            ],
          ),
        ],
      ),
    );
  }

  String? _getTournamentImage(String tournamentName) {
    // Return null to use placeholder/icon instead of hardcoded images
    return null;
  }

  Widget _buildSocialButton(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _downloadAGBs() {
    // Show download dialog or trigger download
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Download Ausschreibung/AGBs'),
          content: Text('Download für ${widget.tournament.name} wird gestartet...'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Schließen'),
            ),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement actual download functionality
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Download gestartet...'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Download'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMatchesSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Matches',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildDropdown('Kategorie', selectedCategory, ['Alle', 'U16-Weiblich', 'U16-Männlich']),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdown('Spielrunde', selectedRound, ['Alle', 'Gruppenphase', 'Achtelfinale', 'Viertelfinale', 'Halbfinale', 'Finale']),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDropdown('Teams', selectedTeams, ['Alle', 'Team A', 'Team B', 'Team C']),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Leer! Hier werden die Spiele des Turniers aufgelistet, sofern der Veranstalter die GBO TO-Software benutzt.',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label*',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    if (label == 'Kategorie') selectedCategory = newValue;
                    if (label == 'Spielrunde') selectedRound = newValue;
                    if (label == 'Teams') selectedTeams = newValue;
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ergebnisse',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          // Tabs
          Row(
            children: [
              _buildResultTab('U16-Weiblich', true),
              const SizedBox(width: 20),
              _buildResultTab('U16-Weiblich', false),
            ],
          ),
          const SizedBox(height: 20),
          // Expandable sections
          _buildExpandableSection('Teams / Ranking', Icons.keyboard_arrow_down),
          const SizedBox(height: 8),
          _buildExpandableSection('Gruppenphase', Icons.keyboard_arrow_down),
          const SizedBox(height: 8),
          _buildExpandableSection('Final & Platzierungsrunde', Icons.keyboard_arrow_down),
          const SizedBox(height: 8),
          _buildExpandableSection('Spielerstatistiken', Icons.keyboard_arrow_down),
        ],
      ),
    );
  }

  Widget _buildResultTab(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue[600] : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isSelected ? Colors.blue[600]! : Colors.grey[300]!,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildExpandableSection(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          Icon(icon, color: Colors.grey[600], size: 20),
        ],
      ),
    );
  }

  Widget _buildCriteriaSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kriterien allgemein',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          _buildExpandableSection('Kriterien allgemein', Icons.keyboard_arrow_down),
          const SizedBox(height: 8),
          _buildExpandableSection('Kriterium Referee', Icons.keyboard_arrow_down),
          const SizedBox(height: 8),
          _buildExpandableSection('Kriterium Delegate', Icons.keyboard_arrow_down),
          const SizedBox(height: 8),
          _buildExpandableSection('Kriterium Scouter', Icons.keyboard_arrow_down),
        ],
      ),
    );
  }

  Widget _buildOrganizationSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Text(
                    '01',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Team. Orga.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.emoji_events, size: 20),
              const SizedBox(width: 12),
              const Text(
                'Turnierorganisator GBO',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.email, size: 20),
              const SizedBox(width: 12),
              const Text(
                'beachcup-herrenhausen@online.de',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 