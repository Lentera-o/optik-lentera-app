import 'package:flutter_test/flutter_test.dart';
import 'package:optik_lentera/services/whatsapp_phone_service.dart';

void main() {
  group('normalizeWhatsAppPhone', () {
    const expected = '6281234567890';

    test('normalizes Indonesian local format', () {
      expect(normalizeWhatsAppPhone('0812 3456-7890'), expected);
    });

    test('keeps Indonesian international format', () {
      expect(normalizeWhatsAppPhone('+62 812-3456-7890'), expected);
    });

    test('removes optional zero after country code', () {
      expect(normalizeWhatsAppPhone('62 (0) 812 3456 7890'), expected);
    });

    test('supports international dialing prefix', () {
      expect(normalizeWhatsAppPhone('0062 812 3456 7890'), expected);
    });

    test('supports local number without leading zero', () {
      expect(normalizeWhatsAppPhone('81234567890'), expected);
    });

    test('supports numeric spreadsheet cells with trailing decimal', () {
      expect(normalizeWhatsAppPhone('081234567890.0'), expected);
    });

    test('supports scientific notation from spreadsheet numeric cells', () {
      expect(normalizeWhatsAppPhone('8.123456789E+10'), expected);
    });

    test('returns empty for blank input', () {
      expect(normalizeWhatsAppPhone('   '), isEmpty);
    });
  });

  group('isValidWhatsAppPhone', () {
    test('accepts normalized Indonesian mobile number', () {
      expect(isValidWhatsAppPhone('6281234567890'), isTrue);
    });

    test('rejects Indonesian number with missing mobile prefix', () {
      expect(isValidWhatsAppPhone('621234567890'), isFalse);
    });

    test('rejects number outside supported length', () {
      expect(isValidWhatsAppPhone('628123'), isFalse);
    });

    test('accepts valid international E.164 number', () {
      expect(isValidWhatsAppPhone('14155552671'), isTrue);
    });
  });
}
