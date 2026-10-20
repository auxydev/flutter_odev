# Fiş Takip

Fişlerini tarayıp harcamalarını günlük, haftalık ve aylık raporlayan Flutter muhasebe uygulaması.

## Özellikler

- **Kayıt ve giriş:** Kullanıcı adı veya e-posta ile giriş yapılır. Şifreler cihazda salt + SHA-256 ile saklanır, oturum açık kalır.
- **Ana sayfa:** Üstte "Merhaba (kullanıcı adı)!" karşılaması, sağ üstte **+** butonu, bu ayın, bu haftanın ve bugünün harcama özeti, kategori dağılımı ve son fişler bulunur.
- **Fiş ekleme (+):**
  - **Fişi tara / Galeriden seç:** Google ML Kit fotoğraftaki metni cihaz üzerinde ve internet gerektirmeden okur.
  - **Fiş metnini yapıştır:** Kopyalanan fiş metni ayrıştırılır. Web'de test etmek için kullanışlıdır.
  - **Elle gir.**
  - Okunan bilgiler kaydedilmeden önce düzenlenebilir: mağaza, tarih/saat, kategori, ödeme tipi, ürünler (adet ve tutar), KDV ve toplam. Ürünlerin toplamı fiş toplamını tutmazsa uygulama uyarı gösterir.
- **Raporlar:** Günlük, haftalık ve aylık dönemler arasında geçiş yapılabilir. Her dönem için toplam harcama, fiş sayısı, ortalama ve KDV gösterilir, önceki dönemle karşılaştırılır. Ayrıca saat ve gün bazlı grafik, kategori pastası, **ürün bazında döküm** (fişlerden ayrıştırılan kalemler birleştirilir), mağazalar ve dönemin fişleri listelenir.
- **Geçmiş fişler:** Fişler aylara göre gruplanır. Mağaza veya ürün adıyla arama ve kategori filtresi vardır, kaydırarak silinebilir. Fiş detayında görsel, ürünler, okunan ham metin, düzenleme ve silme bulunur.

## Fiş okuma nasıl çalışıyor?

1. `platform_services_io.dart`: ML Kit metni blok blok döndürür. Fişlerde ürün adı ve fiyat çoğu zaman ayrı bloklara düşer. Satırlar dikey konumlarına göre yeniden birleştirilir ve böylece `EKMEK  *7,50` gibi gerçek fiş satırları elde edilir.
2. `receipt_parser.dart`: Türk ÖKC fişlerinin düzenine göre şu bilgileri çıkarır:
   - mağaza adı (ilk anlamlı satır)
   - tarih ve saat
   - `TOPLAM` / `GENEL TOPLAM` ile `TOPKDV`
   - ödeme tipi (nakit veya kart) ve fiş no
   - ürünler: `2 AD X 12,50` gibi adet satırları, fiyatı alt satıra düşmüş ürünler, `%01` KDV işaretleri, `1.234,56` binlik ayırıcıları ve indirimler
3. Kategori, mağaza adındaki anahtar kelimelerden tahmin edilir (Migros → Market, Opet → Akaryakıt vb.).

## Çalıştırma

```bash
flutter pub get
flutter run                 # bağlı emülatör/cihaz
flutter run -d chrome       # web (fotoğraftan okuma hariç)
flutter test                # ayrıştırıcı birim testleri
```

Geliştirme sırasında emülatörde ve web'de oluşturulan test hesabı: kullanıcı adı `kagan`, şifre `deneme123`. Veriler yalnızca cihazda saklanır.

> Fotoğraftan fiş okuma yalnızca Android ve iOS'ta çalışır. Web'de "Fiş metnini yapıştır" ve "Elle gir" seçenekleri kullanılabilir.

## Proje yapısı

```
lib/
  main.dart                 Uygulama girişi, Provider kurulumu
  theme.dart                Material 3 tema (açık/koyu)
  data/app_database.dart    Hive kutuları (users, receipts, session)
  models/                   AppUser, Receipt/ReceiptItem, ExpenseCategory
  state/                    AuthController, ReceiptController (ChangeNotifier)
  services/
    receipt_parser.dart     Fiş metni → yapılandırılmış veri
    report_service.dart     Dönem hesapları ve rapor özetleri
    platform/               ML Kit OCR (mobil) / stub (web)
  screens/
    auth/                   Giriş, kayıt
    home/                   Alt menü iskeleti, ana sayfa
    receipts/               Ekleme akışı, form, detay, geçmiş
    reports/                Raporlar
test/receipt_parser_test.dart
```
