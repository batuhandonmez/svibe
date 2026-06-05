# Veritabani Semasi (PostgreSQL - Supabase)

## 1. `users` Tablosu
- `id`: UUID, primary key.
- `username`: Benzersiz kullanici adi.
- `display_name`: Profilde gorunen ad, bos olabilir.
- `bio`: Kisa profil aciklamasi.
- `profile_picture_url`: S3 profil fotografi URL'i, bos olabilir.
- `password_hash`: Sifre hash'i.
- `is_private`: Gizli hesap bayragi. Gizli hesaplar ana kesfe dusmez.
- `message_privacy`: `everyone`, `followers` veya `off`.
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
- `swipe_right_count`: Like sayisi.
- `is_golden_voice`: Backend tarafindan nadiren atanan Golden Voice bayragi.
- `created_at`: Olusturulma zamani.
- `expires_at`: Vibe'in aktif kalacagi son zaman.

## 3. `vibe_listens` Tablosu
- `id`: UUID, primary key.
- `user_id`: Dinleyen kullanici.
- `vibe_id`: Dinlenen vibe.
- `started_at`: Dinlemenin basladigi zaman.
- `(user_id, vibe_id)`: Ayni kullanici ayni vibe icin tek dinleme kaydi acabilir.

## 4. `vibe_swipes` Tablosu
- `id`: UUID, primary key.
- `user_id`: Karari veren kullanici.
- `vibe_id`: Like/dislike verilen vibe.
- `direction`: `like` veya `dislike`.
- `created_at`: Karar zamani.
- `(user_id, vibe_id)`: Ayni ses tekrar ana akisa dusmesin diye benzersizdir.

## 5. `follows` Tablosu
- `id`: UUID, primary key.
- `follower_id`: Takip eden kullanici.
- `following_id`: Takip edilen kullanici.
- `status`: `accepted` veya `pending`.
- `created_at`, `updated_at`: Iliski zaman bilgileri.

## 6. `dm_threads` Tablosu
- `id`: UUID, primary key.
- `user_low_id`, `user_high_id`: Konusmadaki iki kullanici.
- `(user_low_id, user_high_id)`: Ayni iki kullanici icin tek thread.
- `created_at`, `updated_at`: Konusma zaman bilgileri.

## 7. `dm_messages` Tablosu
- `id`: UUID, primary key.
- `thread_id`: Mesajin ait oldugu DM thread'i.
- `sender_id`: Gonderen kullanici.
- `text`: V1 metin mesaji, bos olabilir.
- `audio_url`: Ileride voice DM icin ses URL'i, bos olabilir.
- `created_at`: Mesaj zamani.
