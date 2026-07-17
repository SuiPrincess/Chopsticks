# App Store 申請用ドラフト

日英フルローカライズ済みのため、日本語＋英語（Primary: 日本語、追加: English (U.S.)）の
2ロケールでメタデータを登録する。

## 日本語メタデータ

### アプリ名
Chopsticks - 割り箸バトル

### サブタイトル（30文字以内）
指1本から始まる頭脳バトル

### プロモーションテキスト（170文字以内）
懐かしの指遊び「割り箸」がスタイリッシュに進化！毎日変わる「今日の挑戦」、CPUラダーを勝ち上がるランク戦、白熱の対面2人プレイ、オンライン対戦。毒・爆弾・ミラーなどの特殊ルールで毎回違う戦いを。

### 説明文

指遊びの定番「割り箸（チョップスティックス）」を、美しいネオンデザインで遊べるiOSゲームにしました。

ルールはシンプル。自分の手を選んで相手の手をタップすると、攻撃した指の本数が相手に加算。5本になった手は死亡、全ての手が死んだら負け。

▼ 遊び方いろいろ
・ランク戦 — CPU Lv.1〜10を勝ち上がるラダー。勝つほど賢くなる
・今日の挑戦 — 毎日変わる特殊ルールに世界中のプレイヤーが同じ条件で挑戦。通算クリアで限定テーマも解放
・今週の試練 — 週替わりのガチ勢向けチャレンジ。最強CPU「鬼」を特殊ルールで攻略
・フリー対戦 — かんたん／つよい／鬼の3段階。「鬼」に勝てたら自慢していい（限定テーマ「オニ」も解放）
・2人対戦 — 1台を挟んで向かい合って対戦
・近くの人と対戦 — Wi-Fi/Bluetoothでオフライン対戦
・オンライン対戦 — Game Centerで世界と対戦

▼ 特殊ルールで無限に遊べる
オーバーフロー／分割／復活／3本手／毒／爆弾／ミラー／ダブルタップ。「おまかせルール」でランダムに組み合わせれば毎回違うゲームに。

▼ 遊びやすさ・上達サポート
・迷ったらヒント — AIが最善手を教えてくれる
・攻略ガイド — キル計算・分割・特殊ルールのコツを図解で解説
・リプレイ — 決着後に全手順を1手ずつ振り返れる
・中断してもOK — 自動保存でいつでも「続きから」
・戦績記録 — 勝率・連勝・連続プレイ日数。Game Centerのリーダーボード・実績にも対応
・気持ちいい演出 — 効果音・ハプティクス・パーティクル（設定でOFF可）

シンプルなのに奥深い。1ゲーム1分の頭脳バトルをどうぞ。

### キーワード（100文字以内）
割り箸,チョップスティックス,指遊び,ボードゲーム,対戦,2人,オフライン,頭脳,パズル,chopsticks

## English metadata

### App Name
Chopsticks: Hand Tap Battle

### Subtitle (≤30 chars)
The classic hand game, evolved

### Promotional Text (≤170 chars)
The playground classic goes neon! Take on the daily challenge, climb the CPU ladder, battle friends face-to-face or online — with Poison, Bomb, Mirror and more twists.

### Description

The classic hand game "Chopsticks" reimagined as a sleek neon iOS game.

The rules are simple: pick one of your hands, tap an opponent's hand, and your finger count is added to theirs. A hand that reaches five is out. Lose every hand and you lose the game.

▼ Many ways to play
- Ranked — climb the CPU ladder from Lv.1 to Lv.10. Every win makes the next CPU smarter
- Daily Challenge — one shared rule set for every player in the world, refreshed daily. Clear it repeatedly to unlock an exclusive theme
- Weekly Trial — a hardcore weekly gauntlet: beat the Oni under this week's special rules
- Free Play — three difficulties: Easy, Strong, and Oni. Beat Oni to brag — and to unlock the exclusive Oni theme
- 2 Players — face off on a single device
- Nearby Match — offline battles over Wi-Fi/Bluetooth
- Online — matchmaking via Game Center

▼ Endless variety with special rules
Wrap, Split, Revival, 3 hands, Poison, Bomb, Mirror, Double Tap. Hit the dice button to shuffle them into a brand-new game every time.

▼ Easy to learn, easy to improve
- Hints — the AI shows you its best move
- Strategy Guide — illustrated lessons on kill math, splits, and every special rule
- Replay — review any finished game move by move
- Auto-save — leave anytime and pick up right where you left off
- Stats — win rate, streaks, daily play streak, plus Game Center leaderboards and achievements
- Juicy feedback — sound effects, haptics, particles (all optional)

Simple to learn, deep to master. One-minute brain battles, anytime.

### Keywords (≤100 chars)
chopsticks,hand game,finger game,strategy,board,2 player,offline,duel,brain,mind,classic,tabletop

## カテゴリ
ゲーム > ボード / 戦略

## 収益化（App Store Connectでの設定が必要）

アプリ内課金（StoreKit 2）。以下のプロダクトをASCで作成する。
ローカルテストは `Chopsticks/Products.storekit` をXcodeのスキーム設定
（Run > Options > StoreKit Configuration）で選択すればASC設定なしで動作確認できる。

| Product ID | 種類 | 内容 | 参考価格 |
|---|---|---|---|
| `com.suiprincess.chopsticks.premium` | 非消耗型 | プレミアムテーマ解放＋AIヒント無制限 | ¥480 |
| `com.suiprincess.chopsticks.tip.small` | 消耗型 | 投げ銭（おにぎり） | ¥160 |
| `com.suiprincess.chopsticks.tip.large` | 消耗型 | 投げ銭（お弁当） | ¥600 |

収益設計:
- 無料でフル対戦可能（ゲームプレイは一切課金で制限しない＝レビューを守る）
- ヒントのみ1日3回制限 → プレミアムで無制限（自然な誘導）
- プレミアムテーマ5種（サンセット/マトリックス/サクラ/ゴールド/ディープシー）
- 報酬テーマ「ミッドナイト」は今日の挑戦を通算7回クリアで解放（課金不要。
  ショップ画面に進捗が出るため「毎日開く理由」と「ショップを見る理由」を同時に作る）
- デイリーリマインダー通知（オプトイン）＋連続プレイ日数・今日の挑戦でリテンション

## スクリーンショット案（6.7インチ・5枚）

| # | 画面 | キャプション（JP / EN） |
|---|---|---|
| 1 | 対戦中の盤面（リーチの赤パルス付き） | 1ゲーム1分の頭脳バトル / One-minute brain battles |
| 2 | ランク戦ボタンとメニュー | CPU Lv.10まで勝ち上がれ / Climb the CPU ladder |
| 3 | 今日の挑戦（ルール確認画面） | 毎日変わる世界共通ルール / A new challenge every day |
| 4 | 特殊ルール設定（毒・爆弾ON） | 特殊ルールで毎回違う戦い / Twist the rules every match |
| 5 | テーマ選択（ショップ） | 勝利を彩るカラーテーマ / Themes to match your style |

## 備考（審査メモ）
- オンライン対戦はGame Center必須
- 近接対戦はローカルネットワーク権限を使用（NSLocalNetworkUsageDescription設定済み）
- 広告なし。課金はStoreKit 2のIAPのみ（上記）。復元ボタンあり
- 通知はオプトイン（設定画面のトグルで許可リクエスト）
- Game Centerリーダーボード（任意）: ID `com.suiprincess.chopsticks.rank`（ランク戦の到達レベル）を
  App Store Connectで作成すると自動で送信される。未設定でも問題なく動作する
- Game Center実績（任意）: 以下のIDをApp Store Connectで作成すると自動で解除される。未設定でも問題なく動作する
  - `com.suiprincess.chopsticks.firstwin` — CPU戦で初勝利
  - `com.suiprincess.chopsticks.streak3` — 3連勝
  - `com.suiprincess.chopsticks.streak10` — 10連勝
  - `com.suiprincess.chopsticks.perfect` — 手を1本も失わずに勝利（PERFECT）
  - `com.suiprincess.chopsticks.oni` — 難易度「鬼」に勝利
  - `com.suiprincess.chopsticks.rankmax` — CPU Lv.10を撃破（全CPU制覇）
