import 'package:flutter/foundation.dart';

import '../../providers/auth_provider.dart';

class LoginViewModel extends ChangeNotifier {
  final AppState _authProvider;

  // Form state
  String _email = '';
  String _password = '';
  String? _errorMessage;
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // Getters
  String get email => _email;
  String get password => _password;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading || _authProvider.isLoading;
  bool get isPasswordVisible => _isPasswordVisible;

  LoginViewModel(this._authProvider) {
    // Listen to auth provider changes
    _authProvider.addListener(_authStateChanged);
  }

  @override
  void dispose() {
    _authProvider.removeListener(_authStateChanged);
    super.dispose();
  }

  void _authStateChanged() {
    // Update error message and loading state when auth provider changes
    if (_authProvider.error != null && _errorMessage != _authProvider.error) {
      _errorMessage = _authProvider.error;
    }

    if (_isLoading != _authProvider.isLoading) {
      _isLoading = _authProvider.isLoading;
    }

    notifyListeners();
  }

  // Update email in the form
  void updateEmail(String value) {
    _email = value;
    notifyListeners();
  }

  // Update password in the form
  void updatePassword(String value) {
    _password = value;
    notifyListeners();
  }

  // Toggle password visibility
  void togglePasswordVisibility() {
    _isPasswordVisible = !_isPasswordVisible;
    notifyListeners();
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    _authProvider.clearError();
    notifyListeners();
  }

  // Validate form inputs
  bool validateForm() {
    if (_email.isEmpty) {
      _errorMessage = 'Please enter your email';
      notifyListeners();
      return false;
    }

    if (!_email.contains('@') || !_email.contains('.')) {
      _errorMessage = 'Please enter a valid email';
      notifyListeners();
      return false;
    }

    if (_password.isEmpty) {
      _errorMessage = 'Please enter your password';
      notifyListeners();
      return false;
    }

    return true;
  }

  // Login method
  Future<bool> login() async {
    if (!validateForm()) {
      return false;
    }

    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    try {
      await _authProvider.signInWithEmailAndPassword(_email, _password);
      return _authProvider.isLoggedIn;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}