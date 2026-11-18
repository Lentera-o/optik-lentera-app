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

    test('preserves international country codes instead of forcing Indonesia', () {
      expect(normalizeWhatsAppPhone('+1 (415) 555-2671'), '14155552671');
      expect(normalizeWhatsAppPhone('+44 20 7946 0958'), '442079460958');
      expect(normalizeWhatsAppPhone('+86 138 0013 8000'), '8613800138000');
      expect(normalizeWhatsAppPhone('0033 6 12 34 56 78'), '33612345678');
      expect(normalizeWhatsAppPhone('0086 138 0013 8000'), '8613800138000');
    });

    test('normalizes international numbers with punctuation', () {
      expect(normalizeWhatsAppPhone('+81 (0) 90-1234-5678'), '8109012345678');
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
      expect(normalizeWhatsAppPhone('021 555 1234'), '62215551234');
      expect(isValidWhatsAppPhone('62215551234'), isTrue);
    });

    test('rejects Indonesian number with invalid zero after country code', () {
      expect(isValidWhatsAppPhone('6208123456789'), isFalse);
    });

    test('rejects number outside supported length', () {
      expect(isValidWhatsAppPhone('628123'), isFalse);
    });

    test('accepts shorter valid international numbers', () {
      expect(isValidWhatsAppPhone('4420794609'), isTrue);
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

    test('extracts international number without plus prefix', () {
      expect(extractWhatsAppPhone('WhatsApp: 447911123456'), '447911123456');
      expect(extractWhatsAppPhone('Contact: 14155552671'), '14155552671');
    });

    test('extracts international number from wa.me link', () {
      expect(extractWhatsAppPhone('https://wa.me/447911123456'), '447911123456');
    });

    test('extracts international number from labeled cell', () {
      expect(extractWhatsAppPhone('Telp luar negeri: +44 20 7946 0958'), '442079460958');
    });

    test('returns empty when no valid number exists', () {
      expect(extractWhatsAppPhone('WhatsApp aktif'), isEmpty);
    });
  });
}
