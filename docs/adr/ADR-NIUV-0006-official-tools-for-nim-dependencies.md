# ADR-NIUV-0006: Nim の依存の取得と解決は公式の道具 (Atlas か Nimble) に任せ、niuv はその先だけを持つ

**Status**: proposed (保留)。2026-10-31 に代表 (jasagiri) が「標準で利用できるものはそちらを利用し、足りないものを niuv として整備するほうが自然」と方向を示し、同じ日に「まだ活発に開発中なら取り込むのは待ったほうが良さそう。ADR だけ起票しておいて」と決めた。取り込みは、下の「再開の条件」を満たすまで行わない。実装は無い
**Date**: 2026-10-31
**Author**: jasagiri (drafted by Claude Opus 5.5)
**仮説の層**: 実装 (ビルドの道具の役割の分け方)。支配軸: 整合性 (エコシステムの標準の道具と、niuv の持つものを重ねない)。想定する失敗: 隣を見ない再実装 (公式の道具が持つ取得と解決を niuv が持ち続ける)、身の丈に合わない設計 (0.x で動いている道具の内部の形に niuv を結びつける)。

## Context

- ADR-NIUV-0001 は「nimble に任せる」を採らなかった (nimble の暗黙の探索 `pkgs2` は、宣言に無い依存を通してしまう。固定した版を別の場所から使うには `--path` の手書きが要る)。外の依存の取得 (git clone、hex) も持たないと決め、`[dependencies.external]` と作業場の `[external] roots` で、置かれた物を取得元・版で選び、中身のハッシュで固定している (NIV-05・07・08・11)。
- 2026-10-31 に、公式の道具の今の状態を読んだ (gh api の読み取りと、手元の版)。
  - **Koch** は「Maintenance program for Nim」で、コンパイラ自身を組み、Nimble・Atlas を固定のコミットで入れる道具である。`koch.nim` の固定は Nimble 0.26.1 (`c154494a`)・Atlas 0.14.7 (`aa6fb162`)。利用者のプロジェクトのビルドには使わない。この ADR の対象外。
  - **Nimble** は v0.26.2 (2026-10-23) が出ている。手元は 0.24.1。SAT による版の解決、`nimble lock` (checksum つき)、`--offline`、`-l` (依存をプロジェクトの中に置く)、`nimble setup` (`nimble.paths` を作る) を持つ。
  - **Atlas** は 0.16.0〜0.16.4 が 2026-09-11〜10-30 に出ている (ほぼ毎週)。Nim 2.2.12 に入っているのは 0.14.7。文書 (`doc/atlas.md`) は CI で head を入れるよう勧めている。依存を `deps/` に取り、`nim.cfg` に `--path` を書く。`atlas.lock` は git のコミットを固定する (`pin`・`rep`)。手元のプロジェクトをつなぐ `link`、Nim の版を選ぶ `env`、feature、NimScript の builder を持つ。最近、作業場の考え方 (`atlas.workspace` と `_deps` から、`atlas.config` と `deps/` の project へ) が変わった。文書は「再現できるビルドを助けるが、完全な手段ではない」と書く。
- niuv の使い手は、いま `services/island-node/image` と `services/gate-node/image` の 2 つの作業場 (宣言は 52) だけである (2026-10-31、`fd` で数えた)。

## niuv の役目と公式の道具の対応 (2026-10-31)

| niuv の役目 | 公式の道具 | 判定 |
|---|---|---|
| 外の依存の取得と版の解決 (niuv は取得を持たない) | Atlas・Nimble | 公式で足りる |
| 手元の兄弟のリポジトリの作業場 | Atlas の `link`、Nimble の `develop` | ほぼ足りる。remote の無い jj のリポジトリを扱えるかは確かめていない |
| ロック (NIV-11・13) | `atlas.lock` はコミットだけ。`nimble.lock` は checksum を持つ | 一部。ツールの実行ファイルの SHA-256、コミットしていない木の中身のハッシュは無い |
| 閉じた Nim のビルド (NIV-14) | Atlas の `nim.cfg` の `--path` が近い | 一部。niuv は周りの設定も読まない (`--skipProjCfg` など。ADR-NIUV-0001 の「採らなかった案」の 1 つ目) |
| Gleam のビルド (NIV-16・17) | 無い。gleam 自身は網の無いゲストで落ちる (gleam-upstream-kit の W-H1) | niuv が持つ |
| 目録・SBOM・ライセンスの門 (NIV-18〜20) | 無い | niuv が持つ |
| fukai/delivery への子 (NIV-21) | 無い | niuv が持つ |
| Linux の目標とビルド用の像 (ADR-NIUV-0002) | 無い | niuv が持つ |

## Decision (提案。保留中。仕様 ID は取り込みを始めるときに振る)

1. Nim の依存の取得・版の解決・開発用の作業場は、公式の道具に任せる。niuv はそれを作り直さない。候補は Atlas を先に見る (探索パスを明示して Nimble の暗黙の探索を使わない形が、NIV-14 に近い)。Nimble の `-l` と `nimble.paths` を比べる対象に残す。
2. niuv は、解決の済んだ探索パスとロックを入力として受け、閉じたビルド (Nim と Gleam)・目録・SBOM・ライセンスの門・ビルド用の像・fukai への子を持つ。
3. niuv が公式の道具から読むのは、その道具が利用者に向けて文書にしている出力 (`nim.cfg` の `--path` と lock のファイル) だけにする。内部の置き場の形 (activation cache など) には頼らない。
4. 置き換えた後に消すのは、niuv の `[dependencies.external]` と作業場の `[external] roots` (NIV-05・07・08 の外の依存の部分) である。ロック (NIV-11) は、公式の lock を参照に持ちつつ、ツールの SHA-256 と中身のハッシュを足す形に改める。

## 再開の条件 (どれも満たしたら取り込みを始める)

- Atlas の更新の速さが落ち着く。目安は、1.0 が出るか、利用者向けの形 (コマンド・`atlas.config`・`atlas.lock`・`nim.cfg` の書き方) を変える版が 3 か月出ないこと。または、Nim の版に入る Atlas が文書の版に追いつくこと。
- 次の 3 つを試して確かめる (Nimble で進めるなら同じことを Nimble で)。
  1. remote の無い jj のリポジトリ (git と同居) を、Atlas が依存として扱えるか (`link`、`file://` の URL)。
  2. 網を断って `atlas rep` (または `atlas install`) が通るか。
  3. Atlas の `nim.cfg` を経たビルドが、niuv の今の出力とバイト列で一致するか (一致しなければ、違いが名前だけであることを `--genDeps:on` で確かめる。ADR-NIUV-0001 と同じ確かめ方)。
- 誰が見るか: niuv の持ち主。半年ごとか、Atlas か Nimble の大きな版が出たときに、上の目安を照らし直す。

## 採らなかった案

- **niuv を消し、公式の道具だけにする**: Gleam のビルド、目録・SBOM・門、ビルド用の像、fukai への子を、どの公式の道具も持たない。
- **今すぐ Atlas に移る**: 0.16 系がほぼ毎週出ていて、作業場の考え方も最近変わった。niuv の使い手 (像の作業場) は再現を約束しているので、動いている道具に結ぶと、変わるたびに像の作りを直すことになる。
- **Koch を使う**: コンパイラの保守の道具で、利用者のプロジェクトを組まない。
- **Atlas の builder (NimScript) に niuv の仕事を載せる**: 目録・門・像は Atlas の依存の木の外の仕事で、builder は依存ごとに `exec` を呼ぶ仕組みである。

## Related

- ADR-NIUV-0001 (NIV-05・07・08・10・11・14、「採らなかった案」の「nimble に任せる」「`nim.cfg` を生成する」「外の依存の取得」): この ADR が取り込まれたら、そこを改める。
- ADR-NIUV-0002 (Linux の目標とビルド用の像): 変えない。
- gleam-upstream-kit の `docs/watch.md` W-H1: Gleam の側を niuv が持ち続ける理由。
