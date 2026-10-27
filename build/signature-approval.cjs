const { execFileSync } = require('node:child_process');
const path = require('node:path');
const approval = require('./maintainer-approval.cjs');
const { validateRevision } = approval;

const CHECK = 'Public signature approval';
const ACCEPT = '/accept-signature-change';

function compare(base, head) {
  validateRevision(base);
  validateRevision(head);
  const git = (...args) => execFileSync('git', args, { encoding: 'utf8' }).trim();
  // Fetch objects only. Never check out or run code from the pull request.
  git('fetch', 'origin', base, head);
  const ancestor = validateRevision(git('merge-base', base, head));
  return JSON.parse(execFileSync('pwsh', [
    '-NoProfile', '-NonInteractive', '-File', path.join(__dirname, 'Get-SignatureDelta.ps1'),
    '-BaseRef', ancestor, '-HeadRef', head,
  ], { encoding: 'utf8', maxBuffer: 8 * 1024 * 1024 }));
}

const policy = {
  checkName: CHECK,
  acceptCommand: ACCEPT,
  pendingTitle: 'Signature changes need maintainer acceptance',
  unchangedTitle: 'No public signature changes',
  acceptedTitle: 'Signature changes accepted',
  unchangedSummary: 'Public declarations match the PR baseline.',
  reviewInstruction: 'Review the declaration changes below',
  countLabel: 'Total declaration changes',
  reportUnit: 'declaration changes',
  reportPrefix: 'Signature',
  resultName: 'signature',
  failureTitle: 'Signature comparison failed',
  failureSummary: 'The gate could not compare declarations. See the workflow logs; acceptance cannot bypass this failure.',
};

async function run({ compareSignatures = compare, ...args }) {
  return approval.run({ ...args, compareChanges: compareSignatures }, policy);
}

module.exports = { run, CHECK, ACCEPT, validateRevision };
