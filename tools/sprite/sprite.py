"""Aseprite helper for Puffe TD sprites (runs Aseprite in batch mode, no editor needed).

    python tools/sprite/sprite.py build <spec.txt> <out.aseprite> [--ref <reference.aseprite>]
        draw an animated sprite from a text spec (see grid_to_aseprite.lua): saves the .aseprite with
        its tags, the packed .png sheet next to it and <out>.preview.png (8x, on grass and sand,
        the reference's first frame at the end for size and colour)
    python tools/sprite/sprite.py info <file.aseprite>...
        size, frame durations, tags, layers and the colours used
    python tools/sprite/sprite.py view <file.aseprite> <out.png> [--scale N] [--frames A-B]
        the frames (0-based, default all) in a row sheet, scaled (default 6), to look at a sprite closely

The spec, .aseprite and sheet of a game sprite go next to each other in assets/art/units/...;
the scene's AnimatedSprite2D then gets its SpriteFrames from the sheet (AsepriteWizard dock).
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ASEPRITE = "C:/Program Files (x86)/Steam/steamapps/common/Aseprite/Aseprite.exe"
BUILD_SCRIPT = os.path.join(HERE, "grid_to_aseprite.lua")
INFO_SCRIPT = os.path.join(HERE, "inspect.lua")
DEFAULT_VIEW_SCALE = "6"
TIMEOUT = 60


def aseprite(args, quiet=False):
    result = subprocess.run([ASEPRITE, "-b"] + args, capture_output=True, text=True,
                            encoding="utf-8", errors="replace", timeout=TIMEOUT)
    output = (result.stdout + result.stderr).strip()
    if output and not quiet:
        print(output)
    return 1 if result.returncode != 0 or "ERROR" in output else 0


def option(args, name, default=None):
    if name in args:
        i = args.index(name)
        value = args[i + 1]
        del args[i:i + 2]
        return value
    return default


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 1
    command, args = argv[1], argv[2:]

    if command == "build" and len(args) >= 2:
        reference = option(args, "--ref", "")
        spec, out = os.path.abspath(args[0]), os.path.abspath(args[1])
        return aseprite(["--script-param", "spec=" + spec, "--script-param", "out=" + out,
                         "--script-param", "reference=" + (os.path.abspath(reference) if reference else ""),
                         "--script", BUILD_SCRIPT])
    if command == "info" and args:
        return max(aseprite(["--script-param", "file=" + os.path.abspath(f), "--script", INFO_SCRIPT]) for f in args)
    if command == "view" and len(args) >= 2:
        scale = option(args, "--scale", DEFAULT_VIEW_SCALE)
        frames = option(args, "--frames")
        frame_range = ["--frame-range", frames.replace("-", ",")] if frames else []
        out = os.path.abspath(args[1])
        code = aseprite(frame_range + [os.path.abspath(args[0]), "--scale", scale, "--sheet-type", "rows",
                                       "--sheet", out, "--data", out + ".json"], quiet=True)
        if os.path.exists(out + ".json"):
            os.remove(out + ".json")
        print("saved", out)
        return code

    print(__doc__)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
