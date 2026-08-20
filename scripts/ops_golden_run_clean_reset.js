#!/usr/bin/env node
/**
 * Golden Run baseline — full user-work audit / backup / delete.
 *
 * Usage:
 *   node scripts/ops_golden_run_clean_reset.js audit
 *   node scripts/ops_golden_run_clean_reset.js delete
 *   node scripts/ops_golden_run_clean_reset.js verify
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
const STORAGE_BUCKET = 'sotongware-control.firebasestorage.app';
const PROTECTED_AGENT_ID = 'agent_9830758291f9c64e';
const ROOT = path.join(__dirname, '..');
const TS = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
const BACKUP_DIR = path.join(ROOT, 'ops_backup', `golden_run_clean_${TS}`);

const USER_WORK_COLLECTIONS = [
  'jobs',
  'workInstructions',
  'businessPlans',
  'sotong24work_projects',
];

const PRESERVE_TOP_LEVEL = new Set([
  'agents',
  'agentTokens',
  'pairingSessions',
  'users',
  'settings',
  'deployed_sites',
  'activity_logs',
  'business_units',
  'projects',
  'tasks',
  'work_logs',
  'deployments',
  'issues',
  'ai_reports',
  'ideas',
  'business_analysis_reports',
  'study_courses',
  'study_chapters',
  'study_content_blocks',
  'study_progress',
  'study_sessions',
  'study_notes',
  'study_questions',
  'study_assignments',
  'study_quizzes',
  'study_quiz_attempts',
  'study_review_items',
  'study_goals',
  'study_lessons',
  'study_course_versions',
  'study_learning_runs',
  'study_lesson_progress',
  'study_generation_jobs',
  'study_ai_messages',
  'study_ai_usage',
]);

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

function storageRequest(method, urlPath) {
  return new Promise((resolve, reject) => {
    accessToken().then((access) => {
      const req = https.request(
        {
          hostname: 'storage.googleapis.com',
          path: urlPath,
          method,
          headers: { Authorization: `Bearer ${access}` },
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
      req.end();
    }, reject);
  });
}

const base = `/v1/projects/${PROJECT}/databases/(default)/documents`;

async function listCollection(colPath, pageSize = 500) {
  const all = [];
  let pageToken = '';
  do {
    const q = pageToken
      ? `?pageSize=${pageSize}&pageToken=${encodeURIComponent(pageToken)}`
      : `?pageSize=${pageSize}`;
    const res = await request('GET', `${base}/${colPath}${q}`);
    all.push(...(res.documents || []));
    pageToken = res.nextPageToken || '';
  } while (pageToken);
  return all;
}

async function deleteDoc(docPath) {
  return request('DELETE', `${base}/${docPath}`);
}

async function listStoragePrefix(prefix) {
  const all = [];
  let pageToken = '';
  do {
    const params = new URLSearchParams({ prefix, maxResults: '1000' });
    if (pageToken) params.set('pageToken', pageToken);
    const res = await storageRequest(
      'GET',
      `/storage/v1/b/${encodeURIComponent(STORAGE_BUCKET)}/o?${params}`,
    );
    all.push(
      ...(res.items || []).map((item) => ({
        name: item.name,
        size: Number(item.size || 0),
        contentType: item.contentType || '',
        md5Hash: item.md5Hash || '',
        updated: item.updated || '',
      })),
    );
    pageToken = res.nextPageToken || '';
  } while (pageToken);
  return all;
}

async function deleteStorageObject(name) {
  return storageRequest(
    'DELETE',
    `/storage/v1/b/${encodeURIComponent(STORAGE_BUCKET)}/o/${encodeURIComponent(name)}`,
  );
}

function fieldStr(fields, key) {
  const f = fields?.[key];
  if (!f) return '';
  if (f.stringValue != null) return f.stringValue;
  if (f.timestampValue != null) return f.timestampValue;
  if (f.integerValue != null) return f.integerValue;
  if (f.booleanValue != null) return String(f.booleanValue);
  return '';
}

function decodeValue(value) {
  if (!value || typeof value !== 'object') return null;
  if (value.nullValue !== undefined) return null;
  if (value.stringValue !== undefined) return value.stringValue;
  if (value.booleanValue !== undefined) return value.booleanValue;
  if (value.integerValue !== undefined) return Number(value.integerValue);
  if (value.doubleValue !== undefined) return Number(value.doubleValue);
  if (value.timestampValue !== undefined) return value.timestampValue;
  if (value.referenceValue !== undefined) return value.referenceValue;
  if (value.bytesValue !== undefined) return '[bytes omitted]';
  if (value.arrayValue) return (value.arrayValue.values || []).map(decodeValue);
  if (value.mapValue) return decodeFields(value.mapValue.fields || {});
  return null;
}

function decodeFields(fields) {
  return Object.fromEntries(
    Object.entries(fields || {}).map(([key, value]) => [key, decodeValue(value)]),
  );
}

function titleFromFields(f) {
  return (
    fieldStr(f, 'title') ||
    fieldStr(f, 'topic') ||
    f.input?.mapValue?.fields?.topic?.stringValue ||
    f.payload?.mapValue?.fields?.topic?.stringValue ||
    ''
  );
}

function summarizeDoc(doc) {
  const f = doc.fields || {};
  const id = doc.name.split('/').pop();
  const data = decodeFields(f);
  return {
    id,
    path: doc.name.replace(`projects/${PROJECT}/databases/(default)/documents/`, ''),
    title: titleFromFields(f),
    instructionId: fieldStr(f, 'instructionId'),
    planId: fieldStr(f, 'planId'),
    jobId: fieldStr(f, 'jobId') || id,
    status: fieldStr(f, 'status') || fieldStr(f, 'state'),
    createdAt: fieldStr(f, 'createdAt'),
    updatedAt: fieldStr(f, 'updatedAt'),
    lastActivityAt: fieldStr(f, 'lastActivityAt'),
    activityState: fieldStr(f, 'activityState'),
    environment: fieldStr(f, 'environment') || 'unknown',
    isTest: f.isTest?.booleanValue === true,
    assignedAgentId: fieldStr(f, 'assignedAgentId'),
    currentStage: fieldStr(f, 'currentStage'),
    currentStageNumber: fieldStr(f, 'currentStageNumber'),
    activeRequestId: fieldStr(f, 'activeRequestId'),
    revision: fieldStr(f, 'revision'),
    source: fieldStr(f, 'source') || fieldStr(f, 'createdBy'),
    createTime: doc.createTime || '',
    updateTime: doc.updateTime || '',
    data,
  };
}

async function listSubcollection(parentPath, sub) {
  try {
    return await listCollection(`${parentPath}/${sub}`);
  } catch (e) {
    if (String(e.message).includes('404')) return [];
    throw e;
  }
}

async function collectJobTree(jobDoc) {
  const jobId = jobDoc.name.split('/').pop();
  const commands = await listSubcollection(`jobs/${jobId}`, 'commands');
  const stages = await listSubcollection(`jobs/${jobId}`, 'stages');
  return {
    job: summarizeDoc(jobDoc),
    commands: commands.map(summarizeDoc),
    stages: stages.map(summarizeDoc),
  };
}

async function collectProjectTree(projectDoc) {
  const projectId = projectDoc.name.split('/').pop();
  const stages = await listSubcollection(
    `sotong24work_projects/${projectId}`,
    'stages',
  );
  const requests = await listSubcollection(
    `sotong24work_projects/${projectId}`,
    'requests',
  );
  const stageRequests = [];
  for (const st of stages) {
    const stageId = st.name.split('/').pop();
    const reqs = await listSubcollection(
      `sotong24work_projects/${projectId}/stages/${stageId}`,
      'requests',
    );
    stageRequests.push({
      stageId,
      requests: reqs.map(summarizeDoc),
    });
  }
  return {
    project: summarizeDoc(projectDoc),
    stages: stages.map(summarizeDoc),
    topRequests: requests.map(summarizeDoc),
    stageRequests,
  };
}

async function collectAgents() {
  const docs = await listCollection('agents');
  return docs.map((d) => {
    const f = d.fields || {};
    const id = d.name.split('/').pop();
    return {
      id,
      deviceName: fieldStr(f, 'deviceName'),
      state: fieldStr(f, 'state'),
      enabled: fieldStr(f, 'enabled'),
      ownerUid: fieldStr(f, 'ownerUid'),
      currentJobId: fieldStr(f, 'currentJobId'),
      currentStage: fieldStr(f, 'currentStage'),
      lastHeartbeatAt: fieldStr(f, 'lastHeartbeatAt'),
      protected: id === PROTECTED_AGENT_ID,
    };
  });
}

async function fullAudit() {
  const report = {
    auditedAt: new Date().toISOString(),
    project: PROJECT,
    protectedAgentId: PROTECTED_AGENT_ID,
    counts: {},
    jobs: [],
    workInstructions: [],
    businessPlans: [],
    projects: [],
    agents: [],
    storageObjects: [],
    deletePlan: [],
    preservedSystem: {
      agents: [],
      note:
        'Catalogs/guides/wizard schema live in app bundle + SharedPreferences locally, not Firestore top-level collections.',
    },
  };

  const jobDocs = await listCollection('jobs');
  report.counts.jobs = jobDocs.length;
  for (const doc of jobDocs) {
    report.jobs.push(await collectJobTree(doc));
  }

  const wiDocs = await listCollection('workInstructions');
  report.counts.workInstructions = wiDocs.length;
  report.workInstructions = wiDocs.map(summarizeDoc);

  const planDocs = await listCollection('businessPlans');
  report.counts.businessPlans = planDocs.length;
  report.businessPlans = planDocs.map(summarizeDoc);

  const projectDocs = await listCollection('sotong24work_projects');
  report.counts.sotong24work_projects = projectDocs.length;
  for (const doc of projectDocs) {
    report.projects.push(await collectProjectTree(doc));
  }

  report.agents = await collectAgents();
  report.counts.agents = report.agents.length;

  // Build delete plan — all user work in target collections.
  for (const j of report.jobs) {
    report.deletePlan.push({
      kind: 'job',
      title: j.job.title,
      instructionId: j.job.instructionId,
      planId: j.job.planId,
      jobId: j.job.id,
      commandCount: j.commands.length,
      stageCount: j.stages.length,
    });
  }
  for (const wi of report.workInstructions) {
    report.deletePlan.push({
      kind: 'workInstruction',
      title: wi.title,
      instructionId: wi.instructionId || wi.id,
      planId: wi.planId,
      jobId: wi.jobId,
    });
  }
  for (const bp of report.businessPlans) {
    report.deletePlan.push({
      kind: 'businessPlan',
      title: bp.title,
      instructionId: bp.instructionId,
      planId: bp.planId || bp.id,
      jobId: bp.jobId,
    });
  }
  for (const p of report.projects) {
    report.deletePlan.push({
      kind: 'project',
      title: p.project.title,
      instructionId: p.project.instructionId || p.project.id,
      planId: p.project.planId,
      jobId: p.project.jobId,
      stageCount: p.stages.length,
      requestCount:
        p.topRequests.length +
        p.stageRequests.reduce((n, b) => n + b.requests.length, 0),
    });
  }

  report.preservedSystem.agents = report.agents.filter((a) => a.protected);

  const instructionIds = new Set();
  for (const item of report.deletePlan) {
    if (item.instructionId) instructionIds.add(item.instructionId);
  }
  for (const instructionId of instructionIds) {
    for (const lane of ['prod', 'test']) {
      const prefix = `sotong24/artifacts/${lane}/${instructionId}/`;
      const objects = await listStoragePrefix(prefix);
      report.storageObjects.push(
        ...objects.map((object) => ({ ...object, prefix })),
      );
    }
  }

  report.cleanup_before_counts = {
    jobs: report.counts.jobs,
    sotong24work_projects: report.counts.sotong24work_projects,
    workInstructions: report.counts.workInstructions,
    businessPlans: report.counts.businessPlans,
    jobCommands: report.jobs.reduce((n, j) => n + j.commands.length, 0),
    jobStages: report.jobs.reduce((n, j) => n + j.stages.length, 0),
    projectStages: report.projects.reduce((n, p) => n + p.stages.length, 0),
    projectRequests: report.projects.reduce(
      (n, p) =>
        n +
        p.topRequests.length +
        p.stageRequests.reduce((m, b) => m + b.requests.length, 0),
      0,
    ),
    agents: report.counts.agents,
    storageObjects: report.storageObjects.length,
    storageBytes: report.storageObjects.reduce((n, item) => n + item.size, 0),
  };

  return report;
}

function saveBackup(rel, data) {
  const out = path.join(BACKUP_DIR, rel);
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, JSON.stringify(data, null, 2), 'utf8');
}

async function clearAgentWorkPointers(agents, deletedJobIds) {
  const deleted = new Set(deletedJobIds);
  for (const a of agents) {
    const cj = a.currentJobId || '';
    if (!cj || !deleted.has(cj)) continue;
    const doc = await request('GET', `${base}/agents/${a.id}`);
    saveBackup(`agents/${a.id}.before_clear.json`, doc);
    const fields = { ...(doc.fields || {}) };
    fields.currentJobId = { stringValue: '' };
    fields.currentStage = { stringValue: '' };
    if (
      fields.state?.stringValue &&
      !['offline', 'error'].includes(fields.state.stringValue)
    ) {
      fields.state = { stringValue: 'idle' };
    }
    await request(
      'PATCH',
      `${base}/agents/${a.id}?updateMask.fieldPaths=currentJobId&updateMask.fieldPaths=currentStage&updateMask.fieldPaths=state`,
      { fields },
    );
    console.log('agent cleared stale pointers', a.id);
  }
}

async function deleteAllUserWork(report) {
  fs.mkdirSync(BACKUP_DIR, { recursive: true });
  saveBackup('before_audit.json', report);
  saveBackup('delete_plan.json', report.deletePlan);
  saveBackup('cleanup_before_counts.json', report.cleanup_before_counts);

  for (const object of report.storageObjects) {
    await deleteStorageObject(object.name);
    console.log('deleted storage object', object.name);
  }

  // Projects first (approvals/requests live here)
  for (const tree of report.projects) {
    const pid = tree.project.id;
    saveBackup(`sotong24work_projects/${pid}.json`, tree);
    for (const block of tree.stageRequests) {
      for (const r of block.requests) {
        await deleteDoc(
          `sotong24work_projects/${pid}/stages/${block.stageId}/requests/${r.id}`,
        );
      }
    }
    for (const r of tree.topRequests) {
      await deleteDoc(`sotong24work_projects/${pid}/requests/${r.id}`);
    }
    for (const st of tree.stages) {
      await deleteDoc(`sotong24work_projects/${pid}/stages/${st.id}`);
    }
    await deleteDoc(`sotong24work_projects/${pid}`);
    console.log('deleted project', pid, tree.project.title);
  }

  // Jobs + commands/stages
  const deletedJobIds = [];
  for (const tree of report.jobs) {
    const jobId = tree.job.id;
    deletedJobIds.push(jobId);
    saveBackup(`jobs/${jobId}.json`, tree);
    for (const c of tree.commands) {
      await deleteDoc(`jobs/${jobId}/commands/${c.id}`);
    }
    for (const s of tree.stages) {
      await deleteDoc(`jobs/${jobId}/stages/${s.id}`);
    }
    await deleteDoc(`jobs/${jobId}`);
    console.log('deleted job', jobId, tree.job.title);
  }

  // workInstructions
  for (const wi of report.workInstructions) {
    saveBackup(`workInstructions/${wi.id}.json`, wi);
    await deleteDoc(`workInstructions/${wi.id}`);
    console.log('deleted workInstruction', wi.id, wi.title);
  }

  // businessPlans — all user mirror docs (ownerUid__planId pattern)
  for (const bp of report.businessPlans) {
    saveBackup(`businessPlans/${bp.id}.json`, bp);
    await deleteDoc(`businessPlans/${bp.id}`);
    console.log('deleted businessPlan', bp.id, bp.title);
  }

  await clearAgentWorkPointers(report.agents, deletedJobIds);

  const after = await fullAudit();
  saveBackup('after_audit.json', after);
  saveBackup('after_counts.json', after.cleanup_before_counts);
  console.log('backup_dir', BACKUP_DIR);
  console.log('after_counts', JSON.stringify(after.cleanup_before_counts));
  return after;
}

async function verify() {
  const report = await fullAudit();
  const c = report.cleanup_before_counts;
  const ok =
    c.jobs === 0 &&
    c.sotong24work_projects === 0 &&
    c.workInstructions === 0 &&
    c.businessPlans === 0 &&
    c.jobCommands === 0 &&
    c.projectRequests === 0 &&
    c.storageObjects === 0;

  const agent = report.agents.find((a) => a.id === PROTECTED_AGENT_ID);
  console.log(JSON.stringify({ counts: c, agent, ok }, null, 2));
  return { ok, report, agent };
}

const mode = process.argv[2] || 'audit';
if (mode === 'audit') {
  fullAudit()
    .then((report) => {
      saveBackup('audit_only.json', report);
      console.log(JSON.stringify(report, null, 2));
      console.log('backup_dir', BACKUP_DIR);
    })
    .catch((e) => {
      console.error(e);
      process.exit(1);
    });
} else if (mode === 'delete') {
  fullAudit()
    .then((report) => deleteAllUserWork(report))
    .catch((e) => {
      console.error(e);
      process.exit(1);
    });
} else if (mode === 'verify') {
  verify()
    .then(({ ok }) => process.exit(ok ? 0 : 1))
    .catch((e) => {
      console.error(e);
      process.exit(1);
    });
} else {
  console.error('usage: audit | delete | verify');
  process.exit(2);
}
