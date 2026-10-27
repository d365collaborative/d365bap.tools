const { test: nodeTest } = require('node:test');
const assert = require('node:assert/strict');

function approvalTests({ run, CHECK, ACCEPT, compareOption, pendingTitle, failureTitle, countLabel, reportPrefix }) {
  const test = (name, action) => nodeTest(`${CHECK}: ${name}`, action);
  function harness({ existing = true, changed = true } = {}) {
    const stamp = '2026-01-01T00:00:00Z';
    const comment = {
      id: 42, node_id: 'comment-node', body: ACCEPT, user: { login: 'maintainer', type: 'User' },
      created_at: '2026-01-01T00:01:00Z', updated_at: '2026-01-01T00:01:00Z', html_url: 'https://example.test/comment/42',
      issue_url: 'https://api.github.com/repos/owner/repo/issues/221', performed_via_github_app: null,
    };
    const state = {
      pr: { state: 'open', head: { sha: 'head' }, base: { sha: 'base', ref: 'main' } },
      permission: 'write', comment, updates: [],
      check: existing ? {
        id: 1, name: CHECK, app: { slug: 'github-actions' },
        external_id: JSON.stringify({ pr: 221, head: 'head', base: 'base', baseRef: 'main' }),
        started_at: stamp, completed_at: stamp, conclusion: 'failure',
        output: { title: pendingTitle },
      } : null,
    };
    const context = {
      repo: { owner: 'owner', repo: 'repo' }, runId: 123, eventName: 'pull_request_target',
      payload: { pull_request: { number: 221 }, action: 'synchronize' },
    };
    const github = {
      paginate: async () => state.check ? [structuredClone(state.check)] : [],
      graphql: async () => ({ node: { id: 'comment-node', lastEditedAt: state.lastEditedAt ?? null } }),
      rest: {
        pulls: { get: async () => ({ data: structuredClone(state.pr) }) },
        checks: {
          listForRef() {},
          create: async input => {
            state.check = { ...input, id: 2, app: { slug: 'github-actions' } };
            return { data: structuredClone(state.check) };
          },
          update: async input => {
            state.updates.push(input);
            Object.assign(state.check, input);
            return { data: state.check };
          },
        },
        issues: { getComment: async () => {
          if (!state.comment) throw Object.assign(new Error('deleted'), { status: 404 });
          return { data: state.comment };
        } },
        repos: { getCollaboratorPermissionLevel: async () => ({ data: { permission: state.permission } }) },
      },
    };
    const args = {
      github, context, core: { info() {} },
      compareChanges: async () => ({ changes: changed ? [{ name: 'Get-Example', before: 'param()', after: 'param([switch]$New)' }] : [] }),
    };
    return {
      state, args,
      accept() {
        context.eventName = 'issue_comment';
        context.payload = { issue: { number: 221 }, action: 'created', comment: structuredClone(comment) };
      },
      approvedPreviously() {
        state.check.external_id = JSON.stringify({ pr: 221, head: 'head', base: 'base', baseRef: 'main', commentId: 42 });
        state.check.conclusion = 'success';
      },
      async result() { await run({ ...args, [compareOption]: args.compareChanges }); return state.check.conclusion; },
    };
  }

  test('changes stay red on first run and reruns after regeneration', async () => {
    for (const existing of [false, true]) {
      const h = harness({ existing });
      assert.equal(await h.result(), 'failure');
      assert.ok(h.state.check.output.summary.includes(ACCEPT));
    }
  });

  test('unchanged protected content passes without acceptance', async () => {
    assert.equal(await harness({ changed: false }).result(), 'success');
  });

  test('a fresh fixed maintainer comment accepts the reviewed revision', async () => {
    const h = harness(); h.accept();
    assert.equal(await h.result(), 'success');
    assert.equal(JSON.parse(h.state.check.external_id).commentId, 42);
  });

  test('same-revision reruns preserve verified acceptance', async () => {
    const h = harness(); h.approvedPreviously();
    assert.equal(await h.result(), 'success');
  });

  test('unrelated reruns do not invalidate a comment after the first report', async () => {
    const h = harness(); h.accept();
    h.state.check.external_id = JSON.stringify({ pr: 221, head: 'head', base: 'base', baseRef: 'main', readyAt: '2026-01-01T00:00:00Z' });
    h.state.check.completed_at = '2026-01-01T00:02:00Z';
    assert.equal(await h.result(), 'success');
  });

  test('editing acceptance revokes it even within the same timestamp second', async () => {
    const h = harness(); h.approvedPreviously(); h.accept();
    h.args.context.payload.action = 'edited';
    assert.equal(await h.result(), 'failure');
  });

  test('same-second edit revokes acceptance even if its event was superseded', async () => {
    const h = harness(); h.approvedPreviously();
    h.state.lastEditedAt = h.state.comment.created_at;
    assert.equal(await h.result(), 'failure');
  });

  test('missing edit marker fails closed', async () => {
    const h = harness(); h.approvedPreviously();
    h.args.github.graphql = async () => ({ node: { id: 'comment-node' } });
    assert.equal(await h.result(), 'failure');
  });

  test('edit marker API failure fails closed', async () => {
    const h = harness(); h.approvedPreviously();
    h.args.github.graphql = async () => { throw new Error('GraphQL unavailable'); };
    await assert.rejects(h.result(), /GraphQL unavailable/);
    assert.equal(h.state.check.conclusion, 'failure');
  });

  for (const scenario of ['bot', 'app', 'reader', 'wrong text', 'other command', 'other check', 'other app', 'other PR check', 'whitespace', 'other issue', 'mismatched timestamp', 'mismatched author', 'edited comment', 'comment predates check', 'check not finished', 'comparison failed', 'no check', 'new head', 'new base']) {
    test(`cannot accept: ${scenario}`, async () => {
      const h = harness(); h.accept();
      switch (scenario) {
        case 'bot': h.state.comment.user.type = 'Bot'; break;
        case 'app': h.state.comment.performed_via_github_app = { slug: 'some-app' }; break;
        case 'reader': h.state.permission = 'read'; break;
        case 'wrong text': h.state.comment.body = 'LGTM'; break;
        case 'other command': h.state.comment.body = ACCEPT === '/accept-intenal-hook' ? '/accept-signature-change' : '/accept-intenal-hook'; break;
        case 'other check': h.state.check.name = 'Unrelated approval'; break;
        case 'other app': h.state.check.app.slug = 'untrusted-app'; break;
        case 'other PR check': h.state.check.external_id = JSON.stringify({ pr: 222, head: 'head', base: 'base', baseRef: 'main' }); break;
        case 'whitespace': h.state.comment.body = ` ${ACCEPT}`; break;
        case 'other issue': h.state.comment.issue_url = 'https://api.github.com/repos/owner/repo/issues/222'; break;
        case 'mismatched timestamp': h.state.comment.created_at = h.state.comment.updated_at = '2026-01-01T00:02:00Z'; break;
        case 'mismatched author': h.state.comment.user.login = 'someone-else'; break;
        case 'edited comment': h.state.comment.updated_at = '2026-01-01T00:02:00Z'; break;
        case 'comment predates check': h.args.context.payload.comment.created_at = '2025-12-31T00:00:00Z'; break;
        case 'check not finished': h.state.check.conclusion = null; break;
        case 'comparison failed': h.state.check.output.title = failureTitle; break;
        case 'no check': h.state.check = null; break;
        case 'new head': h.state.pr.head.sha = 'new-head'; break;
        case 'new base': h.state.pr.base.sha = 'new-base'; break;
      }
      assert.equal(await h.result(), 'failure');
    });
  }

  for (const scenario of ['deleted', 'edited', 'permission removed', 'new head', 'new base', 'new base ref']) {
    test(`previous acceptance is revoked: ${scenario}`, async () => {
      const h = harness(); h.approvedPreviously();
      switch (scenario) {
        case 'deleted': h.state.comment = null; break;
        case 'edited': h.state.comment.updated_at = '2026-01-01T00:02:00Z'; break;
        case 'permission removed': h.state.permission = 'read'; break;
        case 'new head': h.state.pr.head.sha = 'new-head'; break;
        case 'new base': h.state.pr.base.sha = 'new-base'; break;
        case 'new base ref': h.state.pr.base.ref = 'release'; break;
      }
      assert.equal(await h.result(), 'failure');
    });
  }

  test('comparison errors fail closed even with valid acceptance', async () => {
    const h = harness(); h.approvedPreviously();
    h.args.compareChanges = async () => { throw new Error('parser failed'); };
    await assert.rejects(h.result(), /parser failed/);
    assert.equal(h.state.check.conclusion, 'failure');
  });

  test('invalid comparison output fails closed', async () => {
    for (const result of [{}, { changes: 'none' }, { changes: [{ name: 'bad', before: null }] }]) {
      const h = harness(); h.approvedPreviously();
      h.args.compareChanges = async () => result;
      await assert.rejects(h.result(), /Invalid .* comparison result/);
      assert.equal(h.state.check.conclusion, 'failure');
    }
  });

  test('large reports disclose omissions and log all changes without workflow commands', async () => {
    const h = harness();
    const changes = [
      { name: 'First', before: '', after: 'x'.repeat(30000) },
      { name: 'Second', before: '', after: `${'y'.repeat(45000)}\n::error::unsafe\r😀` },
      { name: 'Third', before: null, after: 'new' },
    ];
    const logs = [];
    h.args.core.info = line => logs.push(line);
    h.args.compareChanges = async () => ({ changes });
    assert.equal(await h.result(), 'failure');
    const summary = h.state.check.output.summary;
    assert.ok(summary.length <= 60000);
    assert.match(summary, new RegExp(`${countLabel}: 3`));
    assert.match(summary, /Report truncated: 2 of 3/);
    assert.match(summary, /First/);
    const reportLines = logs.filter(line => line.startsWith(`${reportPrefix} report JSON part `));
    assert.ok(reportLines.length > 1);
    assert.ok(reportLines.every(line => !/[\r\n]/.test(line)));
    const report = reportLines.map(line => line.slice(line.indexOf(': ') + 2)).join('');
    assert.deepEqual(JSON.parse(report), { changes });
  });

  test('summary limit counts UTF-8 bytes for Unicode declarations', async () => {
    const h = harness();
    const logs = [];
    h.args.core.info = line => logs.push(line);
    h.args.compareChanges = async () => ({
      changes: [{ name: 'Unicode', before: '', after: '😀'.repeat(20000) }],
    });
    assert.equal(await h.result(), 'failure');
    assert.ok(Buffer.byteLength(h.state.check.output.summary, 'utf8') <= 60000);
    assert.match(h.state.check.output.summary, /Report truncated: 1 of 1/);
    assert.ok(logs.some(line => line.startsWith(`${reportPrefix} report JSON part `)));
  });

  test('acceptance removed while comparing cannot pass', async () => {
    const h = harness(); h.approvedPreviously();
    h.args.compareChanges = async () => {
      h.state.comment = null;
      return { changes: [{ name: 'Get-Example', before: 'old', after: 'new' }] };
    };
    assert.equal(await h.result(), 'failure');
  });

  test('a failed check cannot carry a previous acceptance', async () => {
    const h = harness(); h.approvedPreviously();
    h.state.check.conclusion = 'failure';
    assert.equal(await h.result(), 'failure');
  });

  test('permission API errors revoke success and fail closed', async () => {
    const h = harness(); h.approvedPreviously();
    h.args.github.rest.repos.getCollaboratorPermissionLevel = async () => { throw new Error('API unavailable'); };
    await assert.rejects(h.result(), /API unavailable/);
    assert.equal(h.state.check.conclusion, 'failure');
  });

  test('a push during comparison cannot receive stale success', async () => {
    const h = harness(); h.approvedPreviously();
    h.args.compareChanges = async () => { h.state.pr.head.sha = 'new-head'; return { changes: [] }; };
    await h.result();
    assert.equal(h.state.updates.some(update => update.conclusion === 'success'), false);
  });

  test('base-branch refresh uses the current PR base and revokes old acceptance', async () => {
    const h = harness(); h.approvedPreviously();
    h.state.pr.base.sha = 'new-base';
    h.args.context.eventName = 'push';
    h.args.context.payload = {};
    h.args.pullNumber = 221;
    let compared;
    h.args.compareChanges = async (base, head) => {
      compared = [base, head];
      return { changes: [{ name: 'Get-Example', before: 'old', after: 'new' }] };
    };
    assert.equal(await h.result(), 'failure');
    assert.deepEqual(compared, ['new-base', 'head']);
  });

  test('a base advance during comparison cannot receive stale success', async () => {
    const h = harness(); h.approvedPreviously();
    h.args.compareChanges = async () => { h.state.pr.base.sha = 'new-base'; return { changes: [] }; };
    await h.result();
    assert.equal(h.state.updates.some(update => update.conclusion === 'success'), false);
  });

  test('a retarget during comparison cannot receive stale success even with the same base SHA', async () => {
    const h = harness(); h.approvedPreviously();
    h.args.compareChanges = async () => { h.state.pr.base.ref = 'release'; return { changes: [] }; };
    await h.result();
    assert.equal(h.state.updates.some(update => update.conclusion === 'success'), false);
  });

}

module.exports = { approvalTests };
