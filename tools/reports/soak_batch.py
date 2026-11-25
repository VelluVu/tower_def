"""Runs soak bot games in parallel and collects their problem lines.
usage: python batch.py <out dir> <parallel> <run spec>...   (a run spec: "level=5 mode=hard chaos=3 ...")"""
import os
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

PROJECT = r"C:\Users\Veli-Matti\Projektit\Godotprojects\tower_def"
out_dir, parallel, specs = sys.argv[1], int(sys.argv[2]), sys.argv[3:]
os.makedirs(out_dir, exist_ok=True)
PROBLEM = re.compile(r"SCRIPT ERROR|ERROR|WARNING|ORPHAN|leaked at exit|TIMEOUT|Leaked instance|still in use: ")


def run(i_spec):
    i, spec = i_spec
    log = os.path.join(out_dir, "run%02d.txt" % i)
    with open(log, "w", encoding="utf8") as f:
        subprocess.run([sys.executable, "tools/gd.py", "run", "tools/reports/soak_level.gd", *spec.split(), "--raw", "--verbose", "--timeout", "1500"],
                       cwd=PROJECT, stdout=f, stderr=subprocess.STDOUT)
    text = open(log, encoding="utf8", errors="replace").read()
    result = re.search(r"SOAK result (.*)", text)
    problems = [l for l in text.splitlines() if PROBLEM.search(l) and "Capture not registered" not in l]
    return i, spec, result.group(1) if result else "NO RESULT", problems


with ThreadPoolExecutor(parallel) as pool:
    for i, spec, result, problems in pool.map(run, enumerate(specs)):
        print("== run%02d %s\n   %s" % (i, spec, result))
        seen = set()
        for p in problems:
            if p not in seen:
                seen.add(p)
                print("   ! " + p[:400])
