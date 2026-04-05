import argparse

from . import shell


def main():
    parser = argparse.ArgumentParser(
        prog="mavis-server",
        description="MAVIS server management CLI",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    shell.register(subparsers)

    args = parser.parse_args()
    # TODO: Clean this error reporting up
    args.func(args)
