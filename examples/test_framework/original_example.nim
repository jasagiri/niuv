## test_framework_example.nim
## ========================
##
## niuv統合テストフレームワークのサンプル使用例
##

import std/[
  strutils,
  sequtils
]

# 統合されたテストフレームワークをインポート
import ../src/test_framework

# 統計を収集しながらテストを実行
runTestsWithStatistics:
  
  suite "基本テスト":
    
    test "シンプルな条件":
      # power_assertでより詳細なエラーメッセージ
      check(1 + 1 == 2)
      check(2 * 3 == 6)
      
    test "文字列操作":
      let s = "Hello, World!"
      check(s.startsWith("Hello"))
      check(s.contains("World"))
      
    test "コレクション操作":
      let numbers = @[1, 2, 3, 4, 5]
      # 複雑な式でも詳細情報が表示される
      check(numbers.foldl(a + b, 0) == 15)
      check(numbers.filter(proc(x: int): bool = x mod 2 == 0) == @[2, 4])
  
  suite "機能テスト":
    
    test "前提条件":
      # テストの前提条件をチェック
      let value = 10
      require(value > 0)  # 前提条件: valueは正の数
      # 前提条件が満たされたら以降のテストを実行
      check(value * 2 == 20)
    
    test "エラーの期待":
      # エラーが期待される場合のテスト
      expectError(ValueError, parseInt("abc"))
      
      # 存在しないインデックスへのアクセス
      var arr = @[1, 2, 3]
      expectError(IndexDefect, arr[10])
    
    test "スキップ例":
      skip()  # このテストはスキップされる
      check(false)  # 実行されない
      
    test "失敗例":
      # このテストは意図的に失敗する - コメントアウトしてテスト実行可能にする
      # check(1 + 1 == 3)  # パワーアサートで詳細な失敗情報が表示される
      check(1 + 1 == 2)  # 実行には成功するバージョン