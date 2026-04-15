#!/usr/bin/env python3
"""Reload Docker Compose services by sending SIGHUP."""

import argparse
import http.client
import os
import socket
import sys


class DockerClient(http.client.HTTPConnection):
    def connect(self):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.connect("/var/run/docker.sock")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("services", nargs="+", help="service names to reload")
    args = parser.parse_args(argv)

    project = os.environ.get("COMPOSE_PROJECT_NAME")
    if not project:
        parser.error("COMPOSE_PROJECT_NAME environment variable is not set")

    failed = False
    for service in args.services:
        container = f"{project}-{service}-1"
        client = DockerClient("localhost")
        client.request("POST", f"/containers/{container}/kill?signal=HUP")
        response = client.getresponse()
        if response.status == 204:
            print(f"Reload {container}: ok")
        else:
            print(f"Reload {container}: failed ({response.status})")
            failed = True

    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
