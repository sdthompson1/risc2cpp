# risc2cpp end-to-end tests

This directory contains a small test suite that validates the full
risc2cpp pipeline: a source program is compiled to a RISC-V ELF,
translated to C++ by risc2cpp, linked with a tiny host harness, run, and
its stdout is compared against a reference file. Each test runs at all
three risc2cpp optimization levels (`-O0`, `-O1`, `-O2`).

There are two flavours of test:

- **C/C++ tests** (`*.c`, `*.cpp`) -- exercise the full risc2cpp +
  newlib pipeline on small but realistic programs (hello world,
  fizzbuzz, qsort, mandelbrot, exceptions, ...).
- **Assembly tests** (`*.S`) -- one file per group of related rv32im
  instructions (arithmetic, shifts, compares, branches, jumps, loads/
  stores, multiply/divide). They give targeted, readable per-instruction
  coverage that the C tests would only exercise incidentally. Each
  block of asm computes a value into `a0` and calls `print_int`
  (a test-only ecall, see below).

## Layout

```
tests/
  src/         # test programs (.c / .cpp / .S), one per test
  expected/    # reference stdout, one .txt per test
  elf/         # prebuilt RISC-V ELFs, checked in
  harness/
    test_main.cpp  # shared host program with syscall dispatcher
  asm/
    start.S        # shared _start + print_int helper for the .S tests
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
  `docs/how_risc2cpp_works.md`). For `.S` files it instead links the
  shared `asm/start.S` and uses `-march=rv32im -mabi=ilp32 -nostdlib
  -nostartfiles -Wl,--emit-relocs`. The resulting ELFs are checked
  into the repo, so you only need to run this script when adding or
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
93) -- enough for everything our tests do -- plus one test-only
syscall, `print_int` (number `0x10000`, well above any Linux number),
which prints `a0` as a signed decimal followed by a newline. The asm
tests use `print_int` to make per-instruction output trivially
diffable. The harness wraps `vm.execute()` in a try/catch so that VM
`runtime_error` exceptions (stack overflow, illegal memory access,
invalid code address, ...) are reported deterministically as
`VM error: <message>` rather than aborting the host process.

## The .S startup

`asm/start.S` provides a shared `_start` that initialises `sp`, calls
the test's `test_main`, and issues `SYS_exit` on return. It also
provides `print_int`, which just sets `a7 = 0x10000` and issues an
`ecall`. The `.S` tests are linked with `-nostdlib -nostartfiles`,
so newlib is not involved -- which means `.bss` is not zeroed; tests
that need initialised data should put it in `.data` (or `.rodata`
for read-only buffers).

## Adding a new test

1. Drop a `.c`, `.cpp`, or `.S` source file in `src/`.
2. Generate the reference output (e.g. compile and run natively, or by
   any other trusted means) and save it as `expected/<name>.txt`.
3. Run `python3 build_elfs.py` to produce `elf/<name>.risc`.
4. Run `python3 run_tests.py <name>` to verify all three opt levels
   pass. Then commit the source, expected file, and ELF together.

Tests must be deterministic: no `time()`, no unseeded random, no
uninitialised reads. Output is compared byte-for-byte against the
expected file.
