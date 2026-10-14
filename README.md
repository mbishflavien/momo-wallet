# MoMo Wallet

A mobile-money wallet in Flutter, built on Labs 3 · 2 · 6: money comes in, you send money to friends, you cash out at an agent, and the balance never lies.

```
flutter run          # Android, Windows or Chrome
flutter test         # 26 tests: the full "done when" checklist and more
```

## Screens

| Screen | What it does |
|---|---|
| **Wallet** | Balance card with Receive / Send / Cash out, statistics (Total IN, Total OUT, Lowest balance), transactions newest first with an All / IN / OUT filter. Tap a transaction for details. Swipe left to delete, with Undo. |
| **Receive** (dialog) | Amount and description → an IN. |
| **Send money** | Phone number and amount → `OUT: Sent to 0788123456`, plus a separate `OUT: Send fee` of 100 RWF. |
| **Cash out** | Amount → *Show notes* (the exact notes, biggest first) → *Confirm* → `OUT: Cash out`. |
| **Transaction details** | Amount, type, date, balance after, the linked fee, and Delete. |

## How it is built

All the money rules live in one plain Dart file, `lib/wallet.dart`, and the screens only call it. The UI does no maths of its own.

- **The history is the truth.** The wallet stores an opening balance (10,000 RWF) and the list of transactions. Balance, totals and lowest balance are always **recomputed from the history**, never kept as separate counters. A delete can't leave a stale total behind because there is no total stored anywhere to go stale.
- **Validate, then mutate.** Every operation (`receive`, `send`, `quoteCashOut`, `confirmCashOut`, `delete`, `undo`) runs all its checks first and returns `Outcome.refused('<which rule failed>')` without touching the list. The transaction list changes only after every check has passed.
- **Amounts** are parsed strictly: `23700` and `23,700` are accepted. `5k`, `0`, `-200`, `1.5` and empty input are refused, each with its own message.
- **Cash out** splits greedily over 5,000 / 2,000 / 1,000 / 500 / 100. Every note is a multiple of 100, so any multiple of 100 splits exactly. Confirm re-checks the balance in case it changed after the notes were shown.
- **Delete** replays the history without the transaction. If the running balance goes below 0 at any point, the delete is refused. Deleting a send also deletes its fee. **Undo** puts the transactions back in their original place. It is checked too: restoring an old OUT after the money has been spent could push the history below 0.

### Sample data

The wallet opens at **10,000 RWF**. The sample transactions cancel out (IN 6,500, OUT 6,500), so the balance still reads 10,000 but the statistics have something to show. The balance dipped to **8,000** after the first send.

## ✔ Done-when checklist (all covered in `test/wallet_test.dart`)

| Check | Result |
|---|---|
| Send to `0721234567` | Refused: *Phone number must start with 078 or 079* |
| Send 50 RWF to `0788123456` | Refused: *Minimum send amount is 100 RWF* |
| Cash out 23,700 | `5,000 × 4 · 2,000 × 1 · 1,000 × 1 · 500 × 1 · 100 × 2` |
| Cash out 250 | Refused: *must be a multiple of 100 RWF* |
| OUT of 1,000,000 | Refused: *Insufficient balance* |
| `5k`, `0`, `-200` | Refused: *whole number* / *greater than 0* |
| Totals and lowest balance after several transactions, after a delete, after undo | Tested |
| Delete that would make the history go below 0 | Refused |

## 🤔 Think

### Why must every check happen before any money moves? What would go wrong if one check came after?

A transaction must happen completely or not at all. If any money moves before the last check, a refusal leaves the wallet half-changed.

Take the send with its fee. Suppose the code recorded `Sent to 0788123456` first and only then checked the balance for the fee. Then a refused send would still have taken the money, and the user would see "Insufficient balance" while their balance had dropped anyway. The balance would lie, which is the one thing this app must never do. Undoing the half-done step in a "rollback" is worse: it's extra code that can itself fail or be forgotten.

The same goes for any order: format check after the amount is recorded, phone check after the debit, balance check after the cash out. Each one means a refused operation still changed the history. So every method here first works out *whether* it may proceed, using only reads, and then performs all its writes together at the end. Cash out shows this most clearly: `quoteCashOut` only reads (showing the notes moves no money), and `confirmCashOut` runs every check again before it writes.

### Your lowest-balance statistic needs a starting value. What did you start it at, and why not 0?

It starts at the **opening balance** (10,000 RWF), the balance before any transaction. Then it takes the minimum with the balance after each transaction.

Not 0, because a balance can never go below 0 in this app (every OUT bigger than the balance is refused). Starting at 0 would make `min(0, …)` always 0, so the statistic would say "your lowest balance was 0" for a wallet that never went below 8,000. The starting value has to be a balance the wallet actually had. The opening balance is the first one, and it is also correct for an empty history (lowest = 10,000, not 0).

Something like `double.infinity` or "the first transaction's balance" would also avoid the bug. But infinity gives a wrong answer when there are no transactions, and the opening balance was a real balance in its own right, so it belongs in the minimum anyway.

## ⚡ Push further, both done

- **100 RWF fee on every send**, recorded as its own OUT (`Send fee (0788123456)`). The fee counts toward the balance check: sending 9,950 with 10,000 is refused. It is linked to its send, so deleting the send removes the fee too, and Undo brings both back.
- **Transaction details screen**: tap any transaction to see its amount, type, date, the balance after it, its fee or parent send, a reference number, and a Delete button.
