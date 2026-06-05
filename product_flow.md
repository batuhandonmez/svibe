# Svibe: Core UX & User Flow (Uygulamanın Ruhu)

Bu dosya, kullanıcının uygulamayı açtığı andan itibaren yaşayacağı "hissi", ekranlar arası geçiş mantığını ve ayrıcalık sistemini (Business Logic) anlatır.

## Adım 1: Kayıt ve "Kader" Anı (The Onboarding)
Kullanıcı kayıt olduğunda sistem arka planda şu kararı verir:
- **Senaryo A (VIP/Kurucu Davetlisi):** Kurucunun belirlediği özel kullanıcılar (`is_vip = True`) doğrudan konuşma hakkıyla (`is_muted = False`) ve yüksek günlük ses limitiyle başlar.
- **Senaryo B (Şanslı Azınlık - %5-10 İhtimal):** Standart bir kullanıcı kayıt olduğunda sistem zar atar. Eğer şanslı dilime girerse ekranda konfeti patlar: *"Tebrikler! Seçilmiş azınlıktansın. Doğrudan konuşma hakkıyla başlıyorsun!"* (`is_muted = False`).
- **Senaryo C (Dilsiz Çoğunluk):** Geriye kalan tüm kullanıcılar sisteme "Dilsiz" (`is_muted = True`) olarak ve günlük 3 ses limitiyle giriş yapar. Ekranda uyarı belirir: *"Önce dinlemeyi öğrenmelisin."*

## Adım 2: Zorunlu Odaklanma (The 3-Second Fuse)
- Kullanıcı "Feed" ekranında sesleri dinlerken, ilk 3 saniye boyunca ekran KİLİTLİDİR. 
- Ekranda buzlu cam profil fotoğrafı üzerinde bir fitil animasyonu yanar. 3 saniye dolmadan kaydırma (Swipe) yapılamaz. Fitil patladığında kilit açılır.

## Adım 3: Prangaları Kırmak (Golden Voice)
- Dilsiz (Senaryo C) bir kullanıcı, sesleri dinlerken sistemin gizlediği "Altın Ses"e denk gelirse ve onu sağa kaydırırsa prangaları kırılır.
- Zafer animasyonu girer: *"Prangaların Kırıldı. Konuşma Sırası Sende!"* (`is_muted` durumu False olur).

## Adım 4: 30 Saniye ve Fırlatma Ritüeli (The Cast)
- Mikrofon kilidi açık olan kullanıcı, sesini kaydeder (Maksimum 30 saniye).
- Ekranda klasik bir gönder butonu yerine *"Vibe'ını fırlatmak için telefonu savur"* yazar. 
- Kullanıcı ivmeölçer yardımıyla telefonu sertçe savurduğunda ses bir kırbaç efektiyle sisteme fırlatılır. Günlük `daily_vibe_count` limiti 1 düşer.