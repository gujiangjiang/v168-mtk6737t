/* fbconsole — v168-mtk6737t Linux Phase 1 帧缓冲控制台 + 触摸演示
 *
 * 用途:
 *   --info          打印帧缓冲与输入设备信息 (只读, 不改屏幕)
 *   --text "..."    把若干行文字画到屏幕后退出
 *   --demo          演示模式: 屏幕信息 + 触摸十字线 (左上角连点两次退出)
 *
 * 编译 (CI 或 Linux):
 *   arm-linux-gnueabihf-gcc -O2 -static -o fbconsole fbconsole.c
 * macOS 本地语法检查:
 *   cc -fsyntax-only -Wall fbconsole.c
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <signal.h>
#include <time.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/utsname.h>
#include <dirent.h>

#if defined(__linux__)
#include <linux/fb.h>
#include <linux/input.h>
#else
/* ---- macOS 语法检查用的最小替身 (不用于运行, 非 ABI 精确) ---- */
struct fb_bitfield {
    uint32_t offset, length, msb_right;
};
struct fb_var_screeninfo {
    uint32_t xres, yres, xres_virtual, yres_virtual, xoffset, yoffset;
    uint32_t bits_per_pixel, grayscale;
    struct fb_bitfield red, green, blue, transp;
    uint32_t nonstd, activate, height, width, accel_flags;
    uint32_t pixclock, left_margin, right_margin, upper_margin, lower_margin;
    uint32_t hsync_len, vsync_len, sync, vmode, rotate, colorspace, reserved[4];
};
struct fb_fix_screeninfo {
    char id[16];
    unsigned long smem_start;
    uint32_t smem_len, type, type_aux, visual;
    uint16_t xpanstep, ypanstep, ywrapstep;
    uint32_t line_length;
    unsigned long mmio_start;
    uint32_t mmio_len, accel;
    uint16_t capabilities, reserved[2];
};
#define FBIOGET_VSCREENINFO 0x4600
#define FBIOGET_FSCREENINFO 0x4602
struct input_event {
    int32_t tv_sec, tv_usec;
    uint16_t type, code;
    int32_t value;
};
#define EV_SYN 0x00
#define EV_KEY 0x01
#define EV_ABS 0x03
#define ABS_X 0x00
#define ABS_Y 0x01
#define ABS_MT_POSITION_X 0x35
#define ABS_MT_POSITION_Y 0x36
#define BTN_TOUCH 0x14a
#define SYN_REPORT 0
#define EVIOCGNAME(x) 0
#endif

#include "font8x16.h"

#define FONT_W 8
#define FONT_H 16

static int fb_fd = -1;
static uint8_t *fb = NULL;
static uint8_t *fb_back = NULL;
static size_t fb_len = 0;
static uint32_t SCREEN_W, SCREEN_H, LINE, BPP;
static struct fb_var_screeninfo vi;
static struct fb_fix_screeninfo fi;
static volatile sig_atomic_t g_quit = 0;

static void on_sigint(int s)
{
    (void)s;
    g_quit = 1;
}

static uint32_t col_rgb(uint8_t r, uint8_t g, uint8_t b)
{
    uint32_t v = 0;
    if (vi.red.length)
        v |= (uint32_t)((uint32_t)r * ((1u << vi.red.length) - 1) / 255) << vi.red.offset;
    if (vi.green.length)
        v |= (uint32_t)((uint32_t)g * ((1u << vi.green.length) - 1) / 255) << vi.green.offset;
    if (vi.blue.length)
        v |= (uint32_t)((uint32_t)b * ((1u << vi.blue.length) - 1) / 255) << vi.blue.offset;
    if (vi.transp.length)
        v |= ((1u << vi.transp.length) - 1) << vi.transp.offset;
    return v;
}

static void put_pixel(uint8_t *buf, int x, int y, uint32_t c)
{
    if (x < 0 || y < 0 || (uint32_t)x >= SCREEN_W || (uint32_t)y >= SCREEN_H)
        return;
    uint8_t *p = buf + (size_t)y * LINE + (size_t)x * (BPP / 8);
    switch (BPP) {
    case 8:
        p[0] = (uint8_t)c;
        break;
    case 16:
        p[0] = (uint8_t)c;
        p[1] = (uint8_t)(c >> 8);
        break;
    case 24:
        p[0] = (uint8_t)c;
        p[1] = (uint8_t)(c >> 8);
        p[2] = (uint8_t)(c >> 16);
        break;
    default:
        p[0] = (uint8_t)c;
        p[1] = (uint8_t)(c >> 8);
        p[2] = (uint8_t)(c >> 16);
        p[3] = (uint8_t)(c >> 24);
        break;
    }
}

static void fb_flush(void)
{
    if (fb && fb_back)
        memcpy(fb, fb_back, fb_len);
}

static void clear(uint32_t c)
{
    for (uint32_t y = 0; y < SCREEN_H; y++)
        for (uint32_t x = 0; x < SCREEN_W; x++)
            put_pixel(fb_back, (int)x, (int)y, c);
}

static void draw_char(int x, int y, char c, uint32_t fg)
{
    const unsigned char *g;
    if (c < 32 || c > 126)
        c = '?';
    g = font8x16[(int)c - 32];
    for (int r = 0; r < FONT_H; r++) {
        unsigned char bits = g[r];
        for (int b = 0; b < FONT_W; b++)
            if (bits & (0x80 >> b))
                put_pixel(fb_back, x + b, y + r, fg);
    }
}

static void draw_text(int x, int y, const char *s, uint32_t fg)
{
    for (; *s; s++, x += FONT_W)
        draw_char(x, y, *s, fg);
}

static int open_fb(void)
{
    const char *paths[] = { "/dev/graphics/fb0", "/dev/fb0" };
    for (int i = 0; i < 2; i++) {
        fb_fd = open(paths[i], O_RDWR);
        if (fb_fd < 0)
            continue;
        if (ioctl(fb_fd, FBIOGET_VSCREENINFO, &vi) < 0 ||
            ioctl(fb_fd, FBIOGET_FSCREENINFO, &fi) < 0) {
            close(fb_fd);
            fb_fd = -1;
            continue;
        }
        SCREEN_W = vi.xres;
        SCREEN_H = vi.yres;
        BPP = vi.bits_per_pixel;
        LINE = fi.line_length ? fi.line_length : SCREEN_W * (BPP / 8);
        fb_len = (size_t)LINE * SCREEN_H;
        fb = mmap(NULL, fb_len, PROT_READ | PROT_WRITE, MAP_SHARED, fb_fd, 0);
        if (fb == MAP_FAILED) {
            fb = NULL;
            close(fb_fd);
            fb_fd = -1;
            continue;
        }
        fb_back = (uint8_t *)malloc(fb_len);
        if (!fb_back) {
            munmap(fb, fb_len);
            fb = NULL;
            close(fb_fd);
            fb_fd = -1;
            return -1;
        }
        printf("fb: %s  %ux%u %ubpp line=%u\n", paths[i], SCREEN_W, SCREEN_H, BPP, LINE);
        return 0;
    }
    return -1;
}

static void list_inputs(void)
{
    DIR *d = opendir("/dev/input");
    struct dirent *e;
    if (!d) {
        printf("input: /dev/input 不存在\n");
        return;
    }
    while ((e = readdir(d))) {
        char path[128];
        char name[128] = "?";
        int fd;
        if (strncmp(e->d_name, "event", 5))
            continue;
        snprintf(path, sizeof path, "/dev/input/%s", e->d_name);
        fd = open(path, O_RDONLY | O_NONBLOCK);
        if (fd < 0)
            continue;
        ioctl(fd, EVIOCGNAME(sizeof name), name);
        printf("input: %-22s %s\n", path, name);
        close(fd);
    }
    closedir(d);
}

static int input_open_touch(void)
{
    DIR *d = opendir("/dev/input");
    struct dirent *e;
    if (!d)
        return -1;
    while ((e = readdir(d))) {
        char path[128];
        char name[128] = "";
        int fd;
        if (strncmp(e->d_name, "event", 5))
            continue;
        snprintf(path, sizeof path, "/dev/input/%s", e->d_name);
        fd = open(path, O_RDONLY | O_NONBLOCK);
        if (fd < 0)
            continue;
        ioctl(fd, EVIOCGNAME(sizeof name), name);
        if (strstr(name, "touch") || strstr(name, "Touch") || strstr(name, "ts") ||
            strstr(name, "tablet") || strstr(name, "Tablet") || strstr(name, "Touchscreen")) {
            printf("touch: %s (%s)\n", path, name);
            closedir(d);
            return fd;
        }
        close(fd);
    }
    closedir(d);
    return -1;
}

static void draw_ui(int x, int y, int down, int taps)
{
    uint32_t bg = col_rgb(8, 12, 30);
    uint32_t fg = col_rgb(230, 240, 255);
    uint32_t acc = col_rgb(80, 220, 160);
    uint32_t warn = col_rgb(255, 180, 60);
    char buf[160];
    struct utsname u;

    clear(bg);
    draw_text(16, 16, "v168-mtk6737t  Linux Phase 1", fg);
    snprintf(buf, sizeof buf, "screen: %ux%u  %ubpp  line=%u", SCREEN_W, SCREEN_H, BPP, LINE);
    draw_text(16, 44, buf, acc);
    if (!uname(&u)) {
        snprintf(buf, sizeof buf, "kernel: %s %s", u.sysname, u.release);
        draw_text(16, 68, buf, acc);
    }
    snprintf(buf, sizeof buf, "touch : x=%d  y=%d  %s  (corner taps: %d)",
             x, y, down ? "DOWN" : " up ", taps);
    draw_text(16, 92, buf, fg);
    draw_text(16, 116, "tap top-left corner twice to exit", warn);

    for (uint32_t xx = 0; xx < SCREEN_W; xx++)
        put_pixel(fb_back, (int)xx, y, acc);
    for (uint32_t yy = 0; yy < SCREEN_H; yy++)
        put_pixel(fb_back, x, (int)yy, acc);
    fb_flush();
}

int main(int argc, char **argv)
{
    if (argc >= 2 && !strcmp(argv[1], "--info")) {
        if (open_fb() < 0) {
            printf("fb: 未找到可用 framebuffer (/dev/graphics/fb0, /dev/fb0)\n");
        } else {
            printf("fb fix: id='%s' smem_len=%u line_length=%u\n", fi.id, fi.smem_len,
                   fi.line_length);
            printf("fb var: red[%u/%u] green[%u/%u] blue[%u/%u] transp[%u/%u]\n",
                   vi.red.offset, vi.red.length, vi.green.offset, vi.green.length,
                   vi.blue.offset, vi.blue.length, vi.transp.offset, vi.transp.length);
        }
        list_inputs();
        return 0;
    }

    if (open_fb() < 0) {
        fprintf(stderr, "错误: 找不到 framebuffer\n");
        return 1;
    }

    if (argc >= 3 && !strcmp(argv[1], "--text")) {
        int y = 16;
        clear(col_rgb(0, 0, 0));
        for (int i = 2; i < argc; i++) {
            draw_text(16, y, argv[i], col_rgb(240, 240, 240));
            y += FONT_H + 4;
        }
        fb_flush();
        return 0;
    }

    if (argc >= 2 && !strcmp(argv[1], "--demo")) {
        int x = (int)SCREEN_W / 2;
        int y = (int)SCREEN_H / 2;
        int down = 0, taps = 0;
        int tfd;

        signal(SIGINT, on_sigint);
        signal(SIGTERM, on_sigint);
        tfd = input_open_touch();

        while (!g_quit) {
            struct input_event ev;
            ssize_t n;
            if (tfd >= 0) {
                while ((n = read(tfd, &ev, sizeof ev)) == (ssize_t)sizeof ev) {
                    if (ev.type == EV_ABS &&
                        (ev.code == ABS_X || ev.code == ABS_MT_POSITION_X))
                        x = ev.value;
                    else if (ev.type == EV_ABS &&
                             (ev.code == ABS_Y || ev.code == ABS_MT_POSITION_Y))
                        y = ev.value;
                    else if (ev.type == EV_KEY && ev.code == BTN_TOUCH) {
                        down = ev.value;
                        if (down && x < 96 && y < 96) {
                            taps++;
                            if (taps >= 2) {
                                g_quit = 1;
                                break;
                            }
                        }
                    } else if (ev.type == EV_SYN && ev.code == SYN_REPORT) {
                        draw_ui(x, y, down, taps);
                    }
                }
            } else {
                draw_ui(x, y, down, taps);
                sleep(1);
            }
            usleep(5000);
        }
        clear(col_rgb(0, 0, 0));
        fb_flush();
        return 0;
    }

    fprintf(stderr, "用法: fbconsole --info | --text <行...> | --demo\n");
    return 2;
}
