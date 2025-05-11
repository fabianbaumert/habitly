import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/providers/habit_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:habitly/models/habit.dart';

class HabitFormScreen extends ConsumerStatefulWidget {
  const HabitFormScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HabitFormScreen> createState() => _HabitFormScreenState();
}

class _HabitFormScreenState extends ConsumerState<HabitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dailyGoalController = TextEditingController();
  TimeOfDay? _reminderTime;

  bool _isLoading = false;
  String _testMessage = '';

  @override
  void initState() {
    super.initState();
    // Test Firebase connection on screen load
    _testFirebaseConnection();
  }

  // Test Firebase connection
  Future<void> _testFirebaseConnection() async {
    try {
      setState(() {
        _testMessage = 'Testing Firebase connection...';
      });
      
      // Try to access Firestore
      final testDoc = await FirebaseFirestore.instance
          .collection('_test_connection')
          .doc('test')
          .get();
      
      setState(() {
        _testMessage = 'Firebase connection successful';
      });
      
      print('Firebase connection test successful: ${testDoc.exists ? 'Document exists' : 'Document does not exist'}');
    } catch (e) {
      setState(() {
        _testMessage = 'Firebase connection failed: $e';
      });
      print('Firebase connection test failed: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dailyGoalController.dispose();
    super.dispose();
  }

  // Format time to a readable string
  String _formatTimeOfDay(TimeOfDay timeOfDay) {
    final hour = timeOfDay.hourOfPeriod;
    final minute = timeOfDay.minute.toString().padLeft(2, '0');
    final period = timeOfDay.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  // Show time picker dialog
  Future<void> _selectTime() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? TimeOfDay.now(),
    );

    if (pickedTime != null && pickedTime != _reminderTime) {
      setState(() {
        _reminderTime = pickedTime;
      });
    }
  }

  // Save the habit
  Future<void> _saveHabit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create a new habit instance
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      final habit = Habit(
        id: FirebaseFirestore.instance.collection('habits').doc().id,
        name: _nameController.text.trim(),
        dailyGoal: _dailyGoalController.text.trim().isNotEmpty
            ? _dailyGoalController.text.trim()
            : null,
        reminderTime: _reminderTime,
        isDone: false,
        createdAt: DateTime.now(),
        userId: user.uid,
      );

      // Add the habit using the provider
      await ref.read(habitsProvider.notifier).addHabit(habit);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Habit created successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating habit: $e')),
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
        title: const Text('New Habit'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Firebase connection test message
              if (_testMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _testMessage,
                    style: TextStyle(
                      color: _testMessage.contains('failed')
                          ? Colors.red
                          : Colors.green,
                    ),
                  ),
                ),
              
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
              
              // Daily Goal (Optional)
              TextFormField(
                controller: _dailyGoalController,
                decoration: const InputDecoration(
                  labelText: 'Daily Goal (Optional)',
                  hintText: 'e.g., 8 glasses, 30 minutes, 10 pages',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              // Reminder Time
              ListTile(
                title: const Text('Reminder Time (Optional)'),
                subtitle: Text(_reminderTime != null 
                    ? 'Set for ${_formatTimeOfDay(_reminderTime!)}'
                    : 'No reminder set'),
                trailing: IconButton(
                  icon: const Icon(Icons.alarm),
                  onPressed: _selectTime,
                ),
                onTap: _selectTime,
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
                    : const Text('Save Habit', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}