class Validators {
  static String? email(String value) {
    if (value.trim().isEmpty) return 'Email is required.';
    if (!value.contains('@')) return 'Enter a valid email address.';
    return null;
  }

  static String? password(String value) {
    if (value.trim().isEmpty) return 'Password is required.';
    if (value.trim().length < 6) return 'Password must be at least 6 characters.';
    return null;
  }
}
