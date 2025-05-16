import 'package:flutter/material.dart';
import 'package:habitly/services/habit_storage_service.dart';

class DebugScreen extends StatelessWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Menu'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Reset Hive Database'),
            subtitle: const Text('Clear all locally stored habits (dev only)'),
            trailing: const Icon(Icons.delete_forever),
            onTap: () async {
              // Show confirmation dialog
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Reset Database'),
                  content: const Text(
                    'This will delete all local habits data. This action cannot be undone. Continue?'
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Reset', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              // If confirmed, reset the database
              if (confirmed == true) {
                await HabitStorageService.resetDatabase();

                // Show confirmation snackbar
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Hive database has been reset'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
          ),
          const Divider(),
          // Add more debug options here as needed
        ],
      ),
    );
  }
}