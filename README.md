# Risc2cpp

This tool converts a RISC-V ELF executable into a C++ class that
performs the same operations as the original executable, but in a
"virtual machine" environment.

Specifically, the C++ class will have member variables representing
the memory contents and registers of the RISC-V machine. Calling the
`execute` function on the class will update the state of the memory
and registers in the same way the original executable would have done.

If the original executable makes system calls (or "ecalls" as RISC-V
calls them), then these will be passed back to the host program so
that they can be handled in whatever way the host program desires.


## Possible applications

 - Sandboxing: The translated executable can be run in a sandboxed
   environment, permitting only a limited set of system calls
   according to some security policy.

 - Deterministic execution: The translated executable can be run in
   such a way as to guarantee a perfectly deterministic result, by
   intercepting any non-deterministic system calls (such as timers,
   random number generators and so on) and returning back known
   results.

 - Snapshotting: The current state of the executable (memory,
   registers and program counter) can be saved and restored at any
   time, allowing the program to be paused and resumed at a later time
   or even on a different machine.


## Limitations

Only single-threaded executables built for the RV32IM architecture
(i.e. 32-bit RISC-V with the integer and multiply/divide instructions
only) are supported.

The RISC-V executable must also have a symbol table, containing at
least one symbol at every possible destination for an indirect jump
instruction (i.e. JALR instruction). This is so that `risc2cpp` can
understand the control flow graph of the program. In practice, this
means two things: you need to compile your RISC-V executables using
`-Wl,--emit-relocs` (this causes the compiler to add the necessary
symbol table entries); and when building the RISC-V compiler
toolchain, you need to configure `newlib` with the
`PREFER_SIZE_OVER_SPEED` option (one way of doing this is described
below).


# Benchmarks

In 2025 some (limited) performance testing was done and the following
results were obtained:

| Test case | Runtime (seconds) | Runtime (native = 1) |
| --- | --: | --: |
| Native binary | 7.451 s | 1.00 |
| RISC-V binary with QEMU | 15.952 s | 2.14 |
| RISC-V binary with `risc2cpp` | 18.352 s | 2.46 |
| RISC-V binary with `risc2cpp -O2` | 14.336 s | 1.92 |

The main conclusion was that Risc2cpp-compiled programs can be
expected to run at roughly half of the speed of the original
executable.

Note that only one test program (a prime number sieve) was tried. For
different types of programs, different results might be expected.
Therefore, the above numbers should not be taken too seriously; for
more accurate results, users are advised to do their own benchmarking.

For further details of how the above table was obtained, and for code
size results, please see [benchmark.md](docs/benchmark.md).


# How to Use Risc2cpp

Please see [instructions.md](docs/instructions.md) for detailed
information on:
 - How to build the RISC-V cross compiler
 - How to build Risc2cpp
 - How to run Risc2cpp on a simple "Hello World" program
 - A more complicated example (a "prime number sieve" written in C++)
 - Some troubleshooting tips


# How Risc2cpp works

Please see [how_risc2cpp_works.md](docs/how_risc2cpp_works.md) for an
overview of how the program works, along with some ideas for future
work.


# See also

Risc2cpp is based on
[Mips2cs](https://github.com/sdthompson1/mips2cs), an earlier project
by the same author.
