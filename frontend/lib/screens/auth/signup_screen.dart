import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../app_shell.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  static const Color primaryColor = Color(0xFF57068C);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _nyuIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _majorController = TextEditingController();
  final _minorController = TextEditingController();
  final _gpaController = TextEditingController();

  int _academicStanding = 1;
  int _workWillingness = 5;
  String _preferredLocation = 'Bobst';
  String _timePreference = 'After 12';
  bool _obscurePassword = true;
  String? _error;

  static const List<String> _locationOptions = ['Kimmel', 'Bobst', 'Off-campus'];
  static const List<String> _timeOptions = ['Before 12', 'After 12'];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _nyuIdController.dispose();
    _passwordController.dispose();
    _majorController.dispose();
    _minorController.dispose();
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
            preferredLocation: _preferredLocation,
            timePreference: _timePreference,
            gpa: _gpaController.text.trim().isEmpty
                ? null
                : double.tryParse(_gpaController.text.trim()),
          );
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AppShell()),
          (_) => false,
        );
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                  children: [
                    if (_error != null) _buildErrorBanner(_error!),
                    _buildSectionLabel('ACCOUNT'),
                    _buildCard([
                      _buildField(_nameController, 'Full Name',
                          Icons.person_outline, validator: _required),
                      _divider(),
                      _buildField(_emailController, 'NYU Email',
                          Icons.email_outlined,
                          keyboard: TextInputType.emailAddress,
                          validator: _required),
                      _divider(),
                      _buildField(_nyuIdController, 'NYU ID (NetID)',
                          Icons.badge_outlined,
                          validator: _required),
                      _divider(),
                      _buildPasswordField(),
                    ]),
                    const SizedBox(height: 24),
                    _buildSectionLabel('ACADEMIC INFO'),
                    _buildCard([
                      _buildField(_majorController, 'Major',
                          Icons.school_outlined,
                          validator: _required),
                      _divider(),
                      _buildField(_minorController, 'Minor (optional)',
                          Icons.book_outlined),
                      _divider(),
                      _buildStandingDropdown(),
                      _divider(),
                      _buildField(_gpaController, 'GPA (optional)',
                          Icons.star_outline,
                          keyboard: TextInputType.number,
                          validator: (v) {
                        if (v == null || v.isEmpty) return null;
                        final n = double.tryParse(v);
                        if (n == null || n < 0 || n > 4.0) {
                          return 'Enter a valid GPA (0.0 – 4.0)';
                        }
                        return null;
                      }),
                    ]),
                    const SizedBox(height: 24),
                    _buildSectionLabel('STUDY PREFERENCES'),
                    _buildCard([
                      _buildLocationDropdown(),
                      _divider(),
                      _buildTimeDropdown(),
                      _divider(),
                      _buildWillingnessSlider(),
                    ]),
                    const SizedBox(height: 32),
                    _buildSubmitButton(auth.isLoading),
                    const SizedBox(height: 16),
                    _buildLoginLink(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F4))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF6F6F8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back, color: primaryColor, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Account',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                'Join the NYU study community',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16, top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 56, endIndent: 0);

  Widget _buildField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          prefixIcon: Icon(icon, color: primaryColor, size: 20),
          border: InputBorder.none,
          errorStyle: const TextStyle(fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextFormField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        validator: (v) =>
            v == null || v.length < 8 ? 'Minimum 8 characters' : null,
        decoration: InputDecoration(
          labelText: 'Password',
          labelStyle: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          prefixIcon: const Icon(Icons.lock_outline, color: primaryColor, size: 20),
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _obscurePassword = !_obscurePassword),
            child: Icon(
              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: Colors.grey.shade400,
              size: 20,
            ),
          ),
          border: InputBorder.none,
          errorStyle: const TextStyle(fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildStandingDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonFormField<int>(
        initialValue: _academicStanding,
        decoration: const InputDecoration(
          labelText: 'Academic Standing',
          labelStyle: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          prefixIcon: Icon(Icons.school, color: primaryColor, size: 20),
          border: InputBorder.none,
        ),
        items: const [
          DropdownMenuItem(value: 1, child: Text('Freshman')),
          DropdownMenuItem(value: 2, child: Text('Sophomore')),
          DropdownMenuItem(value: 3, child: Text('Junior')),
          DropdownMenuItem(value: 4, child: Text('Senior')),
        ],
        onChanged: (v) => setState(() => _academicStanding = v!),
      ),
    );
  }

  Widget _buildLocationDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonFormField<String>(
        initialValue: _preferredLocation,
        decoration: const InputDecoration(
          labelText: 'Preferred Study Location',
          labelStyle: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          prefixIcon: Icon(Icons.location_on_outlined, color: primaryColor, size: 20),
          border: InputBorder.none,
        ),
        items: _locationOptions
            .map((l) => DropdownMenuItem(value: l, child: Text(l)))
            .toList(),
        onChanged: (v) => setState(() => _preferredLocation = v!),
      ),
    );
  }

  Widget _buildTimeDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonFormField<String>(
        initialValue: _timePreference,
        decoration: const InputDecoration(
          labelText: 'Preferred Study Time',
          labelStyle: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          prefixIcon: Icon(Icons.schedule_outlined, color: primaryColor, size: 20),
          border: InputBorder.none,
        ),
        items: _timeOptions
            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
            .toList(),
        onChanged: (v) => setState(() => _timePreference = v!),
      ),
    );
  }

  Widget _buildWillingnessSlider() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department_outlined,
                  color: primaryColor, size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Work Willingness',
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: primaryColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_workWillingness / 10',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: primaryColor,
              thumbColor: primaryColor,
              overlayColor: primaryColor.withAlpha(30),
              inactiveTrackColor: Colors.grey.shade200,
            ),
            child: Slider(
              value: _workWillingness.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              onChanged: (v) => setState(() => _workWillingness = v.round()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'How intensely do you want to study? (1 = casual, 10 = very focused)',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(bool loading) {
    return ElevatedButton(
      onPressed: loading ? null : _submit,
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        disabledBackgroundColor: primaryColor.withAlpha(100),
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        shadowColor: primaryColor.withAlpha(60),
      ),
      child: loading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : const Text(
              'Create Account',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
        ),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Text(
            'Sign In',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  String? _required(String? v) =>
      v == null || v.trim().isEmpty ? 'Required' : null;
}
