import os
import json
import subprocess

REGION = "eu-west-2"
PRODUCTION_ENVS = {"production", "production-data-replication"}


def cluster(env):
    return f"mavis-{env}"


def s3_bucket(env):
    if env in PRODUCTION_ENVS:
        return "mavis-filetransfer-production"
    return "mavis-filetransfer-development"


def ensure_authenticated(exit_without_login=False):
    """Check AWS auth; attempt SSO login if needed."""
    result = subprocess.run(
        ["aws", "sts", "get-caller-identity"],
        capture_output=True,
    )
    if result.returncode == 0:
        return
    if exit_without_login:
        raise RuntimeError(
            "Not authenticated with AWS. Run 'aws sso login' and try again."
        )
    print("Not authenticated with AWS. Attempting SSO login...")
    login = subprocess.run(["aws", "sso", "login"])
    if login.returncode != 0:
        raise RuntimeError("AWS SSO login failed.")
    recheck = subprocess.run(
        ["aws", "sts", "get-caller-identity"],
        capture_output=True,
    )
    if recheck.returncode != 0:
        raise RuntimeError("Still not authenticated after SSO login.")


def aws_json(*cmd):
    """Run an AWS CLI command and return parsed JSON output."""
    result = subprocess.run(["aws", *cmd], capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"aws {' '.join(cmd)}:\n{result.stderr.strip()}")
    return json.loads(result.stdout)


def resolve_task(env, task_id=None, task_ip=None, service=None):
    """
    Resolve to (short_task_id, container_name). Three mutually exclusive modes:

    - task_id  — validate the specific task is running
    - task_ip  — search all running tasks in the cluster for a matching IP
    - service  — return the first running task in the service; defaults to
                 mavis-{env}-ops, or mavis-{env}-web for data-replication envs
    """
    cl = cluster(env)

    if task_id:
        tasks = aws_json(
            "ecs",
            "describe-tasks",
            "--region",
            REGION,
            "--cluster",
            cl,
            "--tasks",
            task_id,
        ).get("tasks", [])
        if not tasks or tasks[0]["lastStatus"] != "RUNNING":
            raise RuntimeError(f"Task {task_id} is not running in cluster {cl}")
        return task_id, _application_container(tasks[0])

    if task_ip:
        task_arns = aws_json(
            "ecs",
            "list-tasks",
            "--region",
            REGION,
            "--cluster",
            cl,
            "--desired-status",
            "RUNNING",
        ).get("taskArns", [])
        if not task_arns:
            raise RuntimeError(f"No running tasks found in cluster {cl}")
        tasks = aws_json(
            "ecs",
            "describe-tasks",
            "--region",
            REGION,
            "--cluster",
            cl,
            "--tasks",
            *task_arns,
        ).get("tasks", [])
        for task in tasks:
            if _task_private_ip(task) == task_ip:
                return _short_id(task), _application_container(task)
        raise RuntimeError(f"No running task with IP {task_ip} found in cluster {cl}")

    if not service:
        service = _default_service(env)

    task_arns = aws_json(
        "ecs",
        "list-tasks",
        "--region",
        REGION,
        "--cluster",
        cl,
        "--service-name",
        service,
        "--desired-status",
        "RUNNING",
    ).get("taskArns", [])
    if not task_arns:
        raise RuntimeError(f"No running tasks found in service {service}")
    tasks = aws_json(
        "ecs",
        "describe-tasks",
        "--region",
        REGION,
        "--cluster",
        cl,
        "--tasks",
        *task_arns,
    ).get("tasks", [])
    for task in tasks:
        container = _application_container(task)
        if container:
            return _short_id(task), container
    raise RuntimeError(
        f"No running tasks with an application container found in service {service}"
    )


def run_command(
    env, task_id, command, container=None, interactive=True, replace_process=False
):
    """Execute a command in an ECS task, returning the exit code."""
    cmd = [
        "aws",
        "ecs",
        "execute-command",
        "--region",
        REGION,
        "--cluster",
        cluster(env),
        "--task",
        task_id,
        "--command",
        command,
    ]
    if container:
        cmd += ["--container", container]
    if interactive:
        cmd.append("--interactive")
    if replace_process:
        os.execvp(cmd[0], cmd)
    return subprocess.run(cmd).returncode


# --- private helpers ---


def _default_service(env):
    if env.endswith("data-replication"):
        return f"mavis-{env}"
    return f"mavis-{env}-ops"


def _short_id(task):
    return task["taskArn"].split("/")[-1]


def _application_container(task):
    for c in task.get("containers", []):
        if (
            c.get("name") == "application"
            and c.get("lastStatus") == "RUNNING"
            and c.get("runtimeId")
        ):
            return c["name"]
    return None


def _task_private_ip(task):
    for attachment in task.get("attachments", []):
        for detail in attachment.get("details", []):
            if detail.get("name") == "privateIPv4Address":
                return detail.get("value")
    return None
