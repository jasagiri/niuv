# 仕様網羅（G1）: ADR-NIUV-0001 の規則と E テストの対応

宣言した規則 NIV-01〜NIV-22 のそれぞれに、それを検証する E テストの suite を結ぶ。G1 は、この表のどの行も「テストあり」であること。

| 規則 | E テスト（ファイル: suite 名） | 状態 |
|---|---|---|
| NIV-01 | tests/unit/test_decl.nim: `NIV-01 package table` | あり（N1） |
| NIV-02 | tests/unit/test_decl.nim: `NIV-02 nim table` | あり（N1） |
| NIV-03 | tests/unit/test_decl.nim: `NIV-03 gleam table` | あり（N1） |
| NIV-04 | tests/unit/test_decl.nim: `NIV-04 wasm table` | あり（N1） |
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
| NIV-15 | tests/unit/test_nimbuild.nim: `NIV-15 nim build` | あり（N1） |
| NIV-16 | tests/unit/test_gleambuild.nim: `NIV-16 gleam plumbing` | 未実装（N2） |
| NIV-17 | tests/unit/test_gleambuild.nim: `NIV-17 fixed bytes` | 未実装（N2） |
| NIV-18 | tests/unit/test_manifest.nim: `NIV-18 manifest` | 未実装（N2） |
| NIV-19 | tests/unit/test_sbom.nim: `NIV-19 sbom` | 未実装（N2） |
| NIV-20 | tests/unit/test_sbom.nim: `NIV-20 license gate` | 未実装（N2） |
| NIV-21 | tests/unit/test_child.nim: `NIV-21 child form` | 未実装（N2 の後。未実装の間は TODO） |
| NIV-22 | tests/unit/test_cli.nim: `NIV-22 commands` | あり（N1） |

## 注

- 「未実装」の行は、テストがまだ無い。実装と同じ変更でこの表を更新する。
- 対象外の文（G0）は `docs/adr/ADR-NIUV-0001.md` の「対象外」の表にある。
