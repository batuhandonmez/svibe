# Svibe Teknik Mimarisi

## Frontend (Mobil - Flutter)
- **State Management:** Riverpod (Modern, ölçeklenebilir ve güvenli veri akışı için).
- **Lokal Depolama:** Hive (Kullanıcının JWT token'ı, tema ayarı vb. küçük veriler için).
- **Mimari Desen:** Feature-First (Özellik bazlı) klasör yapısı (örneğin: `features/auth`, `features/feed`, `features/profile`).
- **Tasarım Dili:** Aydınlık ve Karanlık mod destekli. Profil fotoğraflarında "Frosted Glass" (Buzlu cam) efekti kullanılacak.

## Backend (Sunucu - Python)
- **Framework:** FastAPI (Asenkron, hızlı, otomatik Swagger dökümantasyonu).
- **Sunucu Yapısı:** Uvicorn ile çalıştırılacak.
- **Klasör Yapısı:** `routers/`, `models/`, `schemas/`, `core/`, `services/`.

## Veritabanı ve Depolama (Cloud)
- **Veritabanı:** Supabase (Sadece PostgreSQL veritabanı olarak kullanılacak, ORM olarak SQLAlchemy veya SQLModel kullanılabilir).
- **Medya Depolama:** AWS S3 (Kullanıcı profil fotoğrafları ve 30 saniyelik .opus/.m4a ses dosyaları burada tutulacak. Boto3 kullanılacak).