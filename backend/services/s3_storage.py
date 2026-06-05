# backend/services/s3_storage.py
from pathlib import Path
from typing import BinaryIO
from urllib.parse import urlparse
from uuid import UUID, uuid4

import boto3
from botocore.exceptions import BotoCoreError, ClientError
from fastapi import HTTPException, UploadFile, status

from core.config import settings


ALLOWED_AUDIO_CONTENT_TYPES = {
    "audio/aac",
    "audio/m4a",
    "audio/mp4",
    "audio/mpeg",
    "audio/ogg",
    "audio/opus",
    "audio/wav",
    "audio/webm",
    "audio/x-m4a",
    "application/octet-stream",
}


def _has_s3_settings() -> bool:
    return all(
        [
            settings.AWS_ACCESS_KEY_ID,
            settings.AWS_SECRET_ACCESS_KEY,
            settings.AWS_S3_BUCKET_NAME,
        ]
    )


def _require_s3_settings() -> None:
    missing = [
        name
        for name, value in {
            "AWS_ACCESS_KEY_ID": settings.AWS_ACCESS_KEY_ID,
            "AWS_SECRET_ACCESS_KEY": settings.AWS_SECRET_ACCESS_KEY,
            "AWS_S3_BUCKET_NAME": settings.AWS_S3_BUCKET_NAME,
        }.items()
        if not value
    ]
    if missing:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Missing S3 configuration: {', '.join(missing)}",
        )


def _client():
    _require_s3_settings()
    return boto3.client(
        "s3",
        region_name=settings.AWS_REGION,
        aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
        aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
    )


def _extension(filename: str | None) -> str:
    suffix = Path(filename or "").suffix.lower()
    allowed = {".aac", ".m4a", ".mp3", ".ogg", ".opus", ".wav", ".webm"}
    return suffix if suffix in allowed else ".bin"


def _ensure_file_size(file_obj: BinaryIO) -> None:
    max_bytes = settings.MAX_AUDIO_FILE_SIZE_MB * 1024 * 1024
    current_position = file_obj.tell()
    file_obj.seek(0, 2)
    size = file_obj.tell()
    file_obj.seek(current_position)
    if size > max_bytes:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"Audio file is larger than {settings.MAX_AUDIO_FILE_SIZE_MB} MB.",
        )


def _audio_object_url(key: str) -> str:
    return f"https://{settings.AWS_S3_BUCKET_NAME}.s3.{settings.AWS_REGION}.amazonaws.com/{key}"


def _key_from_audio_url(audio_url: str) -> str:
    parsed = urlparse(audio_url)
    return parsed.path.lstrip("/")


def create_presigned_audio_url(audio_url: str, expires_in: int = 3600) -> str:
    if not _has_s3_settings():
        return audio_url

    key = _key_from_audio_url(audio_url)
    try:
        return _client().generate_presigned_url(
            "get_object",
            Params={"Bucket": settings.AWS_S3_BUCKET_NAME, "Key": key},
            ExpiresIn=expires_in,
        )
    except (BotoCoreError, ClientError) as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Could not create a playable audio URL.",
        ) from exc


def delete_audio_file(audio_url: str) -> None:
    key = _key_from_audio_url(audio_url)
    try:
        _client().delete_object(Bucket=settings.AWS_S3_BUCKET_NAME, Key=key)
    except (BotoCoreError, ClientError):
        return


def upload_audio_file(user_id: UUID, audio_file: UploadFile) -> str:
    if audio_file.content_type not in ALLOWED_AUDIO_CONTENT_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unsupported audio file type.",
        )

    _ensure_file_size(audio_file.file)
    audio_file.file.seek(0)

    key = (
        f"{settings.AWS_S3_AUDIO_PREFIX}/{user_id}/"
        f"{uuid4()}{_extension(audio_file.filename)}"
    )
    extra_args = {"ContentType": audio_file.content_type or "application/octet-stream"}

    try:
        _client().upload_fileobj(
            audio_file.file,
            settings.AWS_S3_BUCKET_NAME,
            key,
            ExtraArgs=extra_args,
        )
    except (BotoCoreError, ClientError) as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Could not upload audio to S3.",
        ) from exc

    return _audio_object_url(key)
