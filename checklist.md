# Svibe Gelistirme Yol Haritasi (MVP)

## Faz 1: Backend Iskeleti ve Veritabani
- [x] FastAPI sanal ortami ve klasor yapisi kuruldu.
- [x] Supabase/PostgreSQL baglantisi yapildi.
- [x] `users` ve `vibes` modelleri olusturuldu.
- [x] Hafif migration sistemi eklendi.

## Faz 2: AWS S3 ve API Endpointleri
- [x] AWS S3 baglantisi Boto3 ile kuruldu.
- [x] `svibe-audio-dev` S3 bucket olusturuldu.
- [x] Sinirli yetkili `svibe-s3-uploader-dev` IAM kullanicisi olusturuldu.
- [x] Ses yukleme (`POST /vibes`) endpointi yazildi.
- [x] Feed sesleri (`GET /vibes`) endpointi yazildi.
- [x] Kayit, giris ve token tabanli auth eklendi.
- [x] Golden Voice kilit acma mekanigi eklendi.
- [x] Golden Voice client seciminden cikarilip backend kontrollu hale getirildi.
- [x] Backend tarafinda 3 saniye dinleme olmadan swipe kilidi eklendi.
- [x] Like/dislike swipe kaydi ve tek seslik kesif endpointi eklendi.
- [x] Gizli hesap, takip istegi ve DM gizlilik ayari eklendi.
- [x] DM thread ve mesaj endpointleri eklendi.
- [x] Profil fotografi icin direkt upload endpointi eklendi.
- [x] Gunluk konusma hakki reset mekanizmasi eklendi.
- [x] AWS harcama uyarisi icin 1 USD budget olusturuldu.

## Faz 3: Flutter Temel Kurulumu
- [x] Flutter projesi `mobile/` altinda olusturuldu.
- [x] Riverpod, Dio ve secure storage entegrasyonu yapildi.
- [x] Kayit/giris ekranlari backend auth endpointlerine baglandi.
- [x] Feed, profile, Cast ve DM UI iskeleti olusturuldu.
- [x] Profile ekraninda galeriden fotograf secme/upload akisi eklendi.
- [ ] Dilsiz giris ekrani ozel animasyon ve metinlerle cilalanacak.

## Faz 4: Core Mobil Mekanikler
- [x] Flutter tarafinda 3 saniye swipe kilidi.
- [x] Flutter feed tek seslik kesif ve sag/sol/yukari gesture akisi.
- [x] Cast ritueli icin olta atar gibi firlatma UI ve buton fallback.
- [x] Cast ekranindan ses dosyasi secip `/vibes` upload endpointine gonderme.
- [x] Mikrofon kayit akisi ve Cast upload baglantisi.
- [x] Native accelerometer ile telefonu savurarak ses gonderme.
- [x] Golden Voice icin shake your vibe sensör tetikleyici.
- [x] Feed dinleme baslatma entegrasyonu.
- [x] DM backend ve temel mesajlasma entegrasyonu.
- [ ] Voice DM ses kaydi ve audio upload entegrasyonu.

## Faz 5: Guvenlik ve Yayina Hazirlik
- [ ] AWS access key rotate edilecek ve yerel `.env` tekrar guncellenecek.
- [ ] Production icin IAM Role/secret yonetimi planlanacak.
- [x] Temel rate limit ve abuse korumasi eklendi.
- [ ] Gercek cihazla uc uca test yapilacak.
