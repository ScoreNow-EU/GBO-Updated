import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/observation_template.dart';
import '../models/referee_observation.dart';
import '../services/observation_template_service.dart';
import '../services/referee_observation_service.dart';

/// Observation form for both delegate (t46) and team manager (t47) flows.
/// [templateType] is 'delegate' or 'team'.
/// If [existingObservation] is provided, the form opens in edit/view mode.
class RefereeObservationFormScreen extends StatefulWidget {
  final String gameId;
  final String tournamentId;
  final String gameName; // e.g. "Team A vs Team B"
  final String gameDate; // formatted for display
  final List<String> refereeIds;
  final List<String> refereeNames;
  final String submitterId;
  final String submitterName;
  final String submitterRole;
  final String templateType;
  final RefereeObservation? existingObservation;

  const RefereeObservationFormScreen({
    super.key,
    required this.gameId,
    required this.tournamentId,
    required this.gameName,
    required this.gameDate,
    required this.refereeIds,
    required this.refereeNames,
    required this.submitterId,
    required this.submitterName,
    required this.submitterRole,
    required this.templateType,
    this.existingObservation,
  });

  @override
  State<RefereeObservationFormScreen> createState() =>
      _RefereeObservationFormScreenState();
}

class _RefereeObservationFormScreenState
    extends State<RefereeObservationFormScreen> {
  final ObservationTemplateService _templateService =
      ObservationTemplateService();
  final RefereeObservationService _observationService =
      RefereeObservationService();

  ObservationTemplate? _template;
  bool _loading = true;
  bool _saving = false;

  // Form state
  List<ObservationCategoryScore> _categoryScores = [];
  final _notesController = TextEditingController();

  bool get _readOnly =>
      widget.existingObservation?.isSubmitted == true &&
      widget.submitterRole != 'admin';

  @override
  void initState() {
    super.initState();
    _loadTemplate();
  }

  Future<void> _loadTemplate() async {
    // Prefer template from existing observation if available
    final existing = widget.existingObservation;
    if (existing != null) {
      _notesController.text = existing.notes;
    }

    // Load templates of the right type and take the first one
    final templates =
        await _templateService.getTemplates(type: widget.templateType).first;
    if (templates.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Keine Vorlage gefunden. Bitte zuerst eine Vorlage anlegen.')));
        Navigator.pop(context);
      }
      return;
    }

    final template = templates.first;

    // Build category scores from existing or fresh
    List<ObservationCategoryScore> scores;
    if (existing != null) {
      // Use existing scores but fill in any missing ones from template
      scores = [];
      for (final major in template.majorCategories) {
        for (final minor in major.minorCategories) {
          final found = existing.categoryScores
              .where((s) => s.minorCategoryId == minor.id)
              .toList();
          scores.add(found.isNotEmpty
              ? found.first
              : ObservationCategoryScore.empty(minor, major.name));
        }
      }
    } else {
      scores = [
        for (final major in template.majorCategories)
          for (final minor in major.minorCategories)
            ObservationCategoryScore.empty(minor, major.name),
      ];
    }

    setState(() {
      _template = template;
      _categoryScores = scores;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _updateScore(int idx, ObservationCategoryScore updated) {
    setState(() => _categoryScores[idx] = updated);
  }

  static const _kMajorColors = [
    Colors.indigo,
    Colors.teal,
    Colors.deepOrange,
    Colors.purple,
    Colors.green,
    Colors.blue,
  ];
  Color _majorColor(int index) => _kMajorColors[index % _kMajorColors.length];

  double get _computedOverall {
    final template = _template;
    if (template == null) return 0.0;
    return RefereeObservation.computeOverallResult(
        _categoryScores, template.calculationMethod);
  }

  Future<void> _save({required bool submit}) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final observation = _buildObservation(
          status: submit ? 'submitted' : 'draft');
      if (widget.existingObservation == null) {
        await _observationService.createObservation(observation);
      } else {
        await _observationService.updateObservation(
            observation.copyWith(id: widget.existingObservation!.id));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(submit
                ? 'Beobachtung eingereicht.'
                : 'Entwurf gespeichert.')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  RefereeObservation _buildObservation({required String status}) {
    final now = DateTime.now();
    return RefereeObservation(
      id: widget.existingObservation?.id ?? '',
      templateId: _template!.id,
      templateType: widget.templateType,
      gameId: widget.gameId,
      tournamentId: widget.tournamentId,
      refereeIds: widget.refereeIds,
      refereeNames: widget.refereeNames,
      submitterId: widget.submitterId,
      submitterName: widget.submitterName,
      submitterRole: widget.submitterRole,
      overallResult: _computedOverall,
      notes: _notesController.text.trim(),
      categoryScores: _categoryScores,
      status: status,
      createdAt: widget.existingObservation?.createdAt ?? now,
      updatedAt: now,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final template = _template!;
    final calcLabel = template.calculationMethod == 'average'
        ? 'Durchschnitt'
        : 'Summe';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        title: Text(
            widget.templateType == 'delegate'
                ? 'Delegiertenbeobachtung'
                : 'Vereinsbeobachtung',
            style: const TextStyle(fontSize: 16)),
        actions: _readOnly
            ? null
            : [
                if (_saving)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white)),
                  )
                else ...[
                  TextButton(
                    onPressed: () => _save(submit: false),
                    child: const Text('Entwurf'),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white),
                    onPressed: () => _save(submit: true),
                    child: const Text('Einreichen'),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info card
            _InfoCard(
              gameName: widget.gameName,
              gameDate: widget.gameDate,
              refereeNames: widget.refereeNames,
              templateName: template.name,
              calcLabel: calcLabel,
              overallResult: _computedOverall,
            ),
            const SizedBox(height: 24),

            // Category sections grouped by major — color-coded
            for (int mi = 0; mi < template.majorCategories.length; mi++) ...[
              _SectionHeader(
                title: template.majorCategories[mi].name,
                color: _majorColor(mi),
              ),
              const SizedBox(height: 8),
              for (final minor in template.majorCategories[mi].minorCategories) ...[
                _MinorCategoryCard(
                  minor: minor,
                  accentColor: _majorColor(mi),
                  score: _categoryScores.firstWhere(
                      (s) => s.minorCategoryId == minor.id,
                      orElse: () => ObservationCategoryScore.empty(
                          minor, template.majorCategories[mi].name)),
                  readOnly: _readOnly,
                  onChanged: (updated) {
                    final idx = _categoryScores
                        .indexWhere((s) => s.minorCategoryId == minor.id);
                    if (idx >= 0) _updateScore(idx, updated);
                  },
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 16),
            ],

            // Overall notes
            _SectionHeader(title: 'Allgemeine Anmerkungen', color: Colors.grey.shade600),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              readOnly: _readOnly,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Optionale Anmerkungen...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.indigo),
                ),
              ),
            ),
            const SizedBox(height: 32),

            if (!_readOnly)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _saving ? null : () => _save(submit: false),
                    child: const Text('Entwurf speichern'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white),
                    onPressed: _saving ? null : () => _save(submit: true),
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('Einreichen'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info card at top of form
// ---------------------------------------------------------------------------
class _InfoCard extends StatelessWidget {
  final String gameName;
  final String gameDate;
  final List<String> refereeNames;
  final String templateName;
  final String calcLabel;
  final double overallResult;

  const _InfoCard({
    required this.gameName,
    required this.gameDate,
    required this.refereeNames,
    required this.templateName,
    required this.calcLabel,
    required this.overallResult,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(gameName,
              style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(gameDate,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.sports, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text('Gespann: ${refereeNames.join(' / ')}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.description, size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Text('Vorlage: $templateName · $calcLabel',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.indigo.shade200),
                ),
                child: Text(
                  'Gesamt: ${overallResult.toStringAsFixed(1)}',
                  style: TextStyle(
                      color: Colors.indigo.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------
class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Minor category card — StatefulWidget to avoid parent rebuilds on every input
// ---------------------------------------------------------------------------
class _MinorCategoryCard extends StatefulWidget {
  final MinorCategory minor;
  final ObservationCategoryScore score;
  final bool readOnly;
  final Color accentColor;
  final void Function(ObservationCategoryScore) onChanged;

  const _MinorCategoryCard({
    required this.minor,
    required this.score,
    required this.readOnly,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  State<_MinorCategoryCard> createState() => _MinorCategoryCardState();
}

class _MinorCategoryCardState extends State<_MinorCategoryCard> {
  late int? _localScore;
  late List<String> _localMangelIds;
  late List<String> _localCauses;
  late TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _localScore = widget.score.score;
    _localMangelIds = List.from(widget.score.selectedMangelIds);
    _localCauses = List.from(widget.score.selectedCauses);
    _notesCtrl = TextEditingController(text: widget.score.notes ?? '');
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  void _notify() {
    widget.onChanged(widget.score.copyWith(
      score: _localScore,
      selectedMangelIds: _localMangelIds,
      selectedCauses: _localCauses,
      notes: _notesCtrl.text,
    ));
  }

  void _setScore(int v) {
    setState(() => _localScore = v);
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final minor = widget.minor;
    final minVal = minor.minScore;
    final maxVal = minor.maxScore;
    final range = maxVal - minVal;
    final accent = widget.accentColor;

    // Score selector widget (left column)
    Widget scoreSelector;
    if (widget.readOnly) {
      scoreSelector = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.withOpacity(0.3)),
        ),
        child: Text(
          _localScore != null ? '$_localScore / $maxVal' : '–',
          style: TextStyle(
              color: accent, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      );
    } else if (range <= 20) {
      scoreSelector = Wrap(
        spacing: 4,
        runSpacing: 4,
        children: List.generate(range + 1, (i) {
          final v = minVal + i;
          final selected = _localScore == v;
          return GestureDetector(
            onTap: () => _setScore(v),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? accent : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: selected ? accent : Colors.grey.shade300),
              ),
              child: Text(
                '$v',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : Colors.black54,
                ),
              ),
            ),
          );
        }),
      );
    } else {
      scoreSelector = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            color: accent,
            onPressed: (_localScore ?? minVal) > minVal
                ? () => _setScore((_localScore ?? minVal) - 1)
                : null,
          ),
          Text(
            _localScore?.toString() ?? '$minVal',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            color: accent,
            onPressed: (_localScore ?? minVal) < maxVal
                ? () => _setScore((_localScore ?? minVal) + 1)
                : null,
          ),
          Text('/ $maxVal',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        ],
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: accent.withOpacity(0.2)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: score buttons
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Score badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accent.withOpacity(0.3)),
                  ),
                  child: Text(
                    _localScore != null
                        ? '$_localScore / $maxVal'
                        : '– / $maxVal',
                    style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                scoreSelector,
              ],
            ),
            const SizedBox(width: 14),
            // Right: name, mängel, notes
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    minor.name,
                    style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                  if (minor.mangel.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: minor.mangel.map((mg) {
                        final selected = _localMangelIds.contains(mg.id);
                        return FilterChip(
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 0),
                          label: Text(mg.description,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: selected
                                      ? Colors.white
                                      : Colors.black87)),
                          selected: selected,
                          onSelected: widget.readOnly
                              ? null
                              : (v) {
                                  setState(() {
                                    v
                                        ? _localMangelIds.add(mg.id)
                                        : _localMangelIds.remove(mg.id);
                                  });
                                  _notify();
                                },
                          backgroundColor: Colors.grey.shade100,
                          selectedColor: accent,
                          checkmarkColor: Colors.white,
                          side: BorderSide(
                              color: selected
                                  ? accent
                                  : Colors.grey.shade300),
                        );
                      }).toList(),
                    ),
                    // Causes for selected Mängel
                    ...minor.mangel
                        .where((mg) =>
                            _localMangelIds.contains(mg.id) &&
                            mg.causes.isNotEmpty)
                        .map((mg) => Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ursachen – ${mg.description}:',
                                    style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 3),
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 3,
                                    children: mg.causes.map((cause) {
                                      final sel = _localCauses.contains(cause);
                                      return FilterChip(
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 0),
                                        label: Text(cause,
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: sel
                                                    ? Colors.white
                                                    : Colors.black87)),
                                        selected: sel,
                                        onSelected: widget.readOnly
                                            ? null
                                            : (v) {
                                                setState(() {
                                                  v
                                                      ? _localCauses.add(cause)
                                                      : _localCauses
                                                          .remove(cause);
                                                });
                                                _notify();
                                              },
                                        backgroundColor: Colors.grey.shade100,
                                        selectedColor: accent.withOpacity(0.8),
                                        checkmarkColor: Colors.white,
                                        side: BorderSide(
                                            color: sel
                                                ? accent
                                                : Colors.grey.shade300),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            )),
                  ],
                  const SizedBox(height: 6),
                  TextField(
                    controller: _notesCtrl,
                    readOnly: widget.readOnly,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Anmerkung (optional)',
                      hintStyle: TextStyle(
                          color: Colors.grey.shade400, fontSize: 12),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 0),
                      border: InputBorder.none,
                      enabledBorder: UnderlineInputBorder(
                          borderSide:
                              BorderSide(color: Colors.grey.shade200)),
                      focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: accent)),
                    ),
                    onChanged: (_) => _notify(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
