/// Normalizes phone numbers for WhatsApp deep links.
///
/// Explicit international prefixes (+ or 00) retain their country code.
/// Indonesian national formats (08..., 8..., 0...) are converted to 62.
/// Other international country codes are never rewritten.
String normalizeWhatsAppPhone(String raw) {
  var value = raw.trim().replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
  if (value.isEmpty) return '';
  final hasInternationalPrefix = value.startsWith('+') || value.startsWith('00');

  // Expand spreadsheet scientific notation using integer arithmetic so
  // long digit strings are not rounded by double precision.
  final scientific = RegExp(r'^\+?(\d+)(?:\.(\d+))?[eE]([+-]?\d+)$')
      .firstMatch(value);
  if (scientific != null) {
    final whole = scientific.group(1)!;
    final fraction = scientific.group(2) ?? '';
    final exponent = int.tryParse(scientific.group(3)!);
    if (exponent == null || exponent.abs() > 30) return '';
    final digits = whole + fraction;
    final decimalPosition = whole.length + exponent;
    if (decimalPosition <= 0) return '';
    value = decimalPosition >= digits.length
        ? digits + List<String>.filled(decimalPosition - digits.length, '0').join()
        : digits.substring(0, decimalPosition);
  } else {
    value = value.replaceFirst(RegExp(r'\.0+$'), '');
  }

  var digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('00')) {
    digits = digits.substring(2);
  }

  if (digits.startsWith('62')) {
    // Tolerate the common national trunk zero after Indonesia's country code.
    digits = '62' + digits.substring(2).replaceFirst(RegExp(r'^0+'), '');
  } else if (!hasInternationalPrefix && digits.startsWith('0')) {
    digits = '62' + digits.substring(1);
  } else if (!hasInternationalPrefix && digits.startsWith('8')) {
    // Bare 8... is the common Indonesian mobile format. Other country
    // codes (e.g. 1, 3, 4, 5, 6, 7, 9) remain untouched.
    digits = '62' + digits;
  }

  return digits;
}

/// Extracts a usable number from a phone cell that may contain labels,
/// extensions, links, or more than one contact number.
String extractWhatsAppPhone(String raw) {
  final direct = normalizeWhatsAppPhone(raw);
  if (isValidWhatsAppPhone(direct)) return direct;

  final linkMatch = RegExp(
    r'(?:wa\.me/|phone=)(\+?[0-9]{8,15})',
    caseSensitive: false,
  ).firstMatch(raw);
  if (linkMatch != null) {
    final linked = normalizeWhatsAppPhone(linkMatch.group(1) ?? '');
    if (isValidWhatsAppPhone(linked)) return linked;
  }

  // Scan complete digit groups. Separators are allowed inside a number;
  // punctuation/labels delimit separate contacts and extensions.
  final pattern = RegExp(r'(?:\+|00)?\d(?:[\s().-]*\d){6,14}');
  for (final match in pattern.allMatches(raw)) {
    final candidate = normalizeWhatsAppPhone(match.group(0) ?? '');
    if (isValidWhatsAppPhone(candidate)) return candidate;
  }
  return '';
}

/// Accepts global international numbers (E.164 digit count: 8–15).
/// Indonesian numbers receive an additional national-number sanity check.
bool isValidWhatsAppPhone(String normalized) {
  if (!RegExp(r'^\d{8,15}$').hasMatch(normalized) ||
      !RegExp(r'^[1-9]').hasMatch(normalized)) {
    return false;
  }

  if (normalized.startsWith('62')) {
    final nationalNumber = normalized.substring(2);
    return nationalNumber.length >= 8 &&
        nationalNumber.length <= 13 &&
        RegExp(r'^[1-9]').hasMatch(nationalNumber);
  }
  return true;
}
