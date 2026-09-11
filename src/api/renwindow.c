#include "api.h"
#include "../renwindow.h"
#include "lua.h"
#include <SDL3/SDL.h>
#include <stdlib.h>

#ifdef _WIN32
#include <windows.h>
#include <dwmapi.h>

/* Applies the user's OS-wide dark mode preference to the native title bar.
   Loaded at runtime so we don't need to link against dwmapi.lib explicitly. */
static void apply_native_titlebar_theme(SDL_Window *window) {
  HWND hwnd = (HWND) SDL_GetPointerProperty(
    SDL_GetWindowProperties(window), SDL_PROP_WINDOW_WIN32_HWND_POINTER, NULL);
  if (!hwnd) return;

  int use_light = 1;
  HKEY key;
  DWORD size = sizeof(use_light);
  if (RegOpenKeyExW(HKEY_CURRENT_USER,
        L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
        0, KEY_READ, &key) == ERROR_SUCCESS) {
    if (RegQueryValueExW(key, L"AppsUseLightTheme", NULL, NULL,
          (LPBYTE) &use_light, &size) != ERROR_SUCCESS) {
      use_light = 1;
    }
    RegCloseKey(key);
  }

  BOOL dark = !use_light;
  typedef HRESULT (WINAPI *DwmSetWindowAttribute_t)(HWND, DWORD, LPCVOID, DWORD);
  HMODULE dwmapi = LoadLibraryW(L"dwmapi.dll");
  if (dwmapi) {
    DwmSetWindowAttribute_t pfn = (DwmSetWindowAttribute_t)
      GetProcAddress(dwmapi, "DwmSetWindowAttribute");
    if (pfn) {
      /* DWMWA_USE_IMMERSIVE_DARK_MODE; fall back to the pre-1809 attribute id. */
      if (FAILED(pfn(hwnd, 20, &dark, sizeof(dark))))
        pfn(hwnd, 19, &dark, sizeof(dark));
    }
    FreeLibrary(dwmapi);
  }
}
#else
static void apply_native_titlebar_theme(SDL_Window *window) {
  (void) window;
}
#endif

static RenWindow *persistant_window = NULL;

static void init_window_icon(SDL_Window *window) {
#if !defined(_WIN32) && !defined(__APPLE__)
  #include "../resources/icons/icon.inl"
  (void) icon_rgba_len; /* unused */
  SDL_PixelFormat format = SDL_GetPixelFormatForMasks(32, 0x000000ff, 0x0000ff00, 0x00ff0000, 0xff000000);
  SDL_Surface *surf = SDL_CreateSurfaceFrom(64, 64, format, icon_rgba, 64 * 4);
  SDL_SetWindowIcon(window, surf);
  SDL_DestroySurface(surf);
#endif
}

static int f_renwin_create(lua_State *L) {
  const char *title = luaL_checkstring(L, 1);
  float width = luaL_optnumber(L, 2, 0);
  float height = luaL_optnumber(L, 3, 0);

  if (video_init() != 0)
    return luaL_error(L, "Error creating Aayushi Code window: %s", SDL_GetError());

  if (width < 1 || height < 1) {
    const SDL_DisplayMode* dm = SDL_GetCurrentDisplayMode(SDL_GetPrimaryDisplay());

    if (width < 1) {
      width = dm->w * 0.8;
    }
    if (height < 1) {
      height = dm->h * 0.8;
    }
  }

  SDL_Window *window = SDL_CreateWindow(
    title, width, height,
    SDL_WINDOW_RESIZABLE | SDL_WINDOW_HIGH_PIXEL_DENSITY | SDL_WINDOW_HIDDEN
  );
  if (!window) {
    return luaL_error(L, "Error creating Aayushi Code window: %s", SDL_GetError());
  }
  init_window_icon(window);
  apply_native_titlebar_theme(window);

  RenWindow **window_renderer = (RenWindow**)lua_newuserdata(L, sizeof(RenWindow*));
  luaL_setmetatable(L, API_TYPE_RENWINDOW);

  *window_renderer = ren_create(window);

  return 1;
}

static int f_renwin_gc(lua_State *L) {
  RenWindow *window_renderer = *(RenWindow**)luaL_checkudata(L, 1, API_TYPE_RENWINDOW);
  if (window_renderer != persistant_window)
    ren_destroy(window_renderer);

  return 0;
}

static int f_renwin_get_size(lua_State *L) {
  RenWindow *window_renderer = *(RenWindow**)luaL_checkudata(L, 1, API_TYPE_RENWINDOW);
  int w, h;
  ren_get_size(window_renderer, &w, &h);
  lua_pushnumber(L, w);
  lua_pushnumber(L, h);
  return 2;
}

static int f_renwin_persist(lua_State *L) {
  RenWindow *window_renderer = *(RenWindow**)luaL_checkudata(L, 1, API_TYPE_RENWINDOW);

  persistant_window = window_renderer;
  return 0;
}

static int f_renwin_restore(lua_State *L) {
  if (!persistant_window) {
    lua_pushnil(L);
  }
  else {
    RenWindow **window_renderer = (RenWindow**)lua_newuserdata(L, sizeof(RenWindow*));
    luaL_setmetatable(L, API_TYPE_RENWINDOW);

    *window_renderer = persistant_window;
  }

  return 1;
}

static const luaL_Reg renwindow_lib[] = {
  { "create",     f_renwin_create     },
  { "__gc",       f_renwin_gc         },
  { "get_size",   f_renwin_get_size   },
  { "_persist",   f_renwin_persist    },
  { "_restore",   f_renwin_restore    },
  {NULL, NULL}
};

int luaopen_renwindow(lua_State* L) {
  luaL_newmetatable(L, API_TYPE_RENWINDOW);
  luaL_setfuncs(L, renwindow_lib, 0);
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, "__index");
  return 1;
}
