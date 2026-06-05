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
- [x] Backend tarafinda 3 saniye dinleme olmadan swipe kilidi eklendi.
- [x] Gunluk konusma hakki reset mekanizmasi eklendi.
- [x] AWS harcama uyarisi icin 1 USD budget olusturuldu.

## Faz 3: Flutter Temel Kurulumu
- [x] Flutter projesi `mobile/` altinda olusturuldu.
- [x] Riverpod, Dio ve secure storage entegrasyonu yapildi.
- [x] Kayit/giris ekranlari backend auth endpointlerine baglandi.
- [x] Feed, profile ve DM UI iskeleti olusturuldu.
- [x] Profile ekraninda profil resmi URL/placeholder destegi eklendi.
- [ ] Dilsiz giris ekrani ozel animasyon ve metinlerle cilalanacak.

## Faz 4: Core Mobil Mekanikler
- [ ] Flutter tarafinda 3 saniye fitil animasyonu ve swipe kilidi.
- [ ] Mikrofon kayit akisi.
- [ ] Accelerometer ile telefonu savurarak ses gonderme (The Cast).
- [ ] Feed oynatma ve dinleme baslatma entegrasyonu.
- [ ] DM backend ve gercek mesajlasma entegrasyonu.

## Faz 5: Guvenlik ve Yayina Hazirlik
- [ ] AWS access key rotate edilecek ve yerel `.env` tekrar guncellenecek.
- [ ] Production icin IAM Role/secret yonetimi planlanacak.
- [ ] Rate limit ve abuse korumalari eklenecek.
- [ ] Gercek cihazla uc uca test yapilacak.
