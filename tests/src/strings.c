#include <stdio.h>
#include <string.h>

/* Exercises libc string/memory routines as translated through risc2cpp. */

static void show_buf(const char *label, const unsigned char *b, size_t n)
{
    printf("%s:", label);
    for (size_t i = 0; i < n; i++) printf(" %02x", b[i]);
    printf("\n");
}

int main(void)
{
    const char *s = "the quick brown fox jumps over the lazy dog";

    printf("strlen      = %zu\n", strlen(s));
    printf("strcmp eq   = %d\n", strcmp("hello", "hello"));
    printf("strcmp lt   = %d\n", strcmp("apple", "banana") < 0);
    printf("strcmp gt   = %d\n", strcmp("banana", "apple") > 0);
    printf("strncmp     = %d\n", strncmp("foobar", "foobaz", 5));
    printf("strchr 'f'  = %s\n", strchr(s, 'f'));
    printf("strchr 'z'  = %s\n", strchr(s, 'z'));
    printf("strchr '?'  = %s\n", strchr(s, '?') ? "found" : "(null)");
    printf("strrchr 'o' = %s\n", strrchr(s, 'o'));
    printf("strstr      = %s\n", strstr(s, "jumps"));
    printf("strstr miss = %s\n", strstr(s, "cat") ? "found" : "(null)");

    /* memcpy / memmove / memset / memcmp on raw bytes. */
    unsigned char a[16], b[16];
    memset(a, 0xaa, sizeof a);
    memset(b, 0x55, sizeof b);
    show_buf("a init     ", a, 16);
    show_buf("b init     ", b, 16);

    memcpy(a, "hello, world!\0\0", 16);
    show_buf("a memcpy   ", a, 16);

    memmove(a + 2, a, 10);  /* overlapping */
    show_buf("a memmove  ", a, 16);

    memset(b + 4, 0, 8);
    show_buf("b memset   ", b, 16);

    printf("memcmp eq   = %d\n", memcmp("abcd", "abcd", 4));
    printf("memcmp ne   = %d\n", memcmp("abcd", "abce", 4) < 0);

    /* Build a string with snprintf and inspect it. */
    char out[64];
    int n = snprintf(out, sizeof out, "[%s] (%d/%d)", "ok", 7, 42);
    printf("snprintf n  = %d, out = %s\n", n, out);

    return 0;
}
