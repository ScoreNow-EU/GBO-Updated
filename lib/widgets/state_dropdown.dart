import 'package:flutter/material.dart';
import '../models/state.dart';
import '../services/city_service.dart';

class StateDropdown extends StatefulWidget {
  final String? value;
  final String labelText;
  final String? hintText;
  final ValueChanged<String?> onChanged;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final Widget? prefixIcon;
  final bool showAllOption;
  final String allOptionText;

  const StateDropdown({
    super.key,
    this.value,
    required this.labelText,
    this.hintText,
    required this.onChanged,
    this.validator,
    this.enabled = true,
    this.prefixIcon,
    this.showAllOption = false,
    this.allOptionText = 'Alle',
  });

  @override
  State<StateDropdown> createState() => _StateDropdownState();
}

class _StateDropdownState extends State<StateDropdown> {
  final CityService _cityService = CityService();
  List<GermanState> _states = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStates();
  }

  Future<void> _loadStates() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final states = await _cityService.getAllStates();
      
      setState(() {
        _states = states;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Fehler beim Laden der Bundesländer: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        Widget buildDropdown(Widget child) {
          // If we have unbounded width, provide a default constraint
          if (constraints.maxWidth == double.infinity) {
            return SizedBox(width: 200, child: child);
          }
          return child;
        }

        if (_isLoading) {
          return buildDropdown(
            DropdownButtonFormField<String>(
              isDense: true,
              decoration: InputDecoration(
                labelText: widget.labelText,
                hintText: widget.hintText,
                border: const OutlineInputBorder(),
                prefixIcon: widget.prefixIcon,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                suffixIcon: const SizedBox(
                  width: 16,
                  height: 16,
                  child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              items: const [],
              onChanged: null,
            ),
          );
        }

        if (_error != null) {
          return buildDropdown(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  isDense: true,
                  decoration: InputDecoration(
                    labelText: widget.labelText,
                    hintText: widget.hintText,
                    border: const OutlineInputBorder(),
                    prefixIcon: widget.prefixIcon,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    errorText: _error,
                  ),
                  items: const [],
                  onChanged: null,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _loadStates,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Erneut versuchen'),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        // Build dropdown items
        final items = <DropdownMenuItem<String>>[];
        
        // Add "All" option if requested
        if (widget.showAllOption) {
          items.add(DropdownMenuItem<String>(
            value: widget.allOptionText,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth == double.infinity ? 150 : constraints.maxWidth - 80,
              ),
              child: Text(
                widget.allOptionText,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ));
        }
        
        // Add state items
        items.addAll(_states.map((state) => DropdownMenuItem<String>(
          value: state.name,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth == double.infinity ? 150 : constraints.maxWidth - 80,
            ),
            child: Text(
              '${state.name} (${state.abbreviation})',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        )));

        return buildDropdown(
          DropdownButtonFormField<String>(
            value: widget.value,
            isDense: true,
            decoration: InputDecoration(
              labelText: widget.labelText,
              hintText: widget.hintText,
              border: const OutlineInputBorder(),
              prefixIcon: widget.prefixIcon,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: items,
            onChanged: widget.enabled ? widget.onChanged : null,
            validator: widget.validator,
          ),
        );
      },
    );
  }
}

/// Simplified version for quick usage
class SimpleStateDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool showAllOption;
  final String allOptionText;

  const SimpleStateDropdown({
    super.key,
    this.value,
    required this.onChanged,
    this.showAllOption = false,
    this.allOptionText = 'Alle',
  });

  @override
  Widget build(BuildContext context) {
    return StateDropdown(
      value: value,
      labelText: 'Bundesland',
      prefixIcon: const Icon(Icons.map),
      onChanged: onChanged,
      showAllOption: showAllOption,
      allOptionText: allOptionText,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Bitte wählen Sie ein Bundesland';
        }
        return null;
      },
    );
  }
}