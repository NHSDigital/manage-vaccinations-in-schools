import os
import secrets
import sys

from . import aws
from .helpers import confirm_production, run_command


def register(subparsers):
    parser = subparsers.add_parser(
        "get-file",
        help="Download a file from an ECS container to local",
        description=(
            "Download a file from inside an ECS container to a local path, "
            "using S3 as an intermediary. The S3 object is always cleaned up."
        ),
    )
    parser.add_argument("env", help="Environment name (cluster will be mavis-ENV)")
    parser.add_argument("remote_path", help="Path of the file inside the container")
    parser.add_argument(
        "local_path",
        nargs="?",
        default=None,
        help="Local destination (file or directory). Defaults to tmp in the project root.",
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

    confirm_production(env)
    aws.ensure_authenticated(exit_without_login=args.exit_without_login)

    task_id, container = aws.resolve_task(
        env, task_id=args.task_id, task_ip=args.task_ip, service=args.service
    )
    bucket = aws.s3_bucket(env)
    key = f"temp-{secrets.token_hex(8)}"
    s3_uri = f"s3://{bucket}/{key}"

    local_dest = _local_destination(args.remote_path, args.local_path)

    try:
        upload_result = aws.run_remote_command(
            env,
            task_id,
            f"aws s3 cp {args.remote_path} {s3_uri} --region {aws.REGION}",
            container=container,
        )
        if not upload_result:
            sys.exit("Error: Failed to copy file from container to S3")

        download_result = run_command(
            ["aws", "s3", "cp", s3_uri, local_dest, "--region", aws.REGION]
        )
        if not download_result:
            sys.exit("Error: Download from S3 failed with code")
    finally:
        run_command(
            ["aws", "s3", "rm", s3_uri, "--region", aws.REGION],
        )

    print(f"File successfully downloaded to {local_dest}")


def _local_destination(remote_path, local_path):
    """
    Resolve the local download destination.

    If local_path is given and is an existing directory, save as
    <local_path>/<basename of remote_path>. If local_path is a file path
    (or doesn't exist yet), use it as-is. Defaults to ./<basename>.
    """
    filename = os.path.basename(remote_path.rstrip("/"))
    if local_path is None:
        return os.path.join(".", filename)
    if os.path.isdir(local_path):
        return os.path.join(local_path, filename)
    return local_path
