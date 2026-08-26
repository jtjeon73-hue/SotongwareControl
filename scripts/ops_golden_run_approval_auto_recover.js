#!/usr/bin/env node
/**
 * Golden Run recovery: keep existing STEP 1, switch approvalMode=auto,
 * retain Agent approval poll context so the already-submitted approve request
 * can be applied (workflowApplied) and STEP 2 can dispatch.
 *
 * Does NOT create a new WorkInstruction / CLEAN RESET / delete data.
 *
 * Usage:
 *   node scripts/ops_golden_run_approval_auto_recover.js audit
 *   node scripts/ops_golden_run_approval_auto_recover.js apply
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

const PROJECT = 'sotongware-control';
const INSTRUCTION_ID = 'wi_plan_1787699077625';
const JOB_ID = 'job_a3777efca75b1d0c';
const COMMAND_ID = 'cmd_94a3ef89e4954738';
const REQUEST_ID = 'req_app_idea_1787703193611000';
const STAGE_ID = 'app_idea';
const STAGE_NUMBER = 1;

const ROOT = path.join(__dirname, '..');
const DOCS = path.join(process.env.USERPROFILE || '', 'Documents', 'Sotong24Work');
const STATE_DIR = path.join(DOCS, 'State');
const WORKSPACE = path.join(DOCS, 'AppProjects', 'SotongApp1_App787699077625');
const BACKUP_DIR = path.join(
  ROOT,
  'ops_backup',
  `approval_auto_recover_${INSTRUCTION_ID}_${new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19)}`,
);

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

function patchLocalJson(filePath, mutator) {
  if (!fs.existsSync(filePath)) return { ok: false, reason: 'missing' };
  const before = fs.readFileSync(filePath, 'utf8');
  const json = JSON.parse(before);
  mutator(json);
  fs.writeFileSync(filePath, `${JSON.stringify(json, null, 2)}\n`, 'utf8');
  return { ok: true };
}

async function audit() {
  const [jobDoc, projDoc, stageDoc, reqDoc, cmdDoc] = await Promise.all([
    request('GET', `${base}/jobs/${JOB_ID}`),
    request('GET', `${base}/sotong24work_projects/${INSTRUCTION_ID}`),
    request('GET', `${base}/sotong24work_projects/${INSTRUCTION_ID}/stages/${STAGE_ID}`),
    request('GET', `${base}/sotong24work_projects/${INSTRUCTION_ID}/requests/${REQUEST_ID}`),
    request('GET', `${base}/jobs/${JOB_ID}/commands/${COMMAND_ID}`),
  ]);
  const job = parseFields(jobDoc.fields || {});
  const project = parseFields(projDoc.fields || {});
  const stage = parseFields(stageDoc.fields || {});
  const req = parseFields(reqDoc.fields || {});
  const cmd = parseFields(cmdDoc.fields || {});
  const report = {
    instructionId: INSTRUCTION_ID,
    jobId: JOB_ID,
    requestId: REQUEST_ID,
    jobStatus: job.status,
    jobApprovalMode: job.approvalMode,
    projectStatus: project.status,
    projectApprovalStatus: project.approvalStatus,
    projectApprovalMode: project.approvalMode,
    stageStatus: stage.status,
    stageApprovalStatus: stage.approvalStatus,
    activeRequestId: stage.activeRequestId,
    request: {
      status: req.status,
      processed: req.processed,
      workflowApplied: req.workflowApplied,
    },
    commandAiExecution: (cmd.payload || {}).aiExecution || null,
    localPollContextExists: fs.existsSync(path.join(STATE_DIR, 'approval_poll_context.json')),
    localTaskState: (() => {
      const p = path.join(WORKSPACE, '.cursor-work', 'task_state.json');
      if (!fs.existsSync(p)) return null;
      return JSON.parse(fs.readFileSync(p, 'utf8'));
    })(),
  };
  console.log(JSON.stringify(report, null, 2));
  return report;
}

async function apply() {
  fs.mkdirSync(BACKUP_DIR, { recursive: true });
  const before = await audit();
  saveBackup('audit.before.json', before);

  const ts = new Date().toISOString();
  const aiExecution = {
    enabled: true,
    worker: 'cursor',
    maxAutoStageOrder: 18,
    approvalRequired: false,
    approvalMode: 'auto',
    artifactUploadEnabled: true,
    autoAdvance: true,
    deploymentAllowed: false,
  };

  const cmdDoc = await request('GET', `${base}/jobs/${JOB_ID}/commands/${COMMAND_ID}`);
  const cmd = parseFields(cmdDoc.fields || {});
  saveBackup('command.before.json', cmd);
  const payload = { ...(cmd.payload || {}), aiExecution, updatedAt: ts };
  await request('PATCH', `${base}/jobs/${JOB_ID}/commands/${COMMAND_ID}?updateMask.fieldPaths=payload`, {
    fields: { payload: toFirestoreValue(payload) },
  });

  await request('PATCH', `${base}/jobs/${JOB_ID}?updateMask.fieldPaths=approvalMode&updateMask.fieldPaths=updatedAt`, {
    fields: {
      approvalMode: { stringValue: 'auto' },
      updatedAt: { stringValue: ts },
    },
  });

  await request(
    'PATCH',
    `${base}/sotong24work_projects/${INSTRUCTION_ID}?updateMask.fieldPaths=approvalMode&updateMask.fieldPaths=updatedAt`,
    {
      fields: {
        approvalMode: { stringValue: 'auto' },
        updatedAt: { stringValue: ts },
      },
    },
  );

  // Keep existing approve request; only ensure it remains actionable for Agent.
  await request(
    'PATCH',
    `${base}/sotong24work_projects/${INSTRUCTION_ID}/requests/${REQUEST_ID}?updateMask.fieldPaths=workflowApplied&updateMask.fieldPaths=processed&updateMask.fieldPaths=status&updateMask.fieldPaths=updatedAt`,
    {
      fields: {
        workflowApplied: { booleanValue: false },
        processed: { booleanValue: true },
        status: { stringValue: 'approved' },
        updatedAt: { stringValue: ts },
      },
    },
  );

  fs.mkdirSync(STATE_DIR, { recursive: true });
  const pollCtxPath = path.join(STATE_DIR, 'approval_poll_context.json');
  if (fs.existsSync(pollCtxPath)) {
    saveBackup('approval_poll_context.before.json', JSON.parse(fs.readFileSync(pollCtxPath, 'utf8')));
  }
  fs.writeFileSync(
    pollCtxPath,
    `${JSON.stringify(
      {
        schemaVersion: 1,
        retained: true,
        projectId: INSTRUCTION_ID,
        stageId: STAGE_ID,
        stageNumber: STAGE_NUMBER,
      },
      null,
      2,
    )}\n`,
    'utf8',
  );

  const ebookPath = path.join(STATE_DIR, `wi_${INSTRUCTION_ID}.ebook.json`);
  patchLocalJson(ebookPath, (j) => {
    if (!j.instruction) j.instruction = {};
    if (!j.instruction.aiExecution) j.instruction.aiExecution = {};
    Object.assign(j.instruction.aiExecution, aiExecution);
    if (j.aiExecution) Object.assign(j.aiExecution, aiExecution);
  });

  const wiDocPath = path.join(
    process.env.LOCALAPPDATA || '',
    'SotongWare',
    'Sotong24Work',
    'WorkInstructions',
    `wi_${INSTRUCTION_ID}.json`,
  );
  patchLocalJson(wiDocPath, (j) => {
    j.aiExecution = { ...(j.aiExecution || {}), ...aiExecution };
  });

  const importedPath = path.join(
    DOCS,
    'Instructions',
    'Imported',
    `remote_${COMMAND_ID}.json`,
  );
  patchLocalJson(importedPath, (j) => {
    j.aiExecution = { ...(j.aiExecution || {}), ...aiExecution };
  });

  const taskPath = path.join(WORKSPACE, '.cursor-work', 'current_task.json');
  patchLocalJson(taskPath, (j) => {
    j.approvalRequiredAfter = false;
    j.autoAdvance = true;
    if (!j.aiExecution) j.aiExecution = {};
    Object.assign(j.aiExecution, aiExecution);
  });

  const after = await audit();
  saveBackup('audit.after.json', after);
  console.log(JSON.stringify({ ok: true, backupDir: BACKUP_DIR, after }, null, 2));
}

async function main() {
  const mode = String(process.argv[2] || 'audit').trim();
  if (mode === 'audit') await audit();
  else if (mode === 'apply') await apply();
  else throw new Error(`unknown mode: ${mode}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
