#include <stdio.h>
#include <inttypes.h>

/* Exercises 64-bit arithmetic on a 32-bit target. On rv32im these become
 * calls into compiler helper routines (__muldi3, __divdi3, __udivdi3, etc.),
 * so this catches breakage in the translation of those code paths. */

int main(void)
{
    /* Factorials (20! is the largest that fits in uint64_t). */
    uint64_t f = 1;
    for (int i = 1; i <= 20; i++) {
        f *= (uint64_t)i;
        printf("%2d! = %20" PRIu64 "\n", i, f);
    }

    /* Multiply, divide, modulo with values that don't fit in 32 bits. */
    uint64_t a = 0x0123456789abcdefULL;
    uint64_t b = 0xfedcba9876543210ULL;
    printf("a    = 0x%016" PRIx64 "\n", a);
    printf("b    = 0x%016" PRIx64 "\n", b);
    printf("a+b  = 0x%016" PRIx64 "\n", a + b);
    printf("a*3  = 0x%016" PRIx64 "\n", a * 3);
    printf("b/7  = 0x%016" PRIx64 "\n", b / 7);
    printf("b%%7  = 0x%016" PRIx64 "\n", b % 7);
    printf("a>>5 = 0x%016" PRIx64 "\n", a >> 5);
    printf("a<<9 = 0x%016" PRIx64 "\n", a << 9);

    /* Signed 64-bit divide. */
    int64_t s = -1234567890123456789LL;
    printf("s    = %" PRId64 "\n", s);
    printf("s/13 = %" PRId64 "\n", s / 13);
    printf("s%%13 = %" PRId64 "\n", s % 13);

    /* FNV-1a 64-bit hash of a fixed string. */
    const char *str = "the quick brown fox jumps over the lazy dog";
    uint64_t h = 0xcbf29ce484222325ULL;
    for (const char *p = str; *p; p++) {
        h ^= (uint8_t)*p;
        h *= 0x100000001b3ULL;
    }
    printf("fnv  = 0x%016" PRIx64 "\n", h);

    return 0;
}
