# AWS Safety Checklist for Svibe

Svibe currently uses AWS only for S3 audio storage.

## Current S3 Setup

- Bucket: `svibe-audio-dev`
- Region: `eu-central-1`
- Public access: should stay blocked
- Purpose: development audio uploads only

## Cost Rules

- Do not create EC2, RDS, NAT Gateway, Load Balancer, or CloudFront unless planned.
- Keep the S3 bucket private.
- Delete test audio objects when they are no longer needed.
- Rotate the IAM access key if it was shared outside the local `.env`.
- Set an AWS Budget alarm before doing more AWS work.

## Recommended AWS Budget

Create a monthly cost budget:

- Budget type: Cost budget
- Amount: USD 1 or USD 5
- Alert threshold: 80% actual spend
- Email: your email address

## Cleanup Command

From `backend/`, this lists objects under the development audio prefix:

```powershell
.\venv\Scripts\python.exe - <<'PY'
import boto3
from core.config import settings

s3 = boto3.client(
    "s3",
    region_name=settings.AWS_REGION,
    aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
    aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
)
response = s3.list_objects_v2(
    Bucket=settings.AWS_S3_BUCKET_NAME,
    Prefix=settings.AWS_S3_AUDIO_PREFIX + "/",
)
for item in response.get("Contents", []):
    print(item["Key"], item["Size"])
PY
```

Do not commit `.env`.
