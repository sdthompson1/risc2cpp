// Shared host program for risc2cpp end-to-end tests.
//
// The VM header to include is supplied at compile time via -DVM_HEADER=...
// The generated C++ source (e.g. hello_vm.cpp) is passed to the compiler
// alongside this file.

#ifndef VM_HEADER
#error "VM_HEADER must be defined (path to generated *_vm.hpp)"
#endif

#include VM_HEADER

#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include <stdexcept>

// RISC-V Linux-style syscall numbers used by newlib.
enum : uint32_t {
    SYS_write     = 64,
    SYS_exit      = 93,
    SYS_brk       = 214,
    // Test-only syscall, well above any Linux number, used by the .S
    // tests in tests/src/ to print the value of a register as a signed
    // decimal followed by a newline.
    SYS_print_int = 0x10000,
};

static bool handleEcall(RiscVM &vm)
{
    switch (vm.getA7()) {
    case SYS_brk: {
        uint32_t requested = vm.getA0();
        if (requested >= vm.getInitialProgramBreak()) {
            vm.setProgramBreak(requested);
        }
        vm.setA0(vm.getProgramBreak());
        return false;
    }

    case SYS_write: {
        uint32_t fd  = vm.getA0();
        uint32_t buf = vm.getA1();
        uint32_t len = vm.getA2();
        std::FILE *out = (fd == 2) ? stderr : stdout;
        for (uint32_t i = 0; i < len; ++i) {
            std::fputc(vm.readByte(buf + i), out);
        }
        vm.setA0(len);
        return false;
    }

    case SYS_exit:
        std::exit(static_cast<int>(vm.getA0()));

    case SYS_print_int:
        std::printf("%d\n", static_cast<int32_t>(vm.getA0()));
        return false;

    default:
        // Unknown syscall: return -ENOSYS.
        vm.setA0(static_cast<uint32_t>(-38));
        return false;
    }
}

int main(void)
{
    RiscVM vm;
    try {
        while (true) {
            vm.execute();
            if (handleEcall(vm)) break;
        }
    } catch (const std::runtime_error &e) {
        // Generated VM throws std::runtime_error on stack overflow,
        // invalid memory access, etc. Print deterministically so tests
        // can match against expected output.
        std::fflush(stdout);
        std::printf("VM error: %s\n", e.what());
    }
    return 0;
}
