#!/bin/sh
# 采集选择回归与内置编码策略基准，不启动远控服务。
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${SUNSHINE_MOD_BUILD_DIR:-$ROOT/cmake-build-sunshine-mod}"
OUT="$BUILD_DIR/test-results"
mkdir -p "$OUT"
FF="${SUNSHINE_MOD_FFMPEG_DIR:-$BUILD_DIR/_deps/ffmpeg}"
if [ ! -d "$FF/include" ]; then
  FF="$(sed -n 's/^FFMPEG_PREPARED_BINARIES:[^=]*=//p' "$BUILD_DIR/CMakeCache.txt" | head -1)"
fi
if [ ! -d "$FF/include" ]; then
  CODEC="$(sed -n 's/^pkgcfg_lib_SUNSHINE_BUNDLED_FFMPEG_avcodec:[^=]*=//p' "$BUILD_DIR/CMakeCache.txt" | head -1)"
  FF="$(dirname "$(dirname "$CODEC")")"
fi
clang++ -std=c++17 -I "$ROOT" "$ROOT/sunshine-mod/tests/capture_test.cpp" -o "$OUT/capture-test"
"$OUT/capture-test"
# 从同一套 FFmpeg 的 pkg-config 获取依赖，避免升级后漏链 dav1d 等静态库。
python3 - "$ROOT" "$OUT" "$FF" <<'COMPILE'
import os,pathlib,shlex,subprocess,sys
root,out,ff=map(pathlib.Path,sys.argv[1:])
assert (ff/'include/libavcodec/avcodec.h').is_file(), f'找不到构建使用的 FFmpeg：{ff}'
env=os.environ.copy();env['PKG_CONFIG_LIBDIR']=str(ff/'lib/pkgconfig');env.pop('PKG_CONFIG_PATH',None)
flags=shlex.split(subprocess.check_output(['pkg-config','--libs','--static','libavcodec','libavutil','libswscale'],env=env,text=True))
subprocess.run(['clang++','-std=c++17','-I',str(ff/'include'),str(root/'sunshine-mod/tests/encode_bench.cpp'),str(root/'src/platform/macos/vt_sync.mm'),*flags,'-liconv','-o',str(out/'encode-bench')],check=True)
COMPILE
python3 - "$OUT" <<'BENCH'
import json,os,pathlib,subprocess,sys
out=pathlib.Path(sys.argv[1]);results=[]
for mode in ['off','on','off']:
    env=os.environ.copy();env['SUNSHINE_MOD_VT_SYNC']='0' if mode=='off' else '1'
    p=subprocess.run([str(out/'encode-bench'),'--hw'],env=env,capture_output=True,text=True,check=True,timeout=30)
    row=json.loads(p.stdout);row['mode']=mode
    assert row['packets']==180 and row['samples']==155 and row['keyframes']==1, row
    results.append(row);print(mode,row,flush=True)
(out/'encode.json').write_text(json.dumps(results,indent=2)+'\n')
print('回归通过；基准结果因设备而异，不设跨设备延迟门槛。')
BENCH
