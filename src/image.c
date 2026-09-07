#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <math.h>

#include <SDL3/SDL.h>

#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

#include "image.h"

RenImage* ren_image_load(const char *filename) {
  int w, h, channels;
  unsigned char *pixels = stbi_load(filename, &w, &h, &channels, 4);
  if (!pixels) {
    return NULL;
  }

  RenImage *img = malloc(sizeof(RenImage));
  if (!img) {
    stbi_image_free(pixels);
    return NULL;
  }

  img->width = w;
  img->height = h;
  img->pixels = pixels;
  img->surface = SDL_CreateSurfaceFrom(
    w, h, SDL_PIXELFORMAT_RGBA32, pixels, w * 4
  );
  if (!img->surface) {
    free(img);
    stbi_image_free(pixels);
    return NULL;
  }

  return img;
}

void ren_image_free(RenImage *img) {
  if (!img) return;
  if (img->surface) SDL_DestroySurface(img->surface);
  if (img->pixels) stbi_image_free(img->pixels);
  free(img);
}

bool ren_draw_image(RenSurface *rs, RenImage *img, int x, int y, int w, int h) {
  if (!rs || !img || !img->surface) return false;
  SDL_Rect dest_rect = { x, y, w, h };
  return SDL_BlitSurfaceScaled(img->surface, NULL, rs->surface, &dest_rect, SDL_SCALEMODE_LINEAR);
}

void ren_image_get_size(RenImage *img, int *w, int *h) {
  if (w) *w = img ? img->width : 0;
  if (h) *h = img ? img->height : 0;
}