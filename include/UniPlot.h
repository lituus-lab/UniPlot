/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 lituus-lab */
#ifndef UNIPLOT_H
#define UNIPLOT_H
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif

#define UNIPLOT_VERSION "1.0.0"
#define UNIPLOT_ABI_VERSION 1
enum { UPLOT_OK = 0, UPLOT_ERR_ARGUMENT = 1, UPLOT_ERR_RENDER = 2 };
typedef struct uplot_plot uplot_plot;

int uplot_init(void);
const char *uplot_version(void);
int uplot_abi_version(void);
uplot_plot *uplot_plot_new(int width, int height);
int uplot_add_line(uplot_plot *, const double *, const double *, size_t,
                   const char *color, float width);
int uplot_add_points(uplot_plot *, const double *, const double *, size_t,
                     const char *color, float radius);
int uplot_set_title(uplot_plot *, const char *title);
int uplot_render_png(uplot_plot *, const char *font_path, uint8_t **, size_t *);
int uplot_render_svg(uplot_plot *, const char *font_path, uint8_t **, size_t *);
void uplot_buffer_free(void *, size_t);
void uplot_plot_free(uplot_plot *);

#ifdef __cplusplus
}
#endif
#endif
