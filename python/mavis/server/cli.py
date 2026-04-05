import argparse

from . import put_file, shell


def main():
    parser = argparse.ArgumentParser(
        prog="mavis-server",
        description="MAVIS server management CLI",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    put_file.register(subparsers)
    shell.register(subparsers)

    args = parser.parse_args()
    # TODO: Clean this error reporting up
    args.func(args)
