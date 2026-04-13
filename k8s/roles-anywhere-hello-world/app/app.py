import json
import os
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer

import boto3
from botocore.exceptions import BotoCoreError, ClientError


def build_payload():
    region = os.getenv("AWS_REGION", os.getenv("AWS_DEFAULT_REGION", "us-east-2"))
    session = boto3.session.Session(region_name=region)

    payload = {
        "message": os.getenv("APP_MESSAGE", "Hello world from Kubernetes"),
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "region": region,
        "imds_endpoint": os.getenv("AWS_EC2_METADATA_SERVICE_ENDPOINT", ""),
    }

    try:
        sts = session.client("sts")
        payload["caller_identity"] = sts.get_caller_identity()
    except (BotoCoreError, ClientError, Exception) as exc:
        payload["caller_identity_error"] = f"{exc.__class__.__name__}: {exc}"
        return payload, 503

    try:
        s3 = session.client("s3")
        response = s3.list_buckets()
        payload["s3_bucket_names"] = [
            bucket["Name"] for bucket in response.get("Buckets", [])
        ]
    except (BotoCoreError, ClientError, Exception) as exc:
        payload["s3_bucket_names"] = []
        payload["s3_error"] = f"{exc.__class__.__name__}: {exc}"

    return payload, 200


class Handler(BaseHTTPRequestHandler):
    def _write_json(self, status_code, body):
        encoded = json.dumps(body, indent=2).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def do_GET(self):
        if self.path == "/healthz":
            self._write_json(200, {"status": "ok"})
            return

        if self.path == "/":
            body, status_code = build_payload()
            self._write_json(status_code, body)
            return

        self._write_json(404, {"error": "not found"})

    def log_message(self, format, *args):
        return


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8080"))
    server = HTTPServer(("0.0.0.0", port), Handler)
    server.serve_forever()
