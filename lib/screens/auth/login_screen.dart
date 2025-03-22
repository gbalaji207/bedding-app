// lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'login_view_model.dart';

class LoginScreen extends StatelessWidget {
  final AppState appState;

  const LoginScreen({Key? key, required this.appState}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Create LoginViewModel with the auth provider and provide it to the widget tree
    return ChangeNotifierProvider(
      create: (_) => LoginViewModel(appState),
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatelessWidget {
  const _LoginView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Access the view model through Provider
    final viewModel = Provider.of<LoginViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // App logo or title
              const Text(
                'Sports App',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),

              // Error message display
              if (viewModel.errorMessage != null)
                _ErrorMessageBox(
                  errorMessage: viewModel.errorMessage!,
                  onClose: viewModel.clearError,
                ),

              // Login form
              _LoginForm(viewModel: viewModel),
            ],
          ),
        ),
      ),
    );
  }
}

// Login form widget
class _LoginForm extends StatelessWidget {
  final LoginViewModel viewModel;

  const _LoginForm({Key? key, required this.viewModel}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Form(
      child: Column(
        children: [
          // Email field
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
            onChanged: viewModel.updateEmail,
            enabled: !viewModel.isLoading,
          ),
          const SizedBox(height: 16),

          // Password field
          TextFormField(
            decoration: InputDecoration(
              labelText: 'Password',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  viewModel.isPasswordVisible
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
                onPressed: viewModel.togglePasswordVisibility,
              ),
            ),
            obscureText: !viewModel.isPasswordVisible,
            onChanged: viewModel.updatePassword,
            enabled: !viewModel.isLoading,
          ),
          const SizedBox(height: 24),

          // Login button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: viewModel.isLoading
                  ? null
                  : () async {
                final success = await viewModel.login();
                if (!success && context.mounted) {
                  // You could show a snackbar here if needed
                }
              },
              child: viewModel.isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Login'),
            ),
          ),
        ],
      ),
    );
  }
}

// Error message box widget
class _ErrorMessageBox extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onClose;

  const _ErrorMessageBox({
    Key? key,
    required this.errorMessage,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.red.shade100,
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMessage,
              style: TextStyle(color: Colors.red.shade900),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}