#include <iostream>
#include <stdexcept>
#include <string>

// Exercises C++ exception handling: throw across frames, catch by type,
// destructors during unwinding, std::exception hierarchy.

struct Tracer {
    std::string name;
    Tracer(const std::string &n) : name(n) {
        std::cout << "  ctor " << name << "\n";
    }
    ~Tracer() {
        std::cout << "  dtor " << name << "\n";
    }
};

static void deep(int n)
{
    Tracer t("deep#" + std::to_string(n));
    if (n == 0) {
        throw std::runtime_error("boom");
    }
    deep(n - 1);
}

static int divide(int a, int b)
{
    if (b == 0) throw std::invalid_argument("divide by zero");
    return a / b;
}

int main()
{
    std::cout << "test 1: catch by exact type\n";
    try {
        throw 42;
    } catch (int x) {
        std::cout << "  caught int " << x << "\n";
    }

    std::cout << "test 2: catch via base class\n";
    try {
        divide(1, 0);
    } catch (const std::exception &e) {
        std::cout << "  caught: " << e.what() << "\n";
    }

    std::cout << "test 3: unwinding runs destructors\n";
    try {
        deep(3);
    } catch (const std::runtime_error &e) {
        std::cout << "  caught runtime_error: " << e.what() << "\n";
    }

    std::cout << "test 4: rethrow\n";
    try {
        try {
            throw std::logic_error("inner");
        } catch (const std::exception &) {
            std::cout << "  inner handler, rethrowing\n";
            throw;
        }
    } catch (const std::logic_error &e) {
        std::cout << "  outer caught: " << e.what() << "\n";
    }

    std::cout << "done\n";
    return 0;
}
