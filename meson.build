project('lite', 'c',
  version : '1.11',
  default_options : ['warning_level=2', 'c_std=gnu11', 'buildtype=debugoptimized'])

cc = meson.get_compiler('c')
m_dep = cc.find_library('m', required : false)

# SDL3 dependency
sdl_dep = dependency('sdl3', required : false)

if not sdl_dep.found()
  # Try to find a subproject or wrap
  sdl_dep = dependency('sdl3', fallback : ['sdl3', 'sdl3_dep'])
endif

lite_sources = [
  'src/api/api.c',
  'src/api/renderer.c',
  'src/api/renderer_font.c',
  'src/api/system.c',
  'src/lib/lua54/lapi.c',
  'src/lib/lua54/lauxlib.c',
  'src/lib/lua54/lbaselib.c',
  'src/lib/lua54/lcode.c',
  'src/lib/lua54/lcorolib.c',
  'src/lib/lua54/lctype.c',
  'src/lib/lua54/ldblib.c',
  'src/lib/lua54/ldebug.c',
  'src/lib/lua54/ldo.c',
  'src/lib/lua54/ldump.c',
  'src/lib/lua54/lfunc.c',
  'src/lib/lua54/lgc.c',
  'src/lib/lua54/linit.c',
  'src/lib/lua54/liolib.c',
  'src/lib/lua54/llex.c',
  'src/lib/lua54/lmathlib.c',
  'src/lib/lua54/lmem.c',
  'src/lib/lua54/loadlib.c',
  'src/lib/lua54/lobject.c',
  'src/lib/lua54/lopcodes.c',
  'src/lib/lua54/loslib.c',
  'src/lib/lua54/lparser.c',
  'src/lib/lua54/lstate.c',
  'src/lib/lua54/lstring.c',
  'src/lib/lua54/lstrlib.c',
  'src/lib/lua54/ltable.c',
  'src/lib/lua54/ltablib.c',
  'src/lib/lua54/ltm.c',
  'src/lib/lua54/lundump.c',
  'src/lib/lua54/lutf8lib.c',
  'src/lib/lua54/lvm.c',
  'src/lib/lua54/lzio.c',
  'src/lib/stb/stb_truetype.c',
  'src/main.c',
  'src/rencache.c',
  'src/renderer.c',
]

c_args = ['-fno-strict-aliasing']

if host_machine.system() == 'windows'
  c_args += '-DLUA_USE_POPEN'
  windows = import('windows')
  lite_sources += windows.compile_resources('res.rc')
else
  c_args += '-DLUA_USE_POSIX'
endif

inc = include_directories('src')

executable('lite',
  lite_sources,
  dependencies : [sdl_dep, m_dep],
  include_directories : inc,
  c_args : c_args,
  install : true
)
