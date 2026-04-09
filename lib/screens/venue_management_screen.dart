import 'package:flutter/material.dart';
import '../models/venue.dart';
import '../services/venue_service.dart';
import '../utils/responsive_helper.dart';

class VenueManagementScreen extends StatefulWidget {
  const VenueManagementScreen({super.key});

  @override
  State<VenueManagementScreen> createState() => _VenueManagementScreenState();
}

class _VenueManagementScreenState extends State<VenueManagementScreen> {
  final VenueService _venueService = VenueService();
  List<Venue> _venues = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVenues();
  }

  Future<void> _loadVenues() async {
    setState(() => _isLoading = true);
    try {
      _venues = await _venueService.getAllVenues();
    } catch (e) {
      debugPrint('Error loading venues: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  List<Venue> get _filteredVenues {
    if (_searchQuery.isEmpty) return _venues;
    final q = _searchQuery.toLowerCase();
    return _venues.where((v) =>
        v.name.toLowerCase().contains(q) ||
        v.city.toLowerCase().contains(q) ||
        v.street.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveHelper.isMobile(screenWidth);

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.teal.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.location_city, color: Colors.teal.shade700, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hallenbörse',
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_venues.length} Halle${_venues.length == 1 ? '' : 'n'} registriert',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showVenueDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Neue Halle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Search
          TextField(
            decoration: InputDecoration(
              hintText: 'Halle suchen...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: 24),

          // Venues list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredVenues.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_off, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'Keine Hallen gefunden',
                              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredVenues.length,
                        itemBuilder: (ctx, i) => _buildVenueCard(_filteredVenues[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildVenueCard(Venue venue) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.teal.shade100,
              radius: 24,
              child: Icon(Icons.stadium, color: Colors.teal.shade700),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(venue.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(venue.fullAddress, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (venue.courtNames.isNotEmpty) ...[
                        Icon(Icons.sports_handball, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text('${venue.courtNames.length} Feld${venue.courtNames.length == 1 ? '' : 'er'}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        const SizedBox(width: 12),
                      ],
                      if (venue.capacity != null) ...[
                        Icon(Icons.people, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text('${venue.capacity} Plätze',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (action) {
                if (action == 'edit') _showVenueDialog(venue: venue);
                if (action == 'delete') _deleteVenue(venue);
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Bearbeiten'))),
                const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text('Löschen'))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showVenueDialog({Venue? venue}) {
    final isEdit = venue != null;
    final nameCtrl = TextEditingController(text: venue?.name ?? '');
    final streetCtrl = TextEditingController(text: venue?.street ?? '');
    final houseNumberCtrl = TextEditingController(text: venue?.houseNumber ?? '');
    final plzCtrl = TextEditingController(text: venue?.plz ?? '');
    final cityCtrl = TextEditingController(text: venue?.city ?? '');
    final capacityCtrl = TextEditingController(text: venue?.capacity?.toString() ?? '');
    final contactPersonCtrl = TextEditingController(text: venue?.contactPerson ?? '');
    final contactEmailCtrl = TextEditingController(text: venue?.contactEmail ?? '');
    final contactPhoneCtrl = TextEditingController(text: venue?.contactPhone ?? '');
    final notesCtrl = TextEditingController(text: venue?.notes ?? '');
    final courtsCtrl = TextEditingController(text: venue?.courtNames.join(', ') ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Halle bearbeiten' : 'Neue Halle erstellen'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name *', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(flex: 3, child: TextField(controller: streetCtrl, decoration: const InputDecoration(labelText: 'Straße *', border: OutlineInputBorder()))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: houseNumberCtrl, decoration: const InputDecoration(labelText: 'Nr.', border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: plzCtrl, decoration: const InputDecoration(labelText: 'PLZ *', border: OutlineInputBorder()))),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: TextField(controller: cityCtrl, decoration: const InputDecoration(labelText: 'Stadt *', border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: capacityCtrl, decoration: const InputDecoration(labelText: 'Kapazität', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: TextField(controller: courtsCtrl, decoration: const InputDecoration(labelText: 'Felder (kommagetrennt)', hintText: 'Feld 1, Feld 2', border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 16),
                const Align(alignment: Alignment.centerLeft, child: Text('Kontakt', style: TextStyle(fontWeight: FontWeight.bold))),
                const SizedBox(height: 8),
                TextField(controller: contactPersonCtrl, decoration: const InputDecoration(labelText: 'Ansprechpartner', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: contactEmailCtrl, decoration: const InputDecoration(labelText: 'E-Mail', border: OutlineInputBorder()))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: contactPhoneCtrl, decoration: const InputDecoration(labelText: 'Telefon', border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notizen', border: OutlineInputBorder()), maxLines: 2),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || streetCtrl.text.isEmpty || plzCtrl.text.isEmpty || cityCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bitte Pflichtfelder ausfüllen')));
                return;
              }

              final courtNames = courtsCtrl.text.isNotEmpty
                  ? courtsCtrl.text.split(',').map((c) => c.trim()).where((c) => c.isNotEmpty).toList()
                  : <String>[];

              final newVenue = Venue(
                id: venue?.id ?? '',
                name: nameCtrl.text.trim(),
                street: streetCtrl.text.trim(),
                houseNumber: houseNumberCtrl.text.trim().isNotEmpty ? houseNumberCtrl.text.trim() : null,
                plz: plzCtrl.text.trim(),
                city: cityCtrl.text.trim(),
                capacity: int.tryParse(capacityCtrl.text),
                courtNames: courtNames,
                contactPerson: contactPersonCtrl.text.trim().isNotEmpty ? contactPersonCtrl.text.trim() : null,
                contactEmail: contactEmailCtrl.text.trim().isNotEmpty ? contactEmailCtrl.text.trim() : null,
                contactPhone: contactPhoneCtrl.text.trim().isNotEmpty ? contactPhoneCtrl.text.trim() : null,
                notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                createdAt: venue?.createdAt ?? DateTime.now(),
              );

              try {
                if (isEdit) {
                  await _venueService.updateVenue(venue!.id, newVenue);
                } else {
                  await _venueService.createVenue(newVenue);
                }
                Navigator.of(ctx).pop();
                await _loadVenues();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isEdit ? 'Halle aktualisiert' : 'Halle erstellt')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
              }
            },
            child: Text(isEdit ? 'Speichern' : 'Erstellen'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteVenue(Venue venue) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Halle löschen?'),
        content: Text('Möchten Sie "${venue.name}" wirklich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _venueService.deleteVenue(venue.id);
      await _loadVenues();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Halle gelöscht')));
      }
    }
  }
}
