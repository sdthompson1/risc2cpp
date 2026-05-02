#include <iostream>
#include <vector>

static int count_primes(int n) {
    std::vector<bool> isPrime(n + 1, true);
    isPrime[0] = isPrime[1] = false;
    for (int p = 2; p * p <= n; p++) {
        if (isPrime[p]) {
            for (int i = p * p; i <= n; i += p) {
                isPrime[i] = false;
            }
        }
    }
    int count = 0;
    for (int p = 2; p <= n; p++) {
        if (isPrime[p]) count++;
    }
    return count;
}

int main() {
    int n = 1000 * 1000;
    std::cout << "Counting primes upto " << n << std::endl;
    std::cout << "Number of primes found: " << count_primes(n) << std::endl;
    return 0;
}
