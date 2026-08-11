"use strict";

/**
 * Read-only Firestore helpers for relay (request_poll).
 * Never writes / deletes / updates.
 */

const COLLECTION = "sotong24work_projects";

async function getProjectDoc(db, projectId) {
  const snap = await db.collection(COLLECTION).doc(projectId).get();
  if (!snap.exists) return null;
  return snap.data() || {};
}

/**
 * List up to [limit] documents from requests subcollection.
 * Prefer createdAt desc when orderBy is available; fallback to unordered get.
 */
async function listRequestDocs(db, projectId, { maxRead = 40 } = {}) {
  const col = db
    .collection(COLLECTION)
    .doc(projectId)
    .collection("requests");

  try {
    if (typeof col.orderBy === "function") {
      const snap = await col.orderBy("createdAt", "desc").limit(maxRead).get();
      return snap.docs.map((d) => ({ id: d.id, data: d.data() || {} }));
    }
  } catch (_) {
    // missing index / mock — fall through
  }

  const snap = await col.limit(maxRead).get();
  return snap.docs.map((d) => ({ id: d.id, data: d.data() || {} }));
}

module.exports = {
  COLLECTION,
  getProjectDoc,
  listRequestDocs,
};
