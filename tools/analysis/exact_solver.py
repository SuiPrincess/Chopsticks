#!/usr/bin/env python3
"""Chopsticksの厳密ソルバー（ルール構成の健全性検証用）。

GameState.apply(_:)と同じルール（wrap/クラシック死亡・分割・復活・爆弾連鎖・
ミラー・ダブルタップ・60ターンサドンデス）を、手番視点の正規化状態
（手の昇順タプル×2, attacksThisTurn, turnCount）でメモ化探索し、
先手（人間）視点の理論値と最適応答での決着手数を計算する。

用途: 今週の試練/今日の挑戦のルール構成が
  1) 先手に必勝戦略があるか（後手必勝＝鬼AI相手に勝てない週になる）
  2) 最適応答で十分な手数がかかるか（数手決着＝自明なチーズ）
を機械的に確認する。結果の表と採用基準は docs/ai-notes.md を参照。

注意: 毒ルールは意図的に未実装（パリティ退化が証明済みでチャレンジに使わないため）。
"""
from functools import lru_cache
from itertools import product
import sys

sys.setrecursionlimit(1_000_000)
TURN_LIMIT = 60


def receive(fingers, add, wrap):
    if fingers == 0:
        return 0
    total = fingers + add
    if wrap:
        if total == 5:
            return 0
        return total - 5 if total > 5 else total
    return 0 if total >= 5 else total


def process_bombs(mine, theirs, wrap):
    mine, theirs = list(mine), list(theirs)
    exploded = True
    while exploded:
        exploded = False
        for hands in (mine, theirs):
            for i, f in enumerate(hands):
                if f == 4:
                    hands[i] = 0
                    exploded = True
                    for hs in (mine, theirs):
                        for j in range(len(hs)):
                            if hs is hands and j == i:
                                continue
                            hs[j] = receive(hs[j], 1, wrap)
                    break
            if exploded:
                break
    return tuple(mine), tuple(theirs)


def distributions(total, count):
    if count == 2:
        return [(a, total - a) for a in range(5) if 0 <= total - a <= 4]
    return [(a, b, total - a - b)
            for a in range(5) for b in range(5) if 0 <= total - a - b <= 4]


def make_solver(wrap, split, revival, bomb, mirror, double):
    """(value, plies) を返すソルバー。value: +1=手番側勝ち/0=引き分け/-1=負け。
    pliesは最適応答（勝ちは最短・負けは最長粘り）での残り手数。"""

    @lru_cache(maxsize=None)
    def solve(mine, theirs, attacks, turn):
        moves = []
        for i, f in enumerate(mine):
            if f > 0:
                for j, g in enumerate(theirs):
                    if g > 0:
                        moves.append(("tap", i, j))
        if split:
            current = tuple(sorted(mine))
            total = sum(mine)
            for dist in distributions(total, len(mine)):
                if tuple(sorted(dist)) == current:
                    continue
                if not revival and any(d > 0 and mine[k] == 0 for k, d in enumerate(dist)):
                    continue
                moves.append(("split", dist))

        best = None
        for move in moves:
            if move[0] == "tap":
                _, i, j = move
                new_theirs, new_mine = list(theirs), list(mine)
                new_theirs[j] = receive(theirs[j], mine[i], wrap)
                if mirror:
                    new_mine[i] = receive(mine[i], mine[i], wrap)
                new_mine, new_theirs = tuple(new_mine), tuple(new_theirs)
                if bomb:
                    new_mine, new_theirs = process_bombs(new_mine, new_theirs, wrap)
                was_tap = True
            else:
                new_mine, new_theirs = tuple(move[1]), theirs
                if bomb:
                    new_mine, new_theirs = process_bombs(new_mine, new_theirs, wrap)
                was_tap = False

            mine_dead = all(f == 0 for f in new_mine)
            theirs_dead = all(f == 0 for f in new_theirs)
            if mine_dead or theirs_dead:
                # 相討ちはとどめを刺した手番側の勝ち（GameViewModelと同じ）
                value, length = (1 if theirs_dead else -1), 1
            elif was_tap and double and attacks == 0:
                v, l = solve(tuple(sorted(new_mine)), tuple(sorted(new_theirs)), 1, turn)
                value, length = v, l + 1
            else:
                next_turn = turn + 1
                if next_turn >= TURN_LIMIT:
                    alive_m = sum(1 for f in new_mine if f > 0)
                    alive_t = sum(1 for f in new_theirs if f > 0)
                    if alive_m != alive_t:
                        value = 1 if alive_m > alive_t else -1
                    elif sum(new_mine) != sum(new_theirs):
                        value = 1 if sum(new_mine) < sum(new_theirs) else -1
                    else:
                        value = 0
                    length = 1
                else:
                    v, l = solve(tuple(sorted(new_theirs)), tuple(sorted(new_mine)), 0, next_turn)
                    value, length = -v, l + 1

            candidate = (value, length)
            if best is None:
                best = candidate
            else:
                bv, bl = best
                if value > bv:
                    best = candidate
                elif value == bv:
                    if value == 1 and length < bl:
                        best = candidate
                    elif value <= 0 and length > bl:
                        best = candidate
        return best if best is not None else (-1, 0)

    return solve


def main():
    print(f"{'ルール':24s} hands wrap rev -> 先手視点の理論値（最適応答の手数）")
    viable = []
    for split, bomb, mirror, double in product((False, True), repeat=4):
        for hands, wrap in product((2, 3), (True, False)):
            for revival in ([False, True] if split else [False]):
                solve = make_solver(wrap, split, revival, bomb, mirror, double)
                start = tuple([1] * hands)
                value, length = solve(start, start, 0, 0)
                names = "+".join(n for n, on in zip(
                    ("split", "bomb", "mirror", "double"),
                    (split, bomb, mirror, double)) if on) or "standard"
                label = {1: "先手勝ち", 0: "引き分け", -1: "後手勝ち"}[value]
                mark = ""
                if value == 1 and length >= 9:
                    viable.append((names, hands, wrap, revival, length))
                    mark = "  <= 試練採用可"
                print(f"{names:24s} {hands}     {int(wrap)}    {int(revival)}   "
                      f"-> {label} in {length}手{mark}")
    print()
    print(f"採用可（先手勝ち・最短9手以上）: {len(viable)}件")
    for v in viable:
        print("  ", v)


if __name__ == "__main__":
    main()
