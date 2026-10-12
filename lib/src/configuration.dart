/// Canonicalizes JSON permission keys consistently for runtime and setup.
String permissionKey(String key) => key.trim().toLowerCase();

/// Returns whether a supported JSON configuration value enables a permission.
bool enabledValue(dynamic value) =>
    value == true ||
    (value is String && value.trim().isNotEmpty) ||
    (value is Map && value['required'] == true);

/// Copies configuration values and rejects ambiguous case-insensitive duplicates.
Map<String, dynamic> normalizeConfig(Map<String, dynamic> config) {
  final result = <String, dynamic>{};
  for (final entry in config.entries) {
    final key = permissionKey(entry.key);
    if (key.isEmpty || result.containsKey(key)) {
      throw FormatException('Empty or duplicate permission key: ${entry.key}');
    }
    result[key] = entry.value is Map
        ? Map<String, dynamic>.unmodifiable(
            Map<String, dynamic>.from(entry.value as Map),
          )
        : entry.value;
  }
  return Map.unmodifiable(result);
}
