#!/usr/bin/env python3
"""beforeShellExecution hook: auto-allow read-only `git -C <path> diff ...` in any repo.

A permission rule cannot express this safely. `Shell(git:diff *)` matches by prefix and
can approve injected git global options (`-c core.pager=<cmd>`, `--exec-path=<dir>`,
`-c diff.external=<cmd>`), each of which runs arbitrary code. This allowlists the exact
command shape instead: one -C, an absolute path, the `diff` subcommand, and arguments
drawn from charsets that contain no space, quote, or shell metacharacter.

Anything that does not fullmatch gets no verdict, so it falls through to the normal
permission rules and prompts as usual.
"""
import json
import re
import sys

# No token may contain a space, so nothing can be smuggled in ahead of `diff`.
PATTERN = re.compile(r"git -C /[A-Za-z0-9._/-]+ diff(?: [A-Za-z0-9._/~^@:=-]+)*")

# `git diff --output=FILE` writes a file, which is not read-only. Keep it out.
WRITES_A_FILE = re.compile(r"^(--output(=|$)|-o$)")


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, UnicodeDecodeError, ValueError):
        return 0

    command = payload.get("command")
    if not isinstance(command, str):
        return 0

    if "\n" in command or "\r" in command:
        return 0

    if not PATTERN.fullmatch(command):
        return 0

    if any(WRITES_A_FILE.match(arg) for arg in command.split(" ")[4:]):
        return 0

    json.dump(
        {
            "permission": "allow",
            "agent_message": "read-only `git -C <path> diff` (allowlisted shape)",
        },
        sys.stdout,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
