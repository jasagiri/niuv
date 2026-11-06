# 仕様網羅（G1）: ADR-NIUV-0001 の規則と E テストの対応

宣言した規則 NIV-01〜NIV-22 のそれぞれに、それを検証する E テストの suite を結ぶ。G1 は、この表のどの行も「テストあり」であること。

| 規則 | E テスト（ファイル: suite 名） | 状態 |
|---|---|---|
| NIV-01 | tests/unit/test_decl.nim: `NIV-01 package table` | あり（N1） |
| NIV-02 | tests/unit/test_decl.nim: `NIV-02 nim table` | あり（N1） |
| NIV-03 | tests/unit/test_decl.nim: `NIV-03 gleam table` | あり（N1） |
| NIV-04 | tests/unit/test_decl.nim: `NIV-04` の旧い形は ADR-NIUV-0007 で NIV-49 に置き換えた（旧い `entry` の形を断る: `NIV-49 wasm components`） | 置き換え（ADR-NIUV-0007） |
| NIV-05 | tests/unit/test_decl.nim: `NIV-05 dependencies` | あり（N1） |
| NIV-06 | tests/unit/test_decl.nim: `NIV-06 package root` | あり（N1） |
| NIV-07 | tests/unit/test_workspace.nim: `NIV-07 workspace` | あり（N1） |
| NIV-08 | tests/unit/test_resolve.nim: `NIV-08 closure`、tests/unit/test_cli.nim: `NIV-08 check through the command line` | あり（N1） |
| NIV-09 | tests/unit/test_resolve.nim: `NIV-09 two versions of one name` | あり（N1） |
| NIV-10 | tests/unit/test_decl.nim: `NIV-10 no version ranges` | あり（N1） |
| NIV-11 | tests/unit/test_lock.nim: `NIV-11 lock content` | あり（N1） |
| NIV-12 | tests/unit/test_lock.nim: `NIV-12 stale lock`、tests/unit/test_cli.nim: `NIV-12 stale lock through the command line` | あり（N1） |
| NIV-13 | tests/unit/test_lock.nim: `NIV-13 tool pin`、tests/unit/test_cli.nim: `NIV-13 tool pin through the command line` | あり（N1） |
| NIV-14 | tests/unit/test_nimbuild.nim: `NIV-14 nim plumbing` | あり（N1） |
| NIV-15 | tests/unit/test_nimbuild.nim: `NIV-15 nim build`、tests/unit/test_cli.nim: `NIV-15 NIV-18 NIV-19 a mixed build writes a manifest and an SBOM` | あり（N1） |
| NIV-16 | tests/unit/test_gleambuild.nim: `NIV-16 gleam plumbing` | あり（N2） |
| NIV-17 | tests/unit/test_gleambuild.nim: `NIV-17 fixed bytes`、tests/acceptance/test_fukai_agent.nim: `N2 acceptance: fukai/agent from two places`（test_all の外） | あり（N2） |
| NIV-18 | tests/unit/test_manifest.nim: `NIV-18 manifest`、tests/unit/test_cli.nim の同上 suite | あり（N2） |
| NIV-19 | tests/unit/test_sbom.nim: `NIV-19 sbom`、tests/unit/test_cli.nim の同上 suite | あり（N2） |
| NIV-20 | tests/unit/test_sbom.nim: `NIV-20 license gate`、tests/unit/test_cli.nim: `NIV-20 license gate through the command line`、tests/acceptance/test_fukai_agent.nim: `N2 acceptance: a GPL-3.0 dependency of a sealed agent` | あり（N2） |
| NIV-21 | tests/unit/test_child.nim: `NIV-21 child form` | あり（N2） |
| NIV-22 | tests/unit/test_cli.nim: `NIV-22 commands` | あり（N1） |
| NIV-23 | tests/unit/test_gleambuild.nim: `NIV-23 beam placement` | あり（N2） |

## ADR-NIUV-0002 の規則（K4-2）

実装は `src/niuv/target.nim`（NIV-24）、`lock.nim`（NIV-25、26）、`inbuilder.nim`（NIV-27、28、31）、`manifest.nim`（NIV-29）、`cli.nim`。kite を偽物に置き換えた E テストは `test_all` の中。実物の kite でゲストを起こす受け入れは `tests/acceptance/test_builder_guest.nim`（test_all の外）。

| 規則 | E テスト（ファイル: suite 名） | 状態 |
|---|---|---|
| NIV-24 | tests/unit/test_target.nim: `NIV-24 targets`、tests/unit/test_cli.nim: `NIV-24 NIV-25 NIV-29 targets, locks and manifests through the command line` | あり（K4-2） |
| NIV-25 | tests/unit/test_lock.nim: `NIV-25 one lock per target`、tests/unit/test_cli.nim の同上 suite | あり（K4-2） |
| NIV-26 | tests/unit/test_lock.nim: `NIV-26 builder image`、tests/unit/test_cli.nim: `NIV-26 the builder image through the command line`、tests/unit/test_inbuilder.nim（`[builder]` が無ければ断る） | あり（K4-2） |
| NIV-27 | tests/unit/test_inbuilder.nim: `NIV-27 coverRoots`、`NIV-27 what the guest gets`、`NIV-27 niuv build --in-builder`、`NIV-27 beams in the guest's output`、`NIV-27 niuv lock --in-builder`（kite は偽物）。実物の kite: tests/acceptance/test_builder_guest.nim（`N-K4-4 acceptance`: 別の像・別の kite・署名なし・信じない鍵・ゲストの出力の書き換え 12 通り） | あり（K4-2、K4-4）。実物の kite と像での受け入れは 2026-10-17 に通った（手で流す） |
| NIV-28 | tests/unit/test_cli.nim: `NIV-27 NIV-28 option rules`（`--in-guest`: PATH で探す・`--external-root`・`--lock-out`）、tests/unit/test_inbuilder.nim: `NIV-27 what the guest gets`（ゲストの命令） | あり（K4-2）。ゲストの中で実際に `niuv build` が走ることは受け入れ |
| NIV-29 | tests/unit/test_manifest.nim: `NIV-29 manifest format version 2`、tests/unit/test_cli.nim の NIV-24 suite（ネイティブのビルドの目録）、fukai/delivery の `tests/test_publish.nim`（版 1 と版 2 を読む） | あり（K4-2） |
| NIV-30 | （K4-4 で測る。この段では実装しない） | 未実装 |
| NIV-31 | tests/unit/test_inbuilder.nim: `NIV-27 what the guest gets`（`--net` を渡さない・Hex の写しは ro で /hex・ゲストの命令）、`NIV-27 niuv build --in-builder`（Hex の写しが無ければ断る）。ゲストの offline の gleam は受け入れ | 一部あり（K4-2） |
| NIV-32 | builder/test/test_verify.sh（入力の SHA-256 が合わなければ止まる）。像の中身の記録（d）は `builder/records/` の実測で、`builder/selftest.sh` をゲストで流した結果が E | 一部あり（K4-1）。`test_all` の外で `sh builder/test/test_verify.sh` を手で流す |
| NIV-33 | tests/unit/test_lock.nim: `NIV-33 the workspace directory is not part of a package`（ロックを書いてもハッシュとチェックが動かない・作業場の下のファイルが動かさない・根の外の源と宣言は動かす・作業場が根そのものの場合）、tests/unit/test_gleambuild.nim: ステージの名前が作業場の下のファイルで動かない | あり（K5-1c） |

## 注

- 「あり」は、その suite が `tests/test_all.nim` に入っており、全部緑であること（`tests/acceptance/` は fukai の兄弟リポジトリを読むので test_all の外で、手で流す）。テストが無い規則の行は「未実装」と書く。実装と同じ変更でこの表を更新する。
- 警告 0 は `nim check tests/test_all.nim` で確かめる。
- 対象外の文（G0）は `docs/adr/ADR-NIUV-0001.md` の「対象外」の表にある。

## ADR-NIUV-0003（wasm32-wasip1）

実装は `src/niuv/wasm.nim`、`src/niuv/wasm/{start,multi3}.c`、`cli.nim`。テストは実物の nim・clang・wasi-sysroot・wasmtime を使い、`test_all` の中にある。

| 規則 | E テスト（ファイル: suite 名） | 状態 |
|---|---|---|
| NIV-34 | tests/unit/test_wasm.nim: `NIV-34 the recipe` | あり |
| NIV-35 | tests/unit/test_wasm.nim: `NIV-35 the C entry` | あり |
| NIV-36 | tests/unit/test_wasm.nim: `NIV-36 the 128-bit multiply` | あり |
| NIV-37 | tests/unit/test_wasm.nim: `NIV-37 outputs and the stage` | あり |
| NIV-38 | tests/unit/test_wasm.nim: `NIV-38 refusals` | あり |
| NIV-39 | tests/unit/test_wasm.nim: `NIV-39 niuv wasm on the command line`（--help に wasm も） | あり |

## ADR-NIUV-0004（WIT の world の component）

| 規則 | E テスト（ファイル: suite 名） | 状態 |
|---|---|---|
| NIV-40 | tests/unit/test_wasm.nim: `NIV-40 the component recipe` | あり |
| NIV-41 | tests/unit/test_wasm.nim: `NIV-41 a component of a world` | あり |
| NIV-42 | tests/unit/test_wasm.nim: `NIV-42 component refusals` | あり |
| NIV-43 | tests/unit/test_wasm.nim: `NIV-43 niuv wasm --component on the command line` | あり |
| NIV-44 | tests/unit/test_wasm.nim: `NIV-44 a WASI reactor with the preview1 adapter`（world と core の形、nim-wasm-runtime の `wasm_runtime run` と wasmtime で run が ok・err） | あり |
| NIV-45 | tests/unit/test_wasm.nim: 同上の suite（adapter が無ければ断る、既定の場所、`--wasi`・`--adapter` の組み方） | あり |

## ADR-NIUV-0005（自分のソースの指紋）

| 規則 | E テスト（ファイル: suite 名） | 状態 |
|---|---|---|
| NIV-46 | tests/unit/test_fingerprint.nim: `NIV-46 the fingerprint of niuv's sources` | あり |
| NIV-47 | tests/unit/test_fingerprint.nim: `NIV-47 the exit code of niuv --version --check`、`NIV-46` の suite（断るコマンドが 3） | あり |

## ADR-NIUV-0007（プロジェクトのビルドで WASM の component を組む）

| 規則 | E テスト（ファイル: suite 名） | 状態 |
|---|---|---|
| NIV-49 | tests/unit/test_decl.nim: `NIV-49 wasm components`（全部の鍵、必須の鍵ごとの断り、旧い `entry` の形と空の `[wasm]`、知らない鍵、名前の重なり、stack_size の範囲） | あり |
| NIV-50 | tests/unit/test_decl.nim: `NIV-50 component paths are relative`、tests/unit/test_workspace.nim: `NIV-07 workspace`（entry・wit・paths が無い、作業場の外へ出る、兄弟の package は受ける） | あり |
| NIV-51 | tests/unit/test_wasmbuild.nim: `NIV-51 ...`（component を実行、目録の SHA-256 とファイルが一致、出力先は component だけ、2 回で同じ、失敗に名前、stack）、tests/unit/test_cli.nim: `NIV-51 a component beside the other kinds` | あり |
| NIV-52 | tests/unit/test_wasmbuild.nim: `NIV-52 ...`（clang・sysroot・wasm-tools の断りと、component の無い package は要さない） | あり |
| NIV-53 | tests/unit/test_wasmbuild.nim: `NIV-53 --bin selects components too` | あり |
| NIV-54 | tests/unit/test_wasmbuild.nim: `NIV-54 the license gate covers a sealed component` | あり |
| NIV-55 | tests/unit/test_inbuilder.nim: `Given a package that declares a wasm component ... (NIV-55)`（macOS のホストだけ。Linux のホストは NIV-27 の builderHost が先に断る） | あり |
| NIV-56 | tests/unit/test_wasmbuild.nim: `NIV-56 the closure reaches the component` | あり |
| NIV-57 | tests/unit/test_wasmbuild.nim: `NIV-57 the lock covers what the component reads` | あり |
