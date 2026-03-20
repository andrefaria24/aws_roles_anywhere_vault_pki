import boto3
import os
from datetime import datetime, timezone

# Multi-threshold configuration
THRESHOLDS = [90, 60, 30]

ra = boto3.client("rolesanywhere")
sns = boto3.client("sns")

SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]

def lambda_handler(event, context):
    anchors = ra.list_trust_anchors()["trustAnchors"]
    now = datetime.now(timezone.utc)

    for ta in anchors:
        arn = ta["trustAnchorArn"]
        name = ta["name"]

        tags = ra.list_tags_for_resource(resourceArn=arn)["tags"]

        expiry_str = None
        for tag in tags:
            if tag["key"] == "cert_expiration_iso":
                expiry_str = tag["value"]

        if not expiry_str:
            continue

        expiry = datetime.fromisoformat(expiry_str.replace("Z", "+00:00"))
        remaining_days = (expiry - now).days

        for threshold in THRESHOLDS:
            # Alert if remaining days falls within threshold window
            if remaining_days <= threshold and remaining_days > threshold - 1:
                send_alert(name, expiry_str, remaining_days, threshold)

            # Also alert if already below 30 (critical)
            if threshold == 30 and remaining_days <= 30:
                send_alert(name, expiry_str, remaining_days, threshold)

    return {"status": "complete"}


def send_alert(name, expiry_str, remaining_days, threshold):
    severity = (
        "CRITICAL" if threshold == 30
        else "HIGH" if threshold == 60
        else "WARNING"
    )

    subject = f"[{severity}] Roles Anywhere Trust Anchor Expiring ({remaining_days} days)"

    message = f"""
Trust Anchor: {name}
Expires: {expiry_str}
Days Remaining: {remaining_days}

Threshold Triggered: {threshold} days
Severity: {severity}
"""

    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject=subject,
        Message=message
    )