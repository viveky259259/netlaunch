/// Validates site name format for NetLaunch deployments.
/// Pure Dart — no Flutter dependency.
class SiteNameValidator {
  static const int minLength = 3;
  static const int maxLength = 30;
  static final RegExp _startsWithLetter = RegExp(r'^[a-z]');
  static final RegExp _validChars = RegExp(r'^[a-z][a-z0-9-]*$');

  /// Returns null if valid, or an error message string.
  static String? validate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a site name';
    }
    if (value.length < minLength) {
      return 'Site name must be at least $minLength characters';
    }
    if (value.length > maxLength) {
      return 'Site name must be $maxLength characters or less';
    }
    if (!_startsWithLetter.hasMatch(value)) {
      return 'Site name must start with a letter';
    }
    if (!_validChars.hasMatch(value)) {
      return 'Only lowercase letters, numbers, and hyphens allowed';
    }
    if (value.endsWith('-')) {
      return 'Site name cannot end with a hyphen';
    }
    return null;
  }
}
