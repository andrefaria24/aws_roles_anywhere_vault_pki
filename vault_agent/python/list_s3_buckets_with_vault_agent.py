import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import boto3
from botocore.exceptions import BotoCoreError, ClientError
from cryptography import x509
from cryptography.x509.oid import ExtensionOID


def resolve_executable(name: str) -> str:
    path = shutil.which(name)
    if not path:
        raise RuntimeError(f"Required executable not found on PATH: {name}")
    return path


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8", newline="\n")


def run_command(args: list[str], **kwargs) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        args,
        text=True,
        capture_output=True,
        check=False,
        **kwargs,
    )
    if result.returncode != 0:
        command = " ".join(args)
        raise RuntimeError(
            f"Command failed with exit code {result.returncode}: {command}\n"
            f"stdout:\n{result.stdout}\n"
            f"stderr:\n{result.stderr}"
        )
    return result


def validate_certificate(cert_path: Path, expected_uri: str) -> None:
    pem_text = cert_path.read_text(encoding="utf-8")
    certificate = x509.load_pem_x509_certificate(pem_text.encode("utf-8"))
    san = certificate.extensions.get_extension_for_oid(
        ExtensionOID.SUBJECT_ALTERNATIVE_NAME
    ).value
    uris = [str(uri) for uri in san.get_values_for_type(x509.UniformResourceIdentifier)]

    if expected_uri not in uris:
        raise RuntimeError(
            f"Vault Agent rendered a certificate without the expected SAN URI.\n"
            f"Requested URI: {expected_uri}\n"
            f"Actual URIs: {uris}"
        )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Use Vault Agent templating to issue a PKI client certificate, "
            "exchange it with AWS IAM Roles Anywhere via aws_signing_helper, "
            "and list S3 buckets with boto3."
        )
    )
    parser.add_argument("--vault-addr", required=True)
    parser.add_argument("--vault-token", required=True)
    parser.add_argument("--trust-anchor-arn", required=True)
    parser.add_argument("--profile-arn", required=True)
    parser.add_argument("--role-arn", required=True)
    parser.add_argument("--vault-namespace", default="admin")
    parser.add_argument("--pki-backend", default="pki-aws-int")
    parser.add_argument("--pki-role-name", default="team1")
    parser.add_argument("--spiffe-uri", default="spiffe://example/Team1/App1/python")
    parser.add_argument("--certificate-ttl", default="30m")
    parser.add_argument("--region", default="us-east-2")
    parser.add_argument("--endpoint")
    parser.add_argument("--vault-agent-path", default="vault")
    parser.add_argument("--aws-signing-helper-path", default="aws_signing_helper")
    parser.add_argument("--working-directory")
    parser.add_argument("--keep-artifacts", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    endpoint = args.endpoint or f"https://rolesanywhere.{args.region}.amazonaws.com"
    vault_agent_exe = resolve_executable(args.vault_agent_path)
    aws_signing_helper_exe = resolve_executable(args.aws_signing_helper_path)

    working_dir = (
        Path(args.working_directory).resolve()
        if args.working_directory
        else Path(
            tempfile.mkdtemp(prefix="vault-agent-rolesanywhere-", dir=tempfile.gettempdir())
        ).resolve()
    )
    render_dir = working_dir / "rendered"

    token_file = working_dir / "vault-token.txt"
    sink_file = working_dir / "auto-auth-token.txt"
    template_file = working_dir / "issue-cert.ctmpl"
    config_file = working_dir / "vault-agent.hcl"
    render_marker = working_dir / "rendered.txt"

    cert_path = render_dir / "cert.pem"
    key_path = render_dir / "key.pem"
    ca_path = render_dir / "issuing_ca.pem"

    try:
        render_dir.mkdir(parents=True, exist_ok=True)
        write_text(token_file, args.vault_token + "\n")

        cert_request_path = f"{args.pki_backend}/issue/{args.pki_role_name}"
        template_content = f"""{{{{- with pkiCert "{cert_request_path}" "uri_sans={args.spiffe_uri}" "ttl={args.certificate_ttl}" -}}}}
{{{{ .Data.Key | writeToFile "{key_path.as_posix()}" "" "" "0600" }}}}
{{{{ .Data.CA | writeToFile "{ca_path.as_posix()}" "" "" "0644" }}}}
{{{{ .Data.Cert | writeToFile "{cert_path.as_posix()}" "" "" "0644" }}}}
{{{{ .Data.CA | writeToFile "{cert_path.as_posix()}" "" "" "0644" "append" }}}}
rendered
{{{{- end -}}}}
"""
        write_text(template_file, template_content)

        namespace_line = ""
        if args.vault_namespace:
            namespace_line = f'  namespace = "{args.vault_namespace}"\n'

        agent_config = f"""exit_after_auth = true

vault {{
  address = "{args.vault_addr}"
{namespace_line}}}

auto_auth {{
  method "token_file" {{
    config = {{
      token_file_path = "{token_file.as_posix()}"
    }}
  }}

  sink "file" {{
    config = {{
      path = "{sink_file.as_posix()}"
    }}
  }}
}}

template_config {{
  exit_on_retry_failure = true
}}

template {{
  source = "{template_file.as_posix()}"
  destination = "{render_marker.as_posix()}"
  error_on_missing_key = true
}}
"""
        write_text(config_file, agent_config)

        run_command([vault_agent_exe, "agent", f"-config={config_file}"])

        for path in (cert_path, key_path, ca_path):
            if not path.is_file():
                raise RuntimeError(f"Expected file was not created: {path}")

        validate_certificate(cert_path, args.spiffe_uri)

        helper_result = run_command(
            [
                aws_signing_helper_exe,
                "credential-process",
                "--certificate",
                str(cert_path),
                "--private-key",
                str(key_path),
                "--trust-anchor-arn",
                args.trust_anchor_arn,
                "--profile-arn",
                args.profile_arn,
                "--role-arn",
                args.role_arn,
                "--region",
                args.region,
                "--endpoint",
                endpoint,
            ]
        )
        creds = json.loads(helper_result.stdout)

        session = boto3.session.Session(
            aws_access_key_id=creds["AccessKeyId"],
            aws_secret_access_key=creds["SecretAccessKey"],
            aws_session_token=creds["SessionToken"],
            region_name=args.region,
        )

        sts = session.client("sts")
        identity = sts.get_caller_identity()

        s3 = session.client("s3")
        buckets_response = s3.list_buckets()
        bucket_names = [bucket["Name"] for bucket in buckets_response.get("Buckets", [])]

        print(f"Issued certificate with SAN URI: {args.spiffe_uri}")
        print(f"Certificate: {cert_path}")
        print(f"Private key: {key_path}")
        print(f"Issuing CA: {ca_path}")
        print("AWS caller identity:")
        print(json.dumps(identity, indent=2))
        print("")
        print("S3 buckets:")
        if bucket_names:
            for name in bucket_names:
                print(name)
        else:
            print("(none)")

        return 0
    except (RuntimeError, BotoCoreError, ClientError, json.JSONDecodeError) as exc:
        print(str(exc), file=sys.stderr)
        return 1
    finally:
        if not args.keep_artifacts:
            shutil.rmtree(working_dir, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
