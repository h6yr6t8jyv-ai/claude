# RSI(14) Mean-Reversion — BTC/USD, Daily

A fully objective, discretion-free specification of the classic RSI
mean-reversion strategy. Every rule below is a deterministic function of
price data — no judgment calls are involved in generating a signal, a
stop, an exit, or a size.

## 0. Instrument & Data

| Parameter | Value |
|---|---|
| Market | BTC/USD (spot or perpetual swap — pick one source and hold it fixed) |
| Timeframe | 1 daily bar, candle close = 00:00 UTC |
| Price fields required | Open, High, Low, Close per bar |
| Signal evaluation | Only on **fully closed** daily bars (no intrabar repainting) |
| Order execution | Entries/RSI-exits/time-exits fill at the **next bar's Open**; stop-loss fills intrabar (see §4) |

## 1. Indicator Definitions

### RSI(14) — Wilder's method
```
change_t   = Close_t - Close_{t-1}
gain_t     = max(change_t, 0)
loss_t     = max(-change_t, 0)

AvgGain_14 = mean(gain_1 .. gain_14)         # seed value, simple average
AvgLoss_14 = mean(loss_1 .. loss_14)

AvgGain_t  = (AvgGain_{t-1} * 13 + gain_t) / 14   # for t > 14
AvgLoss_t  = (AvgLoss_{t-1} * 13 + loss_t) / 14

RS_t   = AvgGain_t / AvgLoss_t         # if AvgLoss_t == 0 → RSI_t = 100
RSI_t  = 100 - 100 / (1 + RS_t)
```

### ATR(14) — Wilder's smoothed True Range (used for stop and sizing)
```
TR_t = max(High_t - Low_t, |High_t - Close_{t-1}|, |Low_t - Close_{t-1}|)
ATR_14 (seed) = mean(TR_1 .. TR_14)
ATR_t  = (ATR_{t-1} * 13 + TR_t) / 14
```

## 2. Entry Rule (exact, computable)

Evaluated only when **flat** (no open position).

- **Long entry signal**, fires on bar `t`:
  `RSI_{t-1} >= 30  AND  RSI_t < 30`   (RSI crosses below 30)
  → Submit market buy, fills at `Open_{t+1}`.

- **Short entry signal** (symmetric, only if the venue supports shorting BTC/USD):
  `RSI_{t-1} <= 70  AND  RSI_t > 70`   (RSI crosses above 70)
  → Submit market sell/short, fills at `Open_{t+1}`.

No pyramiding: while a position is open, new entry signals are ignored.
Only one position (long or short) may be open at a time.

## 3. Exit Rule (exact, computable)

Three exit conditions exist; while in a position, check them **in this
priority order every bar** — the first one satisfied closes the trade
and the rest are not evaluated that bar:

1. **Stop-loss** (§4) — checked intrabar against `High_t`/`Low_t`.
2. **RSI reversion exit**:
   - Long: `RSI_{t-1} < 55  AND  RSI_t >= 55` → exit at `Open_{t+1}`.
   - Short: `RSI_{t-1} > 45  AND  RSI_t <= 45` → exit at `Open_{t+1}`.
3. **Time-stop**: if `days_held >= 10` trading days and neither of the
   above has triggered, exit at `Open_{t+1}` of the 10th day.

`days_held` is counted in completed bars since the entry fill bar.

## 4. Stop Loss (exact, computable, volatility-adaptive)

Set once, at entry, from `ATR_14` measured on the entry bar (`ATR14_entry`):

```
stop_distance = 2.5 * ATR14_entry

Long:  stop_price  = Entry_Price - stop_distance
Short: stop_price  = Entry_Price + stop_distance
```

- Placed as a resting stop-market order immediately after entry fill (GTC).
- Checked against every subsequent bar's High/Low:
  - Long: if `Low_t <= stop_price` → exit filled at `stop_price`,
    or at `Open_t` if the bar gapped through the stop (`Open_t < stop_price`).
  - Short: symmetric using `High_t` and `Open_t >  stop_price`.
- Fixed, not trailed — no discretion, no manual adjustment.

## 5. Position Sizing (exact, computable, fixed-fractional risk)

```
r               = 0.01                         # risk 1% of equity per trade
Equity_t        = account equity as of prior day's close
stop_distance   = 2.5 * ATR14_entry            # price units, from §4

raw_size        = (Equity_t * r) / stop_distance      # units of BTC

max_notional    = 0.25 * Equity_t                     # leverage/exposure cap
capped_size     = min(raw_size, max_notional / Entry_Price)

position_size   = floor(capped_size / lot_step) * lot_step   # round to venue's lot size
```

- If `position_size` rounds to 0 (equity too small / stop too wide), skip
  the trade — no entry is placed.
- Sizing is computed once at entry and not adjusted afterward (no
  scaling in/out).

## 6. Daily Execution Sequence (removes all remaining ambiguity)

At each bar close `t`:

1. Compute `RSI_t`, `ATR_t`.
2. If in a position: check stop-loss intrabar on bar `t` → priority 1.
3. If still in a position: check RSI reversion exit using `Close_t` → priority 2.
4. If still in a position: check time-stop (`days_held >= 10`) → priority 3.
5. If flat: check entry condition using `Close_t`.
6. Queue any resulting exit/entry order to fill at `Open_{t+1}` (stop-loss
   fills intrabar on the triggering bar itself, per §4).
7. Exits are always processed before new entries on the same fill bar.

## 7. Parameter Summary

| Rule | Value |
|---|---|
| RSI period | 14 (Wilder) |
| ATR period | 14 (Wilder) |
| Long entry | RSI crosses below 30 |
| Short entry | RSI crosses above 70 |
| Long exit (target) | RSI crosses above 55 |
| Short exit (target) | RSI crosses below 45 |
| Time-stop | 10 bars |
| Stop-loss | 2.5 × ATR(14) from entry |
| Risk per trade | 1% of equity |
| Max notional exposure | 25% of equity |
| Pyramiding | None — 1 position at a time |

This is a specification, not investment advice; validate on out-of-sample
data and realistic fees/slippage before trading it live.
