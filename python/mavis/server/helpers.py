import os
import sys
import subprocess


def confirm_production(env):
    """Prompt for confirmation before operating on production."""
    if env != "production":
        return
    print("Warning: You are about to operate on PRODUCTION (not data-replication).")
    answer = input("Type 'production' to continue: ").strip()
    if answer != "production":
        raise RuntimeError("Production confirmation failed")


def run_command(cmd, replace_process=False):
    """Run command and print an error if it fails."""
    if replace_process:
        os.execvp(cmd[0], cmd)
    return_code = subprocess.run(cmd).returncode
    if return_code != 0:
        print(
            f"Command failed with exit code '{return_code}':\n  {' '.join(cmd)}",
            file=sys.stderr,
        )
    return return_code == 0
