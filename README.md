# riscv2cpp

**NOTE: This is work in progress and not ready for use yet**

This tool will convert a RISC-V ELF executable into a C++ class that
performs the same operations as the original executable, but in a
"virtual machine" environment.

Specifically, the C++ class will have member variables representing
the memory contents and registers of the RISC-V machine. Calling the
`execute` function on the class will update the state of the memory
and registers in the same way the original executable would have done.

If the original executable makes syscalls (or "ecalls" as RISC-V calls
them), then these will be passed back to the host program so that
they can be handled in whatever way the host program desires.

## Possible applications

This technology could be useful in scenarios where you want to run an
executable in a strictly deterministic manner, tightly controlling all
inputs and outputs. Another application could be where you want to
"snapshot" the state of an executable, perhaps saving the snapshot to
disk and/or transmitting it to another machine before resuming
execution.

## Limitations

Only executables built for the RV32IM architecture (i.e. 32-bit RISC-V
with the integer and multiply/divide instructions only) will be
supported.

There also needs to be a way for `riscv2cpp` to find all possible
indirect branch targets within the executable. At the moment there are
two possible ideas for this:
 - We could ask the linker to add relocation info to the executable
 file (linker `--emit-relocs` option) and then assume that any address
 with a relocation attached is a potential jump destination.
 - We could try using the `-fcf-protection` compiler option. This asks
 the compiler to emit "landing pad" instructions (from the
 ["Zicfilp"](https://github.com/riscv/riscv-cfi/blob/main/src/cfi_forward.adoc)
 RISC-V extension) at every possible jump destination. This would be
 very convenient but I am not sure how well compilers support the
 "Zicfilp" extension at this point in time. Further investigation is
 ongoing.


# Setting up the cross-compiler

So far I have been using the following github repository to build gcc
as a RISC-V cross-compiler:
https://github.com/riscv-collab/riscv-gnu-toolchain

The following commands will do the build and install. Note this will
download several gigabytes of source code and may take a couple of
hours to do the build. You may need to change the `--prefix` option
below to set the directory where you want to install the toolchain.

```
$ git clone https://github.com/riscv-collab/riscv-gnu-toolchain.git
$ cd riscv-gnu-toolchain
$ ./configure --prefix=$HOME/riscv --with-arch=rv32im --with-abi=ilp32 --with-languages=c,c++
$ make
```

Now add "prefix/bin" to your PATH and you should have the
cross-compiler tools, such as `riscv32-unknown-elf-gcc`,
`riscv32-unknown-elf-g++` and so on, available.


# See also

This program is based on
[Mips2cs](https://github.com/sdthompson1/mips2cs), but I have modified
(or will modify) it to work with RISC-V and C++, instead of MIPS and
C#.

See https://www.solarflare.org.uk/mips2cs for more details about
Mips2cs.
