#ifndef IMAGE_H
#define IMAGE_H

#include <stdbool.h>
#include "renderer.h"

typedef struct {
  int width;
  int height;
  unsigned char *pixels;
  SDL_Surface *surface;
} RenImage;

RenImage* ren_image_load(const char *filename);
void ren_image_free(RenImage *img);
bool ren_draw_image(RenSurface *rs, RenImage *img, int x, int y, int w, int h);
void ren_image_get_size(RenImage *img, int *w, int *h);

#endif