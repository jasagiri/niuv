# テスト用サンプルファイル - 標準unittestの使用方法に変更
import std/unittest
import std/sequtils  
import std/tables    
import std/strutils  

# 標準unittestのテスト

suite "Standard Unittest Example Tests":
  test "Basic assertions":
    let a = 5
    let b = 10
    
    # 成功するアサーション
    check(a * 2 == b)
    check(a + 5 == b)
    
    # 複雑な式でも詳細情報が表示される
    let arr = @[1, 2, 3, 4, 5]
    let sum = 15
    check(arr.foldl(a + b, 0) == sum)
    
  test "Error expectations":
    # エラーが期待される場合のテスト
    expect(ValueError):
      discard parseInt("abc")
    
    # 存在しないキーへのアクセス
    var table = {"a": 1, "b": 2}.toTable
    expect(KeyError):
      discard table["c"]
    
  test "Requirements":
    # テストの前提条件をチェック
    let value = 10
    require(value > 0)  # 前提条件: valueは正の数
    
    # 前提条件が満たされたら以降のテストを実行
    check(value * 2 == 20)
    
# このファイルはテスト統合のサンプルです
# 標準のunittestモジュールを使用するように変更されました