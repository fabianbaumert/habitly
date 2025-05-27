import 'package:flutter/material.dart';
import 'package:habitly/services/connectivity_service.dart';
import 'package:habitly/services/habit_history_storage_service.dart';
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
                await HabitHistoryStorageService.resetDatabase();

                // Show confirmation snackbar
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Hive databases have been reset'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
          ),
          ListTile(
            title: const Text('Check Network Status'),
            subtitle: const Text('Display current connectivity status'),
            trailing: const Icon(Icons.network_check),
            onTap: () async {
              final connectivityService = ConnectivityService();
              final status = await connectivityService.getNetworkStatus();
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Network status: ${status == NetworkStatus.online ? "Online" : "Offline"}'),
                    backgroundColor: status == NetworkStatus.online ? Colors.green : Colors.orange,
                  ),
                );
              }
              
              connectivityService.dispose();
            },
          ),
          const Divider(),
          // Add more debug options here as needed
        ],
      ),
    );
  }
}