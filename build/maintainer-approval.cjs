const writable = new Set(['admin', 'maintain', 'write']);

function metadata(check) {
  try { return JSON.parse(check?.external_id || '{}'); }
  catch { return {}; }
}

function validateRevision(value) {
  if (typeof value !== 'string' || !/^(?:[0-9a-f]{40}|[0-9a-f]{64})$/i.test(value)) {
    throw new Error('Expected a full Git object ID');
  }
  return value;
}

async function run({ github, context, core, compareChanges, pullNumber }, policy) {
  const CHECK = policy.checkName;
  const ACCEPT = policy.acceptCommand;
  const repo = context.repo;
  // A base-branch push may request a fresh evaluation for each open PR. Always
  // fetch the current PR below; push payloads do not describe a PR revision.
  const pull_number = pullNumber ?? context.payload.pull_request?.number ?? context.payload.issue?.number;
  if (!Number.isSafeInteger(pull_number) || pull_number <= 0) throw new Error('Expected a pull request number');
  const getPR = async () => (await github.rest.pulls.get({ ...repo, pull_number })).data;
  const pr = await getPR();
  if (pr.state !== 'open') return;
  const head = pr.head.sha;
  const base = pr.base.sha;
  const baseRef = pr.base.ref;
  if (typeof baseRef !== 'string' || baseRef.length === 0) throw new Error('Expected a base branch');
  const runs = await github.paginate(github.rest.checks.listForRef, {
    ...repo, ref: head, check_name: CHECK, filter: 'all', per_page: 100,
  });
  let check = runs.filter(item => item.name === CHECK && item.app?.slug === 'github-actions' && metadata(item).pr === pull_number)
    .sort((a, b) => b.id - a.id)[0];
  const previous = metadata(check);
  const sameRevision = previous.head === head && previous.base === base && previous.baseRef === baseRef && previous.pr === pull_number;
  const eventComment = context.payload.comment;

  async function authorizedComment(id) {
    let comment;
    try { comment = (await github.rest.issues.getComment({ ...repo, comment_id: id })).data; }
    catch (error) { if (error.status === 404) return null; throw error; }
    // The issue comment endpoint accepts any comment ID in the repository.
    // Bind it to this PR and reject comments created through an application.
    let issuePath;
    try { issuePath = new URL(comment.issue_url).pathname.toLowerCase(); }
    catch { return null; }
    const expectedPath = `/repos/${repo.owner}/${repo.repo}/issues/${pull_number}`.toLowerCase();
    if (!issuePath.endsWith(expectedPath) || comment.id !== id ||
        comment.user?.type !== 'User' || !comment.user.login || comment.performed_via_github_app ||
        comment.body !== ACCEPT || !comment.created_at || comment.created_at !== comment.updated_at ||
        typeof comment.node_id !== 'string') return null;
    // REST timestamps have second precision. A same-second edit can therefore
    // leave created_at equal to updated_at, including when an edit event is
    // replaced in the Actions concurrency queue. Check the edit marker too.
    const edit = await github.graphql(`query($id: ID!) {
      node(id: $id) { ... on IssueComment { id lastEditedAt } }
    }`, { id: comment.node_id });
    if (edit?.node?.id !== comment.node_id || edit.node.lastEditedAt !== null) return null;
    const { data } = await github.rest.repos.getCollaboratorPermissionLevel({
      ...repo, username: comment.user.login,
    });
    return writable.has(data.permission) || writable.has(data.role_name) ? comment : null;
  }

  // Accept only a fresh comment after this exact revision's check was visible.
  // This rejects comments queued before a push or before the first gate run.
  const canAccept = sameRevision && check.conclusion === 'failure' &&
    check.output?.title === policy.pendingTitle &&
    context.eventName === 'issue_comment' && context.payload.action === 'created' &&
    eventComment?.body === ACCEPT &&
    Date.parse(eventComment.created_at) > Date.parse(previous.readyAt || check.completed_at);

  const details_url = `${context.serverUrl || 'https://github.com'}/${repo.owner}/${repo.repo}/actions/runs/${context.runId}`;
  const publishStatus = (state, description) => github.rest.repos.createCommitStatus({
    ...repo, sha: head, context: CHECK, state, description: description.slice(0, 140),
    target_url: check ? `${context.serverUrl || 'https://github.com'}/${repo.owner}/${repo.repo}/runs/${check.id}` : details_url,
  });
  await publishStatus('pending', 'Verifying maintainer acceptance.');
  if (!check) {
    check = (await github.rest.checks.create({
      ...repo, name: CHECK, head_sha: head, status: 'in_progress', details_url,
      started_at: new Date().toISOString(),
      external_id: JSON.stringify({ pr: pull_number, base, baseRef, head }),
    })).data;
  } else {
    await github.rest.checks.update({
      ...repo, check_run_id: check.id, status: 'in_progress',
      external_id: JSON.stringify({ pr: pull_number, base, baseRef, head }),
    });
  }

  try {
    let acceptance = null;
    const revoked = context.eventName === 'issue_comment' && ['edited', 'deleted'].includes(context.payload.action) &&
      eventComment.id === previous.commentId;
    if (sameRevision && check.conclusion === 'success' && previous.commentId && !revoked) acceptance = await authorizedComment(previous.commentId);
    if (canAccept) {
      const candidate = await authorizedComment(eventComment.id);
      if (candidate && candidate.created_at === eventComment.created_at &&
          candidate.user.login === eventComment.user?.login) acceptance = candidate;
    }
    const { changes } = await compareChanges(base, head);
    if (!Array.isArray(changes) || changes.some(change => !change || typeof change.name !== 'string' ||
        ![null, 'string'].includes(change.before === null ? null : typeof change.before) ||
        ![null, 'string'].includes(change.after === null ? null : typeof change.after))) {
      throw new Error(`Invalid ${policy.resultName} comparison result`);
    }
    // A comment may have been deleted, edited, or lost permission while the
    // comparison was running. Recheck it before publishing the result.
    if (acceptance) acceptance = await authorizedComment(acceptance.id);
    const current = await getPR();
    if (current.head.sha !== head || current.base.sha !== base || current.base.ref !== baseRef || current.state !== 'open') return;
    const approved = changes.length === 0 || Boolean(acceptance);
    const title = changes.length === 0 ? policy.unchangedTitle : acceptance
      ? `${policy.acceptedTitle} by @${acceptance.user.login}` : policy.pendingTitle;
    const instruction = changes.length === 0 ? policy.unchangedSummary : acceptance
      ? `Accepted in [this PR comment](${acceptance.html_url}).`
      : `${policy.reviewInstruction}, then post exactly \`${ACCEPT}\` as a new PR comment. A maintainer with write access must do this. Agents and regeneration must leave this decision to the maintainer.`;
    const escape = text => String(text ?? '(absent)').replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
    const entries = changes.map(change => `<details><summary>${escape(change.name)}</summary>\n\nBefore:<pre>${escape(change.before)}</pre>\nAfter:<pre>${escape(change.after)}</pre>\n</details>`);
    const intro = `${instruction}\n\nHead: \`${head}\`\nBase: \`${base}\`\n\n${policy.countLabel}: ${changes.length}.\n\n`;
    // Keep complete entries within GitHub's output limit, reserving room for a
    // visible truncation notice. The full JSON report is in the workflow log.
    const limit = 60000;
    const visible = [];
    let used = Buffer.byteLength(intro, 'utf8');
    for (const entry of entries) {
      const size = Buffer.byteLength(entry, 'utf8') + 1;
      if (used + size > limit - 200) break;
      visible.push(entry);
      used += size;
    }
    const omitted = entries.length - visible.length;
    let notice = '';
    if (omitted) {
      notice = `\n\nReport truncated: ${omitted} of ${changes.length} ${policy.reportUnit} omitted from this check. See the workflow log for the complete JSON report.`;
      // JSON escapes newlines and controls. ASCII-only chunks retain every byte
      // of the JSON while preventing untrusted text from becoming workflow commands.
      const report = JSON.stringify({ changes }).replace(/[^\x20-\x7e]/g, char => `\\u${char.charCodeAt(0).toString(16).padStart(4, '0')}`);
      const chunkSize = 12000;
      const count = Math.ceil(report.length / chunkSize);
      for (let i = 0; i < count; i++) core.info(`${policy.reportPrefix} report JSON part ${i + 1}/${count}: ${report.slice(i * chunkSize, (i + 1) * chunkSize)}`);
    }
    const completed_at = new Date().toISOString();
    await github.rest.checks.update({
      ...repo, check_run_id: check.id, status: 'completed', conclusion: approved ? 'success' : 'failure',
      completed_at, details_url,
      external_id: JSON.stringify({
        pr: pull_number, base, baseRef, head, commentId: acceptance?.id,
        readyAt: sameRevision && previous.readyAt || completed_at,
      }),
      output: { title, summary: `${intro}${visible.join('\n')}${notice}` },
    });
    await publishStatus(approved ? 'success' : 'failure', title);
    core.info(title);
  } catch (error) {
    await github.rest.checks.update({
      ...repo, check_run_id: check.id, status: 'completed', conclusion: 'failure',
      completed_at: new Date().toISOString(),
      output: { title: policy.failureTitle, summary: policy.failureSummary },
    });
    await publishStatus('failure', policy.failureTitle);
    throw error;
  }
}

module.exports = { run, validateRevision };
