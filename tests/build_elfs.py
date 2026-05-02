#!/usr/bin/env python3
"""Compile each test program in tests/src/ to a RISC-V ELF in tests/elf/.

Requires the riscv32-unknown-elf-{gcc,g++} toolchain on PATH.
The ELFs produced here are intended to be checked into the repo so that
end-users without a RISC-V toolchain can still run tests/run_tests.py.
"""

import shutil
import subprocess
import sys
from pathlib import Path

TESTS_DIR = Path(__file__).resolve().parent
SRC_DIR = TESTS_DIR / "src"
ELF_DIR = TESTS_DIR / "elf"

CFLAGS = ["-O2", "-Wl,--emit-relocs"]


def compiler_for(src: Path) -> str:
    return "riscv32-unknown-elf-g++" if src.suffix == ".cpp" else "riscv32-unknown-elf-gcc"


def main() -> int:
    for tool in ("riscv32-unknown-elf-gcc", "riscv32-unknown-elf-g++"):
        if shutil.which(tool) is None:
            print(f"error: {tool} not found on PATH", file=sys.stderr)
            return 1

    ELF_DIR.mkdir(exist_ok=True)
    sources = sorted(p for p in SRC_DIR.iterdir() if p.suffix in (".c", ".cpp"))
    if not sources:
        print(f"no sources found in {SRC_DIR}", file=sys.stderr)
        return 1

    failed = []
    for src in sources:
        out = ELF_DIR / (src.stem + ".risc")
        cmd = [compiler_for(src), str(src), "-o", str(out), *CFLAGS]
        print("$", " ".join(cmd))
        result = subprocess.run(cmd)
        if result.returncode != 0:
            failed.append(src.name)

    if failed:
        print(f"\nFAILED: {', '.join(failed)}", file=sys.stderr)
        return 1
    print(f"\nBuilt {len(sources)} ELF(s) in {ELF_DIR}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
