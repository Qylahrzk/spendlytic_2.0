import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:spendlytic_v2/screens/settings_screen.dart';
import 'dart:io';

import '../../models/user_model.dart';
import '../../services/db_service.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final ImagePicker _picker = ImagePicker();
  final DBService _dbService = DBService();

  /// Holds the currently loaded user profile.
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// Loads the user profile from the DB.
  /// If no user exists yet, creates a default user.
  Future<void> _loadUserData() async {
    try {
      final fetchedUser = await _dbService.getUser();
      if (fetchedUser != null) {
        setState(() => _user = fetchedUser);
      } else {
        // Create a default user if the table is empty
        final newUser = UserModel(
          email: 'your.email@example.com',
          name: 'Your Name',
          defaultCurrency: 'MYR (RM)',
          sorting: 'Date',
          summary: 'Average',
        );
        await _dbService.saveOrUpdateUser(newUser);
        setState(() => _user = newUser);
      }
    } catch (e) {
      debugPrint("Error loading user: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load user data: $e')),
      );
    }
  }

  /// Allows the user to pick a new profile picture from the gallery.
  Future<void> _pickProfilePicture() async {
    if (_user == null) return;

    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _user = _user!.copyWith(profilePicturePath: image.path);
      });
      await _dbService.saveOrUpdateUser(_user!);
    }
  }

  /// Shows a dialog allowing the user to edit name and email.
  Future<void> _editProfile() async {
    if (_user == null) return;

    final nameController = TextEditingController(text: _user!.name);
    final emailController = TextEditingController(text: _user!.email);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              final newEmail = emailController.text.trim();

              if (newName.isNotEmpty && newEmail.contains('@')) {
                setState(() {
                  _user = _user!.copyWith(name: newName, email: newEmail);
                });
                await _dbService.saveOrUpdateUser(_user!);
                if (!mounted) return;
                // ignore: use_build_context_synchronously
                Navigator.pop(context);
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid name and email.')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Generic selector for user preferences (e.g. currency, sorting).
  Future<void> _selectOption({
    required String title,
    required List<String> options,
    required String currentValue,
    required String fieldKey,
  }) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Select $title'),
        children: options
            .map((opt) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, opt),
                  child: Text(opt),
                ))
            .toList(),
      ),
    );

    if (selected != null && selected != currentValue) {
      setState(() {
        switch (fieldKey) {
          case 'defaultCurrency':
            _user = _user!.copyWith(defaultCurrency: selected);
            break;
          case 'sorting':
            _user = _user!.copyWith(sorting: selected);
            break;
          case 'summary':
            _user = _user!.copyWith(summary: selected);
            break;
        }
      });
      await _dbService.saveOrUpdateUser(_user!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    if (_user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final path = _user!.profilePicturePath;
    final hasProfileImage =
        path != null && path.isNotEmpty && File(path).existsSync();
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              "ACCOUNT",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: color.primary,
            foregroundColor: color.onPrimary,
            
            //enable the settings button
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
            /// Profile picture circle avatar
                GestureDetector(
                  onTap: _pickProfilePicture,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: hasProfileImage
                    ? FileImage(File(path))
                    : const AssetImage('assets/default_profile.jpg')
                        as ImageProvider,
                    child: !hasProfileImage
                    ? Icon(Icons.camera_alt, size: 30, color: color.onPrimary)
                    : null,
                  ),
                ),
            const SizedBox(height: 16),
            
            /// User name
            Text(
              _user!.name,
              style:
                  theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),

            /// User email
            Text(
              _user!.email,
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 10),

            /// Edit profile button
            FilledButton.icon(
              onPressed: _editProfile,
              icon: const Icon(Icons.edit),
              label: const Text('Edit Profile'),
            ),
            const SizedBox(height: 24),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'My Preferences',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),

            /// Sorting preference
            ListTile(
              leading: const Icon(Icons.sort),
              title: const Text('Sorting'),
              subtitle: Text(_user!.sorting),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _selectOption(
                title: 'Sorting',
                options: ['Date', 'Alphabetical', 'Category'],
                currentValue: _user!.sorting,
                fieldKey: 'sorting',
              ),
            ),

            /// Summary preference
            ListTile(
              leading: const Icon(Icons.summarize),
              title: const Text('Summary'),
              subtitle: Text(_user!.summary),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _selectOption(
                title: 'Summary',
                options: ['Average', 'Total', 'Detailed'],
                currentValue: _user!.summary,
                fieldKey: 'summary',
              ),
            ),

            /// Default currency preference
            ListTile(
              leading: const Icon(Icons.monetization_on),
              title: const Text('Default Currency'),
              subtitle: Text(_user!.defaultCurrency),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _selectOption(
                title: 'Currency',
                options: [
                  'USD (\$)',
                  'EUR (€)',
                  'MYR (RM)',
                  'JPY (¥)',
                ],
                currentValue: _user!.defaultCurrency,
                fieldKey: 'defaultCurrency',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
