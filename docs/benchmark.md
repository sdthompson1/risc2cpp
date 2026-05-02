This file describes in more detail the process that was used to create
the table of benchmarking results in [README.md](../README.md). For
reference, that table is reproduced here:

| Test case | Runtime (seconds) | Runtime (native = 1) |
| --- | --: | --: |
| Native binary | 7.451 s | 1.00 |
| RISC-V binary with QEMU | 15.952 s | 2.14 |
| RISC-V binary with `risc2cpp` | 18.352 s | 2.46 |
| RISC-V binary with `risc2cpp -O2` | 14.336 s | 1.92 |

The table consists of four rows. Each row details the runtime of the
"prime number sieve" program (see [instructions.md](instructions.md)
for the code), which computes all prime numbers less than 1 billion,
for one particular way of building and running the code.

Row 1 corresponds to building the prime sieve program directly on the
host platform, using `g++ -O2` (g++ version 11.4.0), and then running
it directly as a native executable.

Row 2 shows the runtime if the program is instead built for RISC-V
(using `riscv32-unknown-elf-g++ -O2`, g++ version 14.2.0, with the
toolchain configured as described in
[instructions.md](instructions.md)), and then run using QEMU version
6.2.0. This is relatively slow but provides a simple and effective
method of sandboxing.

Rows 3 and 4 show the runtime if the same RISC-V executable is first
translated to a C++ program using either `risc2cpp` (Risc2cpp with
default optimization), or `risc2cpp -O2` (Risc2cpp with its highest
possible level of optimization), respectively, and then the resulting
program is built (together with a wrapper `main.cpp` program as
described in [instructions.md](instructions.md)) using `g++ -O2` (g++
version 11.4.0). The resulting
times are competitive with QEMU, and the time with `risc2cpp -O2` is
actually slightly faster than QEMU in this case. (This is not
unexpected, because QEMU uses JIT compilation while `risc2cpp` uses
ahead-of-time compilation, and one would expect ahead-of-time
compilation to be slightly faster.)

All times given are the best of 3 consecutive execution attempts. The
tests were done on a machine with a 2.3 GHz Intel i5-8259U CPU and 8
GB physical memory.

As far as code size is concerned, we obtain the following figures:

| Test case | Stripped binary size (bytes) |
| --- | --: |
| Native compiled binary (dynamically linked) | 14,472 |
| Native compiled binary (statically linked) | 1,942,808 |
| RISC-V compiled binary (statically linked) | 810,816 |
| Code produced by `risc2cpp` (dynamically linked) | 5,060,912 |
| Code produced by `risc2cpp` (statically linked) | 5,993,368 |
| Code produced by `risc2cpp -O2` (dynamically linked) | 4,983,088 |
| Code produced by `risc2cpp -O2` (statically linked) | 5,919,640 |

It can be seen that the `risc2cpp` binaries come with a bit of a code
size penalty, compared to the size of the original RISC-V binary for
example. Fortunately, this is not much of an issue on modern PCs with
gigabytes of RAM, but it might might mean that `risc2cpp` is less
suitable for using in more memory-constrained environments.
