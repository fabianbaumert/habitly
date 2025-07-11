import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/providers/habit_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:habitly/models/habit.dart';
import 'package:habitly/widgets/frequency_selector.dart';

class HabitFormScreen extends ConsumerStatefulWidget {
  final Habit? existingHabit;
  
  const HabitFormScreen({
    super.key, 
    this.existingHabit,
  });

  @override
  ConsumerState<HabitFormScreen> createState() => _HabitFormScreenState();
}

class _HabitFormScreenState extends ConsumerState<HabitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isLoading = false;
  bool get _isEditMode => widget.existingHabit != null;
  
  // Frequency settings
  FrequencyType _frequencyType = FrequencyType.daily;
  List<DayOfWeek>? _specificDays;
  int? _dayOfMonth;
  int? _month;

  @override
  void initState() {
    super.initState();
    
    // If editing, populate form with existing habit data
    if (_isEditMode) {
      _nameController.text = widget.existingHabit!.name;
      _descriptionController.text = widget.existingHabit!.description ?? '';
      
      // Initialize frequency settings from existing habit
      _frequencyType = widget.existingHabit!.frequencyType;
      _specificDays = widget.existingHabit!.specificDays;
      _dayOfMonth = widget.existingHabit!.dayOfMonth;
      _month = widget.existingHabit!.month;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Handle frequency changes
  void _handleFrequencyChanged({
    required FrequencyType frequencyType,
    List<DayOfWeek>? specificDays,
    int? dayOfMonth,
    int? month,
  }) {
    setState(() {
      _frequencyType = frequencyType;
      _specificDays = specificDays;
      _dayOfMonth = dayOfMonth;
      _month = month;
    });
  }

  // Save the habit
  Future<void> _saveHabit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate frequency selections based on frequency type
    String? frequencyError;
    switch (_frequencyType) {
      case FrequencyType.weekly:
        if (_specificDays == null || _specificDays!.isEmpty) {
          frequencyError = 'Please select at least one day of the week';
        }
        break;
      case FrequencyType.monthly:
        if (_dayOfMonth == null) {
          frequencyError = 'Please select a day of the month';
        }
        break;
      case FrequencyType.yearly:
        if (_dayOfMonth == null) {
          frequencyError = 'Please select a day for the yearly reminder';
        }
        // Month is always selected because it defaults to January (1) in the dropdown
        break;
      default:
        // Daily frequency doesn't require additional selections
        break;
    }

    // Show error and prevent saving if frequency validation fails
    if (frequencyError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(frequencyError)),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get the current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      if (_isEditMode) {
        // Update existing habit
        final updatedHabit = widget.existingHabit!.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          frequencyType: _frequencyType, // Ensure this is set from the current state
          specificDays: _specificDays,
          dayOfMonth: _dayOfMonth,
          month: _month,
        );
        
        // Update habit through provider
        await ref.read(habitsProvider.notifier).updateHabit(updatedHabit);
        
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Habit updated successfully')),
          );
        }
      } else {
        // Create a new habit
        final newHabit = Habit(
          id: FirebaseFirestore.instance.collection('habits').doc().id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          createdAt: DateTime.now(),
          userId: user.uid,
          frequencyType: _frequencyType, // Ensure this is set from the current state
          specificDays: _specificDays,
          dayOfMonth: _dayOfMonth,
          month: _month,
        );

        // Add the habit using the provider
        await ref.read(habitsProvider.notifier).addHabit(newHabit);
        debugPrint('[HabitFormScreen] addHabit called for id: ${newHabit.id}, name: ${newHabit.name}');

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Habit created successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error ${_isEditMode ? 'updating' : 'creating'} habit: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Habit' : 'New Habit'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Habit Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Habit Name *',
                  hintText: 'e.g., Drink water, Read, Exercise',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a habit name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Description (Optional)
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'e.g., 8 glasses, 30 minutes, 10 pages',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              
              // Frequency Selector
              FrequencySelector(
                initialFrequencyType: _frequencyType,
                initialSpecificDays: _specificDays,
                initialDayOfMonth: _dayOfMonth,
                initialMonth: _month,
                onFrequencyChanged: _handleFrequencyChanged,
              ),
              const SizedBox(height: 32),
              
              // Save Button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveHabit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text(
                        _isEditMode ? 'Update Habit' : 'Save Habit', 
                        style: const TextStyle(fontSize: 16)
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}