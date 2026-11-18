# ADR-NIUV-0004: WIT の world の component も `niuv wasm` が組む

**Status**: accepted（2026-10-29、代表 (jasagiri) の決定「ADRは承認します」。ADR-NIUV-0003 の範囲で、社内のデスクトップの頼み (W4) により実装した）
**Date**: 2026-10-29
**出どころ**: 社内のデスクトップの頼み（2026-10-29、W4: 社内のデスクトップの背を、`example:desktop/desktop@0.1.0` を含む world の component として host で試す）。native も同じものを要する（計画の W4「シェルを component にする」）。手順は 社内の OS の `tools/build-desktop-probe.sh` に手書きで在った。ADR-NIUV-0003 の Future（`--app:lib` の形）の一つ。
**仮説の層**: 実装。支配軸: 整合性（component の組み方を 2 か所目に写させない）。想定する失敗: 早合点（`component new` が通ったことを、core が world の外を import していないことと等価視する）。

## 規則

- **NIV-40** `niuv wasm <program.nim> --component <wit-dir> --world <pkg/world> --export NAME...` は、world の component を組む。Nim は `-d:release --mm:arc -d:useMalloc --threads:off --os:standalone --cpu:wasm32 --noMain:on --panics:on`（呼び手の `--nim-flag` はその後ろ）。C は NIV-34 と同じ clang の旗。リンクは `-nostdlib -Wl,--no-entry`、`--export` ごとに `-Wl,--export=NAME`、wasi-sysroot の `libc.a`（malloc と memcpy）と、NIV-36 の 128 ビットの掛け算。スタックと線形メモリの上限は NIV-34 と同じ。`cabi_realloc` は、world が文字列や list を渡すときに呼び手が `--export` に挙げる（定義はゲストの束縛が持つ）。
- **NIV-41** 出力先には `<名前>.core.wasm`（`_start` も WASI の import も無い core の module）と `<名前>.component.wasm`（`wasm-tools component embed <wit-dir> --world W` の後に `component new`）を置く。中間の embed の結果は置き場の根に置く。
- **NIV-42** 断るもの: プログラムの隣に `panicoverride.nim` が無い（`--os:standalone` で Nim がプログラムのディレクトリから取り込む。niuv からは渡せない。nim を走らせる前に断り、panic は止めずに trap させよと言う）、world か export が無い、world の外（WASI など）を import する core（`wasm-tools component new` の断りをそのまま渡す）、定義されていない export（リンクの断り）、PATH に `wasm-tools` が無い（NIV-38 と同じく名前を示す）。
- **NIV-43** コマンドの行: `--component` は `--world` と 1 つ以上の `--export` を要し、`--aot` とは組まない（component の実行系は wasmtime の AOT ではない）。`--world`・`--export` は `--component` の無いときに断る。標準出力に `core <場所>` と `component <場所>`。

WASI 0.3 を import する world（2026-10-29 に足した。司会の決定、W4 の案 A）

- **NIV-44** `--component` に `--wasi` を付けると、core は WASI の reactor になる。Nim は NIV-34 と同じ旗（wasip1。Nim の std の OS: ファイル・時計が使える）、C の入口は `reactor.c`（constructor で `NimMain` を呼ぶ。wasi-libc の `_initialize` が走らせる）、リンクは `-mexec-model=reactor`（`_start` が無い）。`component new` に `--adapt <adapter>` を渡し、preview1 の import を WASI 0.3 に写す。adapter は nim-wasip1-adapter の reactor の adapter（ファイルの名前が import の module の名前）。`--export` は無くてよい: `wasi:cli/run@0.3.0#run` のような world の名前の export は、ゲストが C の `export_name` で付ける（C の名前に書けないため）。`panicoverride.nim` は要らない（standalone ではない）。NIV-42 の「world の外の import を断る」は効かない（訂正 2026-10-29）。
- **NIV-45** adapter の場所の既定は、niuv の隣（foundation/）の `nim-wasip1-adapter/build/reactor/wasi_snapshot_preview1.wasm`（`scripts/build-adapter.sh` が作る。build/ は版に入らない）。`--adapter FILE` で変えられ、`--wasi` の無い `--adapter`、`--component` の無い `--wasi` は使い方の誤りとして断る。adapter のファイルが無ければ、それを作る script の名前を示して断る。

stack の大きさ（2026-11-05 に足した。nim-actor-guest の報告: 8 MiB の固定で、アクターの VM の既定の上限 1 MiB ではどのアクターも起こせなかった）

- **NIV-48** `niuv wasm` は `--stack-size BYTES` で stack の大きさを選べる（command・component・reactor のどれにも効く。`WasmRequest.stackSize`、0 なら既定の 8 MiB の `StackSize`）。受けるのは 64 KiB から 64 MiB の、16 の倍数（wasm32 の stack の揃え）だけで、ほかは使い方の誤りとして断る。stack は線形メモリの初めに置かれるので、小さくすると、プロセスごとに要る線形メモリがその分だけ小さくなる。

実装は `src/niuv/wasm.nim`（`wsComponent`、`ComponentNimFlags`、`componentLinkArgs`、`reactorLinkArgs`、`DefaultAdapter`）、`src/niuv/wasm/reactor.c` と `cli.nim`。E テストは `tests/unit/test_wasm.nim` の NIV-40〜43（実物の clang・wasi-sysroot・wasm-tools・wasmtime。component は `wasmtime run --invoke` で走らせる）。

## 確かめたこと（2026-10-29）

- 小さなゲスト（seq を使う）の component が wasmtime で `21` を返し、core に import が 1 つも無い。
- （NIV-44、2026-10-29）wasi:cli/run を export し、preopen のファイルと単調な時計を読むゲストを `--wasi` で組んだ。`wasm-tools component wit` は `export wasi:cli/run@0.3.0` と filesystem・clocks の import だけを示し、core に `_start` は無い。nim-wasm-runtime の `wasm_runtime run`（nim-wasm-component + nim-wasi）で、ファイルを見せると ok（終了 0）、見せないと err（終了 1）。wasmtime 48 の `-S p3 -W component-model-async=y` でも ok。adapter は stdout を持たない（ADR-WP1-0001 の WP1-10）ので、ゲストは結果を run の値で返す。
- 社内の OS の `tests/fixtures/desktop_probe.nim` を、社内の OS の script と同じ world（`example:probe/probe`、`run` と `cabi_realloc`）で `niuv wasm --component` に組み、`wasm-tools validate --features all` が通り、core の import は `example:desktop/*` だけだった。

## 採らなかった案

- **Nim を `--os:linux` のまま component にする**: wasi-libc の入口と WASI の import が入り、world の外を求める。社内の OS の world は WASI を持たない。
- **niuv が既定の `panicoverride.nim` を渡す**: Nim は `--os:standalone` の panicoverride をプログラムのディレクトリからだけ取り込む（`--path` では見つからない。2026-10-29 に試した）。プログラムの側に置くしかない。
- **ORC にそろえる**: standalone での ORC は試していない。社内の OS の probe で動いた ARC を採り、変えるなら測ってから。
- **`cabi_realloc` を常に export する**: 定義しないゲスト（list も文字列も渡さない world）でリンクが落ちる。呼び手が挙げる。

## Future

- Future: SIMD の既定は command と同じ（`-msimd128`、`--no-simd` で外す）。component の実行系（nim-wasm-component・社内のカーネル）が v128 を持たないと分かれば、component の既定を変える。

## 訂正 (2026-10-29)

- 「採らなかった案」の「Nim を `--os:linux` のまま component にする」が退けたのは、example:desktop だけの world に WASI を持ち込むことである。WASI 0.3 を import する world には、wasip1 で組み、preview1 → WASI 0.3 の adapter を付けた形を使う（司会の決定、W4 の案 A）。その形の規則は NIV-44 以降に足す。
- NIV-42 の「world の外（WASI など）を import する core を断る」は、freestanding の形（`--adapter` の無い `--component`）だけに効く。adapter を付けた形の core は wasi_snapshot_preview1 を import し、adapter がそれを WASI 0.3 に写す。

## 訂正 (2026-11-06)

- 手順を呼ぶのは `niuv wasm` だけではなくなった。`niuv build` が、`niuv.toml` の `[[wasm.component]]` を同じ `buildWasm` で組む（ADR-NIUV-0007、NIV-49〜57）。NIV-40〜43、48 の規則は変えない。

## 訂正 (2026-11-18) — Nim 2.2.12 からの system モジュールの stdio と exit

- 事実: Nim 2.2.12 から、`-d:useMalloc` と `--os:standalone` の system モジュールは、割り当ての失敗 (`raiseOutOfMem`) と長さの溢れ (`nimSizeOverflow`、2.4 から) で、stderr へ `fwrite`・`fflush` で 1 行書いて `exit` を呼ぶ。2.2.8 は zephyr のときしか呼ばない。これが wasi-libc の stdio と exit を core に引き入れ、wasi_snapshot_preview1 の `clock_time_get`・`fd_write`・`fd_seek`・`fd_close`・`proc_exit` の import が生じて NIV-41 が破れていた [見た: 2026-11-18、Nim 2.4.2 で `tests/unit/test_wasm.nim` の NIV-41 と NIV-43 が落ち、foundation/nim-actor-guest の `build-actor.sh` で services/engi-ichinyo の actor が `component new` に断られた。2.2.8 を PATH の先に置くと通った]。
- NIV-41 を守る手順を足す: freestanding の形 (`--adapter` の無い `--component`) では、niuv は Nim の system モジュールの C (`@psystem.nim.c`) だけを、niuv の `src/niuv/wasm/freestanding.h` を `-include` して翻訳する。この header は、その翻訳単位の中の `fwrite`・`fflush`・`exit` を trap に、`stderr` を空のポインタに置き換える。freestanding の core には書く先も終わる過程も無く、panic は trap する (NIV-42) ので、2 つの致命の道も trap にそろえる。Nim が `@psystem.nim.c` を作らなければ、黙って進めずに断る。
- 置き換えは system モジュールに限る。ゲストが自分で stdio を呼べば、今までどおり `wasm-tools component new` が断る (NIV-42)。リンク全体に `fwrite` などを定義する案は、この断りを黙った trap に変えるので採らなかった。
- 確かめ: `tests/unit/test_wasm.nim` の NIV-41 (system モジュールの引数、長さが溢れるゲストの core に import が無く呼ぶと trap する) と NIV-42 (stderr に自分で書くゲストは断られる)。
- Future: Nim の standalone の `raiseOutOfMem` と `nimSizeOverflow` が panicoverride の panic を通るようになったら、header を外す。
