"use strict";

/**
 * In-memory Firestore subset for remote contract tests.
 * Supports: doc get/set/update, transactions, where+limit, collectionGroup, orderBy.
 */
function createMemoryDb() {
  const store = new Map();

  function key(parts) {
    return parts.join("/");
  }

  function parsePath(pathKey) {
    return pathKey.split("/");
  }

  function matchesWhere(data, filters) {
    for (const f of filters) {
      const v = data[f.field];
      if (f.op === "==") {
        if (v !== f.value) return false;
      }
    }
    return true;
  }

  function docRef(parts) {
    const path = parts.slice();
    const k = key(path);
    return {
      id: path[path.length - 1],
      path: k,
      async get() {
        return {
          exists: store.has(k),
          id: path[path.length - 1],
          data: () => (store.has(k) ? { ...store.get(k) } : undefined),
          ref: docRef(path),
        };
      },
      async set(data, opts) {
        if (opts && opts.merge && store.has(k)) {
          store.set(k, { ...store.get(k), ...data });
        } else {
          store.set(k, { ...data });
        }
      },
      async update(data) {
        if (!store.has(k)) throw new Error("not-found");
        store.set(k, { ...store.get(k), ...data });
      },
      async delete() {
        store.delete(k);
      },
      collection(name) {
        return collectionRef([...path, name]);
      },
    };
  }

  function queryResult(docs) {
    return {
      empty: docs.length === 0,
      docs,
      get size() {
        return docs.length;
      },
    };
  }

  function collectionRef(parts) {
    const base = parts.slice();
    const filters = [];
    let order = null;
    let lim = null;

    const api = {
      doc(id) {
        return docRef([...base, id]);
      },
      where(field, op, value) {
        filters.push({ field, op, value });
        return api;
      },
      orderBy(field, dir) {
        order = { field, dir: dir || "asc" };
        return api;
      },
      limit(n) {
        lim = n;
        return api;
      },
      async get() {
        const prefix = key(base) + "/";
        let rows = [];
        for (const [k, v] of store.entries()) {
          if (!k.startsWith(prefix)) continue;
          const rest = k.slice(prefix.length);
          if (!rest || rest.includes("/")) continue;
          if (!matchesWhere(v, filters)) continue;
          rows.push({
            id: rest,
            exists: true,
            data: () => ({ ...v }),
            ref: docRef([...base, rest]),
          });
        }
        if (order) {
          rows.sort((a, b) => {
            const av = a.data()[order.field] || "";
            const bv = b.data()[order.field] || "";
            if (av === bv) return 0;
            const cmp = av < bv ? -1 : 1;
            return order.dir === "desc" ? -cmp : cmp;
          });
        }
        if (lim != null) rows = rows.slice(0, lim);
        return queryResult(rows);
      },
    };
    return api;
  }

  return {
    store,
    collection(name) {
      return collectionRef([name]);
    },
    collectionGroup(name) {
      const filters = [];
      let order = null;
      let lim = null;
      const api = {
        where(field, op, value) {
          filters.push({ field, op, value });
          return api;
        },
        orderBy(field, dir) {
          order = { field, dir: dir || "asc" };
          return api;
        },
        limit(n) {
          lim = n;
          return api;
        },
        async get() {
          let rows = [];
          for (const [k, v] of store.entries()) {
            const parts = parsePath(k);
            // .../commands/{id}
            if (parts.length < 2) continue;
            if (parts[parts.length - 2] !== name) continue;
            if (!matchesWhere(v, filters)) continue;
            rows.push({
              id: parts[parts.length - 1],
              exists: true,
              data: () => ({ ...v }),
              ref: docRef(parts),
            });
          }
          if (order) {
            rows.sort((a, b) => {
              const av = a.data()[order.field] || "";
              const bv = b.data()[order.field] || "";
              if (av === bv) return 0;
              const cmp = av < bv ? -1 : 1;
              return order.dir === "desc" ? -cmp : cmp;
            });
          }
          if (lim != null) rows = rows.slice(0, lim);
          return queryResult(rows);
        },
      };
      return api;
    },
    async runTransaction(fn) {
      // Simple serial transaction (no retry conflict simulation)
      const tx = {
        async get(ref) {
          return ref.get();
        },
        set(ref, data, opts) {
          return ref.set(data, opts);
        },
        update(ref, data) {
          return ref.update(data);
        },
      };
      return fn(tx);
    },
  };
}

module.exports = { createMemoryDb };
