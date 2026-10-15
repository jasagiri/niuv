# niuv

Nim・Gleam・WASM のビルドの道具。規則の正本は `docs/adr/ADR-NIUV-0001.md`（NIV-NN）。設計の出どころは `fukai/docs/build-and-delivery.md`。

## 規則の置き場

- 規則（NIV-NN）: `docs/adr/ADR-NIUV-0001.md`
- 規則とテストの対応（G1）: `docs/quality/spec-coverage.md`。規則を足したら、同じ変更で E テストと表の行を足す
- 変異検査（G2）は実装が落ち着くまで流さず、`docs/quality/g2-unmeasured.md` に未測定として足す
- 消した旧の機能: `docs/removed-2026-10-16.md`（読み戻しは `jj file show -r f06a84e1 <path>`）

## 試し方

```sh
# Nim 2.2.12 は mise 経由。nim.cfg が探索パスを持つ
mise exec nim@2.2.12 -- nim c -r --hints:off tests/unit/test_decl.nim   # 1 ファイル
mise exec nim@2.2.12 -- nim c -r --hints:off tests/test_all.nim         # 全部
```

- テストは `std/unittest`、suite 名に規則 ID（`NIV-05 dependencies`）、test 名は Given-When-Then
- Gleam と Erlang が要るテスト（NIV-16/17）は `gleam` と `erl` が PATH に無いと失敗する（飛ばさない）
- 一時のビルド・比較の出力は作業場の外のスクラッチに出す。`fukai/` のリポジトリの `bin/` は上書きしない

## 守ること

- 公開 proc は `{.raises: [].}`。失敗は `Result[T, NiuvError]` の値で返し、握り潰さない
- 実装していない機能を README・コメントで現在形で書かない（`TODO:` / `Future:` と書く）
- 版の管理は jj のみ。`jj git push` はしない
