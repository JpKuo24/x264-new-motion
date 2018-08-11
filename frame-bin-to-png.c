#include <stdlib.h>
#include <stdio.h>
#include <png.h>

typedef u_int8_t uint8_t;

/* 
 * read the binary frame, each byte is uint8_t pixel luma value, next row is stride away.
 */
int read_frame_binary(const char *filename, int stride, int height, png_structp png) {
    int length = stride * height;
    uint8_t *pixels = malloc(length * sizeof(uint8_t));

    FILE *file = fopen(filename, "rb");
    if (file == NULL) {
        printf("file pt is null\n");
        return 1;
    }

    int lr = fread(pixels, sizeof(uint8_t), length, file);
    if (lr != length) {
        printf("read pixels != length %d vs %d\n", lr, length);
        return 1;
    }

    png_bytep row = (png_bytep) malloc(1 * stride * sizeof(png_byte));

    for (int y = 0; y < height; y++) {
        for (int x = 0; x < stride; x++) {
            row[x] = pixels[x + y*stride];
        }
        png_write_row(png, row);
    }

    free(pixels);
    free(row);

    return 0;
}

int write_png_file(char *filename, char *bin_filename, int width, int height) {
    int y;

    FILE *fp = fopen(filename, "wb");
    if(!fp) return 1;

    png_structp png = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
    if (!png) return 1;

    png_infop info = png_create_info_struct(png);
    if (!info) return 1;

    if (setjmp(png_jmpbuf(png))) return 1;

    png_init_io(png, fp);

    // Output is 8bit depth, RGBA format.
    png_set_IHDR(
        png,
        info,
        width, height,
        8,
        PNG_COLOR_TYPE_GRAY,
        PNG_INTERLACE_NONE,
        PNG_COMPRESSION_TYPE_DEFAULT,
        PNG_FILTER_TYPE_DEFAULT
    );
    png_write_info(png, info);

    if (read_frame_binary(bin_filename, width, height, png))
        return 1;

    png_write_end(png, NULL);

    fclose(fp);

    return 0;
}

int main(int argc, char** argv) {
    int ret;

    if (argc != 5) {
        printf("error: invalid args count. args: <bin_file> <png_file> <stride> <height>\n");
        return 0;
    }

    const int stride = atoi(argv[3]);
    const int height = atoi(argv[4]);

    if (write_png_file(argv[2], argv[1], stride, height)) {
        printf("error\n");
        return 1;
    }

    return 0;
}
