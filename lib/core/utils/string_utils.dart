class StringUtils {
  /// Get first letter of name for grouping
  static String getFirstLetter(String name) {
    if (name.isEmpty) return '#';
    final firstChar = name.trim()[0].toUpperCase();
    if (RegExp(r'[A-Z]').hasMatch(firstChar)) {
      return firstChar;
    }
    return '#';
  }

  /// Normalize string for search (remove spaces, convert to lowercase)
  static String normalizeForSearch(String text) {
    return text.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Check if search query matches name (supports space-separated names)
  static bool matchesSearch(String name, String query) {
    final normalizedName = normalizeForSearch(name);
    final normalizedQuery = normalizeForSearch(query);
    
    // Check if query matches any part of the name
    return normalizedName.contains(normalizedQuery);
  }

  /// Format phone number
  static String formatPhoneNumber(String phone) {
    // Remove all non-digit characters
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    
    // Basic formatting (can be customized based on country)
    if (digits.length >= 10) {
      return '${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6)}';
    }
    return phone;
  }
}

