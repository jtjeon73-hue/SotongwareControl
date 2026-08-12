"use strict";

/** protocolVersion shared with Sotong24Work AgentProtocol.h */
const PROTOCOL_VERSION = "1.0";

const COMMAND_TYPE = Object.freeze({
  START_JOB: "START_JOB",
  APPROVE_STAGE: "APPROVE_STAGE",
  REQUEST_REVISION: "REQUEST_REVISION",
  CANCEL_JOB: "CANCEL_JOB",
  PAUSE_JOB: "PAUSE_JOB",
  RESUME_JOB: "RESUME_JOB",
});

const COMMAND_STATUS = Object.freeze({
  QUEUED: "queued",
  CLAIMED: "claimed",
  COMPLETED: "completed",
  FAILED: "failed",
});

/** Job / Stage shared vocabulary (AgentProtocol.h) */
const WORK_STATUS = Object.freeze({
  QUEUED: "queued",
  CLAIMED: "claimed",
  RUNNING: "running",
  WAITING_APPROVAL: "waiting_approval",
  REVISION_REQUESTED: "revision_requested",
  REWORKING: "reworking",
  APPROVED: "approved",
  COMPLETED: "completed",
  FAILED: "failed",
  CANCELLED: "cancelled",
  PAUSED: "paused",
});

/** Agent::StateKey wire values */
const AGENT_STATE = Object.freeze({
  STARTING: "starting",
  IDLE: "idle",
  RECEIVING_JOB: "receiving_job",
  RUNNING: "running",
  WAITING_APPROVAL: "waiting_approval",
  REVISION_REQUESTED: "revision_requested",
  ERROR: "error",
  OFFLINE: "offline",
});

const ONLINE_WITHIN_MS = 90_000;
const PAIRING_TTL_MS = 10 * 60 * 1000;
const PULL_DEFAULT_LIMIT = 5;
const PULL_MAX_LIMIT = 10;
const MAX_BODY_BYTES = 256 * 1024;

const COL = Object.freeze({
  AGENTS: "agents",
  AGENT_TOKENS: "agentTokens",
  JOBS: "jobs",
  PAIRING: "pairingSessions",
  USERS: "users",
});

module.exports = {
  PROTOCOL_VERSION,
  COMMAND_TYPE,
  COMMAND_STATUS,
  WORK_STATUS,
  AGENT_STATE,
  ONLINE_WITHIN_MS,
  PAIRING_TTL_MS,
  PULL_DEFAULT_LIMIT,
  PULL_MAX_LIMIT,
  MAX_BODY_BYTES,
  COL,
};
