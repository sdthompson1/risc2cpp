# risc2cpp end-to-end tests

This directory contains a small test suite that validates the full
risc2cpp pipeline: a C/C++ source program is compiled to a RISC-V ELF,
translated to C++ by risc2cpp, linked with a tiny host harness, run, and
its stdout is compared against a reference file. Each test runs at all
three risc2cpp optimization levels (`-O0`, `-O1`, `-O2`).

## Layout

```
tests/
  src/         # test programs (.c / .cpp), one per test
  expected/    # reference stdout, one .txt per test
  elf/         # prebuilt RISC-V ELFs, checked in
  harness/
    test_main.cpp  # shared host program with syscall dispatcher
  build_elfs.py    # rebuild the ELFs (needs a RISC-V toolchain)
  run_tests.py     # run the rest of the pipeline (no toolchain needed)
  build/           # build artefacts (gitignored)
```

## The two scripts

The pipeline is split deliberately so contributors without a RISC-V
toolchain can still validate risc2cpp itself:

- **`build_elfs.py`** compiles every program in `src/` to a RISC-V ELF
  in `elf/`, using `riscv32-unknown-elf-{gcc,g++}` with `-O2` and
  `-Wl,--emit-relocs` (the latter is required by risc2cpp -- see
  `docs/how_risc2cpp_works.md`). The resulting ELFs are checked into
  the repo, so you only need to run this script when adding or
  modifying a test program.

- **`run_tests.py`** is what runs in CI / day-to-day. For each ELF it:
    1. invokes risc2cpp to translate the ELF to C++,
    2. compiles that C++ together with `harness/test_main.cpp`,
    3. runs the resulting binary,
    4. diffs stdout against `expected/<name>.txt`.

  It needs only a `risc2cpp` binary (located via `$PATH`,
  `--risc2cpp PATH`, or auto-discovered in `dist-newstyle/`) and a host
  C++ compiler. It runs each (test, opt-level) pair in parallel; pass
  `-j1` for serial output. The host C++ compile uses `-O0` by default
  -- the generated code is large and slow to optimize, and tests only
  check correctness.

## The harness

`harness/test_main.cpp` is a single shared host program. It is included
into every test by passing `-DVM_HEADER="<name>_vm.hpp"` at compile
time, then compiled together with the corresponding generated `.cpp`.

It implements three Linux-like syscalls (`brk` 214, `write` 64, `exit`
93) -- enough for everything our tests do -- and wraps `vm.execute()`
in a try/catch so that VM `runtime_error` exceptions (stack overflow,
illegal memory access, invalid code address, ...) are reported
deterministically as `VM error: <message>` rather than aborting the
host process.

## Adding a new test

1. Drop a `.c` or `.cpp` source file in `src/`.
2. Generate the reference output (e.g. compile and run natively, or by
   any other trusted means) and save it as `expected/<name>.txt`.
3. Run `python3 build_elfs.py` to produce `elf/<name>.risc`.
4. Run `python3 run_tests.py <name>` to verify all three opt levels
   pass. Then commit the source, expected file, and ELF together.

Tests must be deterministic: no `time()`, no unseeded random, no
uninitialised reads. Output is compared byte-for-byte against the
expected file.
