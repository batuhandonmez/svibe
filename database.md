# Veritabani Semasi (PostgreSQL - Supabase)

## 1. `users` Tablosu
- `id`: UUID, primary key.
- `username`: Benzersiz kullanici adi.
- `profile_picture_url`: Profil fotografi URL'i, bos olabilir.
- `password_hash`: Sifre hash'i, eski/dev kullanicilarda bos olabilir.
- `is_muted`: Kullanici su an konusma hakkina sahip mi?
- `daily_vibe_count`: Bugun kalan vibe yukleme hakki.
- `daily_vibe_reset_at`: Gunluk haklarin yenilenecegi zaman.
- `is_vip`: VIP/kurucu kullanici bayragi.
- `created_at`: Olusturulma zamani.

## 2. `vibes` Tablosu
- `id`: UUID, primary key.
- `user_id`: Vibe'i yukleyen kullanici.
- `audio_url`: S3'teki ses dosyasi URL'i.
- `duration`: Ses suresi, maksimum 30 saniye.
- `swipe_right_count`: Saga kaydirma sayisi.
- `is_golden_voice`: Golden Voice kilit acma bayragi.
- `created_at`: Olusturulma zamani.
- `expires_at`: Vibe'in aktif kalacagi son zaman.

## 3. `vibe_listens` Tablosu
- `id`: UUID, primary key.
- `user_id`: Dinleyen kullanici.
- `vibe_id`: Dinlenen vibe.
- `started_at`: Dinlemenin basladigi zaman.
- `(user_id, vibe_id)`: Ayni kullanici ayni vibe icin tek dinleme kaydi acabilir.
