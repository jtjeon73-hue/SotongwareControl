"use strict";

/**
 * Public control-plane auth mapping for the hosting login UI.
 * Password is never returned. Values mirror firestore.rules admin identity.
 */
function resolveControlAuthPublicConfig() {
  const adminAuthEmail = String(
    process.env.CONTROL_ADMIN_AUTH_EMAIL || "sotongware@naver.com"
  ).trim();
  const adminUid = String(
    process.env.CONTROL_ADMIN_UID || "YrJNhBlxSeck5qZi5NgHWrx1CjE3"
  ).trim();
  const displayAdminId = "sotongware";
  const configured =
    adminAuthEmail.length > 0 &&
    adminUid.length > 0 &&
    displayAdminId.length > 0;
  return {
    ok: configured,
    displayAdminId,
    adminAuthEmail,
    adminUid,
    configured,
  };
}

function handleAuthPublicConfig(req, res) {
  if (req.method !== "GET") {
    res.status(405).json({ ok: false, error: "method_not_allowed" });
    return;
  }
  const body = resolveControlAuthPublicConfig();
  if (!body.configured) {
    res.status(503).json({ ok: false, error: "auth_config_unavailable" });
    return;
  }
  res.status(200).json(body);
}

module.exports = {
  handleAuthPublicConfig,
  resolveControlAuthPublicConfig,
};
