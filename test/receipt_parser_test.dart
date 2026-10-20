import 'package:fis_takip/services/receipt_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = ReceiptParser();

  test('tipik market fişini ayrıştırır', () {
    const text = '''
MİGROS TİCARET A.Ş.
ATATÜRK MAH. CUMHURİYET CAD. NO:12
KADIKÖY / İSTANBUL
TARİH: 15.10.2026   SAAT: 14:32
FİŞ NO: 0045
2 AD X 12,50
EKMEK              %01  *25,00
SÜT 1L             %01  *32,90
0,750 KG X 40,00
DOMATES            %01  *30,00
İNDİRİM                 -5,00
TOPKDV                  *0,82
TOPLAM                  *82,90
NAKİT                   *100,00
PARA ÜSTÜ               *17,10
''';
    final r = parser.parse(text);

    expect(r.storeName, 'Migros Ticaret A.Ş.');
    expect(r.date, DateTime(2026, 10, 15, 14, 32));
    expect(r.total, 82.90);
    expect(r.vat, 0.82);
    expect(r.paymentMethod, 'Nakit');
    expect(r.receiptNo, '0045');
    expect(r.category, 'market');
    expect(r.items.map((i) => i.name), ['Ekmek', 'Süt 1L', 'Domates', 'İndirim']);
    expect(r.items[0].quantity, 2);
    expect(r.items[0].total, 25.0);
    expect(r.items[2].quantity, 0.75);
    expect(r.items[3].total, -5.0);
    expect(r.itemsTotal, closeTo(82.90, 0.001));
  });

  test('fiyatı alt satıra düşmüş ürünleri ve binlik ayırıcıları okur', () {
    const text = '''
TEKNOSA İÇ VE DIŞ TİCARET
19/10/26 10:05
KULAKLIK BLUETOOTH
*1.249,90
USB KABLO   *149,00
KDV TOPLAM  *233,32
GENEL TOPLAM  *1.398,90
KREDİ KARTI   *1.398,90
''';
    final r = parser.parse(text);

    expect(r.storeName, 'Teknosa İç Ve Dış Ticaret');
    expect(r.date, DateTime(2026, 10, 19, 10, 5));
    expect(r.total, 1398.90);
    expect(r.vat, 233.32);
    expect(r.paymentMethod, 'Kart');
    expect(r.category, 'elektronik');
    expect(r.items.length, 2);
    expect(r.items[0].name, 'Kulaklık Bluetooth');
    expect(r.items[0].total, 1249.90);
    expect(r.items[1].total, 149.0);
  });

  test('toplam yoksa kalemlerden hesaplar, ürün adlarını anahtar kelimelerle karıştırmaz', () {
    const text = '''
ŞOK MARKETLER
TELEFON KILIFI  29,90
KARTON BARDAK  15,50
ÇEKİRDEK  20,00
''';
    final r = parser.parse(text);

    expect(r.storeName, 'Şok Marketler');
    expect(r.category, 'market');
    expect(r.items.map((i) => i.name), ['Telefon Kılıfı', 'Karton Bardak', 'Çekirdek']);
    expect(r.total, 65.40);
    expect(r.date, isNull);
  });

  test('ML Kit karakter hatalarını düzeltir (emülatörde okunan gerçek çıktı)', () {
    const text = '''
MÍGROS TỈCARET A.Ş.
ATAŞEHİR MAH. ÇAMLIK SK. NO:8
TEL: 0216 555 12 34
TARİH: 18.10. 2026  SAAT: 18:47
FİŞ NO: 0312
3 AD X 12, 50
SU O.5L  %01  *37, 50
MAKARNA 500G  %01  *24,9
ZEYTİNYAĞI 1L %O1  *329,00
DETERJAN  %20  *189,90
ELMA  %01  *42,75
TOPKDV  *35,71
TOPLAM  *624,O5
KREDİ KARTI  *624,05
TEŞEKKÜR EDERİz
''';
    final r = parser.parse(text);

    expect(r.storeName, 'Migros Ticaret A.Ş.');
    expect(r.category, 'market');
    expect(r.date, DateTime(2026, 10, 18, 18, 47));
    expect(r.receiptNo, '0312');
    expect(r.total, 624.05);
    expect(r.vat, 35.71);
    expect(r.items.map((i) => i.name),
        ['Su 0.5L', 'Makarna 500G', 'Zeytinyağı 1L', 'Deterjan', 'Elma']);
    expect(r.items.first.quantity, 3);
    expect(r.items[1].total, 24.90);
    expect(r.itemsTotal, closeTo(624.05, 0.001));
  });

  test('harften sonra gelen O harfine dokunmaz', () {
    final r = parser.parse('DR.OETKER MARKET\nFİŞ NO.0045\nPUDİNG  *15,00\nTOPLAM  *15,00');
    expect(r.storeName, 'Dr.oetker Market');
    expect(r.receiptNo, '0045');
    expect(r.items.single.name, 'Puding');
  });

  test('boş metinde çökmez', () {
    final r = parser.parse('');
    expect(r.items, isEmpty);
    expect(r.total, isNull);
    expect(r.storeName, isNull);
    expect(r.category, 'diger');
  });
}
