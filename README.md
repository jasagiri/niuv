# niuv

Nim・Gleam（・WASM）の多言語ビルドの道具。パッケージごとの宣言（`niuv.toml`）と作業場（`niuv.workspace.toml`）から、依存の閉包を解決し、ロック（`niuv.lock`）に固定し、`nim` と `gleam` を呼んでビルドし、成果物の目録（決定的 CBOR）と SBOM を出す。`sealed` 印の成果物に GPL-3.0・LGPL-3.0・AGPL-3.0 が入るときは断る。

腐海（fukai）を知らない。鍵・署名・封じる・網は持たない。配る側は `fukai/delivery`（別のリポジトリ）が担う。

設計の出どころは `fukai/docs/build-and-delivery.md`、規則は [ADR-NIUV-0001](docs/adr/ADR-NIUV-0001.md)（Status: proposed）、規則とテストの対応は [docs/quality/spec-coverage.md](docs/quality/spec-coverage.md)。

## 使い方

```sh
niuv lock [--workspace FILE]                 # ツール・パッケージ・外の依存を中身のハッシュで固定する
niuv check <package>                         # 閉包を依存が先の順に並べる
niuv build <package> [--out DIR] [--bin NAME]... [--stage DIR]
niuv child                                   # nim-frames の枠で 1 つのビルドの頼みを受ける（腐海の子）
```

`build` はロックが無い・古い、ツールの版か実行ファイルがロックと違う、閉包に同じ外の依存が 2 つの版で来る、のどれかで断る。出力先には成果物（Nim の実行ファイルは `<bin 名>`、Gleam の `.beam` は `beam/<app>/`）、`niuv.manifest.cbor`、`niuv.sbom.cdx.json` が置かれる。

宣言と作業場の書き方は ADR の NIV-01〜NIV-07、例は `tests/unit/` の各ファイルの先頭にある。

## 確かめていること・いないこと

- Nim: 同じ引数の `nim c` と同じバイト列ができる（設定ファイルと nimble の暗黙の探索を使わない）。fukai の `scripts/build.sh` の出力とは一致しない。理由は ADR の「採らなかった案」
- Gleam: 場所の違う 2 か所からビルドして、出荷される全 `.beam`（Erlang の FFI と Hex のパッケージを含む）の SHA-256 が一致する（`tests/acceptance/test_fukai_agent.nim` で実物の `fukai/agent` を、`tests/unit/test_gleambuild.nim` で小さな例を）
- 確かめていない: Linux・Windows、gleam 1.19.1 と OTP 29.1.1 以外の版、`gleam` が Hex から取得する経路（Hex のキャッシュにある版だけで確かめた）、変異検査（`docs/quality/g2-unmeasured.md`）

## 持たない物

仮想環境、`activate`、シェルの統合、MCP、版の範囲の解決（SAT）、外の依存の取得（git clone・hex）、WASM のコンパイル手順（`[wasm]` は宣言の形を検証するだけで、ビルドは「宣言のみ」と報告する）。理由は ADR の「対象外」と「採らなかった案」。Future: `.app` ファイルの目録への掲載、`OR` 式のライセンスでどちらを取るかの宣言。

旧 niuv（Nim の仮想環境の管理）の中身は jj のコミット `f06a84e1` に残してあり、消した物の一覧は [docs/removed-2026-10-16.md](docs/removed-2026-10-16.md)。
