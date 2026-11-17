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

    test('accepts Indonesian WhatsApp business landline', () {
      expect(normalizeWhatsAppPhone('021 555 1234'), '622155551234');
      expect(isValidWhatsAppPhone('622155551234'), isTrue);
    });

    test('rejects Indonesian number with invalid zero after country code', () {
      expect(isValidWhatsAppPhone('6208123456789'), isFalse);
    });

    test('rejects number outside supported length', () {
      expect(isValidWhatsAppPhone('628123'), isFalse);
    });

    test('accepts valid international E.164 number', () {
      expect(isValidWhatsAppPhone('14155552671'), isTrue);
    });
  });

  group('extractWhatsAppPhone', () {
    test('extracts a phone number with a WA label', () {
      expect(extractWhatsAppPhone('WA: 0812 3456 7890'), '6281234567890');
    });

    test('extracts a phone number when a cell contains an extension', () {
      expect(extractWhatsAppPhone('0812-3456-7890 ext. 123'), '6281234567890');
    });

    test('uses the first valid number when a cell contains two numbers', () {
      expect(extractWhatsAppPhone('0812-3456-7890 / 0856-1234-5678'), '6281234567890');
    });

    test('returns empty when no valid number exists', () {
      expect(extractWhatsAppPhone('WhatsApp aktif'), isEmpty);
    });
  });
}
