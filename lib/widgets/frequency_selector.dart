import 'package:flutter/material.dart';
import 'package:habitly/models/habit.dart';

/// A widget that provides UI for selecting a habit frequency
class FrequencySelector extends StatefulWidget {
  /// The current frequency type (for existing habits)
  final FrequencyType initialFrequencyType;
  
  /// The current specific days selection (for existing habits, now used for weekly)
  final List<DayOfWeek>? initialSpecificDays;
  
  /// The current day of month (for existing monthly/yearly habits)
  final int? initialDayOfMonth;
  
  /// The current month (for existing yearly habits)
  final int? initialMonth;
  
  /// Callback when frequency settings change
  final void Function({
    required FrequencyType frequencyType,
    List<DayOfWeek>? specificDays,
    int? dayOfMonth,
    int? month,
  }) onFrequencyChanged;

  const FrequencySelector({
    Key? key,
    this.initialFrequencyType = FrequencyType.daily,
    this.initialSpecificDays,
    this.initialDayOfMonth,
    this.initialMonth,
    required this.onFrequencyChanged,
  }) : super(key: key);

  @override
  State<FrequencySelector> createState() => _FrequencySelectorState();
}

class _FrequencySelectorState extends State<FrequencySelector> {
  late FrequencyType _frequencyType;
  List<DayOfWeek> _specificDays = [];
  int? _dayOfMonth;
  int? _month;

  @override
  void initState() {
    super.initState();
    _frequencyType = widget.initialFrequencyType;
    _specificDays = widget.initialSpecificDays ?? [];
    _dayOfMonth = widget.initialDayOfMonth;
    _month = widget.initialMonth;
  }

  void _notifyFrequencyChanged() {
    widget.onFrequencyChanged(
      frequencyType: _frequencyType,
      specificDays: _specificDays.isNotEmpty ? _specificDays : null,
      dayOfMonth: _dayOfMonth,
      month: _month,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Frequency',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        
        // Frequency type selection
        DropdownButtonFormField<FrequencyType>(
          value: _frequencyType,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: FrequencyType.values
              .where((type) => type != FrequencyType.custom)
              .map((type) {
            return DropdownMenuItem<FrequencyType>(
              value: type,
              child: Text(_getFrequencyTypeLabel(type)),
            );
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null) {
              setState(() {
                _frequencyType = newValue;
              });
              _notifyFrequencyChanged();
            }
          },
        ),
        
        const SizedBox(height: 16),
        
        // Additional options based on frequency type
        _buildFrequencyOptions(),
      ],
    );
  }
  
  String _getFrequencyTypeLabel(FrequencyType type) {
    switch (type) {
      case FrequencyType.daily:
        return 'Daily';
      case FrequencyType.weekly:
        return 'Weekly (select at least one day)';
      case FrequencyType.monthly:
        return 'Monthly (select a specific day)';
      case FrequencyType.yearly:
        return 'Yearly (select month and day)';
      default:
        return '';
    }
  }

  Widget _buildFrequencyOptions() {
    switch (_frequencyType) {
      case FrequencyType.daily:
        return const SizedBox.shrink(); // No additional options for daily
      case FrequencyType.weekly:
        return _buildWeeklySelector();
      case FrequencyType.monthly:
        return _buildMonthlySelector();
      case FrequencyType.yearly:
        return _buildYearlySelector();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildWeeklySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select days (required):'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: DayOfWeek.values.map((day) {
            final isSelected = _specificDays.contains(day);
            return FilterChip(
              label: Text(day.name.substring(0, 3)),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _specificDays.add(day);
                  } else {
                    _specificDays.removeWhere((d) => d == day);
                  }
                });
                _notifyFrequencyChanged();
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMonthlySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Day of month (required):'),
        const SizedBox(height: 8),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 31,
            itemBuilder: (context, index) {
              final day = index + 1;
              final isSelected = _dayOfMonth == day;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('$day'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _dayOfMonth = day;
                      });
                      _notifyFrequencyChanged();
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildYearlySelector() {
    // Month names
    final monthNames = [
      'January', 'February', 'March', 'April',
      'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Month:'),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: _month ?? 1,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: List.generate(12, (index) {
            final monthNum = index + 1;
            return DropdownMenuItem<int>(
              value: monthNum,
              child: Text(monthNames[index]),
            );
          }),
          onChanged: (newValue) {
            if (newValue != null) {
              setState(() {
                _month = newValue;
              });
              _notifyFrequencyChanged();
            }
          },
        ),
        
        const SizedBox(height: 16),
        const Text('Day (required):'),
        const SizedBox(height: 8),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 31,
            itemBuilder: (context, index) {
              final day = index + 1;
              final isSelected = _dayOfMonth == day;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('$day'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _dayOfMonth = day;
                      });
                        _notifyFrequencyChanged();
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
