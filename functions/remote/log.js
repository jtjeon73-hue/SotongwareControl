"use strict";

function nowIso() {
  return new Date().toISOString();
}

/** Structured log — never log tokens / pairing codes / ID tokens / full payloads */
function safeLog(event) {
  const line = {
    ts: nowIso(),
    type: event.type || null,
    agentId: event.agentId || null,
    jobId: event.jobId || null,
    commandId: event.commandId || null,
    status: event.status || null,
    code: event.code || null,
    latencyMs: event.latencyMs != null ? event.latencyMs : null,
  };
  console.log(JSON.stringify(line));
}

module.exports = { safeLog, nowIso };
