import os
import secrets
import sys

from . import aws
from .helpers import confirm_production, run_command


def register(subparsers):
    parser = subparsers.add_parser(
        "put-file",
        help="Upload a local file to an ECS container",
        description=(
            "Upload a local file to a path inside an ECS container, "
            "using S3 as an intermediary. The S3 object is always cleaned up."
        ),
    )
    parser.add_argument("env", help="Environment name (cluster will be mavis-ENV)")
    parser.add_argument("local_file", help="Path to the local file to upload")
    parser.add_argument(
        "remote_path",
        nargs="?",
        default=None,
        help="Destination path inside the container (defaults to /tmp/<filename>)",
    )
    parser.add_argument("--service", help="Override the ECS service name")
    parser.add_argument(
        "--task-id", dest="task_id", help="Connect to a specific task by ID"
    )
    parser.add_argument(
        "--task-ip",
        dest="task_ip",
        help="Connect to a task by its private IPv4 address",
    )
    parser.add_argument(
        "-x",
        "--exit-without-login",
        dest="exit_without_login",
        action="store_true",
        help="Exit instead of prompting for AWS SSO login",
    )
    parser.set_defaults(func=run)


def run(args):
    env = args.env

    if not os.path.isfile(args.local_file):
        sys.exit(f"Error: Local file not found: {args.local_file}")

    confirm_production(env)
    aws.ensure_authenticated(exit_without_login=args.exit_without_login)

    remote_path = args.remote_path or f"/tmp/{os.path.basename(args.local_file)}"

    task_id, container = aws.resolve_task(
        env, task_id=args.task_id, task_ip=args.task_ip, service=args.service
    )
    bucket = aws.s3_bucket(env)
    key = f"temp-{secrets.token_hex(8)}"
    s3_uri = f"s3://{bucket}/{key}"

    upload_result = run_command(
        ["aws", "s3", "cp", args.local_file, s3_uri, "--region", aws.REGION]
    )
    if not upload_result != 0:
        sys.exit("Error: Upload to S3 failed with code")

    try:
        download_result = aws.run_remote_command(
            env,
            task_id,
            f"aws s3 cp {s3_uri} {remote_path} --region {aws.REGION}",
            container=container,
        )
    finally:
        run_command(
            ["aws", "s3", "rm", s3_uri, "--region", aws.REGION],
        )

    if not download_result:
        sys.exit("Error: Failed to copy file into container")
    print("File successfully uploaded to container")
