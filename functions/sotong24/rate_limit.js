"use strict";

/**
 * 단순 in-process rate limit (인스턴스 로컬).
 * heartbeat 45초 주기는 허용, 비정상 폭주는 거부.
 */
function createRateLimiter({ windowMs = 60_000, max = 30 } = {}) {
  const hits = new Map();

  function prune(now) {
    for (const [k, v] of hits.entries()) {
      if (now - v.windowStart > windowMs * 2) hits.delete(k);
    }
  }

  function check(key) {
    const now = Date.now();
    prune(now);
    const cur = hits.get(key);
    if (!cur || now - cur.windowStart > windowMs) {
      hits.set(key, { windowStart: now, count: 1 });
      return { ok: true, remaining: max - 1 };
    }
    cur.count += 1;
    if (cur.count > max) {
      return { ok: false, remaining: 0 };
    }
    return { ok: true, remaining: max - cur.count };
  }

  function reset() {
    hits.clear();
  }

  return { check, reset };
}

module.exports = { createRateLimiter };
