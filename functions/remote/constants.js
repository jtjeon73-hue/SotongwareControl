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
  CANCELLED_PRESERVED: "cancelled_preserved",
  PAUSED: "paused",
  PAUSED_QUOTA: "paused_quota",
  PAUSED_NETWORK: "paused_network",
  STALLED: "stalled",
  AI_PROCESS_FAILED: "ai_process_failed",
  RESULT_VALIDATION_FAILED: "result_validation_failed",
  RESULT_VALIDATION_RETRYING: "result_validation_retrying",
  STAGE_TRANSITION_FAILED: "stage_transition_failed",
});

/** Agent::StateKey wire values */
const AGENT_STATE = Object.freeze({
  STARTING: "starting",
  IDLE: "idle",
  RECEIVING_JOB: "receiving_job",
  RUNNING: "running",
  RUNNING_AI: "running_ai",
  GENERATING_RESULT: "generating_result",
  VALIDATING_RESULT: "validating_result",
  TRANSITIONING_STAGE: "transitioning_stage",
  WAITING_APPROVAL: "waiting_approval",
  PAUSED_QUOTA: "paused_quota",
  PAUSED_NETWORK: "paused_network",
  STALLED: "stalled",
  AI_PROCESS_FAILED: "ai_process_failed",
  RESULT_VALIDATION_FAILED: "result_validation_failed",
  VALIDATION_RETRY_WAITING: "validation_retry_waiting",
  STAGE_TRANSITION_FAILED: "stage_transition_failed",
  REVISION_REQUESTED: "revision_requested",
  COMPLETED: "completed",
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
  PROJECTS: "sotong24work_projects",
  MONITORING_CONFIG: "monitoring_config",
  NOTIFICATION_EVENTS: "notificationEvents",
});

const ACTIVITY_STATE = Object.freeze({
  AI_REQUESTING: "ai_requesting",
  CODEX_RUNNING: "codex_running",
  RESULT_VALIDATING: "result_validating",
  RESULT_UPLOADING: "result_uploading",
  APPROVAL_PREPARING: "approval_preparing",
  AUTO_APPROVAL: "auto_approval",
  PAUSED_QUOTA: "paused_quota",
  PAUSED_NETWORK: "paused_network",
  STALLED: "stalled",
  AI_PROCESS_FAILED: "ai_process_failed",
  RESULT_VALIDATION_FAILED: "result_validation_failed",
  VALIDATION_RETRY_WAITING: "validation_retry_waiting",
  STAGE_TRANSITION_FAILED: "stage_transition_failed",
});

const ACTIVITY_TYPE = Object.freeze({
  AI_DISPATCH: "ai_dispatch",
  EXECUTOR_STATE_CHANGE: "executor_state_change",
  RESULT_GENERATED: "result_generated",
  RESULT_VALIDATED: "result_validated",
  ARTIFACT_UPLOAD: "artifact_upload",
  STAGE_STATUS: "stage_status",
  APPROVAL_TRANSITION: "approval_transition",
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
  ACTIVITY_STATE,
  ACTIVITY_TYPE,
};
