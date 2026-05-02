#include <iostream>
#include <map>
#include <string>
#include <vector>

// Exercises C++ static initialization (__libc_init_array path): non-trivial
// constructors that run before main, registering side effects into other
// globals. Within a single translation unit, init order is top-to-bottom.

static std::vector<std::string> log;

struct Logger {
    Logger(const std::string &name) {
        log.push_back("ctor " + name);
    }
};

static Logger l1("first");
static Logger l2("second");

// Initializer-list constructed map; runs before main.
static std::map<std::string, int> table = {
    {"alpha", 1},
    {"beta",  2},
    {"gamma", 3},
};

static Logger l3("third");

// Global with a side-effect-only constructor (writes via cout, which itself
// must be initialized first -- tests that ordering too).
struct Banner {
    Banner() { std::cout << "banner constructed\n"; }
};
static Banner banner;

int main()
{
    std::cout << "main starting\n";

    for (const auto &line : log) {
        std::cout << line << "\n";
    }

    for (const auto &kv : table) {
        std::cout << kv.first << " = " << kv.second << "\n";
    }

    static Logger inside_main("inside_main");  // function-local static
    std::cout << log.back() << "\n";

    return 0;
}
