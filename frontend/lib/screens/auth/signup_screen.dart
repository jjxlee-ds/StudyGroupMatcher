import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../home_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _nyuIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _majorController = TextEditingController();
  final _minorController = TextEditingController();
  final _locationController = TextEditingController();
  final _timeController = TextEditingController();
  final _gpaController = TextEditingController();

  int _academicStanding = 1;
  int _workWillingness = 5;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _nyuIdController.dispose();
    _passwordController.dispose();
    _majorController.dispose();
    _minorController.dispose();
    _locationController.dispose();
    _timeController.dispose();
    _gpaController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);
    try {
      await context.read<AuthProvider>().signup(
            name: _nameController.text.trim(),
            nyuEmail: _emailController.text.trim(),
            nyuId: _nyuIdController.text.trim(),
            password: _passwordController.text,
            major: _majorController.text.trim(),
            minor: _minorController.text.trim().isEmpty
                ? null
                : _minorController.text.trim(),
            academicStanding: _academicStanding,
            workWillingness: _workWillingness,
            preferredLocation: _locationController.text.trim().isEmpty
                ? null
                : _locationController.text.trim(),
            timePreference: _timeController.text.trim().isEmpty
                ? null
                : _timeController.text.trim(),
            gpa: _gpaController.text.trim().isEmpty
                ? null
                : double.tryParse(_gpaController.text.trim()),
          );
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (_) => false,
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'NYU Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nyuIdController,
                decoration: const InputDecoration(labelText: 'NYU ID'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (v) =>
                    v == null || v.length < 8 ? 'Min 8 characters' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _majorController,
                decoration: const InputDecoration(labelText: 'Major'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _minorController,
                decoration: const InputDecoration(labelText: 'Minor (optional)'),
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
              TextFormField(
                controller: _locationController,
                decoration:
                    const InputDecoration(labelText: 'Preferred Location (optional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _timeController,
                decoration:
                    const InputDecoration(labelText: 'Time Preference (optional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _gpaController,
                decoration: const InputDecoration(labelText: 'GPA (optional)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: auth.isLoading ? null : _submit,
                child: auth.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Sign Up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
