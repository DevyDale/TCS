import 'package:flutter/material.dart';
import 'package:tcs_app/services/translation_service.dart';
import 'package:tcs_app/widgets/t_text.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final String loginType;
  
  const LoginScreen({super.key, required this.loginType});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  
  final _userIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _identifierController = TextEditingController();
  
  DateTime? _selectedDate;
  final bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.loginType == 'id' ? 'Login with ID' : 'Login with Password'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.school, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              Container(child: T("Go to home page"),),
              const T(
                'Welcome to TCS',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              
              if (widget.loginType == 'id') ...[
                TextFormField(
                  controller: _userIdController,
                  decoration: InputDecoration(
                    labelText: TranslationService.I.tr('User ID'),
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                  ),
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime(2000),
                      firstDate: DateTime(1950),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) setState(() => _selectedDate = date);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: TranslationService.I.tr('Date of Birth'),
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(_selectedDate == null ? 'Select Date' : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
                  ),
                ),
              ] else ...[
                TextFormField(
                  controller: _identifierController,
                  decoration: InputDecoration(
                    labelText: TranslationService.I.tr('Email or Username'),
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: TranslationService.I.tr('Password'),
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
              ],
              
              const SizedBox(height: 24),
              // ElevatedButton(
              //   onPressed: _isLoading ? null : _handleLogin,
              //   style: ElevatedButton.styleFrom(
              //     padding: const EdgeInsets.all(16),
              //   ),
              //   child: _isLoading
              //       ? const CircularProgressIndicator(color: Colors.white)
              //       : const T('Login', style: TextStyle(fontSize: 16)),
              // ),
            ],
          ),
        ),
      ),
    );
  }

  

  @override
  void dispose() {
    _userIdController.dispose();
    _passwordController.dispose();
    _identifierController.dispose();
    super.dispose();
  }
}
