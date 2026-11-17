/// Normalizes Indonesian phone numbers for WhatsApp deep links.
///
/// Accepts common local and international forms such as 0812..., 812...,
/// +62 812..., 62 (0) 812..., and 0062 812.... Google Sheets can sometimes
/// expose numeric cells in scientific notation, which is handled as well.
String normalizeWhatsAppPhone(String raw) {
  var value = raw.trim().replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
  if (value.isEmpty) return '';

  final scientificNotation =
      RegExp(r'^\+?\d+(?:\.\d+)?[eE][+-]?\d+$');
  if (scientificNotation.hasMatch(value)) {
    final numeric = double.tryParse(value.replaceFirst('+', ''));
    if (numeric == null || !numeric.isFinite || numeric <= 0) return '';
    value = numeric.toStringAsFixed(0);
  } else {
    // Numeric Google Sheets cells may be serialized with a trailing .0.
    value = value.replaceFirst(RegExp(r'\.0+$'), '');
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

/// Checks a normalized international number before opening wa.me.
bool isValidWhatsAppPhone(String normalized) {
  if (normalized.length < 10 || normalized.length > 15) return false;
  // Indonesian mobile numbers must use 62 followed by 8 after normalization.
  if (normalized.startsWith('62')) return normalized.startsWith('628');
  // Keep valid E.164 numbers for customers outside Indonesia too.
  return !normalized.startsWith('0');
}
