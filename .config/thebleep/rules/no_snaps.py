"""
no_snaps
========

An opinionated rule: whenever you run `snap`, offer apt or flatpak instead.

    snap install vlc
    -> sudo apt install vlc
    -> flatpak install flathub vlc

Purely for fun (and principles). It never runs anything on its own: you
still pick a suggestion, edit it with tab, or press esc to keep snapping.
"""

from thebleep.types import Suggestion
from thebleep.utils import for_app


@for_app("snap")
def match(command):
    # Any snap command at all. We have opinions.
    return True


def get_new_command(command):
    parts = command.script_parts  # e.g. ["snap", "install", "vlc"]

    # Only translate the common case: `snap install <name> [<name>...]`.
    # Anything else (snap list, snap refresh...) just gets the apt nudge.
    if len(parts) >= 3 and parts[1] == "install":
        packages = [p for p in parts[2:] if not p.startswith("-")]
        names = " ".join(packages)
        return [
            Suggestion(f"sudo apt install {names}", confidence=0.6,
                       evidence=("ubuntu stinky (snap detected)",)),
            Suggestion(f"flatpak install flathub {names}", confidence=0.5,
                       evidence=("flathub has it too, probably",)),
        ]

    return Suggestion("sudo apt update && sudo apt upgrade", confidence=0.3,
                      evidence=("ubuntu stinky (snap detected)",))


# Works from the command alone: no need to wait for snap's output.
requires_output = False
enabled_by_default = True
priority = 100  # run before the sensible rules get a say
