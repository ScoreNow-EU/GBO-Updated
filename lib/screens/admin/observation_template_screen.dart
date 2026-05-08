import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/observation_template.dart';
import '../../services/observation_template_service.dart';
class ObservationTemplateScreen extends StatefulWidget {
  const ObservationTemplateScreen({super.key});

  @override
  State<ObservationTemplateScreen> createState() =>
      _ObservationTemplateScreenState();
}

class _ObservationTemplateScreenState
    extends State<ObservationTemplateScreen> with SingleTickerProviderStateMixin {
  final ObservationTemplateService _service = ObservationTemplateService();
  late final TabController _tabController;
  static const _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _deleteTemplate(ObservationTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vorlage löschen'),
        content: Text(
            'Soll die Vorlage "${template.name}" wirklich gelöscht werden?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Löschen', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.deleteTemplate(template.id);
    }
  }

  Future<void> _openEditor({ObservationTemplate? template, required String type}) async {
    final result = await showDialog<ObservationTemplate>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _TemplateEditorDialog(
        template: template,
        type: type,
        uuid: _uuid,
      ),
    );
    if (result == null) return;
    if (template == null) {
      await _service.addTemplate(result);
    } else {
      await _service.updateTemplate(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: const Color(0xFF0e1120),
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF4fc3f7),
            unselectedLabelColor: Colors.white54,
            indicatorColor: const Color(0xFF4fc3f7),
            tabs: const [
              Tab(text: 'Delegierte'),
              Tab(text: 'Verein'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _TemplateList(
                type: 'delegate',
                service: _service,
                onAdd: () => _openEditor(type: 'delegate'),
                onEdit: (t) => _openEditor(template: t, type: 'delegate'),
                onDelete: _deleteTemplate,
              ),
              _TemplateList(
                type: 'team',
                service: _service,
                onAdd: () => _openEditor(type: 'team'),
                onEdit: (t) => _openEditor(template: t, type: 'team'),
                onDelete: _deleteTemplate,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Template list for a given type
// ---------------------------------------------------------------------------
class _TemplateList extends StatelessWidget {
  final String type;
  final ObservationTemplateService service;
  final VoidCallback onAdd;
  final void Function(ObservationTemplate) onEdit;
  final void Function(ObservationTemplate) onDelete;

  const _TemplateList({
    required this.type,
    required this.service,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0e1120),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onAdd,
        backgroundColor: const Color(0xFF4fc3f7),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Neue Vorlage', style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<List<ObservationTemplate>>(
        stream: service.getTemplates(type: type),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final templates = snapshot.data ?? [];
          if (templates.isEmpty) {
            return const Center(
              child: Text('Keine Vorlagen vorhanden.',
                  style: TextStyle(color: Colors.white54)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: templates.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final t = templates[i];
              final minorCount =
                  t.majorCategories.expand((m) => m.minorCategories).length;
              return Card(
                color: const Color(0xFF1a2035),
                child: ListTile(
                  title: Text(t.name,
                      style: const TextStyle(color: Colors.white)),
                  subtitle: Text(
                    '$minorCount Unterkategorie(n) · '
                    '${t.calculationMethod == 'average' ? 'Durchschnitt' : 'Summe'}',
                    style: const TextStyle(color: Colors.white54),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.white54),
                        onPressed: () => onEdit(t),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => onDelete(t),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Template editor dialog — full hierarchical tree editor
// ---------------------------------------------------------------------------
class _TemplateEditorDialog extends StatefulWidget {
  final ObservationTemplate? template;
  final String type;
  final Uuid uuid;

  const _TemplateEditorDialog({
    required this.template,
    required this.type,
    required this.uuid,
  });

  @override
  State<_TemplateEditorDialog> createState() => _TemplateEditorDialogState();
}

class _TemplateEditorDialogState extends State<_TemplateEditorDialog> {
  final _nameController = TextEditingController();
  String _calculationMethod = 'average';
  List<MajorCategory> _majorCategories = [];

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    if (t != null) {
      _nameController.text = t.name;
      _calculationMethod = t.calculationMethod;
      _majorCategories = t.majorCategories.map(_cloneMajor).toList();
    }
  }

  MajorCategory _cloneMajor(MajorCategory m) => MajorCategory(
        id: m.id,
        name: m.name,
        minorCategories: m.minorCategories.map(_cloneMinor).toList(),
      );

  MinorCategory _cloneMinor(MinorCategory m) => MinorCategory(
        id: m.id,
        name: m.name,
        bestScore: m.bestScore,
        worstScore: m.worstScore,
        mangel: m.mangel.map(_cloneMangel).toList(),
      );

  Mangel _cloneMangel(Mangel mg) =>
      Mangel(id: mg.id, description: mg.description, causes: List.from(mg.causes));

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addMajor() {
    setState(() {
      _majorCategories.add(MajorCategory(
        id: widget.uuid.v4(),
        name: '',
        minorCategories: [],
      ));
    });
  }

  void _removeMajor(int majorIdx) {
    setState(() => _majorCategories.removeAt(majorIdx));
  }

  void _addMinor(int majorIdx) {
    setState(() {
      _majorCategories[majorIdx] = _majorCategories[majorIdx].copyWith(
        minorCategories: [
          ..._majorCategories[majorIdx].minorCategories,
          MinorCategory(
            id: widget.uuid.v4(),
            name: '',
            bestScore: 6,
            worstScore: 0,
            mangel: [],
          ),
        ],
      );
    });
  }

  void _removeMinor(int majorIdx, int minorIdx) {
    final list = List<MinorCategory>.from(
        _majorCategories[majorIdx].minorCategories)
      ..removeAt(minorIdx);
    setState(() {
      _majorCategories[majorIdx] =
          _majorCategories[majorIdx].copyWith(minorCategories: list);
    });
  }

  void _addMangel(int majorIdx, int minorIdx) {
    _editMangel(majorIdx, minorIdx, null);
  }

  void _editMangel(int majorIdx, int minorIdx, Mangel? existing) async {
    final result = await showDialog<Mangel>(
      context: context,
      builder: (ctx) => _MangelEditorDialog(mangel: existing, uuid: widget.uuid),
    );
    if (result == null) return;
    final minor = _majorCategories[majorIdx].minorCategories[minorIdx];
    final newMangel = existing == null
        ? [...minor.mangel, result]
        : minor.mangel.map((m) => m.id == existing.id ? result : m).toList();
    _updateMinor(
        majorIdx, minorIdx, minor.copyWith(mangel: newMangel));
  }

  void _removeMangel(int majorIdx, int minorIdx, String mangelId) {
    final minor = _majorCategories[majorIdx].minorCategories[minorIdx];
    final newMangel = minor.mangel.where((m) => m.id != mangelId).toList();
    _updateMinor(majorIdx, minorIdx, minor.copyWith(mangel: newMangel));
  }

  void _updateMinor(int majorIdx, int minorIdx, MinorCategory updated) {
    final list = List<MinorCategory>.from(
        _majorCategories[majorIdx].minorCategories);
    list[minorIdx] = updated;
    setState(() {
      _majorCategories[majorIdx] =
          _majorCategories[majorIdx].copyWith(minorCategories: list);
    });
  }

  ObservationTemplate? _buildResult() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Name darf nicht leer sein.')));
      return null;
    }
    final now = DateTime.now();
    return ObservationTemplate(
      id: widget.template?.id ?? '',
      type: widget.type,
      name: name,
      calculationMethod: _calculationMethod,
      majorCategories: _majorCategories,
      createdAt: widget.template?.createdAt ?? now,
      updatedAt: now,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1a2035),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              color: const Color(0xFF0e1120),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.template == null
                          ? 'Neue Vorlage erstellen'
                          : 'Vorlage bearbeiten',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Name der Vorlage',
                        labelStyle: TextStyle(color: Colors.white54),
                        enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF4fc3f7))),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _calculationMethod,
                      dropdownColor: const Color(0xFF252c42),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Berechnung',
                        labelStyle: TextStyle(color: Colors.white54),
                        enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24)),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'average', child: Text('Durchschnitt')),
                        DropdownMenuItem(value: 'sum', child: Text('Summe')),
                      ],
                      onChanged: (v) =>
                          setState(() => _calculationMethod = v!),
                    ),
                    const SizedBox(height: 24),
                    // Major categories
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Hauptkategorien',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        TextButton.icon(
                          onPressed: _addMajor,
                          icon: const Icon(Icons.add, size: 16,
                              color: Color(0xFF4fc3f7)),
                          label: const Text('Hinzufügen',
                              style: TextStyle(color: Color(0xFF4fc3f7))),
                        ),
                      ],
                    ),
                    ..._majorCategories.asMap().entries.map((majorEntry) {
                      final majorIdx = majorEntry.key;
                      final major = majorEntry.value;
                      return _MajorCategoryEditor(
                        key: ValueKey(major.id),
                        major: major,
                        majorIdx: majorIdx,
                        uuid: widget.uuid,
                        onNameChanged: (v) {
                          setState(() {
                            _majorCategories[majorIdx] =
                                major.copyWith(name: v);
                          });
                        },
                        onRemove: () => _removeMajor(majorIdx),
                        onAddMinor: () => _addMinor(majorIdx),
                        onRemoveMinor: (minorIdx) =>
                            _removeMinor(majorIdx, minorIdx),
                        onMinorChanged: (minorIdx, updated) =>
                            _updateMinor(majorIdx, minorIdx, updated),
                        onAddMangel: (minorIdx) =>
                            _addMangel(majorIdx, minorIdx),
                        onEditMangel: (minorIdx, mg) =>
                            _editMangel(majorIdx, minorIdx, mg),
                        onRemoveMangel: (minorIdx, mgId) =>
                            _removeMangel(majorIdx, minorIdx, mgId),
                      );
                    }),
                  ],
                ),
              ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF0e1120),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Abbrechen',
                        style: TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4fc3f7)),
                    onPressed: () {
                      final result = _buildResult();
                      if (result != null) Navigator.pop(context, result);
                    },
                    child: const Text('Speichern',
                        style: TextStyle(color: Colors.white)),
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

// ---------------------------------------------------------------------------
// Major category inline editor widget
// ---------------------------------------------------------------------------
class _MajorCategoryEditor extends StatelessWidget {
  final MajorCategory major;
  final int majorIdx;
  final Uuid uuid;
  final void Function(String) onNameChanged;
  final VoidCallback onRemove;
  final VoidCallback onAddMinor;
  final void Function(int) onRemoveMinor;
  final void Function(int, MinorCategory) onMinorChanged;
  final void Function(int) onAddMangel;
  final void Function(int, Mangel) onEditMangel;
  final void Function(int, String) onRemoveMangel;

  const _MajorCategoryEditor({
    super.key,
    required this.major,
    required this.majorIdx,
    required this.uuid,
    required this.onNameChanged,
    required this.onRemove,
    required this.onAddMinor,
    required this.onRemoveMinor,
    required this.onMinorChanged,
    required this.onAddMangel,
    required this.onEditMangel,
    required this.onRemoveMangel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF252c42),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.folder, color: Colors.white54, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: major.name,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      hintText: 'Hauptkategorie Name',
                      hintStyle: TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: onNameChanged,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 18),
                  onPressed: onRemove,
                  tooltip: 'Hauptkategorie entfernen',
                ),
              ],
            ),
            const Divider(color: Colors.white12),
            // Minor categories
            ...major.minorCategories.asMap().entries.map((entry) {
              final minorIdx = entry.key;
              final minor = entry.value;
              return _MinorCategoryEditor(
                key: ValueKey(minor.id),
                minor: minor,
                onChanged: (updated) => onMinorChanged(minorIdx, updated),
                onRemove: () => onRemoveMinor(minorIdx),
                onAddMangel: () => onAddMangel(minorIdx),
                onEditMangel: (mg) => onEditMangel(minorIdx, mg),
                onRemoveMangel: (mgId) => onRemoveMangel(minorIdx, mgId),
              );
            }),
            TextButton.icon(
              onPressed: onAddMinor,
              icon: const Icon(Icons.add, size: 14, color: Colors.white38),
              label: const Text('Unterkategorie hinzufügen',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Minor category inline editor
// ---------------------------------------------------------------------------
class _MinorCategoryEditor extends StatelessWidget {
  final MinorCategory minor;
  final void Function(MinorCategory) onChanged;
  final VoidCallback onRemove;
  final VoidCallback onAddMangel;
  final void Function(Mangel) onEditMangel;
  final void Function(String) onRemoveMangel;

  const _MinorCategoryEditor({
    super.key,
    required this.minor,
    required this.onChanged,
    required this.onRemove,
    required this.onAddMangel,
    required this.onEditMangel,
    required this.onRemoveMangel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16, bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1a2035),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.subdirectory_arrow_right,
                  size: 14, color: Colors.white38),
              const SizedBox(width: 4),
              Expanded(
                child: TextFormField(
                  initialValue: minor.name,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Unterkategorie Name',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (v) => onChanged(minor.copyWith(name: v)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 14, color: Colors.red),
                onPressed: onRemove,
              ),
            ],
          ),
          // Score range
          Row(
            children: [
              const SizedBox(width: 18),
              const Text('Beste Pkt:',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(width: 6),
              SizedBox(
                width: 48,
                child: TextFormField(
                  initialValue: minor.bestScore.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      border: InputBorder.none, isDense: true),
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null) onChanged(minor.copyWith(bestScore: n));
                  },
                ),
              ),
              const SizedBox(width: 12),
              const Text('Schlechteste Pkt:',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(width: 6),
              SizedBox(
                width: 48,
                child: TextFormField(
                  initialValue: minor.worstScore.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      border: InputBorder.none, isDense: true),
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null) onChanged(minor.copyWith(worstScore: n));
                  },
                ),
              ),
            ],
          ),
          // Mängel list
          if (minor.mangel.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...minor.mangel.map((mg) => Row(
                  children: [
                    const SizedBox(width: 18),
                    const Icon(Icons.fiber_manual_record,
                        size: 6, color: Colors.white38),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        mg.description,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (mg.causes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text('(${mg.causes.length} Ursachen)',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11)),
                      ),
                    InkWell(
                      onTap: () => onEditMangel(mg),
                      child: const Icon(Icons.edit,
                          size: 14, color: Colors.white38),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => onRemoveMangel(mg.id),
                      child: const Icon(Icons.close,
                          size: 14, color: Colors.red),
                    ),
                  ],
                )),
          ],
          TextButton.icon(
            onPressed: onAddMangel,
            icon: const Icon(Icons.add, size: 12, color: Colors.white24),
            label: const Text('Mangel hinzufügen',
                style: TextStyle(color: Colors.white24, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mangel editor dialog
// ---------------------------------------------------------------------------
class _MangelEditorDialog extends StatefulWidget {
  final Mangel? mangel;
  final Uuid uuid;

  const _MangelEditorDialog({required this.mangel, required this.uuid});

  @override
  State<_MangelEditorDialog> createState() => _MangelEditorDialogState();
}

class _MangelEditorDialogState extends State<_MangelEditorDialog> {
  final _descController = TextEditingController();
  final _causeController = TextEditingController();
  List<String> _causes = [];

  @override
  void initState() {
    super.initState();
    if (widget.mangel != null) {
      _descController.text = widget.mangel!.description;
      _causes = List.from(widget.mangel!.causes);
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    _causeController.dispose();
    super.dispose();
  }

  void _addCause() {
    final text = _causeController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _causes.add(text);
      _causeController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1a2035),
      title: Text(
          widget.mangel == null ? 'Mangel hinzufügen' : 'Mangel bearbeiten',
          style: const TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _descController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Beschreibung des Mangels',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF4fc3f7))),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Ursachen',
                style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _causeController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Ursache eingeben',
                      hintStyle: TextStyle(color: Colors.white38),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24)),
                      focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF4fc3f7))),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addCause(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: Color(0xFF4fc3f7)),
                  onPressed: _addCause,
                ),
              ],
            ),
            ..._causes.asMap().entries.map(
                  (e) => Row(
                    children: [
                      const Icon(Icons.fiber_manual_record,
                          size: 6, color: Colors.white38),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(e.value,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13))),
                      IconButton(
                        icon: const Icon(Icons.close,
                            size: 14, color: Colors.red),
                        onPressed: () =>
                            setState(() => _causes.removeAt(e.key)),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen',
              style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4fc3f7)),
          onPressed: () {
            final desc = _descController.text.trim();
            if (desc.isEmpty) return;
            Navigator.pop(
              context,
              Mangel(
                id: widget.mangel?.id ?? widget.uuid.v4(),
                description: desc,
                causes: _causes,
              ),
            );
          },
          child: const Text('Speichern',
              style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
