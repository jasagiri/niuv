# ADR-NIUV-0002: Linux の目標は、署名したビルド用の像の中で、その場の目標として作る

**Status**: accepted（2026-10-17、jasagiri が「決めてほしい点」を推奨どおり承認。fukai roadmap 0.1 章 119・120。K4-1 の結果を反映）
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
- **NIV-26** `niuv.<T>.lock` は `[builder]` を 1 つ持つ: `image = "NAME@sha256:<64 hex>"`（ビルド用の像。タグは受けない）。`NAME` は `/` を含む。ホスト側の `niuv build --target T --in-builder`（NIV-27）は、この digest でなければ像を起こさない。`[builder]` の無い `niuv.<T>.lock` を `--in-builder` で使えば断る。署名ファイルはロックに入れない（署名は pin ではなく、確かめる材料。場所は `--signature` か kite の保存先）。ロックが既に像を pin しているとき、`niuv lock --target T --in-builder --builder X` の `X` が違う像なら断る（誤りの文面に今の digest と `X` を出し、動かすには `--repin-builder` を足す。同じ像、まだロックが無い、は今のまま。2026-10-17、K4-4 の見つけたこと 2 から）。

ホストからの呼び出し

- **NIV-27** `niuv build <パッケージ> --target T --in-builder [--signature FILE]` は、ホストで次を行う。(1) ロックの `[builder]` を読む。(2) 作業場（読み取り専用）、外の依存の探し場所（読み取り専用）、出力先（書ける）、gleam の Hex の写し（NIV-29）を、ゲストへ渡す。(3) `kite run --image:<digest> --signature:<FILE> --mount:… ` を、網なし（`--net` なし）で起こす。(4) 終わった後、出力先の `niuv.manifest.cbor` を読み、**ホストが**各成果物の SHA-256 と大きさを目録と照らし、合わなければ断る（ゲストの出力を信じない）。kite はライブラリとして取り込まず、実行ファイルとして呼ぶ（`[tools.kite]` として版と実行ファイルの SHA-256 を、ホストの `niuv.lock` に固定する。版は `kite --version` で照らす。`KnownTools` に `kite` を足す）。niuv は腐海を知らないままで、kite は foundation の道具。
- **NIV-28** ゲストの中では、像に入れた niuv が `niuv build --target T`（`--in-builder` なし）を行う。ツールの固定は NIV-13 のとおり、`niuv.<T>.lock` の実行ファイルの SHA-256 と照らす。像の digest を niuv が自分の中から確かめることはできない（像は自分の digest を持てない）ので、像の digest の強制は NIV-27 の呼び出しと kite の署名の確かめが受け持つ。

目録と決まったバイト列

- **NIV-29** 目録（NIV-18）の形式の版を 2 に上げ、`5: 目標（NIV-24 の文字列）`、`6: OTP の版（beam を含まなければ空文字）` を足す。復号は版 2 の 6 キーの map を受け、版 1 は読み続けるか断るかを `fukai/delivery` と決める（決めてほしい点 5）。理由: beam は作った OTP の版に縛られ（下の「beam」）、Nim の子は目標に縛られる。配る側が、島の機械が動かせる物かを目録から判断できるようにする。
- **NIV-30** NIV-17 を目標付きに読み替える: 同じ入力（像の digest を含む）を、場所も置き場の根も違う 2 つのゲストで別々にビルドして、全 `.beam` の SHA-256 が一致する。**Nim の実行ファイルの一致は約束しない**（NIV-17 は元から約束していない）。測って、一致すれば `docs/quality/` に事実として書き、一致しなければ違いの原因を書く。ホストの OTP 29.1.1 が作った beam とゲストの beam の一致は、約束でなく測定の対象（一致すれば、beam はビルドの OS によらないと言える。しなければ、beam は作った環境ごとの物として扱う）。
- **NIV-31** ゲストのビルドは網を持たない。Hex のパッケージは、gleam の Hex の写し（ホストの `~/.cache/gleam` など）を読み取り専用で渡して賄う（NIV-16 のとおり版は根の `manifest.toml` の `outer_checksum` が決める。写しに無いパッケージは断る）。

ビルド用の像の作り方（niuv の `builder/` に置く、腐海を知らない部品）

- **NIV-32** 像の作り方は `builder/` に、(a) 入力の表（Alpine の index の digest、OTP・Nim・gleam の取得元の URL と SHA-256、niuv の木の中身のハッシュ）、(b) Dockerfile、(c) 作った像を OCI のレイアウトで書き出す手順、(d) 作った像に入っている物の記録（`apk info -v`、各ツールの版と実行ファイルの SHA-256、`erl` の OTP_VERSION）、から成る。(a) の SHA-256 が合わない取得は、作業を止める。署名は `builder/` の外（`kite_sign`、鍵は niuv が持たない）。署名した像の digest が `niuv.<T>.lock` の `[builder]` に入る。

作業場とパッケージの境（K5-1c、fukai roadmap 0.1 章 127 (1)）

- **NIV-33** 作業場のディレクトリ（`niuv.workspace.toml` のあるディレクトリ。宣言 `decls/` とロックを置く所）は、パッケージの一部ではない。パッケージの中身のハッシュ（NIV-11。ロックの `sha256`）と Gleam のステージの名前（NIV-16）は、作業場のディレクトリがパッケージの根（や Nim の `src`・bin の main のあるディレクトリ）の中にあれば、その下を数えない。作業場のディレクトリが数える木そのものなら、`niuv.workspace.toml` と `niuv*.lock` だけを数えない。宣言 `niuv.toml` は NIV-11 のとおり別に数える。理由: 作業場がパッケージの根の中にあると、ロックを書くたびにパッケージのハッシュが変わり、`niuv build` が NIV-12 の「changed since it was locked」で必ず断った（島のノードの像、`island_node` の根の中の `image/`）。採らなかった案: 使い手の側で作業場を根の外へ出す（置き場の制約を使い手に押し付け、niuv が自分の書くファイルでハッシュを狂わす欠陥が残る）。

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

## K4-1 の結果（2026-10-17）

`builder/` に像の作り方を置き、podman で作り、kite に取り込んで署名し、ゲストで起動して確かめた。記録は `builder/records/` と `builder/README.md`。

- **合格の形**: 署名した像が kite のゲスト（網なし、作業場を `--mount` で読み取り専用、出力先を書ける）で起動し、`builder-selftest`（`builder/selftest.sh`）が終了コード 0 で終わった。`nim -v` は 2.2.12、OTP は 29（`OTP_VERSION` 29.1.1、erts 17.1）、`gleam --version` は 1.19.1、`niuv --help` は終了コード 0。加えて、Nim が C にコンパイルして実行でき、`erlc` が beam を作れ、読み取り専用の mount に書けず、ネットワークの機器が `lo` だけ、を同じ実行で確かめた。
- **上流の照合**: 3 つの tarball の SHA-256 は ADR の値と一致した（Nim `2639a06a…`、OTP `054e0143…`、gleam `b0eeed8c…`。gleam は取った tarball を実際にハッシュして公開の `.sha256` と照合）。違う値を渡すと、ホストの `verify-inputs.sh` が終了コード 1 で止まり（`builder/test/test_verify.sh`）、`Containerfile` の最初の段（`sha256sum -c`）も、1 桁違えた一覧で `podman build` が止まる。像の中で長い段に入る前に止まる。
- **podman の層は tar+gzip**（K4-0 の確認どおり）で、`kite import` が受けた。署名の名前は `niuv/builder-k4`（`/` を含む）で、`kite_sign image` と `kite run --image` がそのまま通った。
- **署名は開発用の鍵**。像の鍵の儀式（fukai roadmap 118）はまだ無いので、kite の `dev_keys` に登録した鍵で署名した。実行のたびに kite が「development key で署名された」と警告する。本物の鍵の儀式ができるまで、`[builder]` に書く digest は開発用の鍵で署名した像のもの。儀式ができたら、同じ像を本物の鍵で署名し直す（像の digest は変わらない）。
- **像は作るたびに digest が変わる**（層に時刻が入る。同じ入力で 2 回作り、マニフェストの digest が違った）。したがって `[builder]` の pin は「作り直せる」ことでなく「この digest の像」を固定する。それが NIV-26 の設計どおりで、像の再現（同じ digest を作り直す）は約束しない。
- **時間と大きさ**（podman の VM は 4 CPU・6 GiB。Nim と OTP の段は並んで走る）: キャッシュなしの全部の作り直しで 397 秒（`podman build`）。像は、展開後 403,273,456 バイト、層の圧縮後の合計 173,618,888 バイト、層 11 枚。ゲストでの起動から終了まで 108 秒（層の展開を含む）。
- **入った物**: apk の版は `builder/records/apk-info.txt`（38 件。gcc 15.2.0-r5、musl 1.2.6-r2、libcrypto3 3.5.8-r0、alpine-release 3.24.2-r0 など）。実行ファイルの SHA-256 は `builder/records/exe-sha256.txt`。

この段で確かめていないこと: ゲストの中での niuv の試験の実行（K4-3）、offline の gleam、像を同じ digest で作り直せるか（約束しない）、sigstore の検証（Future）、`erlc` が出す beam がホストの OTP 29.1.1 のものと一致するか（K4-4）。

## K4-2 の結果（2026-10-17）

NIV-24〜29、31 を実装し、E テストを足した（`docs/quality/spec-coverage.md`）。実物の kite と像での受け入れ（`tests/acceptance/test_builder_guest.nim`）が通った。

- **macOS の目標名は `aarch64-macos-none`**（NIV-24。libc の欄は none）。jasagiri 側の承認済み。
- **像に入口が要った。** kite は `--cmdline:init=PATH` の PATH が像の根に在ることを要求する（mount したスクリプトは起動できない。実測: `the image root has no /ctl/run.sh to start`）。そこで像に `builder-run`（`exec /bin/sh /ctl/run.sh`）を足して作り直した。新しい digest が `[builder]` の pin（`builder/records/build-record.md`）。K4-1 の像（`f5d5b3c2…`）は入口を持たないので、`--in-builder` には使えない。
- **ゲストの niuv は像の中の niuv。** 当初は「mount したソースからゲストで `nim c` する」案だったが、niuv の第三者の Nim ソース（parsetoml・results・checksums）は像の最終段に無い（ビルド段だけ）ので、ゲストでは組めない。像の niuv は像を作るときに記録した木（nim-cbor-det・nim-frames・nim-fdio を含む）から組まれ、それを信じる根は NIV-28 のとおり像の digest。
- **ホストの呼び出し。** ソースは同じ絶対パスで ro に mount（読み込み先が isomorphic なので、ゲストは同じ `niuv.workspace.toml`・同じロック・同じ相対パスを読む）。出力先は `/out`（rw）、命令は `/ctl/run.sh`（ro）、gleam の Hex の写しは `/hex`（ro。ゲストがキャッシュへ写す）。kite の mount は 8 個までなので、ソースの置き場所が多いときは共通の親へまとめる（`/` までは上がらない）。`--net` は渡さない。
- **kite の固定。** ホストの `niuv.lock` に `[tools.kite]` の版と実行ファイルの SHA-256 を持つ。版は `kite --version`（kite 0.2.0 以降。出力 `kite <版>`）を走らせて照らす。
- **ホストの再照合（NIV-27 の 4）の範囲。** 目録の形式の版が 2、パッケージ・版・目標が頼んだとおり、Nim の bin の集合が宣言と一致、beam を含むなら OTP の版が `niuv.<T>.lock` の erlang の版と一致、ファイル名が安全（`/` や `..` を含まない）、全ファイルが通常のファイル（シンボリックリンクでない）で SHA-256 と大きさが目録と一致、目録・SBOM・目録に載ったファイル以外が出力先に無い。出力先は、始める前に空でなければ断る。`lock --in-builder` では、ホストが全パッケージ・外の依存のハッシュを自分で取り直し、ゲストのロックと合わなければ断る（ツールの SHA-256 だけがゲストの申告）。
- **実測。** 受け入れ（Nim の bin 1 つと、`gleam_stdlib` に依存する Gleam のアプリ 1 つ）でゲストの `niuv lock --target aarch64-linux-musl` と `niuv build` が通り、Nim の出力は ELF（aarch64）、目録は版 2・目標 `aarch64-linux-musl`・OTP `29.1.1`。Nim が通らないパッケージは、ゲストが終了コード 1 で終わり、ホストが断った。ゲストの offline の gleam（Hex の写しと `manifest.toml` だけ）は通った。
- **確かめていないこと。** `fukai/agent` など実物のパッケージ（K4-3）、全 `.beam` の一致（K4-4）、像の署名は開発用の鍵のまま。kite は走るたびに `~/.kite/runs/<id>/rootfs`（約 400 MB）を残す（kite 側の課題）。

## K4-3 の結果（2026-10-17）

fukai の実物のパッケージを、K4-2 の像（`sha256:0f5f221a…`）のゲストで作り、試験を流した。作業場の宣言は fukai の各リポジトリに置かず、作業場の側の宣言（NIV-06 の `[package] root`）で実物のソースを指した（niuv は腐海を知らない）。kite は 0b4a0351（`kite run` の終わりに根を消す）から作り直した。

- **合格の形（2 つの試験）。** ゲストの OTP 29.1.1・musl の Nim 2.2.12・gleam 1.19.1 で、`fukai/agent` の Gleam の試験が **32 件通り**（ホストの macOS でも 32 件）、`fukai/database` の `column_child` の試験が **10 件通った**（ホストでも 10 件）。K1 の基準（32・10）と同数で、K1 の OTP 27 でなく像の OTP 29 でも通った。ゲストの終了コードは 0（kite の `--exit-status`）。ゲストの試験の流しは、台本の準備（ソースの写し・子の置き）を含めて 50 秒。
- **niuv の Linux の目標を通して作れたもの。** Nim の子 3 つ（`column_child`、`sealer_child`、`blob_child`）は `niuv build … --target aarch64-linux-musl --in-builder` で作り、ホストが目録と SHA-256 を照らし直した。`sealer_child` は nim-hpke・nim-mlkem・tamayura-storage など 11 の Nim パッケージと、外の依存 3 つ（bearssl 0.2.13、nimcrypto 0.7.3、results 0.5.1。`[external] roots` に `~/.nimble/pkgcache`）を引く。ゲストのロック（`niuv lock --in-builder`）は 20 パッケージ・外の依存 3 つで 20 秒、`column_child` のビルドは 22 秒、`sealer_child` と `blob_child` は 60〜70 秒（C の libsodium を含む）。同じソースから 2 回作った `sealer_child` の SHA-256 は一致した（Nim の子の再現は K4-4 で改めて測る）。
- **niuv の外で行ったこと。** (1) Gleam の試験そのもの（`gleam test`）と `column_child` の試験の実行（niuv はビルドだけを受け持つ）。台本が、ro で渡したソースを rw のゲスト内の作業場へ写し、niuv が作った子（`/children`、ro）を置いて流す。(2) **`fukai/agent` の Gleam のビルド（`niuv build fukai-agent --target …`）はゲストで通らなかった**（下の「Gleam の path 依存」）。試験は `gleam test` が自分でビルドしたもので、niuv の目標を通した beam ではない。(3) Hex の写し（`gleam_stdlib`、`gleam_erlang`、`gleeunit` の 3 つ）は、ホストで repo.hex.pm から取り、`manifest.toml` の `outer_checksum` と SHA-256 が一致するのを確かめて置いた。
- **見つけた問題 1（fukai/store、直した）。** 中身のディレクトリ名が、Linux では Gleam の口・islands と食い違った。原因は `blob.nim` が `tamayura` の傘を取り込み、そこが出す大文字の `toHex` が、`./bytes` の小文字の `toHex` より先に選ばれていたこと（`blobs/9F59…`）。Gleam の `blob_name_to_hex` と islands の `wire.hex` は小文字。macOS の大文字小文字を区別しない置き場が隠していて、ゲストで `a_snapshot_whose_shards_are_not_at_hand_is_fetched_from_a_shard_source_test` が `NotFound` で落ちて見つかった（試験 31/32）。`bytes.toHex` を明示し、E テスト（FST-04）を足した。islands を Linux で動かす K5 の前に見つかったのは幸い。
- **見つけた問題 2（fukai/agent、直した）。** 版ごとの入れ替えの試験が読む `fixtures/v1`〜`v3` の `manifest.toml` が、agent が `fukai_column`・`fukai_store`・`gl_cbor_det` の path 依存を持つ前のまま古かった。きれいな木では `fukai_agent` がそれらを欠いてコンパイルされ、`Unknown module fukai_column` で落ちる。ホストで通っていたのは古い `build/` が残っていたため。`gleam deps download` で作り直した。
- **見つけた問題 3（niuv の宿題、直していない）。Gleam の path 依存と網なしの gleam。** gleam 1.19.1 は、path 依存を持つパッケージで `build/packages/<名前>.config_fingerprint` が無い（まっさらな作業場）と `manifest.toml` を古いとみなし、`manifest.toml` がロックしていても Hex のレジストリへ版を聞きに行く（`GLEAM_LOG=debug` に `manifest_outdated`）。網なしのゲストではここで `error sending request for url (https://repo.hex.pm/packages/…)` と落ちる。K4-2 で通ったのは path 依存の無い小さな例だったため。ホストで通るのは、網があるか、前の `build/` が残っているから。隔離した状態（`sandbox-exec` で網を断つ）でも再現し、指紋のファイルを置くと同じ木が網なしで通ることを確かめた。指紋は gleam の内部の値（18 桁ほどの 10 進の数。設定のファイルの SHA-256 や SipHash とは合わなかった）で、niuv が自分で書けない。ステージの木をゲストに渡して「`gleam export` を 1 回流して指紋を書かせ（これは網エラーで落ちる）、2 回目を流す」と、網なしで通り、**54 個の beam の SHA-256 が、ホスト（macOS、OTP 29）で niuv が作った 54 個と全部一致した**（K4-4 の入口の測定。台本は niuv の外）。この 2 回流しを `gleambuild.nim` の正式な手順にするかは設計の決定（落ちる 1 回目を許す正直さの扱い、別の道具の有無）で、しかもゲストの niuv は像の中の物なので、直すと像の作り直しが要る。この問題は下の「K4-3 の続き」で直した。
- **ディスク。** 始めに 18 GiB、終わりに 16 GiB 空き。ゲストの根は `kite run` の終わりに消えるので、ゲスト 1 回あたりの残りは約 8 KB（`runs/<id>/`）。

## K4-3 の続き（2026-10-17）: Gleam を `gleam compile-package` で作る

jasagiri が案 B を選んだ（fukai roadmap 0.1 章 121）。niuv が閉包の順に `gleam compile-package` をパッケージごとに呼ぶ（ADR-NIUV-0001 の NIV-16、NIV-17 と「採らなかった案」を書き直した）。gleam 自身の依存の解決（Hex への問い合わせ、`manifest.toml`、指紋）は通らない。新しい像は `niuv/builder-k4@sha256:40ede3aa423d3c065451d96cf9c1e32467b5549073ff7c3c6106a30d2aaf5107`（開発用の鍵で署名。作り方は `builder/records/build-record.md`）。

- **gleam 1.19.1 の `compile-package` で足りたこと。** `--target erlang --package DIR --out DIR --lib DIR --no-dev [--otp-app-names a=b,…]`。`--lib` に置いたコンパイル済みのパッケージだけが見える（宣言していない依存の import は `Unknown module`）。Erlang の FFI（`.erl`）は `ebin` に `.beam` として入り、`.app` も作られる。Hex のパッケージは、Hex のアーカイブ（`<OUTER_CHECKSUM>.tar` の中の `contents.tar.gz`）を展開した物をそのまま `--package` に渡せる。足りなかったこと: `<app>@@main` の入口モジュール（`gleam export erlang-shipment` が根に足す）を作らない。`--no-dev` でも `test/` の `.erl` は `ebin` に入る（`erlang-shipment` の道でも同じだった）。
- **(a) 旧い道との一致。** fukai/agent の閉包（ホスト）で、旧い道（`gleam export`）の 54 個と新しい道の 53 個を SHA-256 で照らした: **43 個が一致、10 個が違い、1 個（`fukai_agent@@main`）は新しい道が出さない。** 違う 10 個（`fukai_agent`、`fukai_agent@ask`、`fukai_agent@ledger`、`fukai_column`、`fukai_store`、`gl_hotswap`、`gl_hotswap@internal@raw`、`gl_mfa_supervisor`、`gl_mfa_supervisor@internal@callback`、`gleam@erlang@process`）は、`beam_lib` で欄ごとに比べると **`debug_info` の欄（10 個とも）と `Docs` の欄（6 個）だけ**が違い、コード・属性・輸入・輸出・リテラル・文字列・局所関数の欄は同じだった。違いは型変数の名前（旧い道 `'GHW'`、新しい道 `'UA'`）で、gleam が 1 つのプロセスの中で何を先に読んだかの内部のカウンタで決まる。合わせていない（`debug_info` を落とせば合うが、コードの欄の同一性を測る手がかりも失う）。NIV-17 の約束は niuv の道の中だけにした。新しい道の中では決まる: `--lib` に置く順を 3 通りに変えても同じ、場所の違う 2 か所のビルドで同じ。`--lib` に閉包の全部を置くと違う値になる（手で作った 1 回目の測定はそうだった）ので、各パッケージには依存だけを見せる。
- **(a) の判断（jasagiri 側の承認、2026-10-17）。** 違いが `debug_info` と `Docs` に限り、コード以下の欄が同じこと、新しい道の中では場所・順によらず同じこと、ホストとゲストで 53 個が一致したことをもって合格とする。`debug_info` は落とさない。比べた欄（旧い道と新しい道で違った 10 個について）:

  | 欄 | 結果 |
  |---|---|
  | `Code`、`Attr`、`ImpT`、`ExpT`、`LitT`、`StrT`、`LocT`、atoms、compile_info | 10 個とも同じ |
  | `Dbgi`（debug_info） | 10 個とも違う（型変数の名前のみ） |
  | `Docs` | 6 個で違う（同上） |

- **(b) 網を断ったホスト。** `sandbox-exec` で網を断って `niuv build fukai-agent` が通り、網ありの結果と全 `.beam` が一致した（Hex の写しは、ホストの gleam が `~/Library/Caches/gleam` に持つ物）。
- **(c) niuv の試験。** `tests/test_all.nim` は 308 件・失敗 0・警告 0（Gleam の試験は、Hex の写し・展開の拒み・`tar` の起動名を含め 27 件）。`tests/acceptance/test_fukai_agent.nim`（NIV-17、場所に依らない一致と GPL の拒み）は緑。`tests/acceptance/test_builder_guest.nim`（実物の kite と新しい像）も緑。
- **ゲストの `niuv build fukai-agent --target aarch64-linux-musl --in-builder`。** 網なしで通り、ホストの照らし直しが通った（53 モジュール、`gleam_stdlib` と `gleam_erlang` は Hex の写しから）。ゲストの 53 個の SHA-256 は、macOS のホストの niuv が作った 53 個と**全部一致**した（K4-4 の入口の測定）。
- **(4) niuv が作った beam で agent の試験。** 流せた: **32 件通った**。ゲストの台本が、niuv が作ってホストが照らし直した `beam/<アプリ>/` を `erl -pa` で先頭に置き、その上で試験のモジュール・gleeunit・fixtures だけを `compile-package` で作って `fukai_agent_test:main()` を呼んだ（`code:which` で、`fukai_agent`・`fukai_column`・`fukai_store`・`gl_port`・`gleam@list` が niuv の beam であることを確認）。niuv の外の足場: 試験のモジュールは `--no-dev` なしの `compile-package` で作る（niuv は dev のコードを作らない）。そのとき同じパッケージの `src` も作り直されるが、読み込まれるのは niuv の beam。
- **直したこと（途中で見つけた）。** `findExe` は既定でシンボリックリンクをたどり、Alpine の `tar` は busybox へのリンクなので、`busybox -tf …`（`applet not found`）で起動していた。リンクをたどらないようにし、複数のプログラムを 1 つにまとめた実行ファイルへのリンクの `tar` を使う E テストを足した（赤を確かめてから直した）。
- **旧い像の扱い。** K4-2 の像（`sha256:0f5f221a…`）は `gleam export` の道で、path 依存のある Gleam パッケージを網なしで作れない。`[builder]` の pin は新しい像へ移す。

## K4-4 の結果（2026-10-17）: 断る場合を実物の kite と像で確かめた。K4 を閉じる

偽の kite でしか確かめていなかった断る場合を、kite-container 0b4a0351 の木から作った kite 0.2.0 と像 `sha256:40ede3aa…` で確かめ、`tests/acceptance/test_builder_guest.nim` の `N-K4-4 acceptance` に E テストとして足した（規則 NIV-26、27）。受け入れは 5 件通り、失敗 0、コンパイラの警告 0。`test_all` は 308 件・失敗 0・警告 0（`src` は K4-3 の最後のコミットから変わっていない）。

| 場合 | 結果（終了コード 1 = niuv の誤り） |
|---|---|
| (1a) ロックの `[builder]` を、kite の保存先にある別の像（K4-2 の `0f5f221a…`）へ書き換え、今の像の署名を渡す | kite が断る: `PIN-08 image …@sha256:0f5f221a…: the signature is valid but vouches for something else`。niuv は `the builder guest ended with status 1` として伝える。出力先に目録は無い |
| (1b) kite が見たことの無い digest | 同じ文面で断る（署名の確かめが先） |
| (2a) 同じ版 0.2.0 の別の kite の実行ファイル | niuv が kite を起こす前に断る: `tool kite 0.2.0: the executable … has SHA-256 fc50aa35a5e8 but niuv.lock pins 710f96e918f2`。呼び出しの控えに `run` は無い |
| (2b) 版の違う kite（`--version` が 0.1.9） | 起こす前に断る: `tool kite: declared 0.2.0 but … is 0.1.9` |
| (3a) 署名を一度も見ていない kite の保存先 | kite が断る: `PIN-08 … no signature (none in the store; pass one with --signature:PATH)` |
| (3b) 存在しない署名ファイル | `PIN-08 … no signature (… does not exist)` |
| (3c) 信じる鍵の一覧に無い鍵の署名 | `PIN-08 … the signature was made by a key kite does not trust (seWrongKey; 1 keys tried)` |
| (4) ゲストが目録に無いファイルを、出力先の直下・`beam/demo/` に置く | ホストが断る: `the output holds evil.txt, which the manifest does not list` など |
| (5) ゲストの書き換え: 目録の載せた Nim の実行ファイルに 1 バイト足す | `the host hashed … but the manifest says …` |
| 同: 実行ファイルをシンボリックリンクに替える | `… is not a regular file` |
| 同: `beam/demo/` をシンボリックリンクに替える | `the manifest lists the beam 'demo' but 0 applications … have it (one is required)` |
| 同: 目録を壊れた中身にする / 消す | `manifest: not deterministic CBOR: truncated` / `the guest left no …/niuv.manifest.cbor` |
| 同: 目録の SHA-256 だけ、大きさだけを偽る | `the host hashed … but the manifest says 000…` / `is 156792 bytes but the manifest says 156793` |
| 同: 目録に `../escape` の名前、別のパッケージ名、無い beam を載せる | `which is not a file name` / `the guest built other 0.1.0, not demo 0.1.0` / `lists the beam 'ghost' but 0 applications … have it` |

- 見つけたこと 1: `--signature` を渡さなくても、kite は一度確かめた署名を自分の保存先（`~/.kite/signatures`）に持つので、像は起動する。これは仕様どおりで、「署名なし」の確かめには、署名を見ていない保存先が要る（テストはそれを作る）。niuv が署名を強制するのではなく、署名の確かめは kite の PIN-08 が受け持つ（NIV-28）。
- 見つけたこと 2（直した）: `lock --in-builder --builder X` は、既にあるロックの別の像を黙って上書きしていた。いまは断り、`--repin-builder` を要求する（NIV-26）。ホストのコマンドラインに、ロックと違う digest を渡して `build` する口は無い。ロックを手で書き換えた場合は (1a)(1b) のとおり、署名の確かめが断る。
- ゲストの出力の書き換えは、像を変えず、ゲストの台本（`/ctl/run.sh`）が `/out` に honest な出力の写しを作って書き換え、ホストの `verifyBuilderOutput` が 12 通りすべてを断った。受け入れた物は 0。

**K4 全体（2026-10-17）。** K4-0（kite の mount と像の取り込み）、K4-1（像）、K4-2（niuv の目標・ロック・目録・ホストの再照合）、K4-3（fukai の実物をゲストで作って試験: agent 32 件、`column_child` 10 件、niuv が作った beam での試験 32 件）、K4-4（断る場合）が揃った。像の再現は約束せず、`[builder]` は `sha256:40ede3aa…`（開発用の鍵で署名）に固定する。残る物: 像の署名の本物の鍵（fukai roadmap 118）、sigstore による上流の確かめ、x86・glibc の目標、Nim の実行ファイルのゲスト間の一致（NIV-30 は beam だけを約束する。beam はホストとゲストで 53 個一致した）。

## K5 の続き（2026-10-21）: ビルド用の像を `kite pack` で派生させる（fukai roadmap 0.1 章 128）

K4-3 の像 `sha256:40ede3aa…` の中の niuv は NIV-33 の前の物で、ゲストとホストが作業場を指紋に入れるかどうかで食い違い、`services/island-node/image/` にロックをコミットできなかった（K5-1c）。また、ゲストのホスト名が `(none)` のとき、名前の解決に 5 秒かかる。像を podman で作り直さず、今の像の木の 3 つのファイルを差し替えて、`kite pack`（ADR-KITE-0011）で 1 層の像にした。

### `Containerfile` をどうするか（選択肢と比較）

- 要件: 差し替えるのは niuv・入口・`/etc/hosts` の 3 つで、ほかは 1 バイトも変えない。podman を使わない（128）。
- (A) `Containerfile` を正のまま、変えるたびに全部を作り直す。niuv の 1 行の変更でも 400 秒かかり、作るたびに全層の digest が変わる。「ほかは変わっていない」を保てない。
- (B) 派生の道だけにして `Containerfile` を消す。Alpine・Nim・OTP・gleam の最初の像は、派生では作れない（土台が無い）。
- (C) `Containerfile` は「最初の像を作る道」として残し、以後は派生する。変わる物（niuv・入口・hosts）だけが差し替えで変わり、ほかは前の像の木そのもの。
- (C) の代償: 今の像を `Containerfile` が再現しない（`/etc/hosts` の行は派生だけが足し、`kite pack` は像の環境変数・コマンドの設定も書かない）。ただし K4-1 から像の再現は約束していない。
- 結論: (C)。`builder/Containerfile` の先頭、`builder/README.md`、`builder/records/build-record.md` に、どの像がどちらの道かを書いた。

### 手順と結果

- **新しい niuv**: 今の像のゲストで `niuv build niuv --target aarch64-linux-musl --in-builder` が通った（niuv `591200c8` の木）。niuv が自分自身をゲストで組めた。ELF（aarch64、musl の動的リンク）1,073,152 バイト、SHA-256 `bca4ca6e…`。通すために niuv の宣言を 2 点直した（`dfa42652`）。parsetoml の source を `…/parsetoml.git` に（nimble の cache は `parsetomlgit` と名付ける）、parsetoml と checksums に `src = "src"` を（無いと `cannot open file: checksums/sha2`）。niuv が自分を組む道は、この宣言の誤りで一度も通っていなかった。
- **`builder/derive.sh`**: 土台の像の木を kite の読み手で取り出し（`tools/imagetree.nim unpack`）、3 つを差し替え、差が 3 行だけであることを確かめ、`kite pack` を 2 回（同じ digest を要求）、`kite import`、取り込んだ像を取り出して木と照らし、署名する。
- **新しい像** `niuv/builder@sha256:1d1da016041cb2d144308049b9b965e5a5baa31214c31e358e829b1e112a74f6`（開発用の鍵で署名。層 1 枚、展開後 6234 エントリ）。同じ木からの 2 回の pack で digest が一致し、`derive.sh` を 2 回（kite の zippy が違う 2 つの版）流しても同じ digest だった。土台の木との差は `/usr/local/bin/niuv`・`/usr/local/bin/builder-run`・`/etc/hosts` の 3 行だけ。SHA-256 は `builder/records/replaced-sha256.txt`。
- **途中で見つけた kite の欠陥**: zippy 0.10.18 の inflate が arm64 の macOS で、展開後が約 256 MiB を超える層を読み違え（`Checksum verification failed`）、この像の層（407 MB）を kite 自身が展開できなかった。kite-container `8d9ac045` が zippy を 0.10.20 に上げて直した。`kite pack` の digest は変わらない。
- **入口とホスト名**: `builder-run` が先頭で `hostname niuv-builder` を呼び、像の `/etc/hosts` の 127.0.0.1 の行に同じ名前を足した（対。島の像の入口と同じ手当て）。`inet:gethostbyname` の時間は、土台の像で 5014 ms（名前 `(none)`）、新しい像で 2 ms。
- **K4 の受け入れの試験**（`tests/acceptance/test_builder_guest.nim`）は新しい像で 5 件通った。`tests/test_all.nim` は 319 件・失敗 0・警告 0。
- **island-node**: `image/` を作業場にして、`niuv lock --in-builder`（40 パッケージ、外の依存 6）、`niuv build island-node`、`niuv build island-boot` が、`image/` を除いた複製なしで通り、ホストの再照合も通った。ロックは island-node にコミットした（`ab677c51`）。ロックがまだ無かったので `--repin-builder` は要らなかった（NIV-26 が要るのは、別の像を pin しているロックだけ）。
- **ゲストの起動**: `kite pack` は owner・時刻・hard link・拡張属性を書かず、像の設定（環境変数・コマンド）も空にする。ゲストはこの像で起動し、受け入れの試験が通った。環境変数に頼る道が出たら、像の側で足す。

### 残るもの

- 像の署名は開発用の鍵のまま（fukai roadmap 118）。
- `tools/imagetree.nim` の `list` は、island-node の `image/tools/imagetree.nim` とほぼ同じ物。kite が木を並べる口を持てば一本にできる（Future:）。
- 派生の鎖が長くなる。最初の像から作り直すときは `build.sh` から始め、`derive.sh` の差し替えを順に当てる。

## 作り直し（2026-10-22、足場の消失による）

2026-10-22、足場（組んだ kite と kite_sign、開発用の鍵、kite の HOME、署名した像 `niuv/builder@sha256:1d1da016…` とその土台 `niuv/builder-k4@sha256:40ede3aa…`、署名、initrd、niuv）が一時ディレクトリごと消えた。署名した鍵が無いので、消えた像は使えない（kite は署名を確かめる）。jasagiri の決定（2026-10-22、案 (a)）: podman を使わない（fukai の決定 124）。kite の Alpine の像を網つきのゲスト（`--net`）で起こして像を組む。置き場は、どのリポジトリにも入らず消えない `~/.local/share/godsgolem/kite-site/`（0700、鍵は 0600）。

- **新しい像**: `niuv/builder@sha256:4131aa3a16d670c15ca4ec9fa5e3d51c5720b9cdca983c7f7af5194d225bf079`（土台 `niuv/builder-base@sha256:83187985f489b596d3ccd33a7173489b3d8aa8b02afe8247486ca0c376c583ea`、開発用の鍵 `godsgolem-kite-site-dev`（kid `c7096c88…`）で署名）。層 1 枚、6234 エントリ（前の像と同じ数）。同じ木から 2 回 `kite pack` して digest が一致した（土台、派生の像とも）。
- **道**: `builder/bootstrap-alpine.sh`（段: site・kite・assets・initrd・base・builder・site-env）。kite は kite-container の最後のコミット済みの版（`8489bb0d`）を `jj file show` で取り出して組む（作業場の未コミットの変更を読まない）。initrd は `guest/Dockerfile` の中身を Alpine 3.22 のゲストで同じ手順にした（`bootstrap/guest-initrd.sh`）。土台の像は `Containerfile` の中身を同じ版・同じハッシュで、`bootstrap/guest-base.sh` が網つきのゲストで組む（入力の tarball は `sha256sum -c`、Nim・OTP を組み、`apk add --root` で固定の土台の木に実行時の apk を足す）。木はゲストから tar で出し、ホストで 2 回 pack して digest の一致を要求し、取り込んで署名する。続く niuv の組み直しと派生は `derive.sh`（前と同じ作法）。網があるのはこの 2 つのゲスト（と kite 自身の Alpine の pull。digest で固定）だけ。
- **前の像との違い**: (1) podman でなく Alpine のゲストで組んだ。(2) 土台の像は `niuv/builder-k4` の名前をやめ `niuv/builder-base`（K4 の像ではなくなったため）。(3) 土台の像が最初から今の `builder-run` を持つので、派生で変わるのは `/etc/hosts` と niuv の 2 つだけ（`derive.sh` は、`/etc/hosts` と niuv が変わり、ほかが変わらないことを要求し、`builder-run` が変わるのは許す形にした）。(4) **Alpine の索引から `musl-1.2.6-r2` と `musl-dev-1.2.6-r2` が消え（r3 だけ）、記録の版の組を再現できなかった**。この 2 つだけ r3 にし、`records/apk-info.txt` を直した（ほかの 38 個は記録のとおり一致）。(5) 入った物のバイト列は前の像と同じにならない: Nim（`opt/nim/bin/nim` `0bf3fbb1…`）、OTP（`beam.smp` `5796968a…`、`erlexec` `009dcb04…`）。gleam は同じ（配布物）。新しい niuv は `fc21b322…`（niuv `7a3f3946` の木）。
- **ゲストの kernel**: `Image-custom`（2026-10-14）には nf_tables が無く、kite の init が `--net` のとき firewall を読めず止まる（`Unable to initialize Netlink socket`）。`--net` のゲストだけ、netfilter 入りの `Image-vsock`（kite-container `build/assets`、2026-10-22 の build、sha256 `f5c2660e…`）の複製を使った。網なしのゲスト（ビルド・受け入れの試験）は `Image-custom` で通る。
- **確かめたこと**: 土台の像・最後の像とも `run-selftest.sh`（13 項目 ok、`RESULT ok`）。K4 の受け入れの試験（`tests/acceptance/test_builder_guest.nim`）5 件が通った。`bootstrap-alpine.sh all` を別の置き場で最初から流し直し、最後まで通ることを確かめた（その像の digest は、土台 `c93e69d3…`、派生 `8a57e197…` で、上の像とは違う）。**同じ入力からの組み直しは同じ digest にならない**（前と同じく、再現は約束していない。pin は 1 つの像の digest）。
- **確かめていない**: 組み直しの digest が揃わない理由（OTP・Nim の成果物のどこが違うか）。Alpine 3.22 の initrd の apk が 2026-10 の版であること以外の initrd の同一性（`initramfs-kite` は `319ce1f9…`、前の物とは別）。

## 決めてほしい点

（2026-10-17、jasagiri が 1〜9 を推奨どおり承認。以下は承認された案の理由として残す。）

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
- 未確認で残るもの: offline の gleam（K4-3）、ツールチェーンの再現（K4-4）、上流の sigstore の検証。K4-1 までに確かめた物（podman の層が gzip、署名の名前に `/` を含めると通る、ゲストの終了コード、OTP・Nim のビルドの時間と大きさ）は「K4-1 の結果」に書いた。

## 訂正 (2026-10-28)

- NIV-24 の「クロスコンパイルをしない」は、`niuv build` の目標についての規則として残る。`niuv wasm` の wasm32-wasip1（ADR-NIUV-0003）は、ロックも目録も持たない別の道で、その外にある（代表の決定、2026-10-28。ADR-NIUV-0003）。
