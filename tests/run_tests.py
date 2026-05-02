#!/usr/bin/env python3
"""Run risc2cpp end-to-end tests.

For each ELF in tests/elf/, this script:
  1. Runs risc2cpp to translate it to C++.
  2. Compiles the generated C++ together with tests/harness/test_main.cpp.
  3. Runs the resulting binary and compares stdout against tests/expected/<name>.txt.

Does not require a RISC-V toolchain. Requires risc2cpp on PATH (or located
via --risc2cpp) and a host C++ compiler.
"""

import argparse
import difflib
import os
import shutil
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

TESTS_DIR = Path(__file__).resolve().parent
ELF_DIR = TESTS_DIR / "elf"
EXPECTED_DIR = TESTS_DIR / "expected"
HARNESS = TESTS_DIR / "harness" / "test_main.cpp"
BUILD_DIR = TESTS_DIR / "build"


def find_risc2cpp(explicit: str | None) -> str:
    if explicit:
        return explicit
    found = shutil.which("risc2cpp")
    if found:
        return found
    # Fall back to dist-newstyle build output.
    candidates = sorted((TESTS_DIR.parent / "dist-newstyle").rglob("risc2cpp"))
    candidates = [c for c in candidates if c.is_file() and os.access(c, os.X_OK)]
    if candidates:
        return str(candidates[-1])
    print("error: could not find risc2cpp executable; pass --risc2cpp PATH", file=sys.stderr)
    sys.exit(1)


def run(cmd, **kwargs):
    return subprocess.run(cmd, **kwargs)


def run_one(name: str, elf: Path, risc2cpp: str, cxx: str,
            opt_level: str, host_opt: str) -> tuple[bool, str]:
    expected = EXPECTED_DIR / f"{name}.txt"
    if not expected.exists():
        return False, f"missing expected output: {expected}"

    tag = f"{name}_{opt_level.lstrip('-')}"
    vm_stem = BUILD_DIR / f"{tag}_vm"
    vm_hpp = vm_stem.with_suffix(".hpp")
    vm_cpp = vm_stem.with_suffix(".cpp")
    binary = BUILD_DIR / tag

    # 1. risc2cpp
    r = run([risc2cpp, opt_level, str(elf), str(vm_stem)],
            capture_output=True, text=True)
    if r.returncode != 0:
        return False, f"risc2cpp failed:\n{r.stderr}"

    # 2. host compile
    r = run([cxx, host_opt, "-std=c++17",
             f"-DVM_HEADER=\"{vm_hpp.name}\"",
             f"-I{vm_hpp.parent}",
             str(HARNESS), str(vm_cpp),
             "-o", str(binary)],
            capture_output=True, text=True)
    if r.returncode != 0:
        return False, f"host compile failed:\n{r.stderr}"

    # 3. run + compare
    r = run([str(binary)], capture_output=True, text=True, timeout=120)
    actual = r.stdout
    want = expected.read_text()
    if actual != want:
        diff = "".join(difflib.unified_diff(
            want.splitlines(keepends=True),
            actual.splitlines(keepends=True),
            fromfile="expected", tofile="actual"))
        return False, f"output mismatch (exit={r.returncode}):\n{diff}"
    if r.returncode != 0:
        return False, f"nonzero exit: {r.returncode}\nstderr:\n{r.stderr}"
    return True, ""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--risc2cpp", help="path to risc2cpp executable")
    ap.add_argument("--cxx", default=os.environ.get("CXX", "g++"))
    ap.add_argument("--opt", action="append", choices=["-O0", "-O1", "-O2"],
                    help="risc2cpp optimization level (repeatable; "
                         "default: all three)")
    ap.add_argument("--host-opt", default="-O0",
                    help="optimization flag passed to the host C++ compiler "
                         "(default: -O0; tests only check correctness, and "
                         "the generated code is slow to optimize)")
    ap.add_argument("-j", "--jobs", type=int, default=0,
                    help="parallel jobs (default: min(cpu_count, 8); 1 = serial)")
    ap.add_argument("tests", nargs="*", help="optional list of test names to run")
    args = ap.parse_args()

    risc2cpp = find_risc2cpp(args.risc2cpp)
    opt_levels = args.opt if args.opt else ["-O0", "-O1", "-O2"]
    BUILD_DIR.mkdir(exist_ok=True)

    elfs = sorted(ELF_DIR.glob("*.risc"))
    if args.tests:
        wanted = set(args.tests)
        elfs = [e for e in elfs if e.stem in wanted]
        missing = wanted - {e.stem for e in elfs}
        if missing:
            print(f"error: no ELFs for {sorted(missing)}", file=sys.stderr)
            return 1

    if not elfs:
        print(f"no ELFs found in {ELF_DIR}", file=sys.stderr)
        return 1

    jobs = args.jobs if args.jobs > 0 else min(os.cpu_count() or 1, 8)

    print(f"risc2cpp: {risc2cpp}")
    print(f"cxx:      {args.cxx}")
    print(f"opt:      {' '.join(opt_levels)}")
    print(f"host opt: {args.host_opt}")
    print(f"jobs:     {jobs}")
    print()

    work = [(elf.stem, elf, opt) for elf in elfs for opt in opt_levels]
    total = len(work)
    failures = []
    t_start = time.monotonic()

    if jobs == 1:
        for name, elf, opt in work:
            label = f"{name} [{opt}]"
            print(f"[{label}] ... ", end="", flush=True)
            ok, msg = run_one(name, elf, risc2cpp, args.cxx, opt, args.host_opt)
            print("PASS" if ok else "FAIL")
            if not ok:
                print(msg)
                failures.append(label)
    else:
        with ThreadPoolExecutor(max_workers=jobs) as ex:
            futures = {
                ex.submit(run_one, name, elf, risc2cpp, args.cxx, opt,
                          args.host_opt): f"{name} [{opt}]"
                for name, elf, opt in work
            }
            done = 0
            for fut in as_completed(futures):
                label = futures[fut]
                done += 1
                ok, msg = fut.result()
                status = "PASS" if ok else "FAIL"
                print(f"[{done}/{total}] [{label}] ... {status}", flush=True)
                if not ok:
                    print(msg)
                    failures.append(label)

    elapsed = time.monotonic() - t_start
    print()
    if failures:
        print(f"{len(failures)}/{total} failed: {', '.join(failures)} "
              f"({elapsed:.1f}s)")
        return 1
    print(f"all {total} test(s) passed in {elapsed:.1f}s")
    return 0


if __name__ == "__main__":
    sys.exit(main())
