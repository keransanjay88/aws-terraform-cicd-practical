# Demo application

A small Flask app that proves the AWS stack works end to end.

| Endpoint | Purpose |
|---|---|
| `/` | Shows instance ID and AZ, reads/writes visits and notes in RDS |
| `/notes` (POST) | Saves a note to RDS |
| `/s3-test` (POST) | Writes and reads a test object in the app S3 bucket |
| `/health` | Fast liveness check, used by the ALB target group |
| `/health/deep` | Checks Secrets Manager, RDS and S3 (503 if any fails) |

## Configuration (environment variables set by systemd)

- `SECRET_NAME`: name of the Secrets Manager secret (never the value)
- `APP_BUCKET`: application S3 bucket
- `AWS_REGION`: region
- `APP_PORT`: port gunicorn listens on

## Security notes

- DB credentials are fetched from Secrets Manager at runtime with the instance IAM role.
- The database enforces TLS. The app encrypts the connection but skips certificate
  verification in this demo. Production should download the RDS CA bundle and verify it.
- Runs as an unprivileged `appuser` under systemd.