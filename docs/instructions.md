This file explains in detail how to use Risc2cpp. We will build and
install the RISC-V cross compiler, build Risc2cpp, and then compile
and run some example programs to show how the system works.


# Building the RISC-V toolchain

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
   work properly with the standard Newlib build settings (see
   [how_risc2cpp_works.md](how_risc2cpp_works.md) for a detailed
   explanation).

After the build is done, go ahead and add `$HOME/riscv/bin` (or
whatever directory you used) to your `PATH`, then check that gcc is
available:

```
$ riscv32-unknown-elf-gcc --version
```

# Build Risc2cpp

First, make sure you have ghc and cabal (the Haskell compiler tools)
installed. If not, you can install them from your OS's package
repository, or visit https://www.haskell.org/ghcup/.

Now, you should be able to build risc2cpp as follows:

```
$ cabal update
$ cabal build
```

The `risc2cpp` executable will be hidden somewhere inside a
`dist-newstyle` directory. You can use `cabal install` to install it
in your `~/.local/bin`, or `cabal install --installdir=.` to place it
in the current directory.

Running `risc2cpp` will print a usage message; you can use this to
check that it has built correctly.

# Use Risc2cpp on a simple hello world program

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
executable (see [how_risc2cpp_works.md](how_risc2cpp_works.md) for
full details of why this is needed).

If you have QEMU installed, you could try running this executable now
(optional):

```
$ qemu-riscv32 hello.risc
```

Next, run Risc2cpp on the `hello.risc` file:

```
$ risc2cpp hello.risc hello_vm
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


# More complicated example: prime number sieve (in C++)

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
$ risc2cpp prime_sieve.risc prime_sieve_vm
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
$ risc2cpp -O2 prime_sieve.risc prime_sieve_vm_opt
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
with the proper newlib options if applicable (see "Building the RISC-V
toolchain" above). If it still fails, then you will need to use a C++
debugger and make it "break on exceptions", then try to work out where
the exception is coming from, and in particular, the address that the
jump instruction is trying to go to. If it appears to be going to a
valid code address, then you will need to figure out a way to put a
symbol at that address (in your RISC-V executable's symbol table), so
that Risc2cpp knows that this is a possible jump target address. If
it's an invalid address, then your program has probably just crashed
for some reason (e.g. calling a null function pointer perhaps).
