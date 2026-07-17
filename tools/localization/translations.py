#!/usr/bin/env python3
"""English translations for Chopsticks.

Keys are the localization keys as SwiftUI/Foundation generate them:
string literals with \\(Int) -> %lld and \\(String) -> %@.
Generates en.lproj/Localizable.strings (+ ja.lproj fallback stub).
"""

TRANSLATIONS = {
    # ---- AIDifficulty / GameConfig ----
    "かんたん": "Easy",
    "つよい": "Strong",
    "鬼": "Oni",

    # ---- GameState player names ----
    "Player 1": "Player 1",
    "Player 2": "Player 2",
    "CPU Lv.%lld": "CPU Lv.%lld",
    "CPU（%@）": "CPU (%@)",
    "対戦相手": "Opponent",
    "プレイヤー": "Player",

    # ---- NearbyMatchView ----
    "近くの人と対戦": "Nearby Match",
    "部屋を作る": "Create Room",
    "部屋を探す": "Find Room",
    "戻る": "Back",
    "対戦相手を待っています": "Waiting for an opponent",
    "%@ から接続要求": "Connection request from %@",
    "承認": "Accept",
    "拒否": "Decline",
    "部屋を探しています": "Looking for rooms",
    "近くのデバイスを検索中...": "Searching for nearby devices...",
    "接続中...": "Connecting...",
    "キャンセル": "Cancel",

    # ---- GameSessionStore (resume) ----
    "今日の挑戦": "Daily Challenge",
    "ランク戦 Lv.%lld": "Ranked Lv.%lld",
    "CPU戦（%@）": "CPU Match (%@)",
    "2人対戦": "2 Players",
    "%@・ターン%lld": "%@ · Turn %lld",

    # ---- NotificationManager ----
    "今日の割り箸バトル 🥢": "Today's Chopsticks battle 🥢",
    "1勝して連続プレイ日数をつなごう！CPUが待ってます": "Win one game to keep your daily streak alive! The CPU is waiting",

    # ---- Themes ----
    "ネオン": "Neon",
    "サンセット": "Sunset",
    "マトリックス": "Matrix",
    "サクラ": "Sakura",
    "ゴールド": "Gold",
    "ディープシー": "Deep Sea",
    "ミッドナイト": "Midnight",
    "今日の挑戦を%lld回クリアで解放（いま%lld回）":
        "Clear the Daily Challenge %1$lld times to unlock (now: %2$lld)",
    "🎁 限定テーマ「%@」を解放!": "🎁 Exclusive theme “%@” unlocked!",
    "通算クリア %lld回": "Total clears: %lld",

    # ---- GameViewModel banners / messages ----
    "接続が切れました": "Connection lost",
    "相手が退出しました": "Your opponent left",
    "もう1回!": "One more!",
    "分割 %@ が最善!": "Split %@ is the best move!",
    "あと10ターンで判定!": "10 turns until judgment!",

    # ---- AIDifficultyPickerView ----
    "CPU難易度": "CPU Difficulty",
    "ランダムに行動する": "Plays randomly",
    "最善手を選ぶ": "Picks the best move",
    "最深読み。勝てたら自慢していい": "Deepest search. Brag if you beat it",
    "次へ": "Next",

    # ---- HandView / PlayerAreaView accessibility ----
    "手、指%lld本": "hand, %lld fingers",
    "手、死亡": "hand, out",
    "左": "left",
    "右": "right",
    "%lld番目": "number %lld",
    "指%lld本": "%lld fingers",
    "死亡": "out",
    "%@の%@の手、%@": "%1$@'s %2$@ hand, %3$@",

    # ---- SplitControlView ----
    "合計: %lld / %lld": "Total: %lld / %lld",
    "4本にした手は分割直後に爆発します！": "A hand set to 4 explodes right after the split!",
    "決定": "Confirm",

    # ---- GameOverView ----
    "🎯 今日の挑戦クリア！また明日！": "🎯 Daily Challenge cleared! See you tomorrow!",
    "⬆️ RANK UP! 次は Lv.%lld": "⬆️ RANK UP! Next: Lv.%lld",
    "👑 全CPU制覇!": "👑 All CPUs defeated!",
    "Lv.%lld はキープ。もう一度!": "You keep Lv.%lld. Try again!",
    "リマッチ待機中...": "Waiting for rematch...",
    "リマッチ": "Rematch",
    "切断して戻る": "Disconnect & Leave",
    "リベンジ!": "Revenge!",
    "Play Again": "Play Again",
    "結果を自慢する": "Share your win",
    "リマッチしますか？": "Rematch?",
    "いいえ": "No",
    "割り箸バトル「今日の挑戦 %@」クリア！🎯 きみは解けた？ #Chopsticks":
        "Cleared the Chopsticks Daily Challenge (%@)! 🎯 Can you? #Chopsticks",
    "割り箸バトルでCPU Lv.%lldを撃破！現在ランクLv.%lld 🔥 #Chopsticks":
        "Beat CPU Lv.%1$lld in Chopsticks! Now ranked Lv.%2$lld 🔥 #Chopsticks",
    "割り箸バトルで「鬼」に勝った！💪 これは自慢していいやつ #Chopsticks":
        "I beat Oni mode in Chopsticks! 💪 Allowed to brag #Chopsticks",
    "割り箸バトルでCPUに%lld連勝中！🔥 #Chopsticks":
        "%lld wins in a row against the CPU in Chopsticks! 🔥 #Chopsticks",
    "割り箸バトルでCPUに勝利！✌️ #Chopsticks":
        "Beat the CPU in Chopsticks! ✌️ #Chopsticks",
    "引き分け": "It's a draw",
    "%@の勝ち": "%@ wins",
    "もう一回挑戦しよう": "Give it another shot",
    "🔥 %lld連勝中!": "🔥 %lld-win streak!",
    "✨ 自己ベスト更新!": "✨ New personal best!",
    "通算 %lld勝 %lld敗・ベスト連勝 %lld": "Total %1$lld W – %2$lld L · Best streak %3$lld",

    # ---- GameView ----
    "ゲームをやめる": "Quit game",
    "ヒントを表示": "Show hint",
    "相手のターン": "Opponent's turn",
    "ターン %lld/%lld": "Turn %lld/%lld",
    "ルールを表示": "Show rules",
    "ゲームをやめますか？": "Quit this game?",
    "やめる": "Quit",
    "続ける": "Keep playing",
    "進行中のゲームは自動保存され、メニューの「続きから」で再開できます":
        "Your game is saved automatically. Resume anytime with Continue on the menu",
    "今日のヒントを使い切りました": "You're out of hints for today",
    "プレミアムを見る": "See Premium",
    "無料版はヒント1日%lld回まで。プレミアムなら無制限で使えます。":
        "Free players get %lld hints per day. Premium removes the limit.",
    "① 自分の手をタップしてえらぶ": "① Tap one of your hands to select it",
    "② 相手の手をタップしてこうげき！": "② Tap an opponent's hand to attack!",

    # ---- MenuView ----
    "ショップ": "Shop",
    "設定": "Settings",
    "続きから": "Continue",
    "今日の挑戦 — %@": "Daily Challenge — %@",
    "クリア済": "Cleared",
    "フリー対戦": "Free Play",
    "オンライン対戦": "Online Match",
    "ルール設定": "Rules",
    "おまかせルール": "Random rules",
    "戦績": "Stats",
    "Game Centerにログインするとオンライン対戦が可能":
        "Sign in to Game Center to play online",
    "ランク戦 Lv.MAX": "Ranked Lv.MAX",
    "ランク戦 — Lv.%lldに挑戦": "Ranked — Challenge Lv.%lld",
    "🗓️ %lld日連続": "🗓️ %lld-day streak",
    "🔥 %lld連勝中": "🔥 %lld wins in a row",
    "CPU戦 %lld勝 %lld敗": "vs CPU: %1$lld W – %2$lld L",
    "ベスト連勝 %lld": "Best streak %lld",
    "ループ": "Wrap",
    "分割": "Split",
    "復活": "Revival",
    "3本手": "3 Hands",
    "毒": "Poison",
    "爆弾": "Bomb",
    "ミラー": "Mirror",
    "2回攻撃": "Double Tap",

    # ---- RuleDisplayView ----
    "ルール確認": "Rules Check",
    "ルール": "Rules",
    "基本ルール": "Basic Rules",
    "死亡ルール": "Knockout Rule",
    "追加ルール (ON)": "Extra Rules (ON)",
    "追加ルール (OFF)": "Extra Rules (OFF)",
    "ゲーム開始": "Start Game",
    "各プレイヤーは%lld本の手、指1本ずつでスタート":
        "Each player starts with %lld hands, one finger each",
    "自分の手を選んでから、相手の手をタップして攻撃":
        "Select one of your hands, then tap an opponent's hand to attack",
    "叩かれた手に、攻撃側の指の本数が加算される":
        "The tapped hand gains the attacker's finger count",
    "全ての手が死んだプレイヤーの負け":
        "Lose all your hands and you lose the game",
    "%lldターンで決着しない場合は判定（手の数→指が少ない方）":
        "After %lld turns the winner is judged (more hands, then fewer fingers)",
    "3本手モード: 通常より多い手で戦略的に!":
        "3-hand mode: more hands, more strategy!",
    "5を超えたら余りからカウント (例: 3+4=7→2)":
        "Over 5 wraps around (e.g. 3+4=7→2)",
    "ちょうど5になったら死亡": "Exactly 5 knocks the hand out",
    "5以上になったら即死亡 (クラシック)": "5 or more knocks the hand out (classic)",
    "分割: 攻撃の代わりに両手の指を再分配できる":
        "Split: redistribute fingers between hands instead of attacking",
    "復活: 分割で死亡した手を復活させられる":
        "Revival: bring dead hands back via a split",
    "毒: 指1本の攻撃で相手の手を即死（毒を使った手も死ぬ相討ち）":
        "Poison: a 1-finger attack kills instantly (your hand dies too)",
    "爆弾: 手が4になると爆発し全他の手に1ダメージ":
        "Bomb: a hand at exactly 4 explodes, dealing 1 to every other hand",
    "ミラー: 攻撃した分が自分にも加算":
        "Mirror: your attack also adds to your own hand",
    "ダブルタップ: 1ターンに2回攻撃可能":
        "Double Tap: attack twice per turn",
    "ダブルタップ": "Double Tap",

    # ---- RuleSettingsView ----
    "オーバーフロー": "Overflow",
    "5を超えたらループ、ちょうど5で死亡": "Wrap past 5; exactly 5 knocks out",
    "攻撃の代わりに両手の指を再分配できる": "Redistribute fingers instead of attacking",
    "分割で死亡した手を復活させられる": "Revive dead hands via a split",
    "手の数": "Hands",
    "プレイヤーの手": "Hands per player",
    "各プレイヤーの手の数を変更": "Change how many hands each player has",
    "2本": "2",
    "3本": "3",
    "特殊ルール": "Special Rules",
    "指1本の攻撃で相手の手を即死。ただし毒を使った手も死ぬ（相討ち）":
        "A 1-finger attack kills instantly — but the poisoning hand dies too",
    "手がちょうど4になると爆発、全他の手に1ダメージ":
        "A hand at exactly 4 explodes, dealing 1 to every other hand",
    "攻撃後、自分の手にも同じ数が加算される":
        "After attacking, the same amount is added to your hand",
    "1ターンに2回攻撃できる": "Attack twice in one turn",
    "完了": "Done",

    # ---- StatsView ----
    "ランク Lv.MAX": "Rank Lv.MAX",
    "ランク Lv.%lld": "Rank Lv.%lld",
    "全てのCPUを撃破！": "All CPUs defeated!",
    "次はCPU Lv.%lldに挑戦": "Next: challenge CPU Lv.%lld",
    "CPU対戦成績": "vs CPU Record",
    "勝利": "Wins",
    "敗北": "Losses",
    "勝率": "Win rate",
    "ストリーク": "Streaks",
    "連勝中": "Current",
    "ベスト連勝": "Best streak",
    "連続日数": "Day streak",
    "今日の挑戦 %@": "Daily Challenge %@",
    "クリア済み！また明日！": "Cleared! See you tomorrow!",
    "まだ未クリア。日替わりルールに挑もう": "Not cleared yet. Try today's rules!",
    "Game Centerを見る": "Open Game Center",
    "戦績をリセット": "Reset stats",
    "戦績をリセットしますか？": "Reset all stats?",
    "リセット": "Reset",
    "勝敗・連勝記録・ランクの進行が全て初期化されます。この操作は取り消せません。":
        "Wins, streaks and rank progress will be erased. This cannot be undone.",

    # ---- SettingsView ----
    "サウンド": "Sound",
    "効果音を再生する（サイレントスイッチに従う）": "Play sound effects (respects the silent switch)",
    "ハプティクス": "Haptics",
    "タップ・撃破時などの振動フィードバック": "Vibration feedback for taps and knockouts",
    "デイリーリマインダー": "Daily Reminder",
    "毎日19:30、連続プレイ日数が途切れる前にお知らせ": "A nudge at 7:30 PM before your streak breaks",
    "ショップ・カラーテーマ": "Shop & Themes",
    "プレミアムでテーマ解放＆ヒント無制限": "Premium unlocks themes & unlimited hints",
    "チュートリアルをもう一度見る": "Replay the tutorial",
    "次のゲーム開始時に操作ガイドを表示": "Shows the guide at the start of your next game",
    "Chopsticks（割り箸） v%@": "Chopsticks v%@",
    "通知が許可されていません": "Notifications not allowed",
    "設定アプリ > Chopsticks > 通知 から許可してください": "Allow them in Settings > Chopsticks > Notifications",

    # ---- ReplayView ----
    "リプレイ": "Replay",
    "リプレイを見る": "Watch replay",
    "手 %lld/%lld": "Move %lld/%lld",
    "最初へ": "Jump to start",
    "前の手": "Previous move",
    "再生": "Play",
    "一時停止": "Pause",
    "次の手": "Next move",
    "最後へ": "Jump to end",

    # ---- ShopView ----
    "プレミアム": "Premium",
    "解放済み": "Unlocked",
    "全カラーテーマを解放（5種類）": "Unlock all color themes (5)",
    "AIヒントが無制限に": "Unlimited AI hints",
    "個人開発の応援になります": "Supports an indie developer",
    "いつも応援ありがとうございます！": "Thank you for your support!",
    "%@ で解放する": "Unlock for %@",
    "ストアに接続できませんでした。時間をおいて再度お試しください。":
        "Couldn't reach the App Store. Please try again later.",
    "購入を復元": "Restore Purchases",
    "プレミアムは買い切りです。価格は購入画面に表示されます。":
        "Premium is a one-time purchase. The price is shown at checkout.",
    "カラーテーマ": "Color Themes",
    "開発者に差し入れ": "Tip the Developer",
    "読み込み中...": "Loading...",
    "現在利用できません": "Currently unavailable",
    "応援ありがとうございます！🙌": "Thank you for the tip! 🙌",
    "どういたしまして": "You're welcome",
    "いただいた応援は開発の励みになります。これからもChopsticksをよろしくお願いします！":
        "Your support keeps this game growing. Thank you for playing Chopsticks!",
    "購入を開始できませんでした": "Couldn't start the purchase",
    "通信状態を確認して、もう一度お試しください。": "Check your connection and try again.",
}

INFO_PLIST = {
    "NSLocalNetworkUsageDescription": "Used to play with nearby players over the local network",
}
