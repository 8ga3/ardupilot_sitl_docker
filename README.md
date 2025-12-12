# Ardupilot SITL Docker

## 概要
このリポジトリは、ArduPilot SITL (Software In The Loop) 環境をDockerコンテナで簡単にセットアップし、起動するためのものです。

### メリット
- SITLに特化した軽量なDockerイメージを提供します。（サイズ：約440~620MB）
- 軽量化するため、Multi-stageビルドを採用しています。
- Docker Composeを使用して、簡単にビルドと起動が可能です。
- amd64およびarm64アーキテクチャに対応しています。
- ちょっとだけセキュリティ対策を施しています。（非rootユーザーでの実行、不要なパッケージの削除など）

### デメリット
- sim_vehicle.pyと関連スクリプト以外はインストールされません。
- MAVProxyでGUIを必要とする機能（地図表示、コンソールなど）は動作しません。
- FlightGearなどの外部シミュレーターとの連携はサポートしていません。

Author: [@8ga3](https://github.com/8ga3)

---

## ビルドと起動
コンテナはバックグラウンドで起動します。

```sh
docker compose up -d
```

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

## シンプルなDockerファイル

Multi-stageビルドと比較用に、シンプルなDockerfileも用意しています。ビルドサイズは大きくなりますが、理解しやすい構成です。
simpleディレクトリにあります。

---

## さいごに

このリポジトリをベースに、必要に応じて機能を追加・カスタマイズしてご利用ください。

---

## ライセンス
MIT License
