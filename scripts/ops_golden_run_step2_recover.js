#!/usr/bin/env node
/**
 * Audit and narrowly recover the existing app Golden Run STEP 2.
 *
 * This tool never creates/deletes a WorkInstruction or project. `audit` is
 * read-only. The `switch-codex` operation is intentionally implemented only
 * after the audit contract is proven by tests.
 *
 * Usage:
 *   node scripts/ops_golden_run_step2_recover.js audit
 */
'use strict';

const fs = require('fs');
const path = require('path');
const https = require('https');

const PROJECT = 'sotongware-control';
const INSTRUCTION_ID = 'wi_plan_1787699077625';
const JOB_ID = 'job_a3777efca75b1d0c';
const PROJECT_ID = 'wi_plan_1787699077625';
const STAGE_ID = 'app_problem_validate';
const AGENT_ID = 'agent_9830758291f9c64e';
const WORK_INSTRUCTION_DOC_ID =
  'YrJNhBlxSeck5qZi5NgHWrx1CjE3__app__wi_plan_1787699077625';
const WORKSPACE = path.join(
  process.env.USERPROFILE || '',
  'Documents',
  'Sotong24Work',
  'AppProjects',
  'SotongApp1_App787699077625',
);

function resolveFirebaseToolsRoot() {
  const candidates = [
    process.env.FIREBASE_TOOLS_ROOT,
    path.join(process.env.APPDATA || '', 'npm', 'node_modules', 'firebase-tools'),
  ].filter(Boolean);
  const found = candidates.find((root) => fs.existsSync(path.join(root, 'lib', 'auth.js')));
  if (!found) {
    throw new Error('Set FIREBASE_TOOLS_ROOT to the firebase-tools package directory');
  }
  return found;
}

const firebaseToolsRoot = resolveFirebaseToolsRoot();
const auth = require(path.join(firebaseToolsRoot, 'lib', 'auth'));
const scopes = require(path.join(firebaseToolsRoot, 'lib', 'scopes'));

async function accessToken() {
  const account = auth.getGlobalDefaultAccount();
  if (!account?.tokens?.refresh_token) throw new Error('Firebase CLI login required');
  const token = await auth.getAccessToken(account.tokens.refresh_token, [scopes.CLOUD_PLATFORM]);
  return typeof token === 'string' ? token : token.access_token;
}

function request(method, urlPath, body) {
  return new Promise((resolve, reject) => {
    accessToken().then((access) => {
      const req = https.request(
        {
          hostname: 'firestore.googleapis.com',
          path: urlPath,
          method,
          headers: {
            Authorization: `Bearer ${access}`,
            'Content-Type': 'application/json',
          },
        },
        (res) => {
          let data = '';
          res.on('data', (chunk) => (data += chunk));
          res.on('end', () => {
            if (res.statusCode >= 200 && res.statusCode < 300) {
              resolve(data ? JSON.parse(data) : {});
            } else if (res.statusCode === 404) {
              resolve(null);
            } else {
              reject(new Error(`${method} ${urlPath} -> ${res.statusCode}: ${data}`));
            }
          });
        },
      );
      req.on('error', reject);
      if (body) req.write(JSON.stringify(body));
      req.end();
    }, reject);
  });
}

const base = `/v1/projects/${PROJECT}/databases/(default)/documents`;

function parseValue(value) {
  if (value?.stringValue !== undefined) return value.stringValue;
  if (value?.integerValue !== undefined) return Number(value.integerValue);
  if (value?.doubleValue !== undefined) return Number(value.doubleValue);
  if (value?.booleanValue !== undefined) return value.booleanValue;
  if (value?.nullValue !== undefined) return null;
  if (value?.timestampValue !== undefined) return value.timestampValue;
  if (value?.arrayValue) return (value.arrayValue.values || []).map(parseValue);
  if (value?.mapValue) return parseFields(value.mapValue.fields || {});
  return value;
}

function parseFields(fields) {
  return Object.fromEntries(Object.entries(fields || {}).map(([key, value]) => [key, parseValue(value)]));
}

function toFirestoreValue(value) {
  if (value === null || value === undefined) return { nullValue: null };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'number') {
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  }
  if (typeof value === 'boolean') return { booleanValue: value };
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(toFirestoreValue) } };
  }
  const fields = {};
  for (const [key, item] of Object.entries(value)) {
    fields[key] = toFirestoreValue(item);
  }
  return { mapValue: { fields } };
}

async function patchDocument(relativePath, fields) {
  const mask = Object.keys(fields)
    .map((key) => `updateMask.fieldPaths=${encodeURIComponent(key)}`)
    .join('&');
  return request('PATCH', `${base}/${relativePath}?${mask}`, {
    fields: Object.fromEntries(
      Object.entries(fields).map(([key, value]) => [key, toFirestoreValue(value)]),
    ),
  });
}

function decodeDocument(doc) {
  if (!doc) return null;
  return {
    id: String(doc.name || '').split('/').pop(),
    createTime: doc.createTime,
    updateTime: doc.updateTime,
    ...parseFields(doc.fields || {}),
  };
}

async function getDocument(relativePath) {
  return decodeDocument(await request('GET', `${base}/${relativePath}`));
}

async function listDocuments(relativePath) {
  const response = await request('GET', `${base}/${relativePath}?pageSize=100`);
  return (response?.documents || []).map(decodeDocument);
}

function readJson(relativePath) {
  const filePath = path.join(WORKSPACE, relativePath);
  return fs.existsSync(filePath) ? JSON.parse(fs.readFileSync(filePath, 'utf8')) : null;
}

function select(object, keys) {
  if (!object) return null;
  return Object.fromEntries(keys.map((key) => [key, object[key]]));
}

async function audit() {
  const [job, project, stage, agent, workInstruction, commands, requests, stages] = await Promise.all([
    getDocument(`jobs/${JOB_ID}`),
    getDocument(`sotong24work_projects/${PROJECT_ID}`),
    getDocument(`sotong24work_projects/${PROJECT_ID}/stages/${STAGE_ID}`),
    getDocument(`agents/${AGENT_ID}`),
    getDocument(`workInstructions/${WORK_INSTRUCTION_DOC_ID}`),
    listDocuments(`jobs/${JOB_ID}/commands`),
    listDocuments(`sotong24work_projects/${PROJECT_ID}/requests`),
    listDocuments(`sotong24work_projects/${PROJECT_ID}/stages`),
  ]);

  const currentTask = readJson(path.join('.cursor-work', 'current_task.json'));
  const taskState = readJson(path.join('.cursor-work', 'task_state.json'));
  const expectedOutputs = (currentTask?.expectedOutputs || []).map((relative) => {
    const fullPath = path.join(WORKSPACE, relative);
    const stat = fs.existsSync(fullPath) ? fs.statSync(fullPath) : null;
    return {
      relative,
      exists: Boolean(stat),
      bytes: stat?.size || 0,
      modifiedAt: stat?.mtime?.toISOString() || null,
    };
  });

  const report = {
    capturedAt: new Date().toISOString(),
    instructionId: INSTRUCTION_ID,
    jobId: JOB_ID,
    projectId: PROJECT_ID,
    workspace: WORKSPACE,
    job: select(job, [
      'status', 'currentStage', 'currentStageId', 'currentStageOrder', 'revision',
      'activityState', 'lastActivityAt', 'progress', 'approvalMode', 'agentId',
      'recoveryAttempt', 'recoveryStatus', 'recoveryCommandId', 'updatedAt',
    ]),
    project: select(project, [
      'title', 'projectName', 'productType', 'status', 'currentStage', 'currentStageId',
      'currentStageOrder', 'revision', 'activityState', 'lastActivityAt', 'progress',
      'approvalMode', 'currentWorker', 'executorKind', 'taskId', 'recoveryAttempt',
      'recoveryStatus', 'recoveryCommandId', 'updatedAt',
    ]),
    stage: select(stage, [
      'stageId', 'stageKey', 'stageNumber', 'order', 'title', 'status', 'revision',
      'activityState', 'lastActivityAt', 'progress', 'approvalMode', 'approvalStatus',
      'executorKind', 'worker', 'requestedWorker', 'taskId', 'expectedOutputs',
      'activeRequestId', 'workflowApplied', 'recoveryAttempt', 'recoveryStatus',
      'recoveryCommandId', 'updatedAt',
    ]),
    agent: select(agent, [
      'status', 'state', 'currentJobId', 'currentStage', 'lastHeartbeatAt',
      'lastPullAt', 'lastSeenAt', 'updatedAt',
    ]),
    workInstruction: workInstruction
      ? {
          id: workInstruction.id,
          status: workInstruction.status,
          checksum: workInstruction.checksum,
          worker: workInstruction.json?.aiExecution?.worker,
          approvalMode: workInstruction.json?.aiExecution?.approvalMode,
        }
      : null,
    commands: commands.map((command) => ({
      ...select(command, [
        'id', 'type', 'status', 'attempt', 'idempotencyKey', 'agentId', 'ownerId',
        'jobId', 'instructionId', 'claimedAt', 'completedAt', 'failedAt', 'error',
        'createdAt', 'updatedAt',
      ]),
      payloadSummary: command.payload
        ? {
            instructionId: command.payload.instructionId,
            artifactType: command.payload.artifactType,
            aiExecution: command.payload.aiExecution,
            currentStage: command.payload.workflow?.currentStage,
          }
        : null,
    })),
    requests: requests.map((requestDoc) => select(requestDoc, [
      'id', 'type', 'action', 'stageId', 'stageNumber', 'revision', 'status',
      'processed', 'workflowApplied', 'createdAt', 'updatedAt',
    ])),
    stages: stages.map((stageDoc) => select(stageDoc, [
      'id', 'stageId', 'stageNumber', 'status', 'revision', 'activityState',
      'lastActivityAt', 'executorKind', 'worker', 'taskId', 'progress',
    ])),
    local: {
      currentTask,
      taskState,
      expectedOutputs,
    },
  };
  console.log(JSON.stringify(report, null, 2));
  return report;
}

const CORE_KEYS = new Set([
  'schemaVersion', 'instructionId', 'instructionVersion', 'projectId',
  'businessIdea', 'businessPurpose', 'customerProblem', 'targetCustomer',
  'deliverableTypes', 'recommendedSequence', 'valueProposition',
  'requiredMaterials', 'workflowSteps', 'completionCriteria', 'qualityChecks',
  'risks', 'monetizationOptions', 'deploymentTargets', 'promotionChannels',
  'approvalItems', 'executionStatus', 'notes', 'primaryTrack',
  'followUpTracks', 'artifactType', 'contentSubtype', 'identity',
  'projectDefinition', 'positioning', 'scope', 'productionSpec',
  'qualityCriteria', 'aiGuards', 'workflow', 'approval', 'validation',
  'aiExecution',
]);
const SORTABLE_STRING_LIST_KEYS = new Set([
  'deliverableTypes', 'recommendedSequence', 'requiredMaterials',
  'completionCriteria', 'qualityChecks', 'risks', 'monetizationOptions',
  'deploymentTargets', 'promotionChannels', 'approvalItems', 'followUpTracks',
]);

function canonicalize(value) {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (!value || typeof value !== 'object') return value;
  return Object.fromEntries(
    Object.keys(value).sort().map((key) => [key, canonicalize(value[key])]),
  );
}

function stableContentChecksum(source) {
  const raw = JSON.parse(JSON.stringify(source));
  const version = String(raw.instructionVersion ?? raw.version ?? '').trim();
  if (version) raw.instructionVersion = version;
  delete raw.version;
  raw.followUpTracks = Array.isArray(raw.followUpTracks)
    ? raw.followUpTracks.map(String)
    : Array.isArray(raw.followupTracks) ? raw.followupTracks.map(String) : [];
  delete raw.followupTracks;
  for (const key of ['contentSubtype', 'notes', 'sourceFileName', 'status']) {
    if (raw[key] == null || String(raw[key]).trim() === '') raw[key] = '';
  }
  if (Array.isArray(raw.workflowSteps)) {
    raw.workflowSteps = raw.workflowSteps.map((step) => ({
      order: Number(step.order) || 0,
      id: String(step.id || ''),
      title: String(step.title || ''),
      applicable: step.applicable !== false,
      completionCriteria: String(step.completionCriteria || ''),
      notes: String(step.notes || ''),
    })).sort((a, b) => a.order - b.order || a.id.localeCompare(b.id));
  }
  for (const key of SORTABLE_STRING_LIST_KEYS) {
    if (Array.isArray(raw[key])) raw[key] = raw[key].map(String);
  }
  const core = {};
  for (const key of CORE_KEYS) {
    if (raw[key] !== undefined && raw[key] !== null) core[key] = raw[key];
  }
  if (core.notes === undefined) core.notes = '';
  if (core.contentSubtype === undefined) core.contentSubtype = '';
  const encoded = JSON.stringify(canonicalize(core));
  let hash = 2166136261;
  for (let index = 0; index < encoded.length; index += 1) {
    hash ^= encoded.charCodeAt(index);
    hash = Math.imul(hash, 16777619) >>> 0;
  }
  return hash.toString(16).padStart(8, '0');
}

function withCodexPolicy(payload, recoveryAction = '') {
  const next = JSON.parse(JSON.stringify(payload));
  next.aiExecution = {
    ...(next.aiExecution || {}),
    enabled: true,
    worker: 'codex',
    maxAutoStageOrder: 18,
    approvalRequired: false,
    approvalMode: 'auto',
    artifactUploadEnabled: true,
    autoAdvance: true,
    deploymentAllowed: false,
  };
  if (next.recovery && recoveryAction) {
    next.recovery = { ...next.recovery, action: recoveryAction };
  }
  const checksum = stableContentChecksum(next);
  next.checksum = checksum;
  next.contentChecksum = checksum;
  next.checksumAlgorithm = 'canonical_v2';
  next.updatedAt = new Date().toISOString();
  return next;
}

function backupJson(directory, name, value) {
  fs.mkdirSync(directory, { recursive: true });
  fs.writeFileSync(path.join(directory, name), `${JSON.stringify(value, null, 2)}\n`, 'utf8');
}

function patchLocalInstruction(filePath, backupDirectory) {
  if (!fs.existsSync(filePath)) throw new Error(`local instruction missing: ${filePath}`);
  const before = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  backupJson(backupDirectory, path.basename(filePath), before);
  const after = withCodexPolicy(before);
  fs.writeFileSync(filePath, `${JSON.stringify(after, null, 2)}\n`, 'utf8');
  return after;
}

async function switchCodex() {
  const before = await audit();
  const queuedRecovery = before.commands.find(
    (command) => command.id === before.stage.recoveryCommandId,
  );
  const expectedTaskId = `${INSTRUCTION_ID}__${STAGE_ID}__r1`;
  const output = before.local.expectedOutputs[0];
  const conditions = [
    [before.job.status === 'stalled', 'job must be stalled'],
    [before.project.currentStageId === STAGE_ID, 'project stage mismatch'],
    [before.stage.stageId === STAGE_ID && before.stage.revision === 1, 'stage/revision mismatch'],
    [before.local.currentTask?.taskId === expectedTaskId, 'taskId mismatch'],
    [before.local.currentTask?.revision === 1, 'local revision mismatch'],
    [before.local.taskState?.state === 'waiting_for_cursor', 'task is not waiting_for_cursor'],
    [before.local.taskState?.executorKind === 'cursor', 'executor is not cursor'],
    [before.local.taskState?.processId === 0, 'Cursor process ownership is active'],
    [before.local.taskState?.invokeAttempted === false, 'Cursor invocation was attempted'],
    [output && output.exists === false, 'expected output already exists'],
    [queuedRecovery?.status === 'queued', 'recovery command is not queued'],
  ];
  const failed = conditions.filter(([ok]) => !ok).map(([, message]) => message);
  if (failed.length) throw new Error(`precondition failed: ${failed.join('; ')}`);

  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const backupDirectory = path.join(__dirname, '..', 'ops_backup', `step2_codex_${stamp}`);
  backupJson(backupDirectory, 'audit.before.json', before);

  const wi = await getDocument(`workInstructions/${WORK_INSTRUCTION_DOC_ID}`);
  if (!wi?.json || wi.json.instructionId !== INSTRUCTION_ID) {
    throw new Error('workInstruction identity mismatch');
  }
  const patchedInstruction = withCodexPolicy(wi.json);
  await patchDocument(`workInstructions/${WORK_INSTRUCTION_DOC_ID}`, {
    json: patchedInstruction,
    checksum: patchedInstruction.checksum,
    updatedAt: new Date().toISOString(),
  });

  for (const command of before.commands) {
    if (command.type !== 'START_JOB' || !command.payloadSummary) continue;
    const full = await getDocument(`jobs/${JOB_ID}/commands/${command.id}`);
    if (!full?.payload || full.payload.instructionId !== INSTRUCTION_ID) continue;
    const action = command.id === queuedRecovery.id ? 'executor_redispatch_codex' : '';
    await patchDocument(`jobs/${JOB_ID}/commands/${command.id}`, {
      payload: withCodexPolicy(full.payload, action),
      updatedAt: new Date().toISOString(),
    });
  }

  const localInstructionPath = path.join(
    process.env.LOCALAPPDATA || '', 'SotongWare', 'Sotong24Work',
    'WorkInstructions', `wi_${INSTRUCTION_ID}.json`,
  );
  patchLocalInstruction(localInstructionPath, backupDirectory);

  const after = await audit();
  backupJson(backupDirectory, 'audit.after.json', after);
  if (after.workInstruction.worker !== 'codex') {
    throw new Error('remote WorkInstruction worker patch not visible');
  }
  const afterQueued = after.commands.find((command) => command.id === queuedRecovery.id);
  if (afterQueued?.payloadSummary?.aiExecution?.worker !== 'codex' ||
      afterQueued.status !== 'queued') {
    throw new Error('queued recovery command patch verification failed');
  }
  console.log(JSON.stringify({
    ok: true,
    backupDirectory,
    preserved: {
      instructionId: INSTRUCTION_ID,
      jobId: JOB_ID,
      projectId: PROJECT_ID,
      stageId: STAGE_ID,
      revision: 1,
      taskId: expectedTaskId,
    },
    recoveryCommandId: queuedRecovery.id,
    worker: 'codex',
  }, null, 2));
}

const mode = String(process.argv[2] || 'audit').trim();
const operation = mode === 'audit' ? audit : mode === 'switch-codex' ? switchCodex : null;
if (!operation) {
  console.error('usage: audit | switch-codex');
  process.exit(2);
}
operation().catch((error) => {
  console.error(error);
  process.exit(1);
});
