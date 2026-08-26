#!/usr/bin/env node
/**
 * Golden Run app recovery: repair existing START_JOB payload workflow contract
 * and requeue failed command without creating a new WorkInstruction.
 *
 * Usage:
 *   node scripts/ops_golden_run_repair_app.js audit
 *   node scripts/ops_golden_run_repair_app.js repair
 */
'use strict';

const fs = require('fs');
const path = require('path');
const https = require('https');

const auth = require(
  path.join(process.env.APPDATA || '', 'npm/node_modules/firebase-tools/lib/auth'),
);
const scopes = require(
  path.join(process.env.APPDATA || '', 'npm/node_modules/firebase-tools/lib/scopes'),
);

const { APP_STAGE_CONTRACTS } = require('../functions/sotong24/canonical');

const PROJECT = 'sotongware-control';
const INSTRUCTION_ID = 'wi_plan_1787699077625';
const JOB_ID = 'job_a3777efca75b1d0c';
const COMMAND_ID = 'cmd_94a3ef89e4954738';
const ROOT = path.join(__dirname, '..');
const BACKUP_DIR = path.join(
  ROOT,
  'ops_backup',
  `golden_run_repair_${INSTRUCTION_ID}_${new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19)}`,
);

const APP_WORKFLOW_STAGES = APP_STAGE_CONTRACTS.map((stage) => ({
  order: stage.order,
  id: stage.id,
  title: stage.name,
  applicable: true,
  statusLabel: '적용',
  completionCriteria: stage.name,
  notes: '',
}));

const APP_WORKFLOW_CONTRACT = {
  workflowId: 'sotong24_app_production',
  currentStage: 'app_idea',
  startStage: 'app_idea',
  stages: APP_STAGE_CONTRACTS.map((stage) => ({
    id: stage.id,
    order: stage.order,
    title: stage.name,
    purpose: stage.name,
    completionCriteria: [stage.name],
    requiresApproval: stage.approvalTypicallyRequired === true,
  })),
};

async function accessToken() {
  const account = auth.getGlobalDefaultAccount();
  if (!account?.tokens?.refresh_token) {
    throw new Error('Firebase CLI login required');
  }
  const tok = await auth.getAccessToken(account.tokens.refresh_token, [
    scopes.CLOUD_PLATFORM,
  ]);
  return typeof tok === 'string' ? tok : tok.access_token;
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
          res.on('data', (c) => (data += c));
          res.on('end', () => {
            if (res.statusCode >= 200 && res.statusCode < 300) {
              resolve(data ? JSON.parse(data) : {});
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

function parseVal(v) {
  if (v?.stringValue !== undefined) return v.stringValue;
  if (v?.integerValue !== undefined) return Number(v.integerValue);
  if (v?.booleanValue !== undefined) return v.booleanValue;
  if (v?.nullValue !== undefined) return null;
  if (v?.timestampValue !== undefined) return v.timestampValue;
  if (v?.arrayValue) return (v.arrayValue.values || []).map(parseVal);
  if (v?.mapValue) return parseFields(v.mapValue.fields || {});
  return v;
}

function parseFields(fields) {
  const out = {};
  for (const [k, v] of Object.entries(fields || {})) out[k] = parseVal(v);
  return out;
}

function toFirestoreValue(val) {
  if (val === null || val === undefined) return { nullValue: null };
  if (typeof val === 'string') return { stringValue: val };
  if (typeof val === 'number') {
    return Number.isInteger(val)
      ? { integerValue: String(val) }
      : { doubleValue: val };
  }
  if (typeof val === 'boolean') return { booleanValue: val };
  if (Array.isArray(val)) {
    return { arrayValue: { values: val.map(toFirestoreValue) } };
  }
  if (typeof val === 'object') {
    const fields = {};
    for (const [k, v] of Object.entries(val)) fields[k] = toFirestoreValue(v);
    return { mapValue: { fields } };
  }
  return { stringValue: String(val) };
}

function saveBackup(name, data) {
  fs.mkdirSync(BACKUP_DIR, { recursive: true });
  fs.writeFileSync(path.join(BACKUP_DIR, name), JSON.stringify(data, null, 2), 'utf8');
}

async function readCommand() {
  const doc = await request('GET', `${base}/jobs/${JOB_ID}/commands/${COMMAND_ID}`);
  return parseFields(doc.fields || {});
}

async function readJob() {
  const doc = await request('GET', `${base}/jobs/${JOB_ID}`);
  return parseFields(doc.fields || {});
}

async function audit() {
  const [cmd, job] = await Promise.all([readCommand(), readJob()]);
  const payload = cmd.payload || {};
  const steps = (payload.workflowSteps || []).map((s) => ({ order: s.order, id: s.id }));
  const report = {
    instructionId: INSTRUCTION_ID,
    jobId: JOB_ID,
    commandId: COMMAND_ID,
    jobStatus: job.status,
    commandStatus: cmd.status,
    commandError: cmd.error,
    artifactType: payload.artifactType,
    aiExecution: payload.aiExecution,
    workflowFirst: steps.slice(0, 3),
    workflowLast: steps.slice(-3),
    expectedFirst: APP_WORKFLOW_STAGES.slice(0, 3).map((s) => ({ order: s.order, id: s.id })),
  };
  console.log(JSON.stringify(report, null, 2));
  return report;
}

function repairPayload(payload) {
  const repaired = JSON.parse(JSON.stringify(payload));
  repaired.workflowSteps = APP_WORKFLOW_STAGES;
  repaired.workflow = {
    ...(repaired.workflow || {}),
    ...APP_WORKFLOW_CONTRACT,
  };
  if (repaired.contract?.workflow) {
    repaired.contract.workflow = {
      ...(repaired.contract.workflow || {}),
      ...APP_WORKFLOW_CONTRACT,
    };
  }
  repaired.aiExecution = {
    ...(repaired.aiExecution || {}),
    enabled: true,
    worker: 'cursor',
    maxAutoStageOrder: 1,
    approvalRequired: true,
    approvalMode: 'manual',
    artifactUploadEnabled: true,
    autoAdvance: false,
    deploymentAllowed: false,
  };
  repaired.updatedAt = new Date().toISOString();
  repaired.executionStatus = 'Agent 재전달 대기';
  return repaired;
}

async function repair() {
  fs.mkdirSync(BACKUP_DIR, { recursive: true });
  const [beforeCmd, beforeJob] = await Promise.all([readCommand(), readJob()]);
  saveBackup('command.before.json', beforeCmd);
  saveBackup('job.before.json', beforeJob);

  const repairedPayload = repairPayload(beforeCmd.payload || {});
  saveBackup('payload.repaired.json', repairedPayload);

  const ts = new Date().toISOString();
  const cmdFields = {
    payload: toFirestoreValue(repairedPayload),
    status: { stringValue: 'queued' },
    updatedAt: { timestampValue: ts },
    claimedAt: { nullValue: null },
    completedAt: { nullValue: null },
    failedAt: { nullValue: null },
    error: { nullValue: null },
    attempt: { integerValue: '0' },
  };

  await request(
    'PATCH',
    `${base}/jobs/${JOB_ID}/commands/${COMMAND_ID}?` +
      [
        'updateMask.fieldPaths=payload',
        'updateMask.fieldPaths=status',
        'updateMask.fieldPaths=updatedAt',
        'updateMask.fieldPaths=claimedAt',
        'updateMask.fieldPaths=completedAt',
        'updateMask.fieldPaths=failedAt',
        'updateMask.fieldPaths=error',
        'updateMask.fieldPaths=attempt',
      ].join('&'),
    { fields: cmdFields },
  );

  const jobFields = {
    status: { stringValue: 'queued' },
    updatedAt: { timestampValue: ts },
    currentStage: { stringValue: '' },
    progress: { integerValue: '0' },
    startedAt: { nullValue: null },
    completedAt: { nullValue: null },
  };
  await request(
    'PATCH',
    `${base}/jobs/${JOB_ID}?` +
      [
        'updateMask.fieldPaths=status',
        'updateMask.fieldPaths=updatedAt',
        'updateMask.fieldPaths=currentStage',
        'updateMask.fieldPaths=progress',
        'updateMask.fieldPaths=startedAt',
        'updateMask.fieldPaths=completedAt',
      ].join('&'),
    { fields: jobFields },
  );

  const after = await audit();
  saveBackup('audit.after.json', after);
  console.log('backup_dir', BACKUP_DIR);
  console.log('repair_complete', after.commandStatus, after.jobStatus);
  console.log('');
  console.log('NEXT: clear local Agent/processed_commands.json entry for', COMMAND_ID);
  console.log('      then restart Sotong24Work Agent so START_JOB re-executes.');
}

const mode = process.argv[2] || 'audit';
if (mode === 'audit') {
  audit().catch((e) => {
    console.error(e);
    process.exit(1);
  });
} else if (mode === 'repair') {
  repair().catch((e) => {
    console.error(e);
    process.exit(1);
  });
} else {
  console.error('usage: audit | repair');
  process.exit(2);
}
