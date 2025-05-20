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
  
  /// The current custom interval (for existing custom habits)
  final int? initialCustomInterval;
  
  /// Callback when frequency settings change
  final void Function({
    required FrequencyType frequencyType,
    List<DayOfWeek>? specificDays,
    int? dayOfMonth,
    int? month,
    int? customInterval,
  }) onFrequencyChanged;

  const FrequencySelector({
    Key? key,
    this.initialFrequencyType = FrequencyType.daily,
    this.initialSpecificDays,
    this.initialDayOfMonth,
    this.initialMonth,
    this.initialCustomInterval,
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
  int? _customInterval;

  @override
  void initState() {
    super.initState();
    _frequencyType = widget.initialFrequencyType;
    _specificDays = widget.initialSpecificDays ?? [];
    _dayOfMonth = widget.initialDayOfMonth;
    _month = widget.initialMonth;
    _customInterval = widget.initialCustomInterval ?? 1;
  }

  void _notifyFrequencyChanged() {
    widget.onFrequencyChanged(
      frequencyType: _frequencyType,
      specificDays: _specificDays.isNotEmpty ? _specificDays : null,
      dayOfMonth: _dayOfMonth,
      month: _month,
      customInterval: _customInterval,
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
          items: FrequencyType.values.map((type) {
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
        return 'Weekly (select one or more days)';
      case FrequencyType.monthly:
        return 'Monthly on a specific date';
      case FrequencyType.yearly:
        return 'Yearly on a specific date';
      case FrequencyType.custom:
        return 'Custom interval (every X days)';
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
      case FrequencyType.custom:
        return _buildCustomIntervalSelector();
    }
  }

  Widget _buildWeeklySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select days:'),
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
        const Text('Day of month:'),
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
        const Text('Day:'),
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

  Widget _buildCustomIntervalSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Repeat every:'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: (_customInterval ?? 1).toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: (value) {
                  final interval = int.tryParse(value);
                  if (interval != null && interval > 0) {
                    setState(() {
                      _customInterval = interval;
                    });
                    _notifyFrequencyChanged();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            const Text('days'),
          ],
        ),
      ],
    );
  }
}
