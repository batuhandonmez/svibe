# Svibe Progress Report

Bu rapor, projenin su anki durumunu sade dille anlatir.

## Su An Calisan Ana Parcalar

- Kullanici kayit/giris sistemi var.
- Backend kullaniciyi JWT token ile taniyor.
- VIP, sansli normal kullanici ve muted kullanici onboarding mantigi var.
- Room sistemi yok; ana model tek seslik kesif akisi.
- `GET /vibes/discover/next` tek bir kesif sesi donduruyor.
- Kendi sesin, gizli hesap sesleri ve daha once swipe ettigin sesler kesifte
  tekrar gelmiyor.
- Kullanici ilk 3 saniye dinlemeden swipe edemiyor.
- `POST /vibes/{id}/swipe` like/dislike kaydediyor.
- Golden Voice backend tarafindan dusuk ihtimalle atanabiliyor.
- Muted kullanici Golden Voice'u like edip ritueli onaylayinca konusma hakki
  aciliyor.
- Cast ekraninda mikrofon kaydi, ses dosyasi secme ve hareket/fallback ile
  yukleme akisi var.
- Profilde display name, bio, gizlilik, DM gizliligi ve profil fotografi upload
  destegi var.
- DM thread ve mesaj endpointleri var.
- Voice DM icin backend audio upload endpointi ve Flutter temel kayit/dosya
  fallback akisi eklendi.
- Voice DM mesajlari icin temel oynatma butonu eklendi.
- Demo kullanici, demo sesler ve demo DM threadleri seed ediliyor.

## Tasarim Durumu

- Spotify yesili ve klasik AI gradient/orb dili azaltildi.
- Light mode ve dark mode destekleniyor.
- Cast alt orta FAB olmaktan cikarildi; feed ust aksiyonu oldu.
- DM feed sag ustunde duruyor.
- Auth, feed, profil, DM ve cast ekranlarinda daha keskin/premium bir gorsel
  sistem uygulandi.
- Figma MCP Starter limiti dolu oldugu icin son tasarim kararlari once Flutter'a
  uygulandi.
- Tasarim kararlari `docs/DESIGN_DIRECTION.md` dosyasinda tutuluyor.

## AWS/S3 Durumu

- S3 bucket: `svibe-audio-dev`
- Region: `eu-central-1`
- Sesler S3'e yukleniyor ve oynatma icin presigned URL uretiliyor.
- Profil fotograflari `profiles/` prefix'i altinda saklaniyor.
- Voice DM sesleri `dm/` prefix'i altinda saklaniyor.
- AWS Budgets tarafinda 1 USD esikli uyarici budget olusturuldu.

## Supabase ve Guvenlik Durumu

- Supabase advisor halen 7 public tabloda RLS kapali oldugunu kritik uyari
  olarak gosteriyor.
- RLS canli veritabaninda bilincli olarak henuz acilmadi; cunku yanlis policy
  Data API erisimini kilitleyebilir.
- RLS planindaki DM kolon isimleri gercek schema ile hizalandi.
- RLS ve policy filtrelerine hazirlik icin indexler Supabase'e migration olarak
  uygulandi.
- Ayni index SQL'i `docs/supabase_security_indexes.sql` dosyasinda tutuluyor.
- `anon` ve `authenticated` Data API rollerinin public Svibe tablolarindaki
  genis yetkileri revoke edildi.
- Backend'e temel in-process rate limit middleware'i eklendi.
- Production ortaminda default/kisa JWT secret ile API'nin acilmasini engelleyen
  guard eklendi.

## Son Dogrulama

Backend:

```powershell
cd backend
.\venv\Scripts\python.exe -m pytest tests
```

Son sonuc:

```text
7 passed
```

Flutter:

```powershell
cd mobile
flutter analyze --no-pub lib\src\features\dm\dm_screen.dart lib\src\core\api\api_client.dart
flutter test
flutter build web --dart-define API_BASE_URL=http://127.0.0.1:8002 --output C:\svibe_web_demo
```

Son sonuc:

```text
No issues found
All tests passed
Web build succeeded
```

Demo smoke check:

- `demo_user / demo12345` login calisti.
- Kesifte demo ses geldi.
- DM inbox 3 thread dondurdu.

## Siradaki Mantikli Isler

- RLS'i dogrudan production'da acmadan once Supabase Auth / custom JWT kararini
  netlestirmek.
- Supabase Data API dogrudan kullanilacaksa RLS policy + dar grant modelini
  birlikte tasarlamak.
- AWS access key rotate etmek; anahtar gecmiste chat icinde paylasildi.
- Gercek cihazda mikrofon, motion sensor, Cast ve Shake rituelini uc uca test
  etmek.
- Feed kartini Figma limiti acilinca Figma dosyasina tasimak.
- Realtime DM veya polling yenilemesini urun ihtiyacina gore secmek.
