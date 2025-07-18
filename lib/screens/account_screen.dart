import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitly/providers/auth_provider.dart';
import 'package:habitly/providers/habit_history_provider.dart';
import 'package:habitly/screens/feedback_screen.dart';
import 'package:habitly/screens/account_settings_screen.dart';

class AccountScreen extends ConsumerWidget {
  final bool showDrawer;

  const AccountScreen({
    super.key,
    this.showDrawer = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We don't need to set navigation here as it's handled by the navigation provider

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          const Center(
            child: Icon(
              Icons.account_circle,
              size: 80,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              ref.read(authServiceProvider).currentUser?.email ?? '',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 30),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Menu',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          const Divider(),

          // Account Settings
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Account Settings'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AccountSettingsScreen(),
                ),
              );
            },
          ),

          // Privacy & Security
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Privacy & Security'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Privacy settings functionality will be added in future
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Privacy settings coming soon')),
              );
            },
          ),

          // Send Feedback option
          ListTile(
            leading: const Icon(Icons.feedback),
            title: const Text('Send Feedback'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FeedbackScreen(),
                ),
              );
            },
          ),

          // About
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // About functionality will be added in future
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('About page coming soon')),
              );
            },
          ),

          const Divider(),

          // Logout option
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () async {
              try {
                // Update the currentUserIdProvider to trigger UI refresh
                ref.read(currentUserIdProvider.notifier).state = null;

                // Sign out
                await ref.read(authServiceProvider).signOut();

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Successfully logged out')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error signing out: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
