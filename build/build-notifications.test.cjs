const { test } = require('node:test');
const assert = require('node:assert/strict');
const notify = require('./build-notifications.cjs');

function fixture(conclusion = 'failure') {
  const run = {
    id: 10, workflow_id: 20, run_number: 70, run_attempt: 1, conclusion,
    head_branch: 'main', head_sha: 'abc123', head_repository: { full_name: 'owner/repo' },
    html_url: 'https://github.com/owner/repo/actions/runs/10',
  };
  const state = {
    latest: [run], issues: [], mutations: [],
    jobs: [{ name: 'Generate documentation and tests', conclusion: 'failure',
      html_url: `${run.html_url}/job/100`, steps: [{ name: 'Generate all artifacts', conclusion: 'failure' }] }],
  };
  const github = {
    rest: {
      actions: {
        listWorkflowRuns: async () => ({ data: { workflow_runs: state.latest } }),
        listJobsForWorkflowRunAttempt: async args => {
          assert.equal(args.attempt_number, run.run_attempt);
          return state.jobs;
        },
      },
      issues: {
        listForRepo: async args => {
          assert.equal(args.creator, 'github-actions[bot]');
          return state.issues.filter(issue => issue.state === 'open');
        },
        create: async args => {
          if (state.apiError) throw state.apiError;
          state.mutations.push({ method: 'create', ...args });
          state.issues.push({ ...args, number: 1, state: 'open' });
        },
        update: async args => {
          state.mutations.push({ method: 'update', ...args });
          Object.assign(state.issues.find(issue => issue.number === args.issue_number), args);
        },
      },
    },
    paginate: async (method, args) => method(args),
  };
  const summary = { addHeading: () => summary, addLink: () => summary, write: async () => {} };
  const context = { repo: { owner: 'owner', repo: 'repo' }, payload: { workflow_run: run } };
  return { run, state, invoke: () => notify({ github, context, core: { info() {}, summary } }) };
}

function successfulPublication() {
  return [
    { name: 'Build and Release', conclusion: 'success',
      steps: [{ name: 'Create GitHub release', conclusion: 'success' }] },
    { name: 'Publish generated wiki / publish', conclusion: 'success',
      steps: [{ name: 'Publish generated documentation to repository wiki', conclusion: 'success' }] },
  ];
}

test('failure creates an assigned issue with run, job and failed step links', async () => {
  const { state, invoke } = fixture();
  await invoke();
  assert.equal(state.mutations.length, 1);
  assert.equal(state.mutations[0].method, 'create');
  assert.deepEqual(state.mutations[0].assignees, ['Splaxi']);
  assert.match(state.issues[0].body, /Generate all artifacts/);
  assert.match(state.issues[0].body, /actions\/runs\/10\/job\/100/);
});

test('repeated completions are idempotent and later failures update one issue', async () => {
  const { run, state, invoke } = fixture();
  await invoke();
  await invoke();
  assert.equal(state.mutations.length, 1);
  run.run_attempt++;
  await invoke();
  assert.equal(state.issues.length, 1);
  assert.equal(state.mutations[1].method, 'update');
  assert.match(state.issues[0].body, /attempt 2/);
});

test('successful publication closes the failure issue with a recovery link', async () => {
  const { run, state, invoke } = fixture();
  await invoke();
  run.conclusion = 'success';
  state.jobs = successfulPublication();
  await invoke();
  assert.equal(state.issues[0].state, 'closed');
  assert.match(state.issues[0].body, /Recovered:.*actions\/runs\/10/);
});

test('validation-only and superseded publication runs leave the incident open', async () => {
  for (const skip of ['release', 'wiki']) {
    const { run, state, invoke } = fixture();
    await invoke();
    run.conclusion = 'success';
    state.jobs = successfulPublication();
    state.jobs[skip === 'release' ? 0 : 1].steps[0].conclusion = 'skipped';
    await invoke();
    assert.equal(state.issues[0].state, 'open');
    assert.equal(state.mutations.length, 1);
  }
});

test('old runs and old attempts cannot open or close an incident', async () => {
  for (const conclusion of ['failure', 'success']) {
    for (const newer of [{ id: 11, run_attempt: 1 }, { id: 10, run_attempt: 2 }]) {
      for (const incidentOpen of [false, true]) {
        const { run, state, invoke } = fixture();
        if (incidentOpen) await invoke();
        run.conclusion = conclusion;
        state.jobs = conclusion === 'success' ? successfulPublication() : state.jobs;
        state.latest = [newer];
        const before = structuredClone(state.issues);
        await invoke();
        assert.deepEqual(state.issues, before);
      }
    }
  }
});

test('cancelled runs, other branches and forks do not change issues', async () => {
  for (const change of [
    { conclusion: 'cancelled' }, { head_branch: 'feature' },
    { head_repository: { full_name: 'fork/repo' } },
  ]) {
    const { run, state, invoke } = fixture();
    Object.assign(run, change);
    await invoke();
    assert.equal(state.mutations.length, 0);
  }
});

test('workflow-level failures still alert without job details', async () => {
  const { state, invoke } = fixture('timed_out');
  state.jobs = [];
  await invoke();
  assert.match(state.issues[0].body, /workflow-level errors/);
});

test('an issue API error fails the notification job', async () => {
  const { state, invoke } = fixture();
  state.apiError = new Error('GitHub API unavailable');
  await assert.rejects(invoke, /GitHub API unavailable/);
});
