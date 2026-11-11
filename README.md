# niuv

Nim・Gleam（・WASM）の多言語ビルドの道具。パッケージごとの宣言（`niuv.toml`）と作業場（`niuv.workspace.toml`）から、依存の閉包を解決し、ロック（`niuv.lock`）に固定し、`nim` と `gleam` を呼んでビルドし、成果物の目録（決定的 CBOR）と SBOM を出す。`sealed` 印の成果物に GPL-3.0・LGPL-3.0・AGPL-3.0 が入るときは断る。

規則は [ADR-NIUV-0001](docs/adr/ADR-NIUV-0001.md)（NIV-01〜23、Status: proposed）、規則とテストの対応は [docs/quality/spec-coverage.md](docs/quality/spec-coverage.md)。設計の出どころは `fukai/docs/build-and-delivery.md`。Linux の目標とビルド用の像の案は [ADR-NIUV-0002](docs/adr/ADR-NIUV-0002-linux-target-and-builder-image.md)（NIV-24〜32、Status: proposed。未実装）。

## 位置付け

niuv は **ビルド** だけを受け持つ。**配る**（公開、鍵の付与、取り寄せ、実体化、入れ替え）は `fukai/delivery` が受け持つ。2 つに分けたのは `build-and-delivery.md` の問い 1 の決定（案 C）による。

```
  foundation/niuv（Nim。腐海を知らない）
    niuv.toml ─► 解決 ─► niuv.lock ─► nim / gleam ─► 成果物 ＋ 目録(未署名) ＋ SBOM
                                                           │
  ─────────────────────────────────────────────────────────┼──── ここから腐海
                                                           ▼
  fukai/delivery（Gleam のエージェント＋Nim の子）
    公開: 目録から頭を作り keeper の鍵の子で署名、成果物を release の期の鍵で封じる
    付与: 島の表で読み手の機械にだけ期の鍵を包む
    取り込み: 署名を確かめ、差分の断片を取り寄せ、平文の SHA-256 を照らして置く
    入れ替えの司令役: BEAM は動いたまま入れ替え（gl-upgrade-coordinator）、Nim の子は起こし直す
```

| | niuv | fukai/delivery |
|---|---|---|
| 置き場 | `foundation/`（腐海の外） | `fukai/` |
| 判断 | 持たない（宣言どおりにビルドするだけ） | 持つ（何を公開し、だれに渡し、どの版へ移るか。列に書いてから行う） |
| 鍵・署名・封じる・網 | 持たない | 持つ（`fukai/store`、`fukai/keeper`、`fukai/islands` を使う） |
| 腐海が止まっていても | 1 台で、網なしで動く | 動かない |

ビルドを fukai に置かない理由（`build-and-delivery.md` 3.1）:

1. ビルドする物の大半は foundation のパッケージで、ビルドの道具は fukai の外を読む
2. 島のノード自身をビルドするのに、島のノードが動いていることを前提にできない（鶏と卵）
3. 汎用の部品を fukai に置かない（Ecosystem Boundaries）

## 使い手との約束

配る側が頼っている形。変えるときは使い手（いまは `fukai/delivery`）と一緒に変える。

| 約束 | 規則 | 使い手 |
|---|---|---|
| 目録 `niuv.manifest.cbor`: 成果物ごとに名前・種類（`beam` / `nim-child` / `wasm`。`wasm` は NIV-51 の component）・SHA-256・大きさ。場所は載せない。署名しない。形式の版 2（NIV-29）は目標（`aarch64-linux-musl` など）と、beam を作った OTP の版（beam が無ければ空）も載せる。版 1 も読む（目標・OTP は不明） | NIV-18、NIV-29 | delivery は Nim から `niuv/manifest` を読み、目録から署名する頭を作る（目録そのものは署名しない。平文の SHA-256 を頭に出さないため）。版 1 と版 2 のどちらの目録も封じられる |
| 置き場: Nim の実行ファイルは `<out>/<bin 名>`、WASM の component は `<out>/wasm/<名前>.component.wasm`（NIV-51）、Gleam の `.beam` は `<out>/beam/<アプリ>/<モジュール>.beam` | NIV-15、NIV-23 | delivery は目録の名前と SHA-256 で成果物を探して照らす |
| 決まったバイト列: 同じ入力からは、置いた場所によらず同じ `.beam` | NIV-17 | 版の差分（変わったモジュールだけを取る）が成り立つ前提 |
| 腐海の Nim の子としての入口: `niuv child` は nim-frames の枠で 1 つのビルドの頼みを受け、目録のバイト列を返す | NIV-21 | delivery の公開のエージェントが `niuv child` を子として起こし、ビルドを頼む（ロックは人か試験が `niuv lock` で作る） |

## 使い方

```sh
niuv lock [--workspace FILE]                 # ツール・パッケージ・外の依存を中身のハッシュで固定する（niuv.lock）
niuv check <package>                         # 閉包を依存が先の順に並べる
niuv build <package> [--out DIR] [--bin NAME]... [--stage DIR]
niuv child                                   # nim-frames の枠で 1 つのビルドの頼みを受ける（腐海の子）
niuv --version [--check]                     # 版と、組んだソースの指紋（--check: 終了の値 0 一致・3 古い・4 ソースが無い）。ソースが後で変わっていれば、ほかのコマンドは作り直しを求めて断る（ADR-NIUV-0005）
niuv wasm <program.nim> [--out DIR] [--aot] [--nim-flag F]... [--no-simd]   # 1 つの Nim のプログラムを wasm32-wasip1 に組む（宣言・ロックなし）
niuv wasm <program.nim> --target wasm32-wasip3 [--out DIR] [--aot] [--component-type WIT]...   # WASI 0.3 の command の component に組む（ADR-NIUV-0008。wasm-component-ld が要る。--component-type で自前の import の WIT を足す）
niuv wasm <program.nim> --component WIT-DIR --world PKG/WORLD --export NAME... [--out DIR]   # WIT の world の component に組む（ADR-NIUV-0004）
niuv wasm <program.nim> --component WIT-DIR --world PKG/WORLD --wasi [--adapter FILE]       # WASI 0.3 を import する world: wasip1 の reactor に adapter を付ける

# Linux の目標（ADR-NIUV-0002）: ホストの macOS から、署名したビルド用の像の中で（kite のゲスト、網なし）
niuv lock  --target aarch64-linux-musl --in-builder --builder NAME@sha256:<digest> [--repin-builder] [ゲストの旗]  # ロックが別の像を pin していれば、--repin-builder が要る
niuv build <package> --target aarch64-linux-musl --in-builder --out DIR [--signature FILE] [--hex-cache DIR] [ゲストの旗]
```

`niuv build` は `niuv.toml` の `[[wasm.component]]`（`name`・`entry`・`wit`・`world`・`export`、省略可に `stack_size`・`paths`・`flags`・`no_simd`・`sealed`）を、下の `niuv wasm --component` と同じ手順で組み、`<out>/wasm/<name>.component.wasm` だけを出力先に置いて、目録に `wasm` の成果物として載せる（[ADR-NIUV-0007](docs/adr/ADR-NIUV-0007-wasm-components-in-the-build.md)、NIV-49〜57。`--bin` で名前を選べる。clang・wasi-sysroot・wasm-tools が要り、Linux のビルド用の像の中では組まない）。

`niuv wasm` は Nim のプログラムを wasm32-wasip1 のコマンドのモジュールに組む、ただ 1 つの手順（[ADR-NIUV-0003](docs/adr/ADR-NIUV-0003-wasm32-wasip1.md)、NIV-34〜39）。テストの task やベンチはこれを呼び、自前の `build.sh` を持たない。 `--target wasm32-wasip3` では、wasi-libc の wasip3 と `wasm-component-ld` で WASI 0.3 の `wasi:cli/command` の component を組む（[ADR-NIUV-0008](docs/adr/ADR-NIUV-0008-wasm32-wasip3-command.md)、NIV-58〜62。nim-wasm-runtime と wasmtime の `-S p3` で走る）。Homebrew の llvm には wasm32 の compiler-rt が無いので、`__multi3` は niuv の写しをリンクし、その旨を注に出す（`brew install wasi-runtimes` を入れるかは代表が決める）。

`build` はロックが無い・古い、ツールの版か実行ファイルがロックと違う、閉包に同じ外の依存が 2 つの版で来る、のどれかで断る。出力先には成果物と `niuv.manifest.cbor`、`niuv.sbom.cdx.json` だけが置かれ、コンパイラの作業場（nimcache）と Gleam の写しは置き場の根（`--stage`、既定は一時ディレクトリの `niuv-stage`）の下に置かれる。

`--target T` を付けると、ロックは `niuv.<T>.lock` になる（付けなければ `niuv.lock`）。niuv は自分が走っている機械の目標（`aarch64-macos-none` か `aarch64-linux-musl`）だけを作り、別の目標は `--in-builder`（kite のゲストの中で niuv を走らせる）で作る。`--in-builder` は `niuv.<T>.lock` の `[builder] image = "NAME@sha256:…"` の像だけを起こし、終わったあとにホストが目録を読み直して、全成果物の SHA-256 と大きさを自分で取り直す（ゲストの出力は信じない。目録に無いファイルがあれば断る）。ホストの `niuv.lock` には `[tools.kite]` の版（`kite --version`、kite 0.2.0 以降）と実行ファイルの SHA-256 が要る。実物の kite と像での受け入れは `tests/acceptance/test_builder_guest.nim`（手で流す）で、Nim の bin と Gleam のアプリのビルドが通った（ADR-NIUV-0002 の「K4-2 の結果」）。

宣言と作業場の書き方は ADR の NIV-01〜NIV-07、例は `tests/unit/` の各ファイルの先頭にある。宣言を持たない既存のパッケージは、作業場の側の宣言から `[package] root` で指す（NIV-06）。

## いまの使われ方（2026-10-16）

- fukai の各リポジトリは、まだ `scripts/build.sh` と手書きの `nim.cfg` でビルドしている。niuv の宣言はそれらのリポジトリに置いていない。`fukai/store`・`fukai/keeper` の 4 つの実行ファイルは、niuv と `build.sh` で同じソースの組をコンパイルし、記号の名前だけが違う（ADR の「採らなかった案」）
- `fukai/delivery` が niuv を実際に使っている。公開のエージェントは `niuv child` にビルドを頼み、Nim の子は `niuv/manifest` で目録を読む。delivery の試験は見本のプロダクトを `niuv lock` で固定し、その実ビルドで公開・取り込み・入れ替えまで通す
- 旧 niuv の形の `niuv.toml`（`[project]`、`[tasks]`、`[environment]`、版の範囲などを持つもの）は、2026-10-16 にほかのリポジトリから消した（32 か所。各リポジトリの jj に「chore: remove the legacy-form niuv.toml」のコミットがある）。もし見つけたら、新しい niuv は作業場に並べられたときに、知らない節・キーとして場所を示して断る（NIV-01）。それらのリポジトリの文書やスクリプトには、旧 niuv への言及が残っているものがある

## 確かめていること・いないこと

- Nim: 同じ引数の `nim c` と同じバイト列ができる（設定ファイルと nimble の暗黙の探索を使わない）
- Gleam: パッケージごとに `gleam compile-package` を呼ぶ（gleam に依存の解決をさせないので、網のないゲストでも通る。NIV-16）。場所の違う 2 か所からビルドして、出荷される全 `.beam`（Erlang の FFI と Hex のパッケージを含む）の SHA-256 が一致する（`tests/acceptance/test_gleam_closure_places.nim` で実物の `gl-*` の閉包（`gl-upgrade-coordinator`→`gl-hotswap`、Erlang の FFI を持つ `gl-port`・`gl-unix-frames`、Hex の `gleam_stdlib`・`gleam_erlang`）を、`tests/unit/test_gleambuild.nim` で小さな例を）
- テスト: `tests/test_all.nim` で 307 件（警告 0）。kite を使う部分は偽の kite で確かめている。`tests/acceptance/` は兄弟のリポジトリや実物の kite を使うので、その外で手で流す
- 確かめていない: Linux・Windows、gleam 1.19.1 と OTP 29.1.1 以外の版、Hex の写しを niuv が自分で取得する経路（niuv は取得せず、gleam の Hex の写しを読んで checksum を確かめるだけ）、変異検査（`docs/quality/g2-unmeasured.md`）

## 持たない物

仮想環境、`activate`、シェルの統合、MCP、版の範囲の解決（SAT）、外の依存の取得（git clone・hex）、鍵・署名・封じる・網。理由は ADR の「対象外」と「採らなかった案」。Future: `.app` ファイルの目録への掲載、`OR` 式のライセンスでどちらを取るかの宣言。

旧 niuv（Nim の仮想環境の管理）の中身は jj のコミット `f06a84e1` と `88aacec2` に残してあり、消した物の一覧と読み戻し方は [docs/removed-2026-10-16.md](docs/removed-2026-10-16.md)。
