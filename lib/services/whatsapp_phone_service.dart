/// Normalizes phone numbers for WhatsApp deep links.
///
/// Explicit international prefixes (+ or 00) retain their country code.
/// Indonesian national formats (08..., 8...) are converted to 62.
/// Other international country codes are never rewritten.
String normalizeWhatsAppPhone(String raw) {
  var value = raw.trim().replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
  if (value.isEmpty) return '';
  final hasInternationalPrefix = value.startsWith('+') || value.startsWith('00');

  // Expand spreadsheet scientific notation without double precision rounding.
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
  if (digits.startsWith('00')) digits = digits.substring(2);

  if (digits.startsWith('62')) {
    digits = '62' + digits.substring(2).replaceFirst(RegExp(r'^0+'), '');
  } else if (!hasInternationalPrefix && digits.startsWith('0')) {
    digits = '62' + digits.substring(1);
  } else if (!hasInternationalPrefix && digits.startsWith('8')) {
    digits = '62' + digits;
  }
  return digits;
}

/// Extracts a usable phone number from a plain number or labeled sheet cell.
String extractWhatsAppPhone(String raw) {
  final trimmed = raw.trim();
  final isPlainPhone =
      RegExp(r'^(?:\+|00)?[0-9][0-9\s().-]{6,24}$').hasMatch(trimmed) ||
      RegExp(r'^\+?[0-9]+(?:\.[0-9]+)?[eE][+-]?[0-9]+$').hasMatch(trimmed);
  if (isPlainPhone) {
    final direct = normalizeWhatsAppPhone(trimmed);
    if (isValidWhatsAppPhone(direct)) return direct;
  }

  final linkMatch = RegExp(
    r'(?:wa\.me/|phone=)(\+?[0-9]{8,15})',
    caseSensitive: false,
  ).firstMatch(raw);
  if (linkMatch != null) {
    final linked = normalizeWhatsAppPhone(linkMatch.group(1) ?? '');
    if (isValidWhatsAppPhone(linked)) return linked;
  }

  // Keep number groups separate: never concatenate digits from labels or
  // extensions into a different contact number.
  final pattern = RegExp(r'(?:\+|00)?\d(?:[\s().-]*\d){6,14}');
  for (final match in pattern.allMatches(raw)) {
    final candidate = normalizeWhatsAppPhone(match.group(0) ?? '');
    if (isValidWhatsAppPhone(candidate)) return candidate;
  }
  return '';
}

/// Accepts international numbers with 8–15 digits; validates Indonesian
/// national number length after removing the +62 country code.
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
