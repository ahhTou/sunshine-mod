#!/bin/sh
# 采集选择回归与内置编码策略基准，不启动远控服务。
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/cmake-build-sunshine-mod/test-results"
mkdir -p "$OUT"
FF="${SUNSHINE_MOD_FFMPEG_DIR:-$ROOT/cmake-build-sunshine-mod/_deps/ffmpeg}"
if [ ! -d "$FF/include" ]; then
  FF="$(sed -n 's/^FFMPEG_PREPARED_BINARIES:[^=]*=//p' "$ROOT/cmake-build-sunshine-mod/CMakeCache.txt" | head -1)"
fi
clang++ -std=c++17 -I "$ROOT" "$ROOT/sunshine-mod/tests/capture_test.cpp" -o "$OUT/capture-test"
"$OUT/capture-test"
clang++ -std=c++17 -I "$FF/include" "$ROOT/sunshine-mod/tests/encode_bench.cpp" "$ROOT/src/platform/macos/vt_sync.mm" \
  "$FF/lib/libavcodec.a" "$FF/lib/libavutil.a" "$FF/lib/libswscale.a" "$FF/lib/libx264.a" "$FF/lib/libx265.a" "$FF/lib/libSvtAv1Enc.a" \
  -framework VideoToolbox -framework CoreMedia -framework CoreVideo -framework CoreFoundation -framework AudioToolbox -liconv -o "$OUT/encode-bench"
python3 - "$OUT" <<'BENCH'
import json,os,pathlib,subprocess,sys
out=pathlib.Path(sys.argv[1]);results=[]
for mode in ['off','on','off']:
    env=os.environ.copy();env['SUNSHINE_MOD_VT_SYNC']='0' if mode=='off' else '1'
    p=subprocess.run([str(out/'encode-bench'),'--hw'],env=env,capture_output=True,text=True,check=True,timeout=30)
    row=json.loads(p.stdout);row['mode']=mode
    assert row['packets']==180 and row['samples']==155, row
    results.append(row);print(mode,row,flush=True)
(out/'encode.json').write_text(json.dumps(results,indent=2)+'\n')
print('回归通过；基准结果因设备而异，不设跨设备延迟门槛。')
BENCH
