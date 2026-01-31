import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _editing = false;
  bool _saving = false;
  String? _error;

  late TextEditingController _nameController;
  late TextEditingController _majorController;
  late TextEditingController _minorController;
  late TextEditingController _locationController;
  late TextEditingController _timeController;
  late TextEditingController _gpaController;
  late int _academicStanding;
  late int _workWillingness;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user!;
    _nameController = TextEditingController(text: user.name);
    _majorController = TextEditingController(text: user.major);
    _minorController = TextEditingController(text: user.minor ?? '');
    _locationController = TextEditingController(text: user.preferredLocation);
    _timeController = TextEditingController(text: user.timePreference);
    _gpaController = TextEditingController(text: user.gpa?.toString() ?? '');
    _academicStanding = user.academicStanding;
    _workWillingness = user.workWillingness;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _majorController.dispose();
    _minorController.dispose();
    _locationController.dispose();
    _timeController.dispose();
    _gpaController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await UserService.updateMe(UserUpdate(
        name: _nameController.text.trim(),
        major: _majorController.text.trim(),
        minor: _minorController.text.trim().isEmpty
            ? null
            : _minorController.text.trim(),
        academicStanding: _academicStanding,
        workWillingness: _workWillingness,
        preferredLocation: _locationController.text.trim(),
        timePreference: _timeController.text.trim(),
        gpa: _gpaController.text.trim().isEmpty
            ? null
            : double.tryParse(_gpaController.text.trim()),
      ));
      if (mounted) {
        context.read<AuthProvider>().updateUser(updated);
        setState(() => _editing = false);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;

    if (!_editing) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _editing = true),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _infoTile('Name', user.name),
            _infoTile('Email', user.nyuEmail),
            _infoTile('NYU ID', user.nyuId),
            _infoTile('Major', user.major),
            _infoTile('Minor', user.minor ?? 'N/A'),
            _infoTile('Academic Standing', _standingLabel(user.academicStanding)),
            _infoTile('Work Willingness', '${user.workWillingness}/10'),
            _infoTile('Preferred Location', user.preferredLocation),
            _infoTile('Time Preference', user.timePreference),
            _infoTile('GPA', user.gpa?.toStringAsFixed(2) ?? 'N/A'),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _editing = false),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _majorController,
            decoration: const InputDecoration(labelText: 'Major'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _minorController,
            decoration: const InputDecoration(labelText: 'Minor'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _academicStanding,
            decoration: const InputDecoration(labelText: 'Academic Standing'),
            items: const [
              DropdownMenuItem(value: 1, child: Text('Freshman')),
              DropdownMenuItem(value: 2, child: Text('Sophomore')),
              DropdownMenuItem(value: 3, child: Text('Junior')),
              DropdownMenuItem(value: 4, child: Text('Senior')),
            ],
            onChanged: (v) => setState(() => _academicStanding = v!),
          ),
          const SizedBox(height: 12),
          Text('Work Willingness: $_workWillingness'),
          Slider(
            value: _workWillingness.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: _workWillingness.toString(),
            onChanged: (v) => setState(() => _workWillingness = v.round()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _locationController,
            decoration: const InputDecoration(labelText: 'Preferred Location'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _timeController,
            decoration: const InputDecoration(labelText: 'Time Preference'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _gpaController,
            decoration: const InputDecoration(labelText: 'GPA'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return ListTile(
      title: Text(label),
      subtitle: Text(value),
    );
  }

  String _standingLabel(int standing) {
    switch (standing) {
      case 1:
        return 'Freshman';
      case 2:
        return 'Sophomore';
      case 3:
        return 'Junior';
      case 4:
        return 'Senior';
      default:
        return 'Unknown';
    }
  }
}
