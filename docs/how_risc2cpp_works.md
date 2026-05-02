This file gives a rough overview of how Risc2cpp works. It is not
necessary to understand this in order to use Risc2cpp, but reading it
might give some insight into why the generated C++ files are the way
they are.


# Basic idea

The basic idea is to analyse the machine code instructions in the
RISC-V executable and convert them to equivalent C++ code. For
example, `add s0, s1, s2` in RISC-V would be converted to `s1 = s2 +
s3;` in C++. (Because RISC-V instructions are always 4-byte aligned
and exactly 4 bytes in length, it is easy to find and decode the
instructions.)

Risc2cpp then creates code for a `RiscVM` class, in which the
translated C++ code is placed into various `execute` methods. The
RISC-V registers (`s0`, `t1` and so on) are represented by member
variables of type `uint32_t` in the `RiscVM` class. The memory is
represented by an array of 65,536 "pages" of 65,536 bytes (actually
16,384 `uint32_t`s) each. Only pages actually in use are allocated,
which means that the full 4 GB address space does not need to be
allocated as memory on the host. Helper functions, like `readByteU`,
`writeHalf` and so on, are provided for accessing memory in bytes,
halfwords (2 bytes) and words (4 bytes). These functions only work at
aligned addresses and assume little-endian memory layout.


# Handling branches and jumps

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

# Indirect branches

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

# Determining the possible jump targets

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


# Optimizations

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
and smaller final executables (as can be seen in the benchmarking
results in [README.md](../README.md) and
[benchmark.md](benchmark.md)).


# Possible future work

Additional RISC-V extensions could be supported. For example, some
kind of support for floating point (F or D extensions) might be
useful. (Currently, programs that use floating point can be compiled,
but they will simulate floating point operations using integer
instructions, which is slow.)

Support for 64-bit RISC-V might also be useful at some point.

The RISC-V
["Zicfilp"](https://github.com/riscv/riscv-cfi/blob/main/src/cfi_forward.adoc)
extension provides an intriguing opportunity for removing the need to
have the indirect branch destinations encoded in the symbol table.
Instead, the `LPAD` instructions could be used for determining the
possible targets of indirect jumps. Unfortunately, this comes with
some limitations (e.g. compilers can emit "software guarded branches"
which don't use the `LPAD` instructions) but it might nevertheless be
worth looking into.

Perhaps the handling of the virtual machine's memory could be improved
as well. At the moment, the memory is represented as an array of
"pages" where each page is an array of `uint32_t`s. This makes word
access very easy, but byte and halfword accesses require some extra
work. Perhaps it would be better simply to represent each page as an
array of `uint8_t`. For halfword and word operations, we could simply
`memcpy` a 2 or 4 byte region into or out of the memory page. On x86
this would most likely compile down to a single `mov` instruction in
each case, since the architecture supports unaligned loads and stores.
This might well improve the speed and reduce the code size slightly.
(This trick would only work on little-endian host machines, but that
isn't much of an issue since almost everything is little-endian
nowadays.)

For target programs that make heavy use of `memcpy` and/or `memset`,
it might also be useful to "intercept" calls to those functions and
redirect them to use the native `memcpy` and `memset` operations
instead. This would probably give a significant speed boost to such
programs. Also, this would avoid the need to compile newlib with the
`PREFER_SIZE_OVER_SPEED` option, because we would no longer be using
newlib's problematic assembly language `memset` function.
