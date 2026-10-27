const { execFileSync } = require('node:child_process');
const approval = require('./maintainer-approval.cjs');

const CHECK = 'Internal hook approval';
const ACCEPT = '/accept-intenal-hook';
const PROTECTED_PATHS = [
  'build/ps1-lint/internal/',
  'build/ps1-lint/ps1-format/',
  'build/ps1-lint/psscriptanalyzer/',
  'build/ps1-lint/setup/',
  'build/internal-hook-approval.cjs',
  'build/maintainer-approval.cjs',
  'build/signature-approval.cjs',
  'build/Test-HookTouch.ps1',
  '.github/workflows/internal-hook-approval.yml',
  '.github/workflows/signature-approval.yml',
  '.github/workflows/validate.yml',
  'prek.toml',
];

function compareHooks(base, head, { cwd = process.cwd(), fetch = true } = {}) {
  approval.validateRevision(base);
  approval.validateRevision(head);
  const git = (...args) => execFileSync('git', args, {
    cwd, encoding: 'utf8', maxBuffer: 8 * 1024 * 1024, stdio: ['ignore', 'pipe', 'pipe'],
  });
  if (fetch) git('fetch', 'origin', base, head);
  const ancestor = approval.validateRevision(git('merge-base', base, head).trim());
  const commits = git('rev-list', '--reverse', `${ancestor}..${head}`).trim().split('\n').filter(Boolean);
  const touched = new Map();
  for (const commit of commits) {
    approval.validateRevision(commit);
    const files = git('diff-tree', '--root', '-m', '-r', '--no-commit-id', '--name-only', '--no-renames', '-z', commit, '--', ...PROTECTED_PATHS)
      .split('\0').filter(Boolean);
    for (const file of new Set(files)) {
      if (!touched.has(file)) touched.set(file, []);
      touched.get(file).push(commit);
    }
  }
  const readBlob = (revision, file) => {
    const entry = git('--literal-pathspecs', 'ls-tree', '-z', revision, '--', file);
    if (!entry) return null;
    const match = /^(\d+) blob ([0-9a-f]+)\t[^\0]+\0$/.exec(entry);
    if (!match) throw new Error(`Expected a protected file blob: ${file}`);
    return git('cat-file', 'blob', approval.validateRevision(match[2]));
  };
  return { changes: [...touched].sort(([a], [b]) => a.localeCompare(b)).map(([file, revisions]) => ({
    name: `${file} (commits: ${revisions.map(value => value.slice(0, 12)).join(', ')})`,
    before: readBlob(ancestor, file),
    after: readBlob(head, file),
  })) };
}

const policy = {
  checkName: CHECK,
  acceptCommand: ACCEPT,
  pendingTitle: 'Internal hook changes need maintainer acceptance',
  unchangedTitle: 'No internal hook changes',
  acceptedTitle: 'Internal hook changes accepted',
  unchangedSummary: 'No commits touch protected lint or approval tooling.',
  reviewInstruction: 'Review the protected file changes and listed commits below',
  countLabel: 'Total protected file changes',
  reportUnit: 'protected file changes',
  reportPrefix: 'Internal hook',
  resultName: 'internal hook',
  failureTitle: 'Internal hook comparison failed',
  failureSummary: 'The gate could not inspect protected files. See the workflow logs; acceptance cannot bypass this failure.',
};

async function run({ compareHooks: compare = compareHooks, ...args }) {
  return approval.run({ ...args, compareChanges: compare }, policy);
}

module.exports = { run, CHECK, ACCEPT, PROTECTED_PATHS, compareHooks };
