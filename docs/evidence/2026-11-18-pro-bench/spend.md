# Evaluation spend ledger — 1.9.0 (cap $2, plan §2)

OpenRouter balance read with `scripts/openrouter-balance.sh` (`used` is cumulative for the key).

| date | what | calls | used before → after | cost |
|---|---|---|---|---|
| 11-18 | Q0 cloud baseline (preview Worker, Vent + Feral, 3 locales) | 36 | $0.1404 → $0.1463 | $0.0059 |

| 11-18 | Q2b: 2 dev rounds + gate attempts 1 and 2 (control and candidate), preview Worker | 140 | $0.1463 → $0.1735 | $0.0272 |

| 11-18 | Q2a: smoke, 2 dev runs, gate 1, void gate 2, gate 2 (takes + single arms) | ≈ 600 upstream | $0.1735 → $0.3183 | $0.1448 |

| 11-19 | cloud safety sets (candidate + production prompt, 4 rounds), Q2b final check, 2 production smoke tests | ≈ 400 | $0.3183 → $0.3900 | $0.0717 |

Running total: **$0.2496** of $2 (OpenRouter balance $9.61).
