# Svibe: Core UX & User Flow

Svibe oda tabanli bir uygulama degildir. Ana model sudur: kullanici kendi
profiline kisa ses paylasir; acik hesaplarin uygun sesleri ana kesif akisina
duser. Gizli hesaplar ana akisa dusmez.

## 1. Kayit ve Konusma Hakki
- VIP/kurucu kullanicilar konusma hakki acik baslar.
- Sansli azinlik dogrudan konusma hakkiyla baslayabilir.
- Geri kalan kullanicilar once dinler; konusma hakki Golden Voice ile acilir.

## 2. Ana Kesif Akisi
- Ekranda ayni anda tek ses gorunur.
- Onceki sese donus V1'de yoktur.
- Kullanici ilk 3 saniye boyunca sadece dinler.
- Kilit acildiktan sonra:
  - sola kaydirma: dislike/pass
  - saga kaydirma: like
  - yukari kaydirma veya avatar tiklama: profil onizleme
- Ses biterse acik ekranda siradaki ses yuklenebilir.

## 3. Golden Voice
- Golden Voice kullanici tarafindan secilmez.
- Backend dusuk ihtimalle bazi sesleri Golden Voice yapar.
- Muted kullanici Golden Voice'u like ederse "Shake your vibe" ritueli gelir.
- Telefonu sallama hissi ve manuel fallback ile konusma hakki acilir.

## 4. Cast Ritueli
- Konusma hakki acik kullanici en fazla 30 saniyelik ses kaydeder.
- Kayit bittikten sonra sesi olta atar gibi firlatma hareketiyle paylasir.
- Hareket algilanmazsa buton veya kaydirma fallback'i bulunur.
- Mobil MVP'de kullanici mikrofonla kayit alabilir. Dosya secme fallback'i de
  ayni Cast ritueliyle yukleme yapar.
- Basarili paylasim gunluk `daily_vibe_count` hakkini 1 azaltir.

## 5. Profil, Gizlilik ve DM
- Her kullanicinin profili vardir.
- Acik hesaplarin sesleri kesfe dusebilir.
- Gizli hesaplarin sesleri kesfe dusmez; takip istegi/onay gerekir.
- DM ayari kullanici tarafindan `everyone`, `followers` veya `off` yapilabilir.
