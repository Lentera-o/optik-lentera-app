/// Domain models for OPTIK LENTERA.
///
/// These models describe the business data collected by the existing order
/// and payment forms. They do not define Apps Script action names or assume
/// that a transaction API endpoint is deployed yet.
class Customer {
  final String name;
  final String phone;
  final String address;

  const Customer({
    required this.name,
    this.phone = '',
    this.address = '',
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'address': address,
      };

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        name: json['name']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        address: json['address']?.toString() ?? '',
      );
}

class EyePrescription {
  final String doctor;
  final String odSph;
  final String odCyl;
  final String odAxis;
  final String odAdd;
  final String odPd;
  final String osSph;
  final String osCyl;
  final String osAxis;
  final String osAdd;
  final String osPd;
  final String lensType;
  final String note;

  const EyePrescription({
    this.doctor = '',
    this.odSph = '',
    this.odCyl = '',
    this.odAxis = '',
    this.odAdd = '',
    this.odPd = '',
    this.osSph = '',
    this.osCyl = '',
    this.osAxis = '',
    this.osAdd = '',
    this.osPd = '',
    this.lensType = '',
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'doctor': doctor,
        'odSph': odSph,
        'odCyl': odCyl,
        'odAxis': odAxis,
        'odAdd': odAdd,
        'odPd': odPd,
        'osSph': osSph,
        'osCyl': osCyl,
        'osAxis': osAxis,
        'osAdd': osAdd,
        'osPd': osPd,
        'lensType': lensType,
        'note': note,
      };

  factory EyePrescription.fromJson(Map<String, dynamic> json) =>
      EyePrescription(
        doctor: json['doctor']?.toString() ?? '',
        odSph: json['odSph']?.toString() ?? '',
        odCyl: json['odCyl']?.toString() ?? '',
        odAxis: json['odAxis']?.toString() ?? '',
        odAdd: json['odAdd']?.toString() ?? '',
        odPd: json['odPd']?.toString() ?? '',
        osSph: json['osSph']?.toString() ?? '',
        osCyl: json['osCyl']?.toString() ?? '',
        osAxis: json['osAxis']?.toString() ?? '',
        osAdd: json['osAdd']?.toString() ?? '',
        osPd: json['osPd']?.toString() ?? '',
        lensType: json['lensType']?.toString() ?? '',
        note: json['note']?.toString() ?? '',
      );
}

class OrderItem {
  final String description;
  final int price;

  const OrderItem({this.description = '', this.price = 0});

  Map<String, dynamic> toJson() => {
        'description': description,
        'price': price,
      };

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        description: json['description']?.toString() ?? '',
        price: _asInt(json['price']),
      );
}

class OptikOrder {
  final String invoiceNumber;
  final DateTime? orderDate;
  final Customer customer;
  final EyePrescription prescription;
  final OrderItem frame;
  final OrderItem lens;
  final OrderItem other;
  final int initialPayment;
  final String initialPaymentMethod;
  final String note;

  const OptikOrder({
    this.invoiceNumber = '',
    this.orderDate,
    required this.customer,
    this.prescription = const EyePrescription(),
    this.frame = const OrderItem(),
    this.lens = const OrderItem(),
    this.other = const OrderItem(),
    this.initialPayment = 0,
    this.initialPaymentMethod = '',
    this.note = '',
  });

  int get total => frame.price + lens.price + other.price;
  int get remaining => total - initialPayment;

  Map<String, dynamic> toJson() => {
        'invoiceNumber': invoiceNumber,
        'orderDate': orderDate?.toIso8601String(),
        'customer': customer.toJson(),
        'prescription': prescription.toJson(),
        'frame': frame.toJson(),
        'lens': lens.toJson(),
        'other': other.toJson(),
        'initialPayment': initialPayment,
        'initialPaymentMethod': initialPaymentMethod,
        'note': note,
      };
}

class OptikPayment {
  final String invoiceNumber;
  final DateTime paymentDate;
  final int amount;
  final String method;
  final String note;

  const OptikPayment({
    required this.invoiceNumber,
    required this.paymentDate,
    required this.amount,
    required this.method,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'invoiceNumber': invoiceNumber,
        'paymentDate': paymentDate.toIso8601String(),
        'amount': amount,
        'method': method,
        'note': note,
      };
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString().replaceAll(RegExp(r'[^0-9-]'), '') ?? '') ?? 0;
}
