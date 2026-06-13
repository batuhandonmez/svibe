from io import BytesIO
from uuid import uuid4

from starlette.datastructures import Headers, UploadFile

import services.s3_storage as storage


def _upload_file(filename: str, content_type: str, body: bytes) -> UploadFile:
    return UploadFile(
        file=BytesIO(body),
        filename=filename,
        headers=Headers({"content-type": content_type}),
    )


def _configure_local_storage(monkeypatch, tmp_path):
    monkeypatch.setattr(storage.settings, "ENVIRONMENT", "development")
    monkeypatch.setattr(storage.settings, "AWS_ACCESS_KEY_ID", None)
    monkeypatch.setattr(storage.settings, "AWS_SECRET_ACCESS_KEY", None)
    monkeypatch.setattr(storage.settings, "AWS_S3_BUCKET_NAME", None)
    monkeypatch.setattr(storage.settings, "LOCAL_MEDIA_BASE_URL", "http://testserver")
    monkeypatch.setattr(storage, "_local_media_root", lambda: tmp_path)


def test_audio_upload_uses_local_media_when_s3_is_not_configured(monkeypatch, tmp_path):
    _configure_local_storage(monkeypatch, tmp_path)
    user_id = uuid4()

    url = storage.upload_audio_file(
        user_id,
        _upload_file("sample.wav", "audio/wav", b"local-audio"),
    )

    assert url.startswith(f"http://testserver/media/uploads/vibes/{user_id}/")
    assert url.endswith(".wav")
    local_key = url.split("/media/uploads/", 1)[1]
    assert (tmp_path / local_key).read_bytes() == b"local-audio"

    storage.delete_audio_file(url)
    assert not (tmp_path / local_key).exists()


def test_profile_image_upload_uses_local_media_when_s3_is_not_configured(
    monkeypatch,
    tmp_path,
):
    _configure_local_storage(monkeypatch, tmp_path)
    user_id = uuid4()

    url = storage.upload_profile_image(
        user_id,
        _upload_file("avatar.png", "image/png", b"local-image"),
    )

    assert url.startswith(f"http://testserver/media/uploads/profiles/{user_id}/")
    assert url.endswith(".png")
    local_key = url.split("/media/uploads/", 1)[1]
    assert (tmp_path / local_key).read_bytes() == b"local-image"
