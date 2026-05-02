#include <stdio.h>

/* ASCII Mandelbrot set. Deterministic: pure integer/double math, no input. */

int main(void)
{
    const int width = 78;
    const int height = 24;
    const int max_iter = 50;
    const double xmin = -2.0, xmax = 1.0;
    const double ymin = -1.0, ymax = 1.0;
    const char *palette = " .:-=+*#%@";
    const int palette_len = 10;

    for (int py = 0; py < height; py++) {
        double y0 = ymin + (ymax - ymin) * py / (height - 1);
        for (int px = 0; px < width; px++) {
            double x0 = xmin + (xmax - xmin) * px / (width - 1);
            double x = 0.0, y = 0.0;
            int iter = 0;
            while (x * x + y * y <= 4.0 && iter < max_iter) {
                double xt = x * x - y * y + x0;
                y = 2.0 * x * y + y0;
                x = xt;
                iter++;
            }
            char c = (iter == max_iter) ? '@'
                    : palette[(iter * (palette_len - 1)) / max_iter];
            putchar(c);
        }
        putchar('\n');
    }
    return 0;
}
