class ReceiptItem {
  const ReceiptItem({required this.name, this.quantity = 1, required this.total});

  final String name;
  final double quantity;

  /// Satır toplamı (adet x birim fiyat).
  final double total;

  double get unitPrice => quantity == 0 ? total : total / quantity;

  Map<String, dynamic> toMap() => {'name': name, 'quantity': quantity, 'total': total};

  factory ReceiptItem.fromMap(Map<dynamic, dynamic> m) => ReceiptItem(
        name: m['name'] as String,
        quantity: (m['quantity'] as num).toDouble(),
        total: (m['total'] as num).toDouble(),
      );

  @override
  String toString() => 'ReceiptItem($name, $quantity, $total)';
}

class Receipt {
  const Receipt({
    required this.id,
    required this.owner,
    required this.storeName,
    required this.date,
    required this.category,
    required this.items,
    required this.total,
    this.vat,
    this.paymentMethod,
    this.receiptNo,
    this.imagePath,
    this.rawText,
    required this.createdAt,
  });

  final String id;

  /// Fişin sahibi olan kullanıcının kullanıcı adı (küçük harf).
  final String owner;
  final String storeName;
  final DateTime date;
  final String category;
  final List<ReceiptItem> items;
  final double total;
  final double? vat;
  final String? paymentMethod;
  final String? receiptNo;
  final String? imagePath;
  final String? rawText;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'owner': owner,
        'storeName': storeName,
        'date': date.millisecondsSinceEpoch,
        'category': category,
        'items': items.map((e) => e.toMap()).toList(),
        'total': total,
        'vat': vat,
        'paymentMethod': paymentMethod,
        'receiptNo': receiptNo,
        'imagePath': imagePath,
        'rawText': rawText,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Receipt.fromMap(Map<dynamic, dynamic> m) => Receipt(
        id: m['id'] as String,
        owner: m['owner'] as String,
        storeName: m['storeName'] as String,
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
        category: m['category'] as String,
        items: (m['items'] as List)
            .map((e) => ReceiptItem.fromMap(e as Map))
            .toList(),
        total: (m['total'] as num).toDouble(),
        vat: (m['vat'] as num?)?.toDouble(),
        paymentMethod: m['paymentMethod'] as String?,
        receiptNo: m['receiptNo'] as String?,
        imagePath: m['imagePath'] as String?,
        rawText: m['rawText'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
      );
}
