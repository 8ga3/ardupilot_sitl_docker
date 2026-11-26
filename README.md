# Ardupilot SITL Docker

## 概要

このリポジトリは、ArduPilot SITL (Software In The Loop) 環境をDockerコンテナで簡単にセットアップし、起動するためのものです。

### メリット

- SITLに特化した軽量なDockerイメージを提供します。（サイズ：約345MB、詳細は[イメージサイズの比較](#イメージサイズの比較)を参照）
- 軽量化するため、Multi-stageビルドを採用しています。
- Docker Composeを使用して、簡単にビルドと起動が可能です。
- amd64およびarm64アーキテクチャに対応しています。
- ちょっとだけセキュリティ対策を施しています。（非rootユーザーでの実行、不要なパッケージの削除など）

### デメリット

- sim_vehicle.pyと関連スクリプト以外はインストールされません。
- BlimpとAntennaTrackerは使用できません。（[対応している機体](#対応している機体)を参照）
- MAVProxyでGUIを必要とする機能（地図表示、コンソールなど）は動作しません。
- FlightGearなどの外部シミュレーターとの連携はサポートしていません。
- MAVLinkのdialectは `all` / `ardupilotmega` / `common` / `minimal` / `standard` のみ同梱しています。それ以外（`storm32`、`paparazzi`など）は使用できません。
- MAVProxyのcesiumモジュールは使用できません。

Author: [@8ga3](https://github.com/8ga3)

---

## ビルドと起動

コンテナはバックグラウンドで起動します。

```sh
docker compose up -d
```

### 別のバージョンのArduPilotでビルドする

ビルドするArduPilotのバージョンは、`Dockerfile`の`ARG ARDUPILOT_VERSION`で指定しています。値は[ArduPilotリポジトリ](https://github.com/ArduPilot/ardupilot)のブランチ名またはタグ名です。

`Dockerfile`を書き換えずに一時的に別のバージョンでビルドする場合は、`--build-arg`で上書きします。

```sh
docker compose build --build-arg ARDUPILOT_VERSION=ArduPilot-4.6
docker compose up -d --no-build
```

`compose.yaml`で`pull_policy: build`を指定しているため、`--no-build`を付けずに`docker compose up -d`を実行すると、`Dockerfile`のデフォルトのバージョンで再ビルドされ、イメージが上書きされます。別のバージョンのイメージを使い続ける間は、`--no-build`を付けて起動してください。

恒久的にバージョンを変更する場合は、`Dockerfile`の`ARG ARDUPILOT_VERSION`の値を書き換えてください。

---

## ArduPilot SITL 起動

基本的にGitHubをクローンした後の手順と同じです。`sim_vehicle.py`を実行する際に、`docker exec -it ardupilot-sitl`を付与してコンテナ内で実行します。

ポイント

- `--no-rebuild`オプションを付与して、ビルドをスキップします。
- `--mavproxy-args`オプションで、MAVProxyの引数を指定します。`--out udp:host.docker.internal:14550`のように、`host.docker.internal`を使用してホスト側へMAVLinkメッセージを送信します。

```sh
docker exec -it ardupilot-sitl \
  ./Tools/autotest/sim_vehicle.py \
  --vehicle ArduCopter \
  --frame X \
  --custom-location 35.54863,139.78096,4.2,45 \
  --no-rebuild \
  --wipe-eeprom \
  --mavproxy-args="--out udp:host.docker.internal:14550 --state-basedir=/tmp/mavlink-sitl"
```

---

## 対応している機体

`sim_vehicle.py`の`--vehicle`に指定できる機体のうち、以下のバイナリをビルドしてイメージに含めています。

| `--vehicle`の値 | デフォルトの`--frame` | バイナリ | 対応 |
| --- | --- | --- | :---: |
| `ArduCopter` | `quad` | `arducopter` | ○ |
| `Helicopter`（または `ArduCopter` + `--frame heli`） | `heli` | `arducopter-heli` | ○ |
| `ArduPlane` | `plane` | `arduplane` | ○ |
| `Rover` | `rover` | `ardurover` | ○ |
| `ArduSub` | `vectored` | `ardusub` | ○ |
| `Blimp` | `Blimp` | `blimp` | × |
| `AntennaTracker` | `tracker` | `antennatracker` | × |

- ローバーの機体名は`ArduRover`ではなく`Rover`です。（`ArduRover`を指定するとエラーになります）
- BlimpとAntennaTrackerは使用頻度が低いため、イメージサイズとビルド時間を抑える目的で意図的に除外しています。必要な場合は、`Dockerfile`のbuilderステージに`RUN ./waf blimp`または`RUN ./waf antennatracker`を追加し、実行ステージの`mkdir`に`/app/Blimp`または`/app/AntennaTracker`を追加してください。（1機体あたり約3MB増加します）
- 指定できるフレームは`docker exec ardupilot-sitl ./Tools/autotest/sim_vehicle.py --list-frame <機体>`で確認できます。

### 動作しないフレーム

対応している機体でも、以下のフレームは動作しません。

- 外部シミュレーターが必要なフレーム（`gazebo-*`、`airsim-*`、`jsbsim`、`scrimmage-*`、`IrisRos`、`last_letter`、`CRRCSim`、`calibration`）
- AP_Periphのバイナリが必要なフレーム（`quad-can`、`quadplane-can`）

上記以外の72フレームは、起動してMAVProxy経由でHEARTBEATと位置情報を受信できることを確認しています。（arm64、ArduPilot-4.7）

---

## 複数のインスタンスのArduPilot SITLを起動

- システムID (`--sysid`) とインスタンス番号 (`--instance`) をそれぞれ変更して起動します。
- `--mavproxy-args`オプションで、MAVLinkメッセージの送信先ポート(`--out`)と状態保存ディレクトリ(`--state-basedir`)を変更します。
- QGrroundControlで2つ目以降のデフォルト値以外のインスタンスに接続する場合、アプリケーション設定の「通信リンク」に、対応するUDPポートを追加してください。

以下、2つのインスタンスを起動する例です。

1つ目のシェル

```sh
docker exec -it ardupilot-sitl \
  ./Tools/autotest/sim_vehicle.py \
  --vehicle ArduCopter \
  --frame X \
  --custom-location 35.54863,139.78166,4.2,45 \
  --no-rebuild \
  --wipe-eeprom \
  --sysid=1 \
  --instance=0 \
  --mavproxy-args="--out udp:host.docker.internal:14550 --state-basedir=/tmp/mavlink-sitl-1"
```

2つ目のシェル
QGroundControlで接続する場合、UDPポート14560を指定してください。

```sh
docker exec -it ardupilot-sitl \
  ./Tools/autotest/sim_vehicle.py \
  --vehicle ArduCopter \
  --frame X \
  --custom-location 35.54821,139.78196,4.2,90 \
  --no-rebuild \
  --wipe-eeprom \
  --sysid=2 \
  --instance=1 \
  --mavproxy-args="--out udp:host.docker.internal:14560 --state-basedir=/tmp/mavlink-sitl-2"
```

---

## Dockerイメージのエクスポート

以下のコマンドで、Dockerイメージをtar.gz形式でエクスポートできます。

```sh
docker save ardupilot-sitl:latest | gzip > ardupilot-sitl.tar.gz
```

---

## Linuxでの注意点

Linuxホストで実行する場合、`host.docker.internal`が解決できない場合があります。[公式ドキュメント](https://docs.docker.com/desktop/features/networking/#using-docker-desktop-with-a-proxy)

1. Docker Desktop for Linux の場合
   - デフォルトで有効です。
   - Windows版やMac版の Docker Desktop と同様に、設定なしで host.docker.internal を使用してホスト側へアクセスできます。
2. Docker Engine on Linux (ネイティブ版) の場合
   - デフォルトでは無効（解決されません）。
   - Linuxサーバーや、WSL2の中に直接 apt 等でインストールした Docker Engine がこれに該当します。
   - ただし、Docker バージョン 20.10 以降 であれば、コンテナ起動時に以下のオプションを付与することで手動で有効化できます。

```sh
docker run --add-host=host.docker.internal:host-gateway <image>
```

`compose.yaml`をオーバーライドするサンプルファイルを用意しています。コピーして使用してください。Docker Composeで起動するとき、`compose.override.yml`は自動的に読み込まれます。

```sh
cp compose.override.linux.example.yml compose.override.yml
```

---

## イメージサイズの比較

`docker images` での実測値です。（arm64、ArduPilot-4.7、2026-11-26時点）

| 構成 | ディスク使用量 | 圧縮サイズ | 最適化なし比 | 従来比 |
| --- | ---: | ---: | ---: | ---: |
| 最適化なし（ビルド環境をそのままイメージ化） | 4.71GB | 1.4GB | - | - |
| 従来（Multi-stageビルドのみ） | 627MB | 129MB | -87% | - |
| 現在（Multi-stageビルド + 今回の最適化） | 343MB | 77.2MB | -93% | -45%（-284MB） |

「最適化なし」は、本Dockerfileのbuilderステージ（`docker build --target builder`）をそのままイメージにした場合のサイズです。「最適化なし」と「従来」はHelicopter用バイナリを追加する前の計測値で、「現在」にはHelicopter用バイナリ（約4MB）と`sim_vehicle.py`用の追加ファイルを含みます。

### 今回の最適化の内容

| 内容 | 削減量（概算） | 影響 |
| --- | ---: | --- |
| MAVProxyのcesiumモジュールのWebアセットを削除 | 114MB | なし（依存する`tornado`が未インストールのため、もともと動作しない） |
| 使用しないMAVLink dialectを削除 | 約70MB | `all` / `ardupilotmega` / `common` / `minimal` / `standard` 以外のdialectは使用不可 |
| Pythonバイトコード（`.pyc`）の事前コンパイルをやめる | 63MB（上記2項目と一部重複） | Python起動時に毎回コンパイルするため、MAVProxyのimportが約0.2秒遅くなる |
| numpyのテストコードを削除 | 17MB | なし |
| ベースイメージを`python:3.13-slim`から`debian:trixie-slim` + aptの`python3`に変更 | 約10MB | Pythonが3.13.18から3.13.5（Debian同梱版）になる |
| SITLバイナリをstrip | 5MB | クラッシュ時のバックトレースにシンボル名が出ない |
| venvのactivateスクリプト、lxmlのヘッダファイルを削除 | 約1MB | なし |

現在のイメージの内訳は、Debianベース 110MB、Python等のaptパッケージ 46MB、Python仮想環境 88MB、SITLバイナリ（5種） 21MBです。

---

## シンプルなDockerファイル

Multi-stageビルドと比較用に、シンプルなDockerfileも用意しています。ビルドサイズは大きくなりますが、理解しやすい構成です。
simpleディレクトリにあります。

---

## さいごに

このリポジトリをベースに、必要に応じて機能を追加・カスタマイズしてご利用ください。

---

## ライセンス

MIT License
