# ADR-NIUV-0008: Nim のプログラムを WASI 0.3 の command の component に組む (wasm32-wasip3)

**Status**: accepted（2026-11-07、代表の決定「wasm-component-ld を入れて手順 2 を進めてください」。会社の計画 `04_engineering/plans/nim-shell-scripts-on-wasi.md` の手順 2）
**Date**: 2026-11-07
**Author**: jasagiri (drafted by Claude Opus 5.5)

## Context

- 計画は、Nim を 社内のカーネルのスクリプトの言語にする。スクリプトは WASI 0.3 の `wasi:cli/command` の component で、nim-wasm-runtime (nim-wasi) が走らせる。
- 手順 1 の調べ (`nim-upstream-kit/docs/knowhow/wasi.md`、2026-11-07): Nim の command を WASI 0.3 にする道は 3 つで、(a) wasip1 + nim-wasip1-adapter は組めない (adapter が `environ_get` などを持たない)、(b) wasip2 は nim-wasi が断る、(c) wasi-libc の `wasm32-wasip3` は組めて、wasmtime と nim-wasm-runtime で同じに動いた。
- (c) の core module は `env.__wasm_get_stack_pointer` などを import し、それを埋めて component にするのは `wasm-component-ld` である (`wasm-tools component new` は断る)。clang の driver は wasip2/wasip3 のリンクで `wasm-component-ld` を呼ぶ。
- ADR-NIUV-0003 で、Nim を wasm32 に組む手順の持ち主は niuv のただ 1 つと決めた。

## 判断の質 (DQ)

- **仮説層**: 実装。上の層 (Nim のスクリプトを使うか) は計画の手順 4 で確かめる。
- **支配軸**: 整合性。組む手順は `buildWasm` の 1 つのまま、対象だけを値で分ける。
- **想定する失敗のパターン**: 4.14 隣を見ない再実装 → wasip3 のために別の組み方や別のコマンドを作らない。Nim の旗 (NIV-34)、C の入口 (NIV-35)、128 ビットの掛け算 (NIV-36)、置き場 (NIV-37) をそのまま使う。

## 選択肢

| 案 | 良い点 | 悪い点 |
|---|---|---|
| **A. `--target wasm32-wasip1|wasm32-wasip3` を足す (既定は wasip1)** | 対象の名前は clang のものをそのまま使い、語が 1 つで済む。既存の呼び手は変わらない | 引数が 1 つ増える |
| B. `--wasip3` の旗を足す | 短い | 対象を名前で選ぶ形にならず、clang の語と別の語が増える |
| C. 既定を wasip3 にする | 新しい呼び手は何も書かずに済む | wasip1 の command を前提にした既存のテスト・ベンチ (wasmtime の preview1) を壊す |

A を採る。

## 規則

- **NIV-58** `niuv wasm <program.nim> --target wasm32-wasip3` は、1 つの Nim のプログラムを WASI 0.3 の `wasi:cli/command` の component に組む。Nim の旗は NIV-34 と同じで、C の入口は NIV-35 の `start.c`、clang は `--target=wasm32-wasip3`。出力の `<名前>.wasm` が component で、`wasi:cli/run@0.3.0` を export する。プログラムの結果 (`programResult`・`quit`) は終了コードになる: 0 でない結果は `start.c` が `exit()` で終え、wasi-libc が `exit-with-code` を呼ぶ (main から 0 でない値を返すと、`run` の err で終了コードが 1 になり、値が失われるため)。
- **NIV-59** wasip3 のリンクは `wasm-component-ld` を通す。道具を探すときに PATH から見つけ、無ければ名前と入れ方を示して断る。見つけたものを clang に `-fuse-ld=<場所>` で渡す (clang が自分で別のものを探さないように)。wasi-sysroot に `lib/wasm32-wasip3` が無ければ、その名を示して断る。wasip3 と component の形 (`--component`、NIV-40〜45) は組まない (使い方の誤り)。wasip3 の command は、それ自体がすでに component であるため。
- **NIV-60** 128 ビットの掛け算は NIV-36 と同じ。compiler-rt は clang の資源の置き場の wasip3 の置き方 (`lib/wasm32-unknown-wasip3/libclang_rt.builtins.a`、`lib/wasip3/libclang_rt.builtins-wasm32.a`) で探し、wasip1 のものは使わない。無ければ niuv の `multi3.c` をつなぎ、注を出す。
- **NIV-61** コマンドの行: `--target` は `wasm32-wasip1` (既定) か `wasm32-wasip3` を取り、ほかは使い方の誤り。`--out` の既定は、プログラムの隣の `build/<target>`。`--target wasm32-wasip3` と `--component` は組まない。標準出力は NIV-39 と同じく `wasm <場所>` (と `cwasm <場所>`)。
- **NIV-62** `--aot` は wasip3 でも `wasmtime compile` で `<名前>.cwasm` を作る。`wasmtime run --allow-precompiled -S p3 -W component-model-async=y` で走る。

実装は `src/niuv/wasm.nim` (`WasmTarget`、`targetCFlags`、`linkArgs`、`compilerRtCandidates`、`findWasmToolchain`、`buildWasm`)、`src/niuv/wasm/start.c`、`src/niuv/cli.nim`。E テストは `tests/unit/test_wasm.nim` の `NIV-58`〜`NIV-62` の suite (実物の nim・clang・wasi-sysroot・wasm-component-ld・wasmtime で組んで走らせる。無ければ落ちる)。

## 確かめたこと (2026-11-07)

- Nim 2.2.12、Homebrew の clang 23.1.5 と lld、wasi-libc 34、wasm-component-ld 0.5.31、wasm-tools 1.245.1、wasmtime 50.0.1。
- niuv のテスト 390 件が通った (wasm は 47 件。うち新しい 15 件)。コンパイラの警告は 0。
- `start.c` を変えても、wasip1 の command の終了コード (NIV-35 の E テスト) は変わらない。wasi-libc の wasip1 の `_start` は、main の戻り値で同じ `exit` を呼ぶため。

## 採らなかった案

- B と C (上の表)。
- **`wasm-tools component new` で core から component を作る**: p3 の core の `env.__wasm_*` の import を埋められず、断られる (手順 1)。
- **nim-wasip1-adapter の world を広げる** (計画の手順 2 のもう一方の道): wasi-libc が 0.3 を直接 import できるので、adapter を通す理由が無い。adapter は、自分の world を持つ reactor の component (NIV-44) のために残す。

## Consequences

- Nim のスクリプトを WASI 0.3 で走らせる道ができる (計画の手順 3 が使う)。
- 標準ライブラリの一部は wasip3 で誤って動くか、組めない (`walkDir` の `DT_*`、`sysrand` など。`nim-upstream-kit/docs/knowhow/wasi.md`)。niuv はそれを直さない (Nim 本体の問い。ISSUE-UPK-b80779e)。
- 手元に `wasm-component-ld` が要る (`cargo install wasm-component-ld --locked`)。niuv は入れない (ADR-NIUV-0001 の B7)。

## Future

- Future: `niuv build` の宣言 (`[[wasm.component]]`) から wasip3 の command を選べるようにする。使い手 (宣言で組みたいスクリプトのパッケージ) が出たとき。

## Related ADRs

- ADR-NIUV-0003: wasm32-wasip1 の command (NIV-34〜39)。NIV-35 の `start.c` を、この ADR で 0 でない結果を `exit()` で終える形に改めた。
- ADR-NIUV-0004: component の形 (NIV-40〜45)。wasip3 とは組まない。

## 訂正 (2026-11-07、NIV-63 を足した)

会社の計画の手順 4 で、Nim のスクリプトが自前の WIT の interface (`example:pipeline`) を import する。wasi-libc の wasip3 の core は WASI の型の情報を自分で持つが、自前の import の型は持たないので、`wasm-component-ld` に渡す。

- **NIV-63** `niuv wasm --target wasm32-wasip3 --component-type <WIT ファイル>` (何度でも) は、各ファイルを `-Wl,--component-type=<場所>` として `wasm-component-ld` に渡す。component はその interface を import する。wasip1 か component の形で使う、ファイルが無い、のどちらも使い方の誤りとして断る。E テストは `tests/unit/test_wasm.nim` の `NIV-63 more WIT for a wasip3 command`。

