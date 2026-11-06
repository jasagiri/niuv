# ADR-NIUV-0007: `niuv build` は宣言された WASM の component を組む

**Status**: proposed（2026-11-06。代表の承認待ち）
**Date**: 2026-11-06
**出どころ**: fukai/delivery の頼み（2026-11-06）。fukai の決定 147 で BEAM を `foundation/actor-state-machine` に置き換え、WASM のアクターを `foundation/nim-actor-guest` で書く。島のあいだで配るビルドの目録（`niuv.manifest.cbor`）に、そのアクターの component を載せたい。今は `[wasm]` を宣言しても「宣言のみ、ビルドしない」と報告するだけで、種類 `akWasm` を作る道が無い。
**仮説の層**: 実装（ドメイン仮説に近い: 「アクターは目録に載り、封じられ、配られ、差し替えられる」）。支配軸: 整合性（component の組み方を `wasm.nim` の 1 か所に保ち、プロジェクトのビルドに 2 か所目を作らない）。想定する失敗: 早合点（`component new` が通ったことを、目録の SHA-256 が配る物と一致することと等価視する。確かめるのは目録の値と置いたファイルのハッシュ）。

## 文脈

component を組む手順は `niuv wasm --component`（ADR-NIUV-0004、NIV-40〜43、48）に在り、nim-actor-guest の `tools/build-actor.sh` が引数を並べて呼ぶ。プロジェクトのビルド（`niuv build`、`niuv.toml`）はそれを呼ばない。呼び手が引数を持つので、どの component が package の成果物なのかが宣言に無く、ロックも目録も component を知らない。

## 決めたこと

`[wasm]` 節を、component の宣言の配列 `[[wasm.component]]` に置き換える。旧い `[wasm] entry = "x.wat"` は一度も組まれない仮置きだった。後方互換は持たない（版の持ち方は jj。NIV-04 の旧い形は読まず、断る）。組む手順は `src/niuv/wasm.nim` の `buildWasm` をそのまま呼び（写さない）、`src/niuv/wasmbuild.nim` は宣言を `WasmRequest` に写して出力を置くだけにする。

```toml
[[wasm.component]]
name = "counter"                       # 目録の名前。nim bin の名前と重ならない
entry = "actors/counter/main.nim"      # Nim のプログラム（隣に panicoverride.nim）
wit = "../nim-actor-guest/wit"         # WIT のディレクトリ
world = "asm:actor/actor"
export = ["cabi_realloc"]              # core の export（C の名前）。1 つ以上
stack_size = 1048576                   # 省略可。NIV-48 の範囲
paths = ["../nim-actor-guest/src"]     # 省略可。--path に足す
flags = []                             # 省略可。Nim の旗（--nim-flag と同じ）
no_simd = true                         # 省略可。既定は niuv wasm と同じ（SIMD あり）
sealed = false                         # 省略可。NIV-20 の門
```

## 規則

- **NIV-49** `[wasm]` は `[[wasm.component]]` を 1 つ以上持つ（持たない `[wasm]` と旧い `entry` は断る）。component の鍵は `name`・`entry`・`wit`・`world`・`export`（必須。`export` は 1 つ以上）と `stack_size`・`paths`・`flags`・`no_simd`・`sealed`（省略可）。知らない鍵は断る。`name` は文字・数字・`-`・`_` で、同じ package の component と nim bin のあいだで重ならない（目録は名前で引かれる）。`stack_size` は NIV-48 の範囲（64 KiB から 64 MiB の 16 の倍数）だけを受ける。
- **NIV-50** `entry`・`wit`・`paths` は package の根からの相対で、絶対パスは断る。解いた先は作業場（`niuv.workspace.toml` のあるディレクトリ）の中でなければならず、外へ出れば作業場の読み込みで断る（同じ作業場の兄弟 package の `src` は指せる。nim-actor-guest がそうである）。`entry` のファイル、`wit` と `paths` のディレクトリが無ければ、作業場の読み込みで断る。一語ごとの字面の検査（`..` の畳み込み）で、シンボリックリンクは解かない（Future）。
- **NIV-51** `niuv build` は宣言された component を `buildWasm` で組み、`<出力先>/wasm/<name>.component.wasm` に **component だけ**を置く。core module（`<name>.core.wasm`）と中間の embed の結果は置き場（`--stage` の下、`stageFor` の `out/` とその外）に残し、出力先にも目録にも載せない。目録には種類 `wasm`・名前・SHA-256・大きさを、ほかの種類と同じに載せる（場所は載せない: NIV-18）。同じ入力から同じバイト列になる。失敗は component の名前を付けて返し、目録は書かない。
- **NIV-52** component を組むときは、ビルドの前（どの compiler も走る前）に、clang（`--llvm DIR`、既定は `niuv wasm` と同じ）、wasi-sysroot（`--sysroot DIR`）、PATH の `wasm-tools` を `findWasmToolchain` で確かめ、無いものは名前を示して断る。component を組まない package は、これらを要さない。nim は、bin と同じく、ロックに固定された nim を使う（PATH の nim ではない）。clang・sysroot・wasm-tools はロックに固定しない（`niuv wasm` も固定しない。Future）。
- **NIV-53** `--bin NAME` は nim bin だけでなく component の名前も選ぶ。どちらの名前でもなければ使い方の誤りとして断る。選ばれなかった component は組まず、目録にも載せない。
- **NIV-54** `sealed = true` の component を組むときは、nim bin の `sealed` と同じ門（NIV-20）を、閉包の Nim の package の license に通す。
- **NIV-55** `--in-builder`（Linux のビルド用の像）は component を組まない。選ばれた中に component があれば（`--bin` が nim bin だけを選ぶときを除く）、ゲストを起こす前に断る。ゲストが返した目録に `wasm` があれば、検証で断る。
- **NIV-56** 閉包の Nim の package と外の依存の `src` は、bin と同じ `--path` で component の Nim に渡す（`closurePaths`）。続けて component の `paths`、`flags`。
- **NIV-57** ロックの package のハッシュ（NIV-12）は、component の `entry` のあるディレクトリの木（`panicoverride.nim` もそこにある。根にあるときは `entry` と根の `panicoverride.nim` だけ）、`wit` の木、`paths` の木を含む。どれかが変われば、ロックは古い。

実装は `src/niuv/decl.nim`（`WasmComponent`、`readWasm`）、`workspace.nim`（`checkMember`）、`lock.nim`（`packageHash`）、`wasmbuild.nim`、`build.nim`、`cli.nim`、`inbuilder.nim`。E テストは `tests/unit/test_decl.nim`（NIV-49、50）、`test_workspace.nim`（NIV-50）、`test_wasmbuild.nim`（NIV-51〜54、56、57。実物の nim・clang・wasi-sysroot・wasm-tools・wasmtime で component を走らせる）、`test_cli.nim`（NIV-51。Nim・Gleam・WASM を同居させる）、`test_inbuilder.nim`（NIV-55）。

## 採らなかった案

- **`[wasm] entry` の形のまま、鍵を足す**: 1 つの package が複数の component を持てず、world・export・WIT が `entry` に付かない。旧い形は一度も組まれず、使う人がいないので、置き換えて互換を持たない。
- **core module も目録に載せる**: 配る物は component だけで、core は component の中に入っている。出力先に core を置くと、delivery がどちらを封じるかを決めねばならず、2 つの物が同じ SHA-256 の問いに答える。
- **`niuv build` が `build-actor.sh` を呼ぶ**: 手順が 2 か所になる。`buildWasm` が唯一の手順（NIV-40）で、スクリプトは引数を並べるだけの薄い呼び手に戻せる。
- **clang・wasm-tools をロックに固定する**: `niuv wasm` が固定しない物を、ここだけ固定すると基準が 2 つになる。固定するなら `niuv wasm` と一緒に改める（Future）。
- **component の `--wasi`（reactor と adapter）を宣言に入れる**: 頼みは actor の world（WASI を import しない）だけ。NIV-44 の形を宣言で選べるようにするのは、使う人が出てから（Future）。

## Future

- Future: `--wasi` の reactor の component（NIV-44、45）を宣言で選べるようにする。
- Future: clang・wasm-tools・wasi-sysroot の版をロックに固定する（`niuv wasm` と一緒に）。
- Future: Linux のビルド用の像の中で component を組む（NIV-55 の限界）。
- Future: `paths` の解釈でシンボリックリンクを解く（NIV-50）。
