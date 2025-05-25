# 正規表現パターン定義
# このモジュールはniuvプロジェクトで使用する正規表現パターンを定義する

const requirePattern* = "requires\\s+[\"']([^\"']+)[\"']\\s*(\\#\\s*dev)?"
const requireVersionPattern* = "^([\\w\\.-]+)\\s*([<>=@][^\"']+)?$"
const taskPattern* = "task\\s+([^,:\\s]+)[,:]?\\s*(.*)"