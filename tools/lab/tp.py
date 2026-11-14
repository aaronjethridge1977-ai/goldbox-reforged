"""Turbo Pascal's random numbers, as Pool of Radiance's START.EXE has them (0AF8:118F)."""
M = 134775813
def nxt(s): return (s * M + 1) & 0xFFFFFFFF
def random(s, n):            # returns (new seed, Random(n) = (seed >> 16) mod n)
    s = nxt(s); return s, ((s >> 16) % n if n else 0)
def steps(a, b, limit=100000):
    for i in range(limit + 1):
        if a == b: return i
        a = nxt(a)
    return None
