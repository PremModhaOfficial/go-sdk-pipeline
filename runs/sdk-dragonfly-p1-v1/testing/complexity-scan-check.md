# Complexity scan check (G107)

Status: PASS
Declared: 23 · OK: 23 · Violations: 0 · Missing: 0

## OK
- GetJSON: exponent 0.00 ≤ cap 1.10 (O(N))
- SetJSON: exponent 0.00 ≤ cap 1.10 (O(N))
- MGetJSON: exponent 0.82 ≤ cap 1.10 (O(M))
- SAdd: exponent 0.00 ≤ cap 1.25 (O(K))
- SRem: exponent 0.00 ≤ cap 1.25 (O(K))
- SMembers: exponent 0.71 ≤ cap 1.10 (O(N))
- SIsMember: exponent 0.00 ≤ cap 0.10 (O(1))
- SCard: exponent 0.00 ≤ cap 0.10 (O(1))
- SInter: exponent 0.00 ≤ cap 1.10 (O(N))
- SUnion: exponent 0.00 ≤ cap 1.10 (O(N))
- SDiff: exponent 0.00 ≤ cap 1.10 (O(N))
- ZAdd: exponent 0.20 ≤ cap 0.25 (O(log N))
- ZIncrBy: exponent 0.20 ≤ cap 0.25 (O(log N))
- ZRange: exponent 0.20 ≤ cap 0.25 (O(log N))
- ZRangeWithScores: exponent 0.79 ≤ cap 1.10 (O(M))
- ZRangeByScore: exponent 0.20 ≤ cap 0.25 (O(log N))
- ZRank: exponent 0.20 ≤ cap 0.25 (O(log N))
- ZScore: exponent 0.00 ≤ cap 0.10 (O(1))
- ZRem: exponent 0.20 ≤ cap 0.25 (O(log N))
- ZCard: exponent 0.00 ≤ cap 0.10 (O(1))
- ZCount: exponent 0.20 ≤ cap 0.25 (O(log N))
- Scan: exponent 0.68 ≤ cap 1.10 (O(N))
- HScan: exponent 0.78 ≤ cap 1.10 (O(N))
