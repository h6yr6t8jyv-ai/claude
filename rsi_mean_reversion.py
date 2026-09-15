"""
RSI(14) mean-reversion strategy for BTC/USD, daily bars.

Deterministic reference implementation of STRATEGY.md — every entry,
exit, stop, and size is a pure function of the OHLC series, no
discretionary inputs.

Input: a DataFrame indexed by date (ascending) with columns
Open, High, Low, Close.

Usage:
    trades = backtest(df)
"""

from __future__ import annotations

import math
from dataclasses import dataclass

import pandas as pd

RSI_PERIOD = 14
ATR_PERIOD = 14
RSI_LONG_ENTRY = 30.0
RSI_SHORT_ENTRY = 70.0
RSI_LONG_EXIT = 55.0
RSI_SHORT_EXIT = 45.0
TIME_STOP_BARS = 10
ATR_STOP_MULT = 2.5
RISK_PER_TRADE = 0.01
MAX_NOTIONAL_FRAC = 0.25
LOT_STEP = 0.0001


def wilder_rsi(close: pd.Series, period: int = RSI_PERIOD) -> pd.Series:
    delta = close.diff()
    gain = delta.clip(lower=0.0)
    loss = (-delta).clip(lower=0.0)

    avg_gain = pd.Series(index=close.index, dtype=float)
    avg_loss = pd.Series(index=close.index, dtype=float)

    if len(close) > period:
        # Seed: simple average of the first `period` gains/losses. `delta`
        # (and hence `gain`/`loss`) is NaN at index 0, so the first `period`
        # real diffs are at positions 1..period, and the seed lands at
        # position `period`.
        avg_gain.iloc[period] = gain.iloc[1 : period + 1].mean()
        avg_loss.iloc[period] = loss.iloc[1 : period + 1].mean()

        for i in range(period + 1, len(close)):
            avg_gain.iloc[i] = (avg_gain.iloc[i - 1] * (period - 1) + gain.iloc[i]) / period
            avg_loss.iloc[i] = (avg_loss.iloc[i - 1] * (period - 1) + loss.iloc[i]) / period

    rs = avg_gain / avg_loss
    rsi = 100 - 100 / (1 + rs)
    rsi[avg_loss == 0] = 100.0
    return rsi


def wilder_atr(df: pd.DataFrame, period: int = ATR_PERIOD) -> pd.Series:
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
    side: str  # "long" or "short"
    entry_date: pd.Timestamp
    entry_price: float
    stop_price: float
    size: float
    exit_date: pd.Timestamp | None = None
    exit_price: float | None = None
    exit_reason: str | None = None


def _position_size(equity: float, stop_distance: float, entry_price: float) -> float:
    if stop_distance <= 0:
        return 0.0
    raw_size = (equity * RISK_PER_TRADE) / stop_distance
    max_size = (MAX_NOTIONAL_FRAC * equity) / entry_price
    capped = min(raw_size, max_size)
    return math.floor(capped / LOT_STEP) * LOT_STEP


def backtest(df: pd.DataFrame, starting_equity: float = 100_000.0) -> list[Trade]:
    df = df.copy()
    df["RSI"] = wilder_rsi(df["Close"])
    df["ATR"] = wilder_atr(df)
    df["RSI_prev"] = df["RSI"].shift(1)

    equity = starting_equity
    trades: list[Trade] = []
    position: Trade | None = None
    pending_entry_side: str | None = None
    days_held = 0

    n = len(df)
    for i in range(n):
        row = df.iloc[i]
        date = df.index[i]

        # Fill any order queued from the previous bar's close at this bar's open.
        if pending_entry_side is not None and position is None:
            entry_price = row["Open"]
            atr_entry = df["ATR"].iloc[i - 1]  # ATR known as of prior close
            stop_distance = ATR_STOP_MULT * atr_entry
            size = _position_size(equity, stop_distance, entry_price)
            if size > 0:
                stop_price = (
                    entry_price - stop_distance
                    if pending_entry_side == "long"
                    else entry_price + stop_distance
                )
                position = Trade(
                    side=pending_entry_side,
                    entry_date=date,
                    entry_price=entry_price,
                    stop_price=stop_price,
                    size=size,
                )
                days_held = 0
            pending_entry_side = None

        pending_exit = False

        if position is not None:
            days_held += 1

            # Priority 1: stop-loss, checked intrabar.
            if position.side == "long" and row["Low"] <= position.stop_price:
                fill = min(position.stop_price, row["Open"]) if row["Open"] < position.stop_price else position.stop_price
                position.exit_date, position.exit_price, position.exit_reason = date, fill, "stop"
                pending_exit = True
            elif position.side == "short" and row["High"] >= position.stop_price:
                fill = max(position.stop_price, row["Open"]) if row["Open"] > position.stop_price else position.stop_price
                position.exit_date, position.exit_price, position.exit_reason = date, fill, "stop"
                pending_exit = True

            # Priority 2: RSI reversion exit (signal only; fills next open).
            rsi_exit_signal = False
            if not pending_exit:
                if position.side == "long" and row["RSI_prev"] < RSI_LONG_EXIT <= row["RSI"]:
                    rsi_exit_signal = True
                elif position.side == "short" and row["RSI_prev"] > RSI_SHORT_EXIT >= row["RSI"]:
                    rsi_exit_signal = True

            # Priority 3: time-stop.
            time_exit_signal = not pending_exit and not rsi_exit_signal and days_held >= TIME_STOP_BARS

            if pending_exit:
                trades.append(position)
                equity += position.size * (
                    (position.exit_price - position.entry_price)
                    if position.side == "long"
                    else (position.entry_price - position.exit_price)
                )
                position = None
            elif (rsi_exit_signal or time_exit_signal) and i + 1 < n:
                next_row = df.iloc[i + 1]
                exit_price = next_row["Open"]
                position.exit_date = df.index[i + 1]
                position.exit_price = exit_price
                position.exit_reason = "rsi_target" if rsi_exit_signal else "time_stop"
                trades.append(position)
                equity += position.size * (
                    (exit_price - position.entry_price)
                    if position.side == "long"
                    else (position.entry_price - exit_price)
                )
                position = None

        # New entry signal only when flat (evaluate using this bar's close).
        if position is None and pending_entry_side is None:
            if row["RSI_prev"] >= RSI_LONG_ENTRY > row["RSI"]:
                pending_entry_side = "long"
            elif row["RSI_prev"] <= RSI_SHORT_ENTRY < row["RSI"]:
                pending_entry_side = "short"

    return trades


if __name__ == "__main__":
    import sys

    if len(sys.argv) != 2:
        print("usage: python rsi_mean_reversion.py <ohlc_csv_with_Date,Open,High,Low,Close>")
        raise SystemExit(1)

    data = pd.read_csv(sys.argv[1], parse_dates=["Date"], index_col="Date").sort_index()
    results = backtest(data)
    for t in results:
        pnl = t.size * (
            (t.exit_price - t.entry_price) if t.side == "long" else (t.entry_price - t.exit_price)
        )
        print(
            f"{t.side:5s} {t.entry_date.date()} @ {t.entry_price:.2f} -> "
            f"{t.exit_date.date()} @ {t.exit_price:.2f} "
            f"({t.exit_reason:10s}) size={t.size:.4f} pnl={pnl:.2f}"
        )
