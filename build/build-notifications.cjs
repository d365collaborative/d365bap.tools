const marker = '<!-- build-v2-failure -->';
const title = 'Build and release is failing on main';

module.exports = async function notify({ github, context, core }) {
  const run = context.payload.workflow_run;
  const repo = context.repo;
  if (run.head_branch !== 'main' || run.head_repository.full_name !== `${repo.owner}/${repo.repo}`) return;
  const failed = ['failure', 'timed_out', 'action_required', 'stale'].includes(run.conclusion);
  if (!failed && run.conclusion !== 'success') return;

  const { data: { workflow_runs: latest } } = await github.rest.actions.listWorkflowRuns({
    ...repo, workflow_id: run.workflow_id, branch: 'main', status: 'completed', per_page: 1,
  });
  if (latest[0]?.id !== run.id || latest[0]?.run_attempt !== run.run_attempt) {
    core.info('Ignoring an outdated workflow completion.');
    return;
  }

  const jobs = await github.paginate(github.rest.actions.listJobsForWorkflowRunAttempt, {
    ...repo, run_id: run.id, attempt_number: run.run_attempt, per_page: 100,
  });
  const issues = await github.paginate(github.rest.issues.listForRepo, {
    ...repo, state: 'open', creator: 'github-actions[bot]', per_page: 100,
  });
  const issue = issues.find(item => !item.pull_request && item.body?.includes(marker));
  const link = `[Run #${run.run_number}, attempt ${run.run_attempt}](${run.html_url})`;

  if (failed) {
    const failures = jobs.filter(job => ['failure', 'timed_out', 'action_required'].includes(job.conclusion));
    const details = failures.map(job => {
      const steps = (job.steps || []).filter(step => step.conclusion === 'failure').map(step => step.name);
      return `- [${job.name}](${job.html_url}): ${job.conclusion}${steps.length ? ` (${steps.join(', ')})` : ''}`;
    });
    const body = [
      marker, '', `${link} **${run.conclusion}**.`, '',
      `Commit: \`${run.head_sha}\``, '',
      ...(details.length ? details : ['No failed job details are available. Open the run for workflow-level errors.']),
      '', 'This issue tracks the latest failure and closes after a successful release and wiki publication.',
    ].join('\n');
    if (issue) {
      if (issue.body !== body) await github.rest.issues.update({ ...repo, issue_number: issue.number, body });
    } else {
      await github.rest.issues.create({ ...repo, title, body, assignees: ['Splaxi'] });
    }
    await core.summary.addHeading('Build failed').addLink('Open failed run', run.html_url).write();
    return;
  }

  // Validation-only runs cannot prove a broken publication has recovered.
  const released = jobs.some(job => job.name === 'Build and Release' && job.conclusion === 'success' &&
    job.steps?.some(step => step.name === 'Create GitHub release' && step.conclusion === 'success'));
  const wikiPublished = jobs.some(job => job.name.startsWith('Publish generated wiki /') && job.conclusion === 'success' &&
    job.steps?.some(step => step.name === 'Publish generated documentation to repository wiki' && step.conclusion === 'success'));
  if (issue && released && wikiPublished) {
    await github.rest.issues.update({
      ...repo, issue_number: issue.number, state: 'closed', state_reason: 'completed',
      body: `${issue.body}\n\nRecovered: ${link}. Release and wiki publication succeeded.`,
    });
  }
};
