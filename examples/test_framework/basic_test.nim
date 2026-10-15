## basic_test.nim
## =============
##
## シンプルなテストフレームワークの使用例
## power_assert_nim の自動拡張を使用した基本的なテスト
##

import std/[strutils, sequtils]
import ../../src/test_enhanced

# テストを実行
runTests:
  
  suite "基本演算":
    
    test "数値計算":
      # power_assert_nim でより詳細なエラーメッセージを生成
      check(1 + 1 == 2)
      check(2 * 3 == 6)
      check(10 / 2 == 5)
      
    test "文字列操作":
      let s = "Hello, World!"
      check(s.startsWith("Hello"))
      check(s.contains("World"))
      check(s.endsWith("!"))
      
    test "コレクション操作":
      let numbers = @[1, 2, 3, 4, 5]
      # 複雑な式でも詳細情報が表示される
      check(numbers.foldl(a + b, 0) == 15)
      check(numbers.filter(proc(x: int): bool = x mod 2 == 0) == @[2, 4])
      check(numbers.map(proc(x: int): int = x * 2) == @[2, 4, 6, 8, 10])
  
  suite "高度な機能":
    
    test "前提条件":
      # テストの前提条件をチェック
      let value = 10
      require(value > 0)  # 前提条件: valueは正の数
      # 前提条件が満たされたら以降のテストを実行
      check(value * 2 == 20)
    
    test "例外の期待":
      # エラーが期待される場合のテスト
      expectError(ValueError, parseInt("abc"))
      
      # 索引範囲外エラー
      var arr = @[1, 2, 3]
      expectError(IndexDefect, arr[10])
    
    test "スキップ例":
      skip()  # このテストはスキップされる
      check(false)  # 実行されない

when isMainModule:
  # テストはrunTestsテンプレートによって自動的に実行される
  echo "テスト実行が完了しました"