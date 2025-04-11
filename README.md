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
them), then these will be passed back to the host program (i.e. the
client of the C++ class) so that they can be handled in whatever way
the host program desires.

## Possible applications

This technology could be useful in scenarios where you want to run an
executable in a strictly deterministic manner, tightly controlling all
inputs and outputs. Another application could be where you want to
"snapshot" the state of an executable, perhaps saving the snapshot to
disk and/or transmitting it to another machine before resuming
execution.

## Limitations

Only executables built for the RV32IM architecture (32-bit with the
base integer and multiply/divide instructions only) will be supported.
(The `-march` gcc flag can be used to build the executable for the
appropriate architecture, or gcc can simply be configured for this
architecture when it is built.)

There also needs to be a way for `riscv2cpp` to find all possible
indirect branch targets within the executable. The plan is to use the
`-fcf-protection` gcc option, which makes the compiler insert special
"landing pad" instructions into the code at appropriate points. We
will see how well this works in practice!


# Setting up the cross-compiler

We will use the following github repository to build gcc as a RISC-V
cross-compiler: https://github.com/riscv-collab/riscv-gnu-toolchain

In particular, we will configure the compiler for the RV32IM
architecture (only) and switch on the `--enable-cet` feature of gcc
(so that `riscv2cpp` can find indirect jump targets, as explained
above).

Here are the specific commands to run -- note you should change the
`--prefix` option to set the directory where you want to install the
toolchain. (These commands are correct as of April 2025.)

```
$ git clone https://github.com/riscv-collab/riscv-gnu-toolchain.git
$ cd riscv-gnu-toolchain
$ ./configure --prefix=$HOME/riscv --with-arch=rv32im --with-abi=ilp32 --with-languages=c,c++
$ GCC_EXTRA_CONFIGURE_FLAGS=--enable-cet make
```

You should now be able to add "prefix/bin" to your PATH and use the
cross-compiler tools. The tools will have a `riscv32-unknown-elf-`
prefix, e.g. running `riscv32-unknown-elf-gcc` will give you the C
compiler, `riscv32-unknown-elf-g++` is the C++ compiler, etc.


# See also

This program is based on
[Mips2cs](https://github.com/sdthompson1/mips2cs). The plan is to
update the original Mips2cs tool (from 2011) to use RISC-V instead of
MIPS as the base instruction set, to create a C++ target program
instead of C#, and to use the RISC-V "Zicfilp" extension
(`-fcf-protection` gcc flag) as an accurate way of finding indirect
branch points (the original Mips2cs relied on the linker
`--emit-relocs` option but `-fcf-protection` will probably be a
simpler and more robust solution).

See https://www.solarflare.org.uk/mips2cs for more details about
Mips2cs.
