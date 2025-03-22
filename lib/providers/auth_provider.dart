// lib/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

// Access Supabase client
final supabase = Supabase.instance.client;

class AppState extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  User? _user;
  UserProfile? _userProfile;

  bool get isLoading => _isLoading;
  String? get error => _error;
  User? get user => _user;
  bool get isLoggedIn => _user != null;
  UserProfile? get userProfile => _userProfile;
  String? get userRole => _userProfile?.userRole;

  AppState() {
    // Check if user is already authenticated
    _user = supabase.auth.currentUser;

    if (_user != null) {
      // If user is logged in, fetch their profile
      _fetchUserProfile();
    }

    // Listen for auth state changes
    supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      switch (event) {
        case AuthChangeEvent.signedIn:
          _user = session?.user;
          _isLoading = false; // Reset loading state on sign in
          _fetchUserProfile(); // Fetch profile on sign in
          notifyListeners();
          break;
        case AuthChangeEvent.signedOut:
          _user = null;
          _userProfile = null; // Clear profile on sign out
          _isLoading = false; // Reset loading state on sign out
          notifyListeners();
          break;
        case AuthChangeEvent.userUpdated:
          _user = session?.user;
          _fetchUserProfile(); // Re-fetch profile on user update
          notifyListeners();
          break;
        default:
          break;
      }
    });
  }

  // Fetch user profile from the database
  Future<void> _fetchUserProfile() async {
    if (_user == null) return;

    try {
      final response = await supabase
          .from('user_profile')
          .select('*')
          .eq('id', _user!.id)
          .single();

      _userProfile = UserProfile.fromJson(response);
      notifyListeners();
    } catch (e) {
      print('Error fetching user profile: $e');
      // If profile doesn't exist yet, try to create one
      await _createDefaultProfile();
    }
  }

  // Create a default profile if one doesn't exist
  Future<void> _createDefaultProfile() async {
    if (_user == null) return;

    try {
      // Create a basic profile with default role
      final data = {
        'id': _user!.id,
        'display_name': _user!.email?.split('@').first ?? 'User',
        'user_role': 'user'
      };

      await supabase
          .from('user_profile')
          .insert(data);

      // Now fetch the created profile
      await _fetchUserProfile();
    } catch (e) {
      print('Error creating default profile: $e');
    }
  }

  // Update user's display name
  Future<void> updateDisplayName(String displayName) async {
    if (_user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      await supabase
          .from('user_profile')
          .update({'display_name': displayName})
          .eq('id', _user!.id);

      // Refresh the profile
      await _fetchUserProfile();
    } catch (e) {
      _error = 'Failed to update display name: ${e.toString()}';
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Admin function: Update a user's role
  Future<void> updateUserRole(String userId, String newRole) async {
    if (_userProfile?.userRole != 'admin') {
      _error = 'Only admins can update user roles';
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      await supabase
          .from('user_profile')
          .update({'user_role': newRole})
          .eq('id', userId);

      _error = null;
    } catch (e) {
      _error = 'Failed to update role: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign in with email and password
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        _error = "Authentication failed. Please check your credentials.";
        _isLoading = false;
        notifyListeners();
      }
      // No need to set _isLoading = false here as it will be handled by the auth state change listener

    } on AuthException catch (e) {
      // Handle Supabase auth-specific errors
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      print('Supabase AuthException: ${e.message}');
    } catch (e) {
      // Handle all other errors
      _error = "An error occurred: ${e.toString()}";
      _isLoading = false;
      notifyListeners();
      print('Login error: $e');
    }
  }

  // Sign out
  Future<void> logout() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await supabase.auth.signOut();
      // No need to set _isLoading = false here as it will be handled by the auth state change listener
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      print('Logout error: $e');
    }
  }

  // Clear any errors
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Reset loading state (can be called if loading state gets stuck)
  void resetLoadingState() {
    _isLoading = false;
    notifyListeners();
  }
}