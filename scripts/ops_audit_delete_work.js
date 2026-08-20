#!/usr/bin/env node
/**
 * One-off ops: audit / backup / delete a single instructionId from Firestore.
 * Usage:
 *   node scripts/ops_audit_delete_work.js audit
 *   node scripts/ops_audit_delete_work.js delete
 */
'use strict';

const fs = require('fs');
const path = require('path');
const https = require('https');

const auth = require(
  path.join(
    process.env.APPDATA || '',
    'npm/node_modules/firebase-tools/lib/auth',
  ),
);
const scopes = require(
  path.join(
    process.env.APPDATA || '',
    'npm/node_modules/firebase-tools/lib/scopes',
  ),
);

const PROJECT = 'sotongware-control';
const TARGET = 'wi_plan_1786083242850';
const PLAN_ID = 'plan_1786083242850';
const ROOT = path.join(__dirname, '..');
const BACKUP_DIR = path.join(
  ROOT,
  'ops_backup',
  `${TARGET}_${new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19)}`,
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
              reject(
                new Error(`${method} ${urlPath} -> ${res.statusCode}: ${data}`),
              );
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

async function getDoc(docPath) {
  try {
    return await request('GET', `${base}/${docPath}`);
  } catch (e) {
    if (String(e.message).includes('404')) return null;
    throw e;
  }
}

async function listCollection(colPath, pageSize = 300) {
  return request('GET', `${base}/${colPath}?pageSize=${pageSize}`);
}

async function deleteDoc(docPath) {
  return request('DELETE', `${base}/${docPath}`);
}

function saveBackup(rel, data) {
  const out = path.join(BACKUP_DIR, rel);
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, JSON.stringify(data, null, 2), 'utf8');
}

async function collectProjectTree(projectId) {
  const tree = { project: null, stages: [], requests: [] };
  tree.project = await getDoc(`sotong24work_projects/${projectId}`);
  if (!tree.project) return tree;
  const stages = await listCollection(
    `sotong24work_projects/${projectId}/stages`,
  );
  tree.stages = stages.documents || [];
  for (const st of tree.stages) {
    const stageId = st.name.split('/').pop();
    const reqs = await listCollection(
      `sotong24work_projects/${projectId}/stages/${stageId}/requests`,
    );
    tree.requests.push({ stageId, documents: reqs.documents || [] });
  }
  const topReqs = await listCollection(
    `sotong24work_projects/${projectId}/requests`,
  );
  tree.topRequests = topReqs.documents || [];
  return tree;
}

async function audit() {
  const report = { target: TARGET, planId: PLAN_ID, found: {} };

  report.found.workInstruction = await getDoc(`workInstructions/${TARGET}`);
  report.found.project = await getDoc(`sotong24work_projects/${TARGET}`);
  report.found.projectTree = await collectProjectTree(TARGET);

  const jobs = await listCollection('jobs');
  report.found.jobs = (jobs.documents || []).filter((d) => {
    const f = d.fields || {};
    const iid = f.instructionId?.stringValue || '';
    const pid = f.planId?.stringValue || '';
    const id = d.name.split('/').pop();
    return id.includes(TARGET) || iid === TARGET || pid === PLAN_ID;
  });

  for (const job of report.found.jobs) {
    const jobId = job.name.split('/').pop();
    const cmds = await listCollection(`jobs/${jobId}/commands`);
    job._commands = cmds.documents || [];
    const stages = await listCollection(`jobs/${jobId}/stages`);
    job._stages = stages.documents || [];
  }

  const agents = await listCollection('agents');
  report.found.agents = (agents.documents || []).map((d) => {
    const f = d.fields || {};
    return {
      id: d.name.split('/').pop(),
      state: f.state?.stringValue,
      currentJobId: f.currentJobId?.stringValue,
      currentStage: f.currentStage?.stringValue,
      lastHeartbeatAt: f.lastHeartbeatAt?.timestampValue,
    };
  });

  const plans = await listCollection('businessPlans');
  report.found.businessPlans = (plans.documents || []).filter((d) => {
    const f = d.fields || {};
    const id = d.name.split('/').pop();
    const iid = f.instructionId?.stringValue || '';
    const title =
      f.title?.stringValue ||
      f.topic?.stringValue ||
      f.input?.mapValue?.fields?.topic?.stringValue ||
      '';
    return (
      id.includes('1786083242850') ||
      iid === TARGET ||
      String(title).includes('학습 도우미')
    );
  });

  console.log(JSON.stringify(report, null, 2));
  return report;
}

async function backupReport(report) {
  fs.mkdirSync(BACKUP_DIR, { recursive: true });
  saveBackup('firestore_audit.json', report);
  console.log('backup_dir', BACKUP_DIR);
}

async function clearAgentStale(agents) {
  for (const a of agents) {
    const cj = a.currentJobId || '';
    if (!cj.includes(TARGET) && cj !== TARGET) continue;
    const doc = await getDoc(`agents/${a.id}`);
    saveBackup(`agents/${a.id}.before.json`, doc);
    const fields = { ...(doc.fields || {}) };
    fields.currentJobId = { stringValue: '' };
    fields.currentStage = { stringValue: '' };
    if (fields.state?.stringValue && fields.state.stringValue !== 'offline') {
      fields.state = { stringValue: 'idle' };
    }
    await request('PATCH', `${base}/agents/${a.id}?updateMask.fieldPaths=currentJobId&updateMask.fieldPaths=currentStage&updateMask.fieldPaths=state`, {
      fields,
    });
    console.log('agent cleared stale pointers', a.id);
  }
}

async function deleteTree() {
  const report = await audit();
  await backupReport(report);

  if (report.found.workInstruction) {
    await deleteDoc(`workInstructions/${TARGET}`);
    console.log('deleted workInstructions', TARGET);
  }

  const tree = report.found.projectTree;
  if (tree.project) {
    for (const block of tree.requests || []) {
      for (const r of block.documents || []) {
        const rid = r.name.split('/').pop();
        await deleteDoc(
          `sotong24work_projects/${TARGET}/stages/${block.stageId}/requests/${rid}`,
        );
      }
    }
    for (const r of tree.topRequests || []) {
      const rid = r.name.split('/').pop();
      await deleteDoc(`sotong24work_projects/${TARGET}/requests/${rid}`);
    }
    for (const st of tree.stages || []) {
      const sid = st.name.split('/').pop();
      await deleteDoc(`sotong24work_projects/${TARGET}/stages/${sid}`);
    }
    await deleteDoc(`sotong24work_projects/${TARGET}`);
    console.log('deleted sotong24work_projects tree', TARGET);
  }

  for (const job of report.found.jobs || []) {
    const jobId = job.name.split('/').pop();
    for (const c of job._commands || []) {
      const cid = c.name.split('/').pop();
      await deleteDoc(`jobs/${jobId}/commands/${cid}`);
    }
    for (const s of job._stages || []) {
      const sid = s.name.split('/').pop();
      await deleteDoc(`jobs/${jobId}/stages/${sid}`);
    }
    await deleteDoc(`jobs/${jobId}`);
    console.log('deleted job', jobId);
  }

  for (const p of report.found.businessPlans || []) {
    const pid = p.name.split('/').pop();
    saveBackup(`businessPlans/${pid}.json`, p);
    await deleteDoc(`businessPlans/${pid}`);
    console.log('deleted businessPlan', pid);
  }

  await clearAgentStale(report.found.agents || []);

  const after = await audit();
  saveBackup('firestore_after_delete.json', after);
  console.log('done');
}

const mode = process.argv[2] || 'audit';
if (mode === 'audit') {
  audit().catch((e) => {
    console.error(e);
    process.exit(1);
  });
} else if (mode === 'delete') {
  deleteTree().catch((e) => {
    console.error(e);
    process.exit(1);
  });
} else {
  console.error('usage: audit | delete');
  process.exit(2);
}
