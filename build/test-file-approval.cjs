const { execFileSync } = require('node:child_process');
const approval = require('./maintainer-approval.cjs');

const CHECK = 'Test file approval';
const ACCEPT = '/accept-test-file';
const TEST_FILE = /Tests\.ps1$/i;
const GENERATED_PREFIX = 'd365bap.tools/tests/functions/';

function git(cwd, args) {
  return execFileSync('git', args, {
    cwd,
    encoding: 'utf8',
    maxBuffer: 8 * 1024 * 1024,
    stdio: ['ignore', 'pipe', 'pipe'],
  });
}

function listFiles(cwd, revision) {
  return git(cwd, ['-c', 'core.quotePath=false', 'ls-tree', '-r', '-z', '--name-only', revision])
    .split('\0')
    .filter(Boolean);
}

function readBlob(cwd, revision, file) {
  return git(cwd, ['-c', 'core.quotePath=false', 'cat-file', 'blob', `${revision}:${file}`]);
}

// A test file is generated when it lives in the directory owned by
// generate-parameterunittests.ps1. Test-GeneratedTouch.ps1 already rejects
// hand edits there, and CI regenerates the directory after merge.
function isGeneratedTestFile(file) {
  return file.startsWith(GENERATED_PREFIX);
}

// Only hand-written test files need acceptance: additions and edits to existing
// files. Deletions are ordinary cleanup and the baseline already approved the
// file. Generated parameter tests are exempt entirely.
function compareTestFiles(base, head, { cwd = process.cwd(), fetch = true } = {}) {
  approval.validateRevision(base);
  approval.validateRevision(head);
  if (fetch) git(cwd, ['fetch', 'origin', base, head]);
  const ancestor = approval.validateRevision(git(cwd, ['merge-base', base, head]).trim());
  const existing = new Set(listFiles(cwd, ancestor));
  const changes = [];
  for (const file of listFiles(cwd, head)) {
    if (!TEST_FILE.test(file) || isGeneratedTestFile(file)) continue;
    const after = readBlob(cwd, head, file);
    if (!existing.has(file)) {
      changes.push({ name: `${file} (added)`, before: null, after });
      continue;
    }
    const before = readBlob(cwd, ancestor, file);
    if (before !== after) changes.push({ name: `${file} (modified)`, before, after });
  }
  return { changes };
}

const policy = {
  checkName: CHECK,
  acceptCommand: ACCEPT,
  pendingTitle: 'Hand-written test file changes need maintainer acceptance',
  unchangedTitle: 'No hand-written test file changes',
  acceptedTitle: 'Hand-written test file changes accepted',
  unchangedSummary: 'The pull request adds or edits no hand-written test files.',
  reviewInstruction: 'Review the hand-written test file changes below',
  countLabel: 'Total hand-written test file changes',
  reportUnit: 'test file changes',
  reportPrefix: 'Test file',
  resultName: 'test file',
  failureTitle: 'Test file comparison failed',
  failureSummary: 'The gate could not compare test files. See the workflow logs; acceptance cannot bypass this failure.',
};

async function run({ compareTestFiles: compare = compareTestFiles, ...args }) {
  return approval.run({ ...args, compareChanges: compare }, policy);
}

module.exports = { run, CHECK, ACCEPT, compareTestFiles, isGeneratedTestFile, validateRevision: approval.validateRevision };
