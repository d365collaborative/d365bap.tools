const { execFileSync } = require('node:child_process');
const path = require('node:path');

const CHECK = 'Public signature approval';
const ACCEPT = '/accept-signature-change';
const writable = new Set(['admin', 'maintain', 'write']);

function metadata(check) {
  try { return JSON.parse(check?.external_id || '{}'); }
  catch { return {}; }
}

function compare(base, head) {
  const git = (...args) => execFileSync('git', args, { encoding: 'utf8' }).trim();
  // Fetch objects only. Never check out or run code from the pull request.
  git('fetch', 'origin', base, head);
  const ancestor = git('merge-base', base, head);
  return JSON.parse(execFileSync('pwsh', [
    '-NoProfile', '-NonInteractive', '-File', path.join(__dirname, 'Get-SignatureDelta.ps1'),
    '-BaseRef', ancestor, '-HeadRef', head,
  ], { encoding: 'utf8', maxBuffer: 8 * 1024 * 1024 }));
}

async function run({ github, context, core, compareSignatures = compare }) {
  const repo = context.repo;
  const pull_number = context.payload.pull_request?.number || context.payload.issue?.number;
  const getPR = async () => (await github.rest.pulls.get({ ...repo, pull_number })).data;
  const pr = await getPR();
  if (pr.state !== 'open') return;
  const head = pr.head.sha;
  const base = pr.base.sha;
  const runs = await github.paginate(github.rest.checks.listForRef, {
    ...repo, ref: head, check_name: CHECK, filter: 'all', per_page: 100,
  });
  let check = runs.filter(item => item.name === CHECK && item.app?.slug === 'github-actions' && metadata(item).pr === pull_number)
    .sort((a, b) => b.id - a.id)[0];
  const previous = metadata(check);
  const sameRevision = previous.head === head && previous.base === base && previous.pr === pull_number;
  const eventComment = context.payload.comment;

  async function authorizedComment(id) {
    let comment;
    try { comment = (await github.rest.issues.getComment({ ...repo, comment_id: id })).data; }
    catch (error) { if (error.status === 404) return null; throw error; }
    if (comment.user?.type !== 'User' || comment.body.trim() !== ACCEPT ||
        comment.created_at !== comment.updated_at) return null;
    const { data } = await github.rest.repos.getCollaboratorPermissionLevel({
      ...repo, username: comment.user.login,
    });
    return writable.has(data.permission) || writable.has(data.role_name) ? comment : null;
  }

  // Accept only a fresh comment after this exact revision's check was visible.
  // This rejects comments queued before a push or before the first gate run.
  const canAccept = sameRevision && check.conclusion === 'failure' &&
    check.output?.title === 'Signature changes need maintainer acceptance' &&
    context.eventName === 'issue_comment' && context.payload.action === 'created' &&
    eventComment.body.trim() === ACCEPT &&
    Date.parse(eventComment.created_at) > Date.parse(previous.readyAt || check.completed_at);

  const details_url = `${context.serverUrl || 'https://github.com'}/${repo.owner}/${repo.repo}/actions/runs/${context.runId}`;
  if (!check) {
    check = (await github.rest.checks.create({
      ...repo, name: CHECK, head_sha: head, status: 'in_progress', details_url,
      started_at: new Date().toISOString(),
      external_id: JSON.stringify({ pr: pull_number, base, head }),
    })).data;
  } else {
    await github.rest.checks.update({
      ...repo, check_run_id: check.id, status: 'in_progress',
      external_id: JSON.stringify({ pr: pull_number, base, head }),
    });
  }

  try {
    let acceptance = null;
    const revoked = context.eventName === 'issue_comment' && ['edited', 'deleted'].includes(context.payload.action) &&
      eventComment.id === previous.commentId;
    if (sameRevision && previous.commentId && !revoked) acceptance = await authorizedComment(previous.commentId);
    if (canAccept) acceptance = await authorizedComment(eventComment.id);
    const { changes } = await compareSignatures(base, head);
    const current = await getPR();
    if (current.head.sha !== head || current.base.sha !== base || current.state !== 'open') return;
    const approved = changes.length === 0 || Boolean(acceptance);
    const title = changes.length === 0 ? 'No public signature changes' : acceptance
      ? `Signature changes accepted by @${acceptance.user.login}` : 'Signature changes need maintainer acceptance';
    const instruction = changes.length === 0 ? 'Public declarations match the PR baseline.' : acceptance
      ? `Accepted in [this PR comment](${acceptance.html_url}).`
      : `Review the declaration changes below, then post exactly \`${ACCEPT}\` as a new PR comment. A maintainer with write access must do this. Agents and regeneration must leave this decision to the maintainer.`;
    const escape = text => String(text ?? '(absent)').replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
    const diff = changes.map(change => `<details><summary>${escape(change.name)}</summary>\n\nBefore:<pre>${escape(change.before)}</pre>\nAfter:<pre>${escape(change.after)}</pre>\n</details>`).join('\n');
    const completed_at = new Date().toISOString();
    await github.rest.checks.update({
      ...repo, check_run_id: check.id, status: 'completed', conclusion: approved ? 'success' : 'failure',
      completed_at, details_url,
      external_id: JSON.stringify({
        pr: pull_number, base, head, commentId: acceptance?.id,
        readyAt: sameRevision && previous.readyAt || completed_at,
      }),
      output: { title, summary: `${instruction}\n\nHead: \`${head}\`\nBase: \`${base}\`\n\n${diff}`.slice(0, 60000) },
    });
    core.info(title);
  } catch (error) {
    await github.rest.checks.update({
      ...repo, check_run_id: check.id, status: 'completed', conclusion: 'failure',
      completed_at: new Date().toISOString(),
      output: { title: 'Signature comparison failed', summary: 'The gate could not compare declarations. See the workflow logs; acceptance cannot bypass this failure.' },
    });
    throw error;
  }
}

module.exports = { run, CHECK, ACCEPT };
