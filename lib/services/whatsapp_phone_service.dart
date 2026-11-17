/// Normalizes Indonesian phone numbers for WhatsApp deep links.
///
/// Accepts common local and international forms such as 0812..., 812...,
/// +62 812..., 62 (0) 812..., and 0062 812.... Google Sheets can sometimes
/// expose numeric cells in scientific notation, which is handled as well.
String normalizeWhatsAppPhone(String raw) {
  var value = raw.trim().replaceAll(RegExp(r'[\\u200B-\\u200D\\uFEFF]'), '');
  if (value.isEmpty) return '';

  final scientificNotation =
      RegExp(r'^\\+?\\d+(?:\\.\\d+)?[eE][+-]?\\d+$');
  if (scientificNotation.hasMatch(value)) {
    final numeric = double.tryParse(value.replaceFirst('+', ''));
    if (numeric == null || !numeric.isFinite || numeric <= 0) return '';
    value = numeric.toStringAsFixed(0);
  } else {
    value = value.replaceFirst(RegExp(r'\\.0+$'), '');
  }

  var digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('00')) {
    digits = digits.substring(2);
  }

  if (digits.startsWith('62')) {
    final nationalNumber =
        digits.substring(2).replaceFirst(RegExp(r'^0+'), '');
    digits = '62' + nationalNumber;
  } else if (digits.startsWith('0')) {
    digits = '62' + digits.substring(1);
  } else if (digits.startsWith('8')) {
    digits = '62' + digits;
  }

  return digits;
}

/// Extracts a usable number from a phone cell that may also contain labels,
/// extensions, or more than one contact number.
String extractWhatsAppPhone(String raw) {
  final direct = normalizeWhatsAppPhone(raw);
  if (isValidWhatsAppPhone(direct)) return direct;

  final pattern = RegExp(r'(?:\\+|00)?\\d(?:[\\s().-]*\\d){7,14}');
  for (final match in pattern.allMatches(raw)) {
    final candidate = normalizeWhatsAppPhone(match.group(0) ?? '');
    if (isValidWhatsAppPhone(candidate)) return candidate;
  }
  return '';
}

/// Checks a normalized international number before opening wa.me.
bool isValidWhatsAppPhone(String normalized) {
  if (normalized.length < 8 || normalized.length > 15) return false;

  // Indonesian WhatsApp accounts can use mobile numbers (8...) and
  // fixed-line/business numbers (21..., 22..., etc.) after country code 62.
  if (normalized.startsWith('62')) {
    final nationalNumber = normalized.substring(2);
    return nationalNumber.length >= 6 &&
        nationalNumber.length <= 13 &&
        RegExp(r'^[1-9]').hasMatch(nationalNumber);
  }

  // Other international numbers must not begin with a trunk zero.
  return RegExp(r'^[1-9]').hasMatch(normalized);
}
