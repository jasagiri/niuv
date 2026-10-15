# niuv

Nim・Gleam（・WASM）の多言語ビルドの道具。パッケージごとの宣言（`niuv.toml`）と作業場（`niuv.workspace.toml`）から、依存の閉包を解決し、ロック（`niuv.lock`）に固定し、`nim` と `gleam` を呼んでビルドし、成果物の目録を出す。

腐海（fukai）を知らない。鍵・署名・封じる・網は持たない。配る側は `fukai/delivery`（別のリポジトリ）が担う。

設計の出どころは `fukai/docs/build-and-delivery.md`、規則は [ADR-NIUV-0001](docs/adr/ADR-NIUV-0001.md)（Status: proposed）。

## 状態

旧 niuv（Nim の仮想環境の管理）の作り直しの途中。規則と実装の対応は [docs/quality/spec-coverage.md](docs/quality/spec-coverage.md) の「状態」の列が正本で、「未実装」の行はまだ動かない。旧の中身は jj のコミット `f06a84e1` に残してあり、消した物の一覧は [docs/removed-2026-10-16.md](docs/removed-2026-10-16.md)。

## 持たない物

仮想環境、`activate`、シェルの統合、MCP、版の範囲の解決（SAT）、外の依存の取得（git clone・hex）、WASM のコンパイル手順。理由は ADR の「対象外」と「採らなかった案」。
