import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:habitly/screens/auth/login_screen.dart'; // Import your login screen

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Confirm Account Deletion'),
                    content: const Text(
                        'Are you sure you want to delete your account? This action cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Delete'),
                      ),
                    ],
                  );
                },
              );

              if (confirm == true) {
                final passwordController = TextEditingController();

                final password = await showDialog<String>(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Re-authenticate'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                              'Please enter your password to confirm account deletion.'),
                          const SizedBox(height: 16),
                          TextField(
                            controller: passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(null),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.of(context).pop(passwordController.text),
                          child: const Text('Confirm'),
                        ),
                      ],
                    );
                  },
                );

                if (password == null || password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Password is required to delete account.')),
                  );
                  return;
                }

                try {
                  final user = FirebaseAuth.instance.currentUser;

                  if (user != null) {
                    // Re-authenticate the user
                    await user.reauthenticateWithCredential(
                      EmailAuthProvider.credential(
                        email: user.email!,
                        password: password,
                      ),
                    );

                    // Delete Firestore data
                    final firestore = FirebaseFirestore.instance;
                    final batch = firestore.batch();

                    // Delete habits
                    final habitsSnapshot = await firestore
                        .collection('habits')
                        .where('userId', isEqualTo: user.uid)
                        .get();
                    for (final doc in habitsSnapshot.docs) {
                      batch.delete(doc.reference);
                    }

                    // Delete habit history
                    final historySnapshot = await firestore
                        .collection('habitHistory')
                        .doc(user.uid)
                        .collection('dates')
                        .get();
                    for (final doc in historySnapshot.docs) {
                      batch.delete(doc.reference);
                    }
                    batch.delete(
                        firestore.collection('habitHistory').doc(user.uid));

                    await batch.commit();

                    // Delete user from Firebase Authentication
                    await user.delete();

                    // Navigate to login screen
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                          builder: (context) => const LoginScreen()),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting account: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.delete, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Delete Account',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
