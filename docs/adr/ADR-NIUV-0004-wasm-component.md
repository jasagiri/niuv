# ADR-NIUV-0004: WIT の world の component も `niuv wasm` が組む

**Status**: 決定の記録なし。ADR-NIUV-0003（代表が 2026-10-28 に承認: niuv は wasm32 の作り方のただ 1 つの持ち主）の範囲で、社内のデスクトップの頼み (W4) により実装した（2026-10-29）。この形を足すことの承認は司会が代表に確かめている
**Date**: 2026-10-29
**出どころ**: 社内のデスクトップの頼み（2026-10-29、W4: 社内のデスクトップの背を、`example:desktop/desktop@0.1.0` を含む world の component として host で試す）。native も同じものを要する（計画の W4「シェルを component にする」）。手順は 社内の OS の `tools/build-desktop-probe.sh` に手書きで在った。ADR-NIUV-0003 の Future（`--app:lib` の形）の一つ。
**仮説の層**: 実装。支配軸: 整合性（component の組み方を 2 か所目に写させない）。想定する失敗: 早合点（`component new` が通ったことを、core が world の外を import していないことと等価視する）。

## 規則

- **NIV-40** `niuv wasm <program.nim> --component <wit-dir> --world <pkg/world> --export NAME...` は、world の component を組む。Nim は `-d:release --mm:arc -d:useMalloc --threads:off --os:standalone --cpu:wasm32 --noMain:on --panics:on`（呼び手の `--nim-flag` はその後ろ）。C は NIV-34 と同じ clang の旗。リンクは `-nostdlib -Wl,--no-entry`、`--export` ごとに `-Wl,--export=NAME`、wasi-sysroot の `libc.a`（malloc と memcpy）と、NIV-36 の 128 ビットの掛け算。スタックと線形メモリの上限は NIV-34 と同じ。`cabi_realloc` は、world が文字列や list を渡すときに呼び手が `--export` に挙げる（定義はゲストの束縛が持つ）。
- **NIV-41** 出力先には `<名前>.core.wasm`（`_start` も WASI の import も無い core の module）と `<名前>.component.wasm`（`wasm-tools component embed <wit-dir> --world W` の後に `component new`）を置く。中間の embed の結果は置き場の根に置く。
- **NIV-42** 断るもの: プログラムの隣に `panicoverride.nim` が無い（`--os:standalone` で Nim がプログラムのディレクトリから取り込む。niuv からは渡せない。nim を走らせる前に断り、panic は止めずに trap させよと言う）、world か export が無い、world の外（WASI など）を import する core（`wasm-tools component new` の断りをそのまま渡す）、定義されていない export（リンクの断り）、PATH に `wasm-tools` が無い（NIV-38 と同じく名前を示す）。
- **NIV-43** コマンドの行: `--component` は `--world` と 1 つ以上の `--export` を要し、`--aot` とは組まない（component の実行系は wasmtime の AOT ではない）。`--world`・`--export` は `--component` の無いときに断る。標準出力に `core <場所>` と `component <場所>`。

実装は `src/niuv/wasm.nim`（`wsComponent`、`ComponentNimFlags`、`componentLinkArgs`）と `cli.nim`。E テストは `tests/unit/test_wasm.nim` の NIV-40〜43（実物の clang・wasi-sysroot・wasm-tools・wasmtime。component は `wasmtime run --invoke` で走らせる）。

## 確かめたこと（2026-10-29）

- 小さなゲスト（seq を使う）の component が wasmtime で `21` を返し、core に import が 1 つも無い。
- 社内の OS の `tests/fixtures/desktop_probe.nim` を、社内の OS の script と同じ world（`example:probe/probe`、`run` と `cabi_realloc`）で `niuv wasm --component` に組み、`wasm-tools validate --features all` が通り、core の import は `example:desktop/*` だけだった。

## 採らなかった案

- **Nim を `--os:linux` のまま component にする**: wasi-libc の入口と WASI の import が入り、world の外を求める。社内の OS の world は WASI を持たない。
- **niuv が既定の `panicoverride.nim` を渡す**: Nim は `--os:standalone` の panicoverride をプログラムのディレクトリからだけ取り込む（`--path` では見つからない。2026-10-29 に試した）。プログラムの側に置くしかない。
- **ORC にそろえる**: standalone での ORC は試していない。社内の OS の probe で動いた ARC を採り、変えるなら測ってから。
- **`cabi_realloc` を常に export する**: 定義しないゲスト（list も文字列も渡さない world）でリンクが落ちる。呼び手が挙げる。

## Future

- Future: SIMD の既定は command と同じ（`-msimd128`、`--no-simd` で外す）。component の実行系（nim-wasm-component・社内のカーネル）が v128 を持たないと分かれば、component の既定を変える。
