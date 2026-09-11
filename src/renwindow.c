#include <stdlib.h>
#include <assert.h>
#include <stdio.h>
#include <math.h>
#include "renwindow.h"

#ifdef LITE_USE_SDL_RENDERER
static double query_surface_scale(RenWindow *ren) {
  int w_pixels, h_pixels;
  int w_points, h_points;
  SDL_GetWindowSizeInPixels(ren->window, &w_pixels, &h_pixels);
  SDL_GetWindowSize(ren->window, &w_points, &h_points);
  /* The pixel/point ratio is usually an integer on retina displays, but can
     be fractional (1.25, 1.5, etc.) on Windows with per-monitor scaling.
     We average both axes and never assert, so fractional DPI works too. */
  if (w_points <= 0 || h_points <= 0) return 1.0;
  const double sx = (double) w_pixels / w_points;
  const double sy = (double) h_pixels / h_points;
  return (sx + sy) / 2.0;
}

static void setup_renderer(RenWindow *ren, int w, int h) {
  /* Note that w and h here should always be in pixels and obtained from
     a call to SDL_GetWindowSizeInPixels(). */
  if (!ren->renderer) {
    ren->renderer = SDL_CreateRenderer(ren->window, NULL);
  }
  if (ren->texture) {
    SDL_DestroyTexture(ren->texture);
  }
  ren->texture = SDL_CreateTexture(ren->renderer, ren->rensurface.surface->format, SDL_TEXTUREACCESS_STREAMING, w, h);
  ren->rensurface.scale = query_surface_scale(ren);
}
#endif


void renwin_init_surface(RenWindow *ren) {
  ren->scale_x = ren->scale_y = 1;
#ifdef LITE_USE_SDL_RENDERER
  if (ren->rensurface.surface) {
    SDL_DestroySurface(ren->rensurface.surface);
  }
  int w, h;
  SDL_GetWindowSizeInPixels(ren->window, &w, &h);
  SDL_PixelFormat format = SDL_GetWindowPixelFormat(ren->window);
  ren->rensurface.surface = SDL_CreateSurface(w, h, format == SDL_PIXELFORMAT_UNKNOWN ? SDL_PIXELFORMAT_BGRA32 : format);
  if (!ren->rensurface.surface) {
    fprintf(stderr, "Error creating surface: %s", SDL_GetError());
    exit(1);
  }
  setup_renderer(ren, w, h);
#endif
}

void renwin_init_command_buf(RenWindow *ren) {
  ren->command_buf = NULL;
  ren->command_buf_idx = 0;
  ren->command_buf_size = 0;
}


static RenRect scaled_rect(const RenRect rect, const double scale) {
  return (RenRect) {
    (int) llround(rect.x * scale),
    (int) llround(rect.y * scale),
    (int) llround(rect.width * scale),
    (int) llround(rect.height * scale)
  };
}


void renwin_clip_to_surface(RenWindow *ren) {
  SDL_SetSurfaceClipRect(renwin_get_surface(ren).surface, NULL);
}


void renwin_set_clip_rect(RenWindow *ren, RenRect rect) {
  RenSurface rs = renwin_get_surface(ren);
  RenRect sr = scaled_rect(rect, rs.scale);
  SDL_SetSurfaceClipRect(rs.surface, &(SDL_Rect){.x = sr.x, .y = sr.y, .w = sr.width, .h = sr.height});
}


RenSurface renwin_get_surface(RenWindow *ren) {
#ifdef LITE_USE_SDL_RENDERER
  return ren->rensurface;
#else
  SDL_Surface *surface = SDL_GetWindowSurface(ren->window);
  if (!surface) {
    fprintf(stderr, "Error getting window surface: %s", SDL_GetError());
    exit(1);
  }
  return (RenSurface){.surface = surface, .scale = 1};
#endif
}

void renwin_resize_surface(RenWindow *ren) {
#ifdef LITE_USE_SDL_RENDERER
  int new_w, new_h;
  double new_scale;
  SDL_GetWindowSizeInPixels(ren->window, &new_w, &new_h);
  new_scale = query_surface_scale(ren);
  /* Note that (w, h) may differ from (new_w, new_h) on retina displays. */
  if (fabs(new_scale - ren->rensurface.scale) > 0.001 ||
      new_w != ren->rensurface.surface->w ||
      new_h != ren->rensurface.surface->h) {
    renwin_init_surface(ren);
    renwin_clip_to_surface(ren);
    setup_renderer(ren, new_w, new_h);
  }
#endif
}

void renwin_update_scale(RenWindow *ren) {
#ifndef LITE_USE_SDL_RENDERER
  SDL_Surface *surface = SDL_GetWindowSurface(ren->window);
  int window_w = surface->w, window_h = surface->h;
  SDL_GetWindowSize(ren->window, &window_w, &window_h);
  ren->scale_x = (float)surface->w / window_w;
  ren->scale_y = (float)surface->h / window_h;
#endif
}

void renwin_show_window(RenWindow *ren) {
  SDL_ShowWindow(ren->window);
}

void renwin_update_rects(RenWindow *ren, RenRect *rects, int count) {
#ifdef LITE_USE_SDL_RENDERER
  const double scale = ren->rensurface.scale;
  for (int i = 0; i < count; i++) {
    const RenRect *r = &rects[i];
    const int x = (int) llround(scale * r->x), y = (int) llround(scale * r->y);
    const int w = (int) llround(scale * r->width), h = (int) llround(scale * r->height);
    const SDL_Rect sr = {.x = x, .y = y, .w = w, .h = h};
    uint8_t *pixels = ((uint8_t *) ren->rensurface.surface->pixels) + y * ren->rensurface.surface->pitch + x * SDL_BYTESPERPIXEL(ren->rensurface.surface->format);
    SDL_UpdateTexture(ren->texture, &sr, pixels, ren->rensurface.surface->pitch);
  }
  SDL_RenderTexture(ren->renderer, ren->texture, NULL, NULL);
  SDL_RenderPresent(ren->renderer);
#else
  SDL_UpdateWindowSurfaceRects(ren->window, (SDL_Rect*) rects, count);
#endif
}

void renwin_free(RenWindow *ren) {
#ifdef LITE_USE_SDL_RENDERER
  SDL_DestroyTexture(ren->texture);
  SDL_DestroyRenderer(ren->renderer);
  SDL_DestroySurface(ren->rensurface.surface);
#endif
  SDL_DestroyWindow(ren->window);
  ren->window = NULL;
}
