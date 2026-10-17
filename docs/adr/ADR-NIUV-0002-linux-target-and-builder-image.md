# ADR-NIUV-0002: Linux の目標は、署名したビルド用の像の中で、その場の目標として作る

**Status**: proposed
**Date**: 2026-10-17
**出どころ**: fukai `docs/roadmap.md` 0.1 章 119（jasagiri、2026-10-17: Linux 向けのビルドは kite のゲストの中で行い、ゲストの OTP は 29.1.1 にそろえる。範囲は arm64 の Linux だけ）。段 K4（`fukai/docs/fukai-on-kite.md` 6 章）。K1 の測定（同 5.1 章。musl の Nim 2.2.12 で `column_child` などが動き、ホストの OTP 29 の beam はゲストの OTP 27 で `badfile`）。
**仮説の層**: 実装（ビルドの環境をロックに結ぶ。価値・行動の仮説は 119 で決着済み）。支配軸: リスク・不確実性（ビルドの環境が動くと、NIV-17 の前提がロックの外で崩れる）。想定する失敗: 早合点（`niuv build` が完走したことを、署名した像の中で作れたことと等価視する）、名ばかりの完了（「像を固定した」と書いて、ロックにも検査にも digest が無い）、取らぬ狸の拡張点（x86 や別の libc の目標を、使い手のいない今に作る）。

## 文脈

K1 で、Linux のゲストの中なら musl の Nim 2.2.12 で fukai の子が作れ、ゲストの OTP で作った beam が動くことが分かった。119 で、その作り方を「ビルド用の像を作って署名し、ロックにその digest を書き、ソースを渡して、ゲストの中で `niuv build` する」と決めた。この ADR は、その決定を niuv の規則にする。決まっていない部分（像の運び方、ソースの渡し方、ロックの形、目録の形、確かめ方）を選択肢で比べ、推奨を付ける。

### 確かめた事実（2026-10-17、コードを読んで）

- **kite の `--mount` は VZ の背で効かない。** `src/kite.nim` は `--mount:SRC:DST[:ro|rw]` を読み、`validateRuntimeSpec` が存在を調べ、`echo "Mounts: N"` と表示する。しかし `mounts` を使うのは HVF の断り（`hvf/refusal.nim`）と API の JSON だけで、VZ の橋（`vzf_bridge.m`）が作る共有ディレクトリは `kite_root`（像の根、読み取り専用）と `kite_upper`（`runs/<id>/upper`、書ける）の 2 つだけ。ゲストの init（`guest/init`）も `kite_root` と `kite_upper` しか mount しない。`docs/cli.md` の Planned CLI Extensions にも `--mount` が残っている。119 の「ソースは `--mount` で渡す」は、いまは実装が無い。
- **kite は手元の像を取れるが、手元の registry は取れない。** 像の取得は `src/oci/puller.nim` の `obtainImage` 1 つ。マニフェストと層の blob が `~/.kite/blobs/sha256/<hex>` に全部あれば、registry へは問い合わせない（トークンも取らない。`tokenOf` は取りに行く時だけ呼ぶ）。置かれた blob は使う度に SHA-256 を取り直す（PIN-07）。registry の宛先 `RegistryBase` と `AuthUrl` は `var` だが、CLI・環境変数・設定からは変えられず、試験だけがコードの中で書き換える（`tests/test_puller.nim`）。取得は Docker Hub 形式のトークン（`getToken` が常に呼ばれる）を前提にする。K3a の試験の「偽の registry」は、この `Downloader` を差し替えたものとみられる（読んだのは `test_puller.nim` の冒頭だけで、全体は確かめていない）。
- **層の形は tar か tar+gzip だけ。** `manifest.nim` の `layerMediaTypes` は `tar`・`tar+gzip`・Docker の `rootfs.diff.tar.gzip` を許し、zstd などは「kite が展開しない」と断る。
- **署名は `kite_sign image --repo:NAME --digest:sha256:HEX`**（COSE_Sign1 ES256、`external_aad = kite-image-v1`）。ペイロードに名前と digest が入る。名前に `/` が無いと kite が `library/` を足す（`registryRepo`）ので、署名の名前は `/` を含むものにするのが安全（`library/` の足し方が署名の側と合うかは確かめていない）。
- **niuv の現状。** ツールの固定は `{名前, 版, 実行ファイルの SHA-256}`（`lock.nim` の `LockedTool`）で、ロックは目標の区別を持たない。NIV-17（同じ入力から同じバイト列）が言うのは `.beam` だけで、Nim の実行ファイルには何も約束していない。目録の復号は厳しい（`decodeManifest` は「4 つのキーの map」でなければ断り、形式の版が 1 でなければ断る）。`[tools.*]` の既知の名前は nim・gleam・erlang の 3 つ。
- **上流（網で確かめた）。**
  - OTP 29.1.1: タグ `OTP-29.1.1` が GitHub に在る。`otp_src_29.1.1.tar.gz` は 106,873,902 バイトで、**手元に取って SHA-256 を取り、`054e0143e39c780e091107fc9b345792a9c1a55f6bac1eca1c1101510fc06bf6` を確かめた**（同じ値が、リリースの `SHA256.txt` と GitHub の API の `digest` に在る。どちらも同じ GitHub が配る物で、独立した経路ではない）。`.sigstore` の束（Sigstore の署名）が在るが、この機械に `cosign` が無く、**検証していない**。
  - gleam 1.19.1: `gleam-v1.19.1-aarch64-unknown-linux-musl.tar.gz` が在り、公開の `.sha256` の値は `b0eeed8c625471c2ab0fab7058b53979c47fa3bd84315b49b69481e26d583f7d`（API の `digest` と一致。tarball そのものは取っていない）。`.sigstore` は同様に未検証。
  - Nim 2.2.12: `nim-2.2.12.tar.xz` を手元に取り、SHA-256 `2639a06a5ea7a7fcf57df1e7e1ef4d1b2bee58c7ac9bd00dbd2aa5bea1e5a56a` を確かめた（nim-lang.org の `.sha256` と一致。K1 の控えの値の確認は別）。中身は csources 配布（`build.sh` と `c_code/` を含む）で、`sh build.sh` は C から Nim を組む。署名ファイル（`.sig`・`.asc`）は無い。
  - Alpine: `library/alpine:3.24` の index の digest が、今日 `sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6`（`3.23` は `sha256:85fe1e81…`）。Docker Hub の応答ヘッダから取った。像の署名は確かめていない。
- **ホスト**: OTP 29.1.1、gleam 1.19.1、Nim 2.2.12（mise）、podman 6.1.1（applehv の VM が起動中）。

## 規則

目標と作る場所

- **NIV-24** 目標は `<cpu>-<os>-<libc>`（例 `aarch64-linux-musl`）の文字列で、niuv は**自分が走っている機械の目標だけ**を作る（クロスコンパイルをしない）。`niuv lock|build --target T` の `T` が自分の目標と違えば断る。`--target` が無いときは自分の目標で、振る舞いはいまのまま。目標は実行時に判定する（CPU は `hostCPU`、OS は `hostOS`、Linux の libc は `/lib/ld-musl-<cpu>.so.1` の有無。コンパイル時の定義に頼らない）。範囲は `aarch64-linux-musl` と、ホストの macOS（arm64）の目標だけ。x86 は KVM の背（ADR-KITE-0006）の後。
- **NIV-25** ロックは目標ごとに 1 つ。自分の目標を `--target` なしで頼んだ時は `niuv.lock`、`--target T` と書いた時は `niuv.<T>.lock`（NIV-11 の「作業場の全メンバーを覆う 1 つの一貫した組」は、各ファイルの中で守る）。`niuv.<T>.lock` のツールは、その目標の実行ファイルの SHA-256 を持つ（ゲストで `niuv lock --target T` が書く）。パッケージと外の依存の中身のハッシュは目標によらず同じ値になる。ビルドは、頼まれたロックのパッケージ・外の依存が合わなければ NIV-12 で断る。
- **NIV-26** `niuv.<T>.lock` は `[builder]` を 1 つ持つ: `image = "NAME@sha256:<64 hex>"`（ビルド用の像。タグは受けない）。`NAME` は `/` を含む。ホスト側の `niuv build --target T --in-builder`（NIV-27）は、この digest でなければ像を起こさない。`[builder]` の無い `niuv.<T>.lock` を `--in-builder` で使えば断る。署名ファイルはロックに入れない（署名は pin ではなく、確かめる材料。場所は `--signature` か kite の保存先）。

ホストからの呼び出し

- **NIV-27** `niuv build <パッケージ> --target T --in-builder [--signature FILE]` は、ホストで次を行う。(1) ロックの `[builder]` を読む。(2) 作業場（読み取り専用）、外の依存の探し場所（読み取り専用）、出力先（書ける）、gleam の Hex の写し（NIV-29）を、ゲストへ渡す。(3) `kite run --image:<digest> --signature:<FILE> --mount:… ` を、網なし（`--net` なし）で起こす。(4) 終わった後、出力先の `niuv.manifest.cbor` を読み、**ホストが**各成果物の SHA-256 と大きさを目録と照らし、合わなければ断る（ゲストの出力を信じない）。kite はライブラリとして取り込まず、実行ファイルとして呼ぶ（`[tools.kite]` として版と実行ファイルの SHA-256 を、ホストの `niuv.lock` に固定する。`KnownTools` に `kite` を足す）。niuv は腐海を知らないままで、kite は foundation の道具。
- **NIV-28** ゲストの中では、像に入れた niuv が `niuv build --target T`（`--in-builder` なし）を行う。ツールの固定は NIV-13 のとおり、`niuv.<T>.lock` の実行ファイルの SHA-256 と照らす。像の digest を niuv が自分の中から確かめることはできない（像は自分の digest を持てない）ので、像の digest の強制は NIV-27 の呼び出しと kite の署名の確かめが受け持つ。

目録と決まったバイト列

- **NIV-29** 目録（NIV-18）の形式の版を 2 に上げ、`5: 目標（NIV-24 の文字列）`、`6: OTP の版（beam を含まなければ空文字）` を足す。復号は版 2 の 6 キーの map を受け、版 1 は読み続けるか断るかを `fukai/delivery` と決める（決めてほしい点 5）。理由: beam は作った OTP の版に縛られ（下の「beam」）、Nim の子は目標に縛られる。配る側が、島の機械が動かせる物かを目録から判断できるようにする。
- **NIV-30** NIV-17 を目標付きに読み替える: 同じ入力（像の digest を含む）を、場所も置き場の根も違う 2 つのゲストで別々にビルドして、全 `.beam` の SHA-256 が一致する。**Nim の実行ファイルの一致は約束しない**（NIV-17 は元から約束していない）。測って、一致すれば `docs/quality/` に事実として書き、一致しなければ違いの原因を書く。ホストの OTP 29.1.1 が作った beam とゲストの beam の一致は、約束でなく測定の対象（一致すれば、beam はビルドの OS によらないと言える。しなければ、beam は作った環境ごとの物として扱う）。
- **NIV-31** ゲストのビルドは網を持たない。Hex のパッケージは、gleam の Hex の写し（ホストの `~/.cache/gleam` など）を読み取り専用で渡して賄う（NIV-16 のとおり版は根の `manifest.toml` の `outer_checksum` が決める。写しに無いパッケージは断る）。

ビルド用の像の作り方（niuv の `builder/` に置く、腐海を知らない部品）

- **NIV-32** 像の作り方は `builder/` に、(a) 入力の表（Alpine の index の digest、OTP・Nim・gleam の取得元の URL と SHA-256、niuv の木の中身のハッシュ）、(b) Dockerfile、(c) 作った像を OCI のレイアウトで書き出す手順、(d) 作った像に入っている物の記録（`apk info -v`、各ツールの版と実行ファイルの SHA-256、`erl` の OTP_VERSION）、から成る。(a) の SHA-256 が合わない取得は、作業を止める。署名は `builder/` の外（`kite_sign`、鍵は niuv が持たない）。署名した像の digest が `niuv.<T>.lock` の `[builder]` に入る。

## 選択肢と比較

### 1. 像の運び方（OCI の形にして kite に渡す）

| 案 | 中身 | 利点 | 難点 |
|---|---|---|---|
| A. kite の store に入れる（`kite import`） | podman が書き出した OCI レイアウトの blob（マニフェスト・config・層）を、`~/.kite/blobs/sha256/` へ SHA-256 を取りながら置き、署名と合わせて `kite run --image` で使う。kite に小さな口を足す | 網が要らない。置いた物は PIN-07 で使う度に取り直されるので、取り込みの口は信頼の根にならない。kite の既存の道（`obtainImage` の「全部 store にある」）をそのまま使う | kite に取り込みの口が要る（置くだけなら口は要らないが、手でコピーする手順になり、誤りに気づきにくい） |
| B. 手元の registry を立てる | podman の `registry:2` など | 本物の取得の道を通る | `RegistryBase`・`AuthUrl` を外から変える口が要り、registry がトークンの手順を話せる必要がある。足す物が A より多い |
| C. 公開の registry（ghcr など）に置く | | 道具が最小 | 外への公開になる。署名済みでも、ビルド用の像を外に出すかは jasagiri の判断（外向きの操作）。網が要る |

推奨は **A**。理由: kite の変更が最小（取り込み 1 つ。層の media type と digest を検査して置く）で、取り込みの口が信頼を担わない（PIN-07）。B は口と手順が増える割に、得る物が A より少ない。C は外への公開で、いま要る理由が無い。podman の出力が gzip の層になるか（zstd でないか）は**確かめていない**。実装の最初の段で確かめる（zstd なら `--compression-format gzip` などで直す）。

### 2. ソースとゲストの出力の運び方

| 案 | 中身 | 利点 | 難点 |
|---|---|---|---|
| A. kite の VZ の背に `--mount` を実装する | `VZMultipleDirectoryShare` に共有を足し、ゲストの init が tag ごとに mount する。作業場と外の依存は ro、出力先は rw | 119 の決定のとおり。読み取り専用で渡せるので、ゲストはソースを書き換えられない | kite の変更が要る（`--mount` は CLI だけ受け付けて何もしない状態なので、先に直す。VSK・INI の続きの規則になる） |
| B. `kite_upper`（`runs/<id>/upper`）に写す | いまある書ける共有に、作業場の写しを置き、出力もそこから取る | kite の変更が要らない | 作業場全体（fukai と foundation の複数のリポジトリ）を毎回写す。ソースがゲストから書ける。写した木の正しさを別に確かめる必要がある |

推奨は **A**。B は kite を触らずに済むが、ゲストが書ける場所へソースを置くことになり、NIV-12 のロックの照合（ビルド前の中身のハッシュ）と、ビルド中のゲストの書き込みを分けられない。**この ADR の実装の前提として、kite に `--mount` の VZ の実装（K4-0）が要る。** これは kite の責務で、別の ADR（ADR-KITE-0008 の続き）で決める。

### 3. 像を作る場所（鶏と卵）

| 案 | 利点 | 難点 |
|---|---|---|
| A. podman（arm64 の Linux の VM。起動中） | Dockerfile で多段にでき、取り直しが速い。OTP のビルドに複数 CPU を使える | kite の署名の確かめの外で作る。podman の VM を信じる |
| B. kite のゲストの中で作る | 作った環境が実行の環境と同じ道（署名した像）で動く | ゲストにはいま層を組む道が無く、tar とマニフェストを手で組む必要がある。ビルドの遅さ（K1 の 2 CPU・1 GB）が出る |

推奨は **A**。理由: ここで作る物は署名されるまで何も信じられていないので、作る場所の信頼は署名の前の人の確認（入力の表と記録）で担う。署名した後は、像の digest が唯一の信頼の根になる。**信頼の根**を正直に書く: (1) jasagiri の署名の鍵（kite の `trust.json`）、(2) `builder/` の入力の表（Alpine の digest と各ソースの SHA-256。上流が独立した経路の署名を出していても、いまは検証していない）、(3) apk の版（下の「浮く物」）。Alpine の base の digest は、Docker Hub が返した値を記録する。**ツールチェーンの再現（同じ入力から同じ像）は約束しない**（OTP・Nim のビルドが決まったバイト列を出すかは、確かめていない）。像の pin は署名した digest。別の機械で作り直して比べる確かめは、あれば足す（Future）。

### 4. 土台と、浮く物

- 土台は Alpine の arm64 を digest で固定する（`FROM alpine@sha256:…`）。像の中に入れる物のうち、digest や SHA-256 で固定できる物: Alpine の base、OTP・Nim のソース、gleam の musl の配布物、niuv のソース（niuv.lock の中身のハッシュ）。**固定できず浮く物**: `apk add` する gcc・musl-dev・linux-headers・make・openssl-dev などの版（Alpine のパッケージ索引は時間で動く。apk は Alpine の鍵で署名を確かめるが、版は固定されない）。対処は、版を固定して入れるのでなく、**入った版を記録し（NIV-32 d）、署名した像の digest で固定する**こと。版を直書きすると、Alpine が古い版を消した時にビルドが壊れる。OTP の `crypto` が使う openssl の版もこの浮く物に入る（fukai のどの部品が `crypto` を使うかは、この ADR では確かめていない）。
- OTP は `otp_src_29.1.1.tar.gz` を SHA-256 で確かめて展開し、`./configure` と `make`、`make install` をする（`--without-javac --without-wx --without-odbc` などで要らない物を切る。実際の旗は実装の段で決める。ビルドの所要時間と像の大きさは**測っていない**）。Nim は `sh build.sh` で C から組み、`koch boot -d:release` で作り直す（K1 の `musl-nim.sh` のとおり。K1 は網のある環境で、取得も同じ手順に入っていた）。gleam は musl の配布物の `.tar.gz` を SHA-256 で確かめて置く（ソースから作ると Rust のツールチェーンが要り、得る物が少ない）。sigstore の束は、`cosign` を像を作る機械に入れた時点で検証を足す（Future。いまは SHA-256 の照合だけ）。
- niuv 自身は、**自分で自分をビルドできない**（鶏と卵）ので、像を作る段で `nim c` を直に使う（`niuv.toml` の先頭にある、作業場に自分と `nim-cbor-det`・`nim-frames` を並べて組む手順の素手版）。組んだ niuv が自分の木を `niuv build niuv` で作り直した結果と一致するかを見る確かめは、あれば足す（Future）。

### 5. niuv が kite を呼んでよいか、どこまで

| 案 | 中身 | 利点 | 難点 |
|---|---|---|---|
| A. niuv が `kite` を実行ファイルとして呼ぶ（NIV-27） | ロックの像の digest を `kite run --image` に渡すのは niuv だけ | 像の digest の強制が niuv の中にある。人が別の像を渡す余地が無い | niuv が kite の CLI の形（`--mount` など）に依存する。kite の版を固定する（`[tools.kite]`） |
| B. 人（またはスクリプト）が kite を呼び、ゲストで niuv を流す | niuv はゲストの中だけで動く | niuv に kite を知る部分が要らない | ロックの像の digest が、だれの呼び出しにも強制されない。ロックに digest を書いても名ばかりになる |

推奨は **A**（kite はライブラリでなくサブプロセスなので、niuv が Nim で kite に依存するわけではなく、nim・gleam を呼ぶのと同じ位置）。B ではロックの `[builder]` が強制されず、119 の「`niuv.lock` にその digest を書く」が名ばかりになる。腐海（fukai の鍵・署名・島）への依存は A にも無い。

## beam

- **確かめた事実（K1）**: ホストの OTP 29 が作った beam は、ゲストの OTP 27 で `badfile`。ゲストを OTP 27 にして beam も OTP 27 で作り直すと、`fukai/agent` の Gleam の試験が 32 件通った。
- **一般に言われること（この ADR では確かめていない）**: beam ファイルは、作った OTP のコンパイラの版を持ち、新しい OTP で作った beam を古い OTP が読めないことがある（新しい命令が増えるため）。逆（古い beam を新しい OTP が読む）は、数世代は読める（OTP の方針）。したがって、beam が縛られるのは「作った OTP の版」と「動かす OTP の版」の組。119 が一致（29.1.1 と 29.1.1）にそろえるのは、この組の確認を要らなくする安全側の選択。
- NIV-29 の `6: OTP の版` は、この縛りを目録に出す。`erlc` が出す beam が OTP の版だけで決まるのか（libc・OS に左右されないのか）は NIV-30 の測定で確かめる。

## 確かめの段取り（実装の段）

実装は K4 の次の段で行う。以下の順に、各段が合格した時だけ次へ進む。

| 段 | 作る物 | 合格 |
|---|---|---|
| K4-0（kite） | VZ の `--mount`（ro/rw）、像の取り込み、ゲストの終了と結果の渡し方（終了コードをどう返すかは**未確認**。出力先に結果のファイルを置き、`poweroff` で終わる案から始める） | kite の既存の試験が緑のまま。ro の mount への書き込みがゲストで拒まれる。取り込んだ像が、署名なしでは起動しない（PIN-08）、digest が違うと起動しない |
| K4-1（像） | `builder/` の表・Dockerfile・書き出し・記録。podman で作り、取り込み、`kite_sign` で署名 | 署名した像がゲストで起動し、`nim --version` が 2.2.12、`erl` の `OTP_VERSION` が 29.1.1、`gleam --version` が 1.19.1、`niuv` が走る。SHA-256 が合わない入力で作ると止まる。記録に `apk info -v` が在る |
| K4-2（niuv） | NIV-24〜29 の実装と E テスト（目標の判定、目標違いの断り、目標ごとのロック、`[builder]`、目録の版 2、ホストの再照合）。NIV-27 の呼び出しは偽の `kite` で E テストし、本物の `kite` で 1 回通す | 追加の規則すべてに E テストが在り（G1）、警告 0、既存の suite が緑 |
| K4-3（ゲストでの試験） | ゲストの中での `niuv lock --target` と `niuv build --target` | `fukai/agent` の Gleam の試験が通り（K1 の基準は 32 件）、`fukai/database` の `column_child` の試験が通り（K1 の基準は 10 件）、`fukai/store` の子が作れる。ホストの OTP 29.1.1 のこれまでの結果と同数 |
| K4-4（再現と反例） | NIV-30 の測定、NIV-27 の再照合、断りの確認 | 2 つのゲストで全 `.beam` の SHA-256 が一致。Nim の実行ファイルの一致・不一致を記録。ホストとゲストの beam の一致・不一致を記録。ロックの像の digest を書き換える、署名を外す、ゲストの出力を 1 バイト変える、`niuv.<T>.lock` のツールの SHA-256 を変える、のそれぞれが断られる |

K4-3 は、完走でなく、試験の件数で確かめる（早合点を避ける）。

## 決めてほしい点

1. **置き場**: 目標・目標別のロック・ビルド用の像の作り方（`builder/`）・kite を呼ぶ口を niuv に置く。この境界でよいか。推奨は**よい**。境界の判断: 汎用のビルドの道具の責務で、腐海の知識を持たない。kite の変更（`--mount` の VZ の実装、像の取り込み）は kite の責務で、別の ADR。腐海の基盤の実行用の像は K5 で fukai 側。違うと見る場合は、`builder/` だけを別のリポジトリにする案があるが、いま使い手が 1 つなので推奨しない。
2. **kite の前提の追加（K4-0）**: `--mount` の VZ の実装と像の取り込みを kite に足す。推奨は**足す**。足さずに `kite_upper` に写す案は、ゲストが書ける場所にソースを置くので推奨しない。
3. **niuv が `kite` を呼ぶ**（NIV-27）。推奨は**呼ぶ**（比較表 5）。
4. **ロックは目標ごとのファイル**（NIV-25）か、1 つのロックの中に目標の表を持たせるか。推奨は**目標ごとのファイル**。理由: 各ロックが自分だけで完結し、ゲストが書き換える場所が出力先の 1 ファイルで済む。1 つにまとめると、ホストとゲストの 2 つの書き手が 1 つのファイルを更新する。
5. **目録の版 2**（NIV-29）。推奨は**上げる**。ただし `fukai/delivery` の読み手（`niuv/manifest` を取り込むので、同じ復号）と試験が一緒に変わる。版 1 は、読み続ける（既存の公開済みの目録のため）か、断るか。推奨は**読み続け、目標・OTP は「不明」と扱う**。別案は、目録を触らずに SBOM（NIV-19）に目標を書く形だが、配る側が署名する頭は目録から作るので、目標が署名の外に出る。推奨しない。
6. **Hex の写しを渡して網なし**（NIV-31）。推奨は**網なし**（ゼロトラストと決まったバイト列のため）。`--net` を許す案は、ゲストが外へ出る向きを開くことになる（ADR-KITE の「ゲストからホストの待ち受けへ出る向きは開いたまま」の記述と合わせて、ビルドのゲストでは避ける）。ゲストの offline の gleam が写しだけで足りるかは**確かめていない**（K4-3 で確かめる）。
7. **像を作る場所は podman**（比較表 3）。推奨は**podman**。
8. **規則の番号**: 既存の NIV の続き（NIV-24〜32）。新しい接頭辞にしない。理由: 1 つの道具の規則で、`spec-coverage.md` の表が 1 つで済む。規則の行と E テストは、実装の変更と同時に足す（この ADR では足さない）。
9. **gleam は配布物 + SHA-256**（ソースから作らない。sigstore の検証は Future）。推奨は**配布物**。

## 対象外

- x86_64 の Linux、glibc の目標。KVM の背（ADR-KITE-0006）の後、使い手が現れた時に足す。
- 像の署名の鍵の置き場所（ADR-KITE-0009 の section c が未決。`kite_sign` の `--key-file` を使う）。
- 像の実行用の像（腐海の基盤を動かす像）。K5、`fukai` 側。
- クロスコンパイル（ホストで Linux の目標を作る）。採らない: beam の版がホストに縛られ、環境が固定されない（119 の採らなかった案）。

## 採らなかった案

- **ホストで Linux 向けに作る**（119）。ビルドの環境がロックの外に在る。
- **podman のコンテナの中でビルドする**（119）。kite の署名の確かめの外。
- **Alpine の `erlang27` を使う**（119）。開発（OTP 29.1.1）と本番の版が食い違う。
- **`apk add` の版を直書きして固定する**。Alpine のパッケージ索引は古い版を消すので、ビルドが時間で壊れる。入った版を記録し、署名した digest で固定する。
- **ロックに署名の本体を入れる**。署名は pin でなく、確かめる材料。
- **手元の registry を kite の変更なしで使う**。`RegistryBase` を変える口が無い（コードの中でしか変えられない）。

## 影響

- niuv: `toolchain.nim`（`kite` を既知のツールに）、`lock.nim`（目標別のファイル、`[builder]`）、`manifest.nim`（版 2）、`cli.nim`（`--target`、`--in-builder`）、新しい `builder/`。実装は K4-2 で、この ADR では行わない。
- `fukai/delivery`: 目録の版 2 を読む（NIV-29）。K4-2 の時に一緒に直す。
- kite: `--mount` の VZ の実装と像の取り込み（K4-0）。
- 未確認で残るもの: podman の層が gzip か、`library/` の署名の名前の足し方、ゲストの終了コードの返し方、offline の gleam、OTP・Nim のビルドの時間と大きさ、ツールチェーンの再現、上流の sigstore の検証。
