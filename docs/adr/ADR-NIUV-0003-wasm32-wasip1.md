# ADR-NIUV-0003: Nim のプログラムを wasm32-wasip1 に組む手順は niuv が 1 つだけ持つ

**Status**: accepted（2026-10-28、司会 (team-lead) の指示「niuv の wasm32-wasip1 の目標を 1 つの持ち主にする」。代表の記録は無い。下の「代表に確かめること」）
**Date**: 2026-10-28
**出どころ**: シェルを 社内の OS に WASM で載せる計画と W0 の測定。手順が 4 か所に写されていた: 社内の描画器 の `wasm/build.sh` と `start.c`（a95ca7d3）、社内のブラウザのシェル の `wasm/`（362b571f）、社内のデスクトップの手元のビルド、社内の skill の SDK の `scripts/build_nim_skill.sh`。
**仮説の層**: 実装。支配軸: 整合性（同じ問いに答える手順を 1 つにする）。想定する失敗: 名ばかりの完了（「compiler-rt を扱った」と書いて、足りない記号で黙って落ちる）、早合点（リンクが通ったことを、`__multi3` が正しく掛けることと等価視する）。

## 規則

- **NIV-34** `niuv wasm <program.nim>` は 1 つの Nim のプログラムを wasm32-wasip1 のコマンドのモジュール（`_start`）に組む。Nim の旗は ORC、`-d:release -d:useMalloc -d:noSignalHandler -d:nimNoGetRandom --exceptions:goto --threads:off --os:linux --cpu:wasm32 --noMain:on` で、呼び手の `--nim-flag` はその後ろに足す。C は clang の `--target=wasm32-wasip1 --sysroot=<wasi-sysroot> -O2`、既定で `-msimd128`（`--no-simd` で外す）。スタックは 8 MiB、線形メモリの上限は 4 GiB。宣言（`niuv.toml`）もロックも使わず、プログラムの `nim.cfg` / `config.nims` を nim がそのまま読む（テストの道の宣言をリポジトリが既に持っているため）。`int` は 32 ビットになる。
- **NIV-35** C の入口は niuv が持つ `start.c` 1 つ。`--noMain` で組み、`main(argc, argv)` が `cmdCount`・`cmdLine` に渡してから `NimMain` を呼び、`programResult` を終了コードとして返す。wasi-libc の `_start` は 2 引数の `main` を呼び、Nim の書く 3 引数の `main` では署名が合わずに trap するため。
- **NIV-36** 128 ビットの掛け算（`__multi3`、`std/times` が使う）は、clang の資源の置き場に wasm32 の compiler-rt があればそれを、無ければ niuv の `multi3.c`（`__multi3` だけ）をリンクし、その旨を注として出す。注は「`brew install wasi-runtimes` で compiler-rt が入る。入れるかは代表が決める」と言う。niuv の写しに無い compiler-rt の記号が要るプログラムは、リンクで断り、同じことを言う。niuv は何もインストールしない。
- **NIV-37** 出力先には `<名前>.wasm` と、`--aot` のとき `wasmtime compile` の `<名前>.cwasm` だけを置く。nim の作業場・C の目的ファイル・入口の C は、置き場の根（`--stage`、既定は一時ディレクトリの `niuv-stage`）の下の、出力先と名前ごとの場所に置き、組む前に空にする（前のプログラムの C を混ぜない）。
- **NIV-38** 道具が無ければ、名前と場所を示して断る: PATH に nim が無い、`--llvm` の下に clang が無い、`--sysroot` が wasi-sysroot でない（`lib/wasm32-wasip1` が無い）、`--aot` で PATH に wasmtime が無い。プログラムが無ければ使い方の誤り、nim・clang・リンクが落ちれば、その出力を付けて断る。
- **NIV-39** コマンドは `niuv wasm <program.nim> [--out DIR] [--name NAME] [--stage DIR] [--nim-flag F]... [--no-simd] [--aot] [--llvm DIR] [--sysroot DIR]`。標準出力に `wasm <場所>`（と `cwasm <場所>`）、注は標準エラーに出す。`--out` の既定はプログラムの隣の `build/wasm32-wasip1`。

実装は `src/niuv/wasm.nim`、`src/niuv/wasm/start.c`、`src/niuv/wasm/multi3.c`、`src/niuv/cli.nim`。E テストは `tests/unit/test_wasm.nim`（実物の nim・clang・wasi-sysroot・wasmtime で小さなプログラムを組んで走らせる。無ければ落ちる）。

## 確かめたこと（2026-10-28）

- Homebrew の llvm（clang 23.1.3）は wasm32 の compiler-rt を持たない（資源の置き場に `darwin` しか無い）。`std/times` を使うプログラムは `__multi3` が未定義でリンクできない。
- `multi3.c` を `-O1` 以上で組むと、clang が 64×64 の筆算を 128 ビットの掛け算と見抜いて `__multi3` の呼び出しに戻し、自分を呼び続けてスタックが尽きた。`optnone` で最適化を止めた。値は E テストで、3 組の積を Python の多倍長の値と比べて確かめる。
- 使い手のプログラムを `niuv wasm --aot` で組んで wasmtime で走らせ、すべて通った: 社内の描画器 の `tests/test_*.nim` 7 本、nim-opentype の `tests/external/test_*.nim` 8 本、nim-png の `tests/test_*.nim` 2 本、社内のブラウザのシェル の `wasm/shell_bench.nim`（倍率 1、1 巡）。

## 採らなかった案

- **`niuv build --target wasm32-wasip1` だけにする**: 宣言とロックが要り、テストのファイル 1 本を組みたい使い手（`testWasm` の task、ベンチ）に `niuv.toml` を書かせることになる。手順は `wasm.nim` に 1 つだけ置き、宣言の道（NIV-04 の `[wasm]` 節）から使うのは Future とする。
- **rustup の `compiler_builtins` の rlib をリンクする**（社内の描画器の `build.sh` が使っていた）: Rust の版の中身に頼り、Rust の無い機械では組めない。
- **Nim の `main` の名前を `-Dmain=…` で変えて呼ぶ**（社内の描画器の `build.sh`）: Nim の生成する C の名前を前処理器で書き換える。`--noMain` は Nim が用意する口で、`cmdCount`・`cmdLine` を入口が渡す形がはっきりする。
- **compiler-rt を入れる・取ってくる**: niuv は取得しない（ADR-NIUV-0001 の B7）。入れるかは代表が決める。

## 代表に確かめること

- この ADR は ADR-NIUV-0001 の NIV-04（「WASM のコンパイル手順は持たない」）と NIV-22（コマンドは 4 つだけ）、ADR-NIUV-0002 の NIV-24（クロスコンパイルをしない）を改める。司会の指示によるもので、代表の記録は無い（RC-7 a）。
- `brew install wasi-runtimes` を入れれば `multi3.c` は使われなくなる。入れるかどうか。

## Future

- Future: `niuv build` の宣言の道（`[wasm]` 節、NIV-04）から `wasm.nim` を使い、ロックに clang・wasi-sysroot・wasmtime を結ぶ。
- Future: 社内の skill の SDK の部品（`--app:lib` の静的ライブラリを Rust の殻に繋ぐ）は、コマンドのモジュールではないので NIV-34 の外。乗せるなら `--app:lib` の形を規則に足す。
