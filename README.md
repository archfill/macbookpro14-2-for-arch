# MacBook Pro 14,2 for Arch Linux

MacBook Pro 14,2（2017 13インチ Touch Bar）に Arch Linux をインストールする際のセットアップガイド。

## ハードウェア情報

| 項目         | 詳細              |
| ------------ | ----------------- |
| モデル       | MacBookPro14,2    |
| 年式         | 2017 Mid          |
| サイズ       | 13インチ          |
| Touch Bar    | あり              |
| Wi-Fiチップ  | Broadcom BCM43602 |
| CPU          | Intel             |
| 対象 OS      | Arch Linux        |
| 対象カーネル | linux / linux-lts |

## 事前準備

`yay`（AUR ヘルパー）が必要なセットアップがある。未インストールの場合は先に導入する。

```bash
# yay のインストール
sudo pacman -S --noconfirm base-devel git
git clone https://aur.archlinux.org/yay.git /tmp/yay
cd /tmp/yay && makepkg -si --noconfirm
```

## セットアップ手順

### 一括セットアップ

```bash
./scripts/setup.sh
sudo reboot
```

各セクションを yes/no で選択しながら実行できる。個別に実行する場合は以下の手順を参照。

---

### 1. 汎用パッケージ（バッテリー・明るさ・ファン）

```bash
./scripts/setup-base.sh
```

### 2. Wi-Fi（Broadcom BCM43602）

MacBook の Broadcom チップはデフォルトドライバでは接続が不安定。ドライバ差し替えと送信電力の制限、5GHz 用 NVRAM ファイルの導入が必要。

#### セットアップ（自動）

```bash
./scripts/setup-wifi.sh
sudo reboot
```

スクリプトが行うこと:

1. NVRAM ファイル（`brcmfmac43602-pcie.txt`）を取得・インストール → 5GHz 有効化
2. 送信電力制限サービス（`set-wifi-power.service`）を配置・有効化

再起動後、5GHz の確認：

```bash
iw phy phy0 info | grep "Band 2"
```

> CLM blob（`brcmfmac43602-pcie.clm_blob`）は Broadcom の配布制限により公式リポジトリに存在しない。
> 未導入でも主要な 5GHz チャンネル（ch36/40/44/48）は問題なく使用できる。
> BCM43602 はカーネル内で `BRCMF_FW_DEF`（CLM blob 不要）で定義されており、警告ログは非致命的。

#### トラブルシューティング

```bash
# 再起動後も 5GHz が表示されない → NVRAM が正しくロードされているか確認
sudo dmesg | grep -i brcm

# ドライバ再ロード時は brcmfmac_wcc を先に外す（依存関係）
sudo rmmod brcmfmac_wcc brcmfmac && sudo modprobe brcmfmac

# macaddr がズレている場合は NVRAM を再生成
IFACE=$(basename $(readlink -f /sys/class/net/*/device/driver/../.. | grep brcmfmac | head -1)/net/*)
MACADDR=$(ip link show "$IFACE" | awk '/ether/{print $2}')
sudo sed -i "s/macaddr=.*/macaddr=${MACADDR}/" /lib/firmware/brcm/brcmfmac43602-pcie.txt
sudo sed -i "s/macaddr=.*/macaddr=${MACADDR}/" \
  "/lib/firmware/brcm/brcmfmac43602-pcie.Apple Inc.-MacBookPro14,2.txt"
```

### 3. Touch Bar

MacBook Pro 14,2 の Touch Bar は Apple T1（iBridge）チップ経由で USB 接続されている。
[roadrunner2/macbook12-spi-driver](https://github.com/roadrunner2/macbook12-spi-driver) をベースに、**kernel 6.17 で発生するデッドロック問題を修正**したパッチ済みドライバをこのリポジトリに同梱している。

#### セットアップ（自動）

```bash
sudo pacman -S --noconfirm dkms
./scripts/setup-touchbar.sh
sudo reboot
```

スクリプトが行うこと:

1. 既存の DKMS 登録をクリーンアップ
2. `driver/touchbar/` のソースを `/usr/src/appleibridge-0.1/` にコピー
3. DKMS でビルド＆インストール
4. udev ルール（`91-apple-touchbar.rules`）を配置
5. modprobe オプション（`apple-touchbar.conf`）を配置

#### fn キーモード

デフォルトは **ファンクションキー（F1〜F12）表示、fn 長押しで特殊キーに切替** に設定している。
変更する場合は `/etc/modprobe.d/apple-touchbar.conf` の `fnmode` を編集:

| fnmode | 動作                                                                  |
| ------ | --------------------------------------------------------------------- |
| `0`    | 常にファンクションキー                                                |
| `1`    | デフォルト：特殊キー、fn で切替（上流デフォルト）                     |
| `2`    | デフォルト：ファンクションキー、fn で切替（本リポジトリのデフォルト） |
| `3`    | 常に特殊キー                                                          |

#### トラブルシューティング

```bash
# Touch Bar が表示されない場合、手動でモジュールをロード
sudo modprobe apple-ibridge
sudo modprobe apple-ib-tb
sudo modprobe apple-ib-als

# カーネルログでエラーを確認
sudo dmesg | grep -i -E 'ibridge|touchbar|apple'

# DKMS ビルド状態を確認
dkms status

# usbmuxd が iBridge と競合する場合は停止
sudo systemctl stop usbmuxd
```

### 4. Bluetooth

追加設定不要。標準で動作する。HID デバイス（マウス・キーボード）はもちろん、**A2DP（スピーカー・ヘッドフォン）・HFP（ハンズフリー）も動作確認済み**。

```bash
# 状態確認
bluetoothctl show
```

> **BCM.hcd ファームウェアは不要**: 起動時に `BCM: firmware Patch file not found` ログが出るが無害。
> T1（iBridge）チップが起動時に BCM20703A2 へ適切なファームウェアをロード済みのため、
> Linux 側からの追加パッチは不要（むしろ適用しようとすると `fc4c failed (-16)` でチップが壊れる）。
> BCM.hcd を `/lib/firmware/brcm/` に置いてはいけない。

### 5. タッチパッド

タップ・スクロール・ジェスチャーは標準で動作する。ただしデフォルト状態ではタイピング中にタッチパッドが誤反応することがある。

#### タイピング中の誤反応修正（DWT）

`applespi` ドライバが Keyboard の vendor ID を `0x0000` で報告するため、libinput が内蔵キーボードと認識せず Disable-While-Typing（DWT）が正しくペアリングされない。カスタム quirk で修正する。

```bash
./scripts/setup-touchpad.sh
sudo reboot
```

> 再起動後、タイピング中のタッチパッド誤反応が改善される。

### 6. オーディオ

標準カーネルドライバ（`snd_hda_codec_cs8409`）では内蔵スピーカーが動作しない。
[davidjo/snd_hda_macbookpro](https://github.com/davidjo/snd_hda_macbookpro) のパッチ済みドライバが必要。

```bash
./scripts/setup-audio.sh
sudo reboot
```

スクリプトが行うこと:

1. `snd_hda_macbookpro` をクローン
2. DKMS でビルド＆インストール（カーネル更新時に自動再ビルド）

再起動後の確認：

```bash
sudo dmesg | grep -i "patch_cs8409\|APPLE"
# "Primary patch_cs8409 NOT FOUND trying APPLE" が表示されれば正常
```

> MacBook Pro 14,2 (subsystem ID `0x106b3600`) は "compiled but not tested" ステータスだが動作確認済み。
> Ubuntu と異なり、Arch では `linux-source` の問題や HWE カーネル固有のワークアラウンドは不要。

### 7. 日本語入力（fcitx5 + Mozc）

```bash
./scripts/setup-fcitx5.sh
```

`XMODIFIERS=@im=fcitx` を `~/.zshenv` に自動追記する（Wayland環境向け。XWaylandアプリ対応）。
ログアウト・再ログイン後に有効になる。

### 8. キーボードカスタマイズ（keyd）

`keyd` で内蔵キーボードのみにリマップを適用する。外付けキーボードには影響しない。

```bash
./scripts/setup-keyd.sh
sudo reboot
```

スクリプトが行うこと:

1. `keyd` をインストール（公式リポジトリ extra）
2. `interception-tools` を無効化（keyd に統合）
3. 内蔵キーボード専用の keyd 設定を配置
4. fcitx5 のホットキーを Muhenkan/Henkan に更新

#### キーマッピング

| キー       | タップ           | ホールド |
| ---------- | ---------------- | -------- |
| CapsLock   | Escape           | Ctrl     |
| 左 Command | 英数（Muhenkan） | Super    |
| 右 Command | かな（Henkan）   | Super    |

## ディレクトリ構成

```
macbookpro14-2-for-arch/
├── README.md
├── driver/
│   ├── touchbar/          # パッチ済み iBridge ドライバソース
│   │   ├── apple-ibridge.c
│   │   ├── apple-ibridge.h
│   │   ├── apple-ib-tb.c
│   │   ├── apple-ib-als.c
│   │   ├── Makefile
│   │   └── dkms.conf
│   ├── modprobe.d/
│   │   └── apple-touchbar.conf
│   ├── libinput/
│   │   └── local-overrides.quirks  # タッチパッド DWT quirk
│   ├── keyd/
│   │   └── macbook-internal.conf   # キーボードリマップ（keyd）
│   └── udev/
│       └── 91-apple-touchbar.rules
└── scripts/
    ├── setup.sh           # 一括セットアップ（各項目を yes/no で選択）
    ├── setup-base.sh      # 汎用パッケージ（バッテリー・明るさ・ファン）
    ├── setup-wifi.sh      # Wi-Fi ドライバ・NVRAM セットアップ
    ├── setup-touchbar.sh  # Touch Bar DKMS セットアップ
    ├── setup-touchpad.sh  # タッチパッド DWT 修正
    ├── setup-audio.sh     # 内蔵スピーカー（snd_hda_macbookpro DKMS）
    ├── setup-fcitx5.sh    # 日本語入力（fcitx5 + Mozc）
    └── setup-keyd.sh      # キーボードカスタマイズ（keyd）
```

## パッケージ一覧

| カテゴリ     | パッケージ                            | リポジトリ  | 用途                          |
| ------------ | ------------------------------------- | ----------- | ----------------------------- |
| バッテリー   | `tlp`                                 | 公式        | バッテリー最適化              |
| バッテリー   | `powertop`                            | 公式        | 電力消費分析                  |
| 明るさ       | `brightnessctl`                       | 公式        | 画面の明るさ調整              |
| ファン       | `mbpfan-git`                          | AUR         | MacBook用ファン制御（任意）   |
| Touch Bar    | `appleibridge` (DKMS)                 | 同梱        | Touch Bar有効化               |
| 日本語入力   | `fcitx5`, `fcitx5-mozc`, `fcitx5-gtk` | 公式        | 日本語入力メソッド            |
| 日本語入力   | `fcitx5-qt`                           | 公式        | Qt アプリ向け入力サポート     |
| タッチパッド | `libinput`                            | 公式        | トラックパッド対応            |
| キーリマップ | `keyd`                                | 公式(extra) | CapsLock/Command キーリマップ |

## 参考リンク

- [MacBookPro14,2 Ubuntu Guide](https://github.com/twigglits/MacbookPro14-2Ubuntu)
- [Touch Bar Driver (roadrunner2)](https://github.com/roadrunner2/macbook12-spi-driver)
- [Linux on MacBook Pro 2017](https://gist.github.com/roadrunner2/1289542a748d9a104e7baec6a92f9cd7)
- [Wi-Fi Fix (2025)](https://james.cridland.net/blog/2025/wifi-on-macbook-pro-linux/)
- [Broadcom Wi-Fi Drivers](https://gist.github.com/torresashjian/e97d954c7f1554b6a017f07d69a66374)

## ライセンス

このリポジトリに含まれる Touch Bar ドライバソース (`driver/touchbar/`) は
[Ronald Tschalär](https://github.com/roadrunner2) による成果物をベースとし、
kernel 6.17 対応パッチを加えたものです。

- 原著作者: Ronald Tschalär, Copyright (c) 2017-2018
- ライセンス: [GNU General Public License v2.0](LICENSE)
- 参照元: [roadrunner2/macbook12-spi-driver](https://github.com/roadrunner2/macbook12-spi-driver)

オーディオセットアップスクリプト (`scripts/setup-audio.sh`) は
[davidjo/snd_hda_macbookpro](https://github.com/davidjo/snd_hda_macbookpro) を
DKMS 経由でインストールするものです。同リポジトリも GPL-2.0 ライセンスで配布されています。

- 参照元: [davidjo/snd_hda_macbookpro](https://github.com/davidjo/snd_hda_macbookpro)
- ライセンス: [GNU General Public License v2.0](LICENSE)

セットアップスクリプト・ドキュメント類も同ライセンス（GPL-2.0）の下で配布されます。
