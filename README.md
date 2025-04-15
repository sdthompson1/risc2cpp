# Risc2cpp

This tool will convert a RISC-V ELF executable into a C++ class that
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
means two things: you should compile your RISC-V executables using
`-Wl,--emit-relocs` (this causes the compiler to add the necessary
symbol table entries); and when building the RISC-V compiler toolchain
itself, you should make sure you configure `newlib` with the
`PREFER_SIZE_OVER_SPEED` option (one way of doing this is described
below).


# Benchmarks

This section gives the results of a quick benchmarking exercise. The
main conclusion is that Risc2cpp-compiled programs run at about half
the speed of the original executable.

We tested both Risc2cpp and QEMU with a simple C++ "prime number
sieve" program (the exact code for which is given below). This program
computes all prime numbers less than 1 billion. The following results
were obtained:

| Test case | Runtime (seconds) | Runtime (native = 1) |
| --- | --: | --: |
| Native binary | 7.451 s | 1.00 |
| RISC-V binary with QEMU | 15.952 s | 2.14 |
| RISC-V binary with `risc2cpp` | 18.352 s | 2.46 |
| RISC-V binary with `risc2cpp -O2` | 14.336 s | 1.92 |

Details:

Row 1 corresponds to building the prime sieve program directly on the
host platform, using `g++ -O2` (g++ version 11.4.0), and then running
it directly as a native executable. This gives the fastest runtime (of
course), but without any sandboxing.

Row 2 shows the runtime if the program is instead built for RISC-V
(using `riscv32-unknown-elf-g++ -O2`, g++ version 14.2.0, with
configuration options as given below), and then run using QEMU version
6.2.0. This is relatively slow but provides a simple and effective
method of sandboxing.

Rows 3 and 4 show the runtime if the same RISC-V executable is first
translated to a C++ program using either `risc2cpp` (Risc2cpp with
default optimization), or `risc2cpp -O2` (Risc2cpp with its highest
possible level of optimization), respectively, and then the resulting
program is built (together with a wrapper `main.cpp` program as
described below) using `g++ -O2` (g++ version 11.4.0). The resulting
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


# Demo/Tutorial

This section explains in detail how to use Risc2cpp. We will build and
install the RISC-V cross compiler, build Risc2cpp, and then compile
and run some example programs to show how the system works.


## Building the RISC-V toolchain

The first step is to install the RISC-V cross-compiler toolchain,
including `riscv-unknown-elf-gcc` and related tools, so that we can
produce RISC-V executables.

We can use the ready-made github repository from here:
https://github.com/riscv-collab/riscv-gnu-toolchain

First, make sure you have the necessary build prerequisites (as listed
on the README page at the above link) installed.

Next, run the following commands to install the toolchain to
`$HOME/riscv`. (Change the `--prefix` option below if you prefer to
install somewhere else.)

```
$ git clone https://github.com/riscv/riscv-gnu-toolchain
$ cd riscv-gnu-toolchain
$ ./configure --prefix=$HOME/riscv --with-arch=rv32im --with-languages=c,c++
$ NEWLIB_TARGET_FLAGS_EXTRA='CFLAGS_FOR_TARGET="-DPREFER_SIZE_OVER_SPEED=1 $(CFLAGS_FOR_TARGET)"' make
```

Note that running the above commands will download several gigabytes
to your local disk, and might take several hours to build the
toolchain.

Explanation of the commands:

 - The `--with-arch=rv32im` configure option builds the compiler for
   the RISC-V "rv32im" architecture (32-bit RISC-V with integer and
   multiply instructions only). This is the only RISC-V variant that
   Risc2cpp supports.

 - The `NEWLIB_TARGET_FLAGS_EXTRA` setting (in the `make` command)
   builds Newlib in the mode where smaller code size is favoured over
   speed. This is necessary because unfortunately Risc2cpp doesn't
   work properly with the standard Newlib build settings (see "How
   Risc2cpp works" section below for a detailed explanation).

After the build is done, go ahead and add `$HOME/riscv/bin` (or
whatever directory you used) to your `PATH`, then check that gcc is
available:

```
$ riscv32-unknown-elf-gcc --version
```

## Build Risc2cpp

First, make sure you have ghc and cabal (the Haskell compiler tools)
installed. If not, you can install them from your OS's package
repository, or visit https://www.haskell.org/ghcup/.

Next, install the Haskell packages required by Risc2cpp:

```
$ cabal update
$ cabal install elf optparse-applicative --lib
```

Now, build Risc2cpp itself:

```
$ cd /path/to/risc2cpp/src
$ ghc -O Main.hs -o risc2cpp
```

You can run `./risc2cpp` to check that the executable has built
correctly.

## Use Risc2cpp on a simple hello world program

Make a file `hello.c` with the following contents:

```
#include <stdio.h>

int main()
{
    printf("Hello, world!\n");
    return 0;
}
```

Compile it for RISC-V:

```
$ riscv32-unknown-elf-gcc hello.c -o hello.risc -Wl,--emit-relocs
```

Note: The `-Wl,--emit-relocs` option is needed so that Risc2cpp can
get the information it needs about indirect jump targets in the
executable (see "How Risc2cpp works", below, for full details of why
this is needed).

If you have QEMU installed, you could try running this executable now
(optional):

```
$ qemu-riscv32 hello.risc
```

Next, run Risc2cpp on the `hello.risc` file:

```
$ risc2cpp hello.risc hello_vm.hpp hello_vm.cpp
```

This will create two files, `hello_vm.hpp` and `hello_vm.cpp`,
containing the translated code. If you inspect `hello_vm.hpp` you will
see it defines a class `RiscVM` that represents a RISC-V virtual
machine. Calling `RiscVM::execute()` will execute instructions inside
the VM until the next `ecall` (system call) instruction is reached. It
is then up to the host program to implement the syscall (reading and
writing the memory and registers of the VM as appropriate) before
returning control to the VM by calling `RiscVM::execute()` again.

Note that executables created by `riscv32-unknown-elf-gcc` will, by
default, use a limited number of Linux-like syscalls in order to
communicate with the outside world. In our case, it is necessary to
implement syscall numbers 214 (`brk`), 64 (`write`) and 93 (`exit`) so
that our "hello world" program can function correctly. We also need to
write a `main` function that instantiates the `RiscVM` class and calls
`RiscVM::execute`. All this can be done by writing a `main.cpp`
program as follows:

```
#include "hello_vm.hpp"
#include <stdio.h>

// This returns true if the VM should exit
bool handleEcall(RiscVM &vm)
{
    // Syscall number is in A7. Return value goes in A0.
    switch (vm.getA7()) {
    case 214:
        // BRK
        // New program break is in A0
        // If this is below the original program break, just return the
        // current break. Otherwise, set and return new break.
        if (vm.getA0() >= vm.getInitialProgramBreak()) {
            vm.setProgramBreak(vm.getA0());
        }
        vm.setA0(vm.getProgramBreak());
        return false;

    case 93:
        // EXIT
        return true;

    case 64:
        // WRITE
        // File descriptor is in A0
        // Pointer to data to write is in A1
        // Number of bytes to write is in A2
        // (We will ignore the file descriptor and just print everything to stdout!)
        for (int i = 0; i < vm.getA2(); ++i) {
            char byte = vm.readByte(vm.getA1() + i);
            putchar(byte);
        }

        // Return number of bytes written
        vm.setA0(vm.getA2());

        return false;

    default:
        // Unknown syscall. Return -ENOSYS (-38).
        vm.setA0(-38);
        return false;
    }
}

int main()
{
    RiscVM vm;

    bool exited = false;

    while (!exited) {
        vm.execute();
        exited = handleEcall(vm);
    }
}
```

We can now compile `main.cpp` with the Risc2cpp-generated code as
follows:

```
$ g++ main.cpp hello_vm.cpp -O2 -o hello_vm
```

Now you can run `./hello_vm` and you should see the `Hello, world!`
output, along with some debug output showing the system calls being
made by the VM.


## More complicated example: prime number sieve (in C++)

To see Risc2cpp in use on a more complicated example, create
`prime_sieve.cpp` with the following contents:

```
#include <iostream>
#include <vector>

// Return the count of prime numbers upto and including n
int count_primes(int n) {
    // Create a boolean vector "isPrime" and initialize all entries as true
    std::vector<bool> isPrime(n + 1, true);

    // Mark 0 and 1 as non-prime
    isPrime[0] = isPrime[1] = false;

    // Apply the sieve
    for (int p = 2; p * p <= n; p++) {
        if (isPrime[p]) {
            for (int i = p * p; i <= n; i += p) {
                isPrime[i] = false;
            }
        }
    }

    // Count prime numbers found
    int count = 0;
    for (int p = 2; p <= n; p++) {
        if (isPrime[p]) {
            count++;
        }
    }

    return count;
}

int main() {
    int n = 1000 * 1000 * 1000;

    std::cout << "Counting primes upto " << n << std::endl;

    int count = count_primes(n);

    std::cout << "Number of primes found: " << count << std::endl;

    return 0;
}
```

First of all, let's compile it natively to see if it works:

```
$ g++ -O2 prime_sieve.cpp -o prime_sieve
$ ./prime_sieve
Counting primes upto 1000000000
Number of primes found: 50847534
```

Now compile it for RISC-V (don't forget to use `-Wl,--emit-relocs`):

```
$ riscv32-unknown-elf-g++ -O2 prime_sieve.cpp -o prime_sieve.risc -Wl,--emit-relocs
```

Now run risc2cpp:

```
$ risc2cpp prime_sieve.risc prime_sieve_vm.hpp prime_sieve_vm.cpp
```

Note that prime_sieve_vm.cpp is very long -- this is due to
the large amount of standard library code that is included with every
C++ executable.

Now edit the previous `main.cpp` to include `prime_sieve_vm.hpp` (on
line 1) instead of `hello_vm.hpp`, then build and run:

```
$ g++ -O2 main.cpp prime_sieve_vm.cpp -o prime_sieve_vm
$ ./prime_sieve_vm
```

Note that g++ takes a while to compile the code. You should find that
`prime_sieve_vm` prints the same output as `prime_sieve` (plus some
extra debug messages regarding ecalls).

On my machine, `prime_sieve_vm` takes about 2.4x as long to run as
`prime_sieve`. We can improve this by using risc2cpp's optimization
feature, as follows:

```
$ risc2cpp -O2 prime_sieve.risc prime_sieve_vm_opt.hpp prime_sieve_vm_opt.cpp
```

Risc2cpp has three optimization levels: `-O0` (no optimization, not
recommended); `-O1` (light optimization, the default); and `-O2`
(heavy optimization). Note that `risc2cpp -O2` takes some time to run,
but you will get noticeably shorter and faster code as a result.

We can now build and run the optimized version. First edit `main.cpp`
to include `prime_sieve_vm_opt.hpp` instead of `prime_sieve_vm.hpp`.
Now run the following:

```
$ g++ -O2 main.cpp prime_sieve_vm_opt.cpp -o prime_sieve_vm_opt
$ ./prime_sieve_vm_opt
```

On my machine, `prime_sieve_vm_opt` takes about 1.9x as long to run as
the original `prime_sieve`, which is better than the previous 2.4x.


# Troubleshooting

If the generated C++ code throws a `std::runtime_error("Invalid code
address")` exception, then make sure you compiled your RISC-V
executable with `-Wl,--emit-relocs`, and that your toolchain was built
with the proper newlib options if applicable (see "Demo/Tutorial"
section above). If it still fails, then you will need to use a C++
debugger and make it "break on exceptions", then try to work out where
the exception is coming from, and in particular, the address that the
jump instruction is trying to go to. If it appears to be going to a
valid code address, then you will need to figure out a way to put a
symbol at that address (in your RISC-V executable's symbol table), so
that Risc2cpp knows that this is a possible jump target address. If
it's an invalid address, then your program has probably just crashed
for some reason (e.g. calling a null function pointer perhaps).


# How Risc2cpp works

This section gives a rough overview of how Risc2cpp works. It is not
necessary to understand this section in order to use Risc2cpp, but
reading it might give some insight into why the generated C++ files
are the way they are.

## Basic idea

The basic idea is to analyse the machine code instructions in the
RISC-V executable and convert them to equivalent C++ code. For
example, `add s0, s1, s2` in RISC-V would be converted to `s1 = s2 +
s3;` in C++. (Because RISC-V instructions are always 4-byte aligned
and exactly 4 bytes in length, it is easy to find and decode the
instructions.)

The RISC-V registers (`s0`, `t1` and so on) are represented by member
variables of type `uint32_t` in the `RiscVM` class. The memory is
represented by an array of 65,536 "pages" of 65,536 bytes (actually
16,384 `uint32_t`s) each. Only pages actually in use are allocated,
which means that the full 4 GB address space does not need to be
allocated as memory on the host. Helper functions, like `readByteU`,
`writeHalf` and so on, are provided for accessing memory in bytes,
halfwords (2 bytes) and words (4 bytes). These functions only work at
aligned addresses and assume little-endian memory layout.


## Handling branches and jumps

Branch and jump instructions can be handled by placing C++ labels at
the jump destination points. For example, the following RISC-V code:

```
loop:
    addi t0, t0, -1
    add  s0, s0, s1
    bnez t0, loop
```

translates to something roughly like this:

```
label_123:
    t0 = t0 - 1;
    s0 = s0 + s1;
    if (t0 != 0) goto label_123;
```

Note that a label does not need to be placed at every C++ instruction,
only at the jump targets.

## Indirect branches

If the program contains indirect jumps (like `jr s0`), things are more
difficult, because we need to map the new PC location (contained in a
register) to one of our C++ labels. This is handled by placing the
entire generated program inside a giant switch/case block, with a
"case" label at every possible branch destination. We can then use a
big lookup table to map the new PC value (which is only known at
runtime) to an appropriate `case` number, and use the C++ switch/case
mechanism to go directly to that location.

(In practice, the above is a slight over-simplification; what we
actually do is break the program into _multiple_ switch/case blocks,
in order to prevent any one function in the generated code from
becoming too large. This is probably best understood by looking at an
actual Risc2cpp-generated program and examining how the `exec` methods
and the `case_table` work.)

## Determining the possible jump targets

It will be observed that the above system can only work if we know the
locations that all of the jump and branch instructions could possibly
go to (otherwise we would not know where to put the labels). This is
easy for direct jump or branch instructions (you just look at the
instruction) and it is also easy for procedure return instructions
(you just say that any instruction following a "call" instruction is a
possible branch destination) but it is harder for arbitrary indirect
jump instructions (like `jr s0`). Moreover, compilers do routinely use
the latter (for example in jump tables for switch statements), so we
do need to deal with this.

One possible solution would be to put a label in front of (the
translated code for) every single RISC-V instruction, but that is not
a good solution, because it generates C++ code with way too many
labels, and C++ compilers seem to find the resulting code difficult to
optimize (i.e. the generated code runs very slowly).

Instead, we make the assumption that the executable's symbol table
will contain at least one symbol located at each possible indirect
branch destination. That way, Risc2cpp can scan the symbol table,
filtering only for symbols that point to valid code addresses, and use
the resulting set of addresses as the set of possible indirect branch
destinations.

This works reasonably well for compiled code, because when the
compiler generates e.g. a jump table, it always places an assembly
language label (like `.L15:`) at the jump destination point(s). We
just need to find a way to make sure that those labels appear in the
compiled program's symbol table! Ordinarily, this would not happen,
but if you use the `-Wl,--emit-relocs` compiler option, then it turns
out that all of these labels are added to the symbol table, and
therefore Risc2cpp will be able to find all the necessary jump points
as described above. (My understanding is that `--emit-relocs` tells
the linker to add relocation information to the final executable, and
relocation information only "works" if you know the location of all
program labels, even private/local ones like `.L15:`, so that's why
using `--emit-relocs` forces those labels into the symbol table.)

For hand-written assembly code, things are more problematic because
the assembly code will not necessarily have convenient labels placed
at all the jump destination points. An example of where this happens
in practice is the newlib library, which contains a hand-optimized
assembly language `memset` routine for RISC-V. Unfortunately, this
code breaks the above assumption and therefore does not work with
Risc2cpp. To work around this, it is necessary to compile newlib with
the `PREFER_SIZE_OVER_SPEED` flag, which (among other things) disables
this hand-optimized `memset` function and replaces it with a much
simpler function that does not use indirect jumps. The problem is
therefore avoided. Similar considerations might apply if the user
wishes to use any other hand-coded assembly language routines with
Risc2cpp.

## Optimizations

The above does not tell the whole story. If we simply convert RISC-V
machine code instructions to C++ statements, one by one, then we get
C++ code that is somewhat longer than necessary. A very simple example
is that a sequence like

```
    add s0, t0, t1
    add s0, s0, t2
    add s0, s0, t3
```

gets translated to

```
    s0 = t0 + t1;
    s0 = s0 + t2;
    s0 = s0 + t3;
```

rather than the much simpler

```
   s0 = t0 + t1 + t2 + t3;
```

(There are a number of other ways in which "longer-than-necessary"
code might be produced; the above is only one relatively simple
example.)

Now, one might expect that an optimizing C++ compiler would be able to
deal with such things, and automatically produce the best code
possible, even if the input code was somewhat "long-winded".
Unfortunately, this does not seem always to be the case, so it is
worth spending some time on optimizing the proposed C++ code before
writing it to the output files.

Therefore, Risc2cpp works by first converting the RISC-V instructions
into an "intermediate code" representation, then doing various
transformations on the intermediate code. This includes combining
multiple statements into one where possible (like in the `t0 + t1 + t2 + t3`
example above), as well as more classical compiler optimizations, such
as constant folding, constant propagation, dead store elimination, and
so on. All of this results in shorter and simpler final C++ code than
would otherwise be the case, which in turn results in faster run times
and smaller final executables (as was demonstrated in the
"Benchmarks" section above).


# Possible future work

The RISC-V
["Zicfilp"](https://github.com/riscv/riscv-cfi/blob/main/src/cfi_forward.adoc)
extension provides an intriguing opportunity for removing the need to
have the indirect branch destinations encoded in the symbol table.
Instead, the `LPAD` instructions could be used for determining the
possible targets of indirect jumps. (In other words, there would be no
need to compile the RISC-V executable with special options such as
`-Wl,--emit-relocs`.) Unfortunately, I am not sure if C or C++
compilers fully support this extension yet, but perhaps this would be
an interesting thing to investigate in the future.

Perhaps the handling of the virtual machine's memory could be improved
as well. At the moment, the memory is represented as an array of
"pages" where each page is an array of `uint32_t`s. This makes word
access very easy, but byte and halfword accesses require some extra
work. Perhaps it would be better simply to represent each page as an
array of `uint8_t`. For halfword and word operations, we could simply
`memcpy` a 2 or 4 byte region into or out of the memory page. On x86
this would most likely compile down to a single `mov` instruction in
each case, since the architecture supports unaligned loads and stores.
This might well improve the speed and reduce the compiled code size
slightly. (This trick would only work on little-endian host machines,
since the RISC-V is assumed to be little-endian, but that isn't much
of an issue since almost everything is little-endian nowadays.)

For target programs that make heavy use of `memcpy` and/or `memset`,
it might also be useful to "intercept" calls to those functions and
redirect them to use the native `memcpy` and `memset` operations
instead. This would probably give a significant speed boost to such
programs.


# See also

Risc2cpp is based on
[Mips2cs](https://github.com/sdthompson1/mips2cs), an earlier project
by the same author.
