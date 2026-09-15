"""
Donchian channel breakout + ATR trailing stop, for BTC/USD.

Deterministic reference implementation matching donchian_breakout.pine —
used here only to sanity-check the trailing-stop/sizing logic against
synthetic OHLC data (no real market data access in this environment).
This is NOT a substitute for backtesting on real data in TradingView.

Input: a DataFrame indexed by date (ascending) with columns
Open, High, Low, Close.
"""

from __future__ import annotations

import math
from dataclasses import dataclass

import pandas as pd

DONCHIAN_LENGTH = 20
ATR_LENGTH = 14
TREND_SMA_LENGTH = 100
ATR_INITIAL_MULT = 2.0
ATR_TRAIL_MULT = 3.0
RISK_PER_TRADE = 0.01
MAX_NOTIONAL_FRAC = 0.25
LOT_STEP = 0.0001


def wilder_atr(df: pd.DataFrame, period: int = ATR_LENGTH) -> pd.Series:
    prev_close = df["Close"].shift(1)
    tr = pd.concat(
        [
            df["High"] - df["Low"],
            (df["High"] - prev_close).abs(),
            (df["Low"] - prev_close).abs(),
        ],
        axis=1,
    ).max(axis=1)

    atr = tr.rolling(period).mean()
    for i in range(period, len(df)):
        atr.iloc[i] = (atr.iloc[i - 1] * (period - 1) + tr.iloc[i]) / period
    return atr


@dataclass
class Trade:
    side: str
    entry_date: pd.Timestamp
    entry_price: float
    size: float
    exit_date: pd.Timestamp | None = None
    exit_price: float | None = None


def _position_size(equity: float, stop_distance: float, entry_price: float) -> float:
    if stop_distance <= 0:
        return 0.0
    raw_size = (equity * RISK_PER_TRADE) / stop_distance
    max_size = (MAX_NOTIONAL_FRAC * equity) / entry_price
    capped = min(raw_size, max_size)
    return math.floor(capped / LOT_STEP) * LOT_STEP


def backtest(
    df: pd.DataFrame,
    starting_equity: float = 100_000.0,
    use_trend_filter: bool = True,
    allow_short: bool = True,
) -> list[Trade]:
    df = df.copy()
    df["ATR"] = wilder_atr(df)
    df["SMA_trend"] = df["Close"].rolling(TREND_SMA_LENGTH).mean()
    # Prior N-bar high/low, excluding the current bar (no look-ahead).
    df["DonchianHigh"] = df["High"].rolling(DONCHIAN_LENGTH).max().shift(1)
    df["DonchianLow"] = df["Low"].rolling(DONCHIAN_LENGTH).min().shift(1)

    equity = starting_equity
    trades: list[Trade] = []
    position: Trade | None = None
    pending_entry_side: str | None = None
    initial_stop = 0.0
    trail_extreme = 0.0

    n = len(df)
    for i in range(n):
        row = df.iloc[i]
        date = df.index[i]

        if pending_entry_side is not None and position is None:
            entry_price = row["Open"]
            atr_entry = df["ATR"].iloc[i - 1]
            stop_distance = ATR_INITIAL_MULT * atr_entry
            size = _position_size(equity, stop_distance, entry_price)
            if size > 0:
                position = Trade(side=pending_entry_side, entry_date=date, entry_price=entry_price, size=size)
                initial_stop = (
                    entry_price - stop_distance if pending_entry_side == "long" else entry_price + stop_distance
                )
                trail_extreme = row["High"] if pending_entry_side == "long" else row["Low"]
            pending_entry_side = None

        if position is not None:
            if position.side == "long":
                trail_extreme = max(trail_extreme, row["High"])
                trail_stop = trail_extreme - ATR_TRAIL_MULT * row["ATR"]
                stop_price = max(initial_stop, trail_stop)
                if row["Low"] <= stop_price:
                    fill = min(stop_price, row["Open"]) if row["Open"] < stop_price else stop_price
                    position.exit_date, position.exit_price = date, fill
                    equity += position.size * (fill - position.entry_price)
                    trades.append(position)
                    position = None
            else:
                trail_extreme = min(trail_extreme, row["Low"])
                trail_stop = trail_extreme + ATR_TRAIL_MULT * row["ATR"]
                stop_price = min(initial_stop, trail_stop)
                if row["High"] >= stop_price:
                    fill = max(stop_price, row["Open"]) if row["Open"] > stop_price else stop_price
                    position.exit_date, position.exit_price = date, fill
                    equity += position.size * (position.entry_price - fill)
                    trades.append(position)
                    position = None

        if position is None and pending_entry_side is None and pd.notna(row["DonchianHigh"]) and pd.notna(row["SMA_trend"]):
            up_regime = (not use_trend_filter) or row["Close"] > row["SMA_trend"]
            down_regime = (not use_trend_filter) or row["Close"] < row["SMA_trend"]
            if up_regime and row["Close"] > row["DonchianHigh"]:
                pending_entry_side = "long"
            elif allow_short and down_regime and row["Close"] < row["DonchianLow"]:
                pending_entry_side = "short"

    return trades


if __name__ == "__main__":
    import sys

    if len(sys.argv) != 2:
        print("usage: python donchian_breakout.py <ohlc_csv_with_Date,Open,High,Low,Close>")
        raise SystemExit(1)

    data = pd.read_csv(sys.argv[1], parse_dates=["Date"], index_col="Date").sort_index()
    results = backtest(data)
    for t in results:
        pnl = t.size * ((t.exit_price - t.entry_price) if t.side == "long" else (t.entry_price - t.exit_price))
        print(
            f"{t.side:5s} {t.entry_date.date()} @ {t.entry_price:.2f} -> "
            f"{t.exit_date.date()} @ {t.exit_price:.2f} size={t.size:.4f} pnl={pnl:.2f}"
        )
