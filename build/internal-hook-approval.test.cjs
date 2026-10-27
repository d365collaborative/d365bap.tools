const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { run, CHECK, ACCEPT, PROTECTED_PATHS, compareHooks } = require('./internal-hook-approval.cjs');
const { approvalTests } = require('./maintainer-approval.tests.cjs');

approvalTests({
  run, CHECK, ACCEPT, compareOption: 'compareHooks',
  pendingTitle: 'Internal hook changes need maintainer acceptance',
  failureTitle: 'Internal hook comparison failed',
  countLabel: 'Total protected file changes', reportPrefix: 'Internal hook',
});

test('the internal-hook command has the exact requested spelling', () => {
  assert.equal(ACCEPT, '/accept-intenal-hook');
});

test('internal-hook comparison rejects Git option injection', () => {
  for (const value of ['HEAD', '--upload-pack=malicious', 'a'.repeat(39), 'g'.repeat(40), null]) {
    assert.throws(() => compareHooks(value, 'b'.repeat(40), { fetch: false }), /full Git object ID/);
    assert.throws(() => compareHooks('b'.repeat(40), value, { fetch: false }), /full Git object ID/);
  }
});

test('protected Git history is inspected without executing PR files', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'internal-hook-gate-'));
  const git = (...args) => execFileSync('git', args, {
    cwd: directory, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'],
  }).trim();
  const write = (name, content) => {
    const target = path.join(directory, name);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.writeFileSync(target, content);
  };
  const commit = () => { git('add', '.'); git('commit', '-qm', 'fixture'); return git('rev-parse', 'HEAD'); };
  const source = 'build/ps1-lint/internal/Get-Fixture.ps1';
  try {
    git('init', '-q'); git('config', 'user.name', 'Fixture'); git('config', 'user.email', 'fixture@example.test');
    git('config', 'core.autocrlf', 'false'); git('config', 'commit.gpgsign', 'false');
    write(source, 'original');
    write('README.md', 'original');
    const base = commit();
    const compare = (head = git('rev-parse', 'HEAD')) => compareHooks(base, head, { cwd: directory, fetch: false }).changes;

    write('README.md', 'documentation change');
    commit(); assert.deepEqual(compare(), [], 'ordinary documentation is not protected');

    write(source, 'throw "never execute PR code"');
    const changed = commit();
    let changes = compare();
    assert.equal(changes.length, 1);
    assert.match(changes[0].name, /Get-Fixture\.ps1/);
    assert.match(changes[0].name, new RegExp(changed.slice(0, 12)));
    assert.equal(changes[0].before, 'original');
    assert.equal(changes[0].after, 'throw "never execute PR code"');

    write(source, 'original');
    commit(); changes = compare();
    assert.equal(changes.length, 1, 'reverted protected changes still require acceptance');
    assert.equal(changes[0].before, changes[0].after);

    const spaced = 'build/ps1-lint/internal/Fixture [1].ps1';
    write(spaced, 'new file');
    commit(); changes = compare();
    const added = changes.find(change => change.name.includes('Fixture [1].ps1'));
    assert.equal(added.before, null);
    assert.equal(added.after, 'new file');

    fs.renameSync(path.join(directory, source), path.join(directory, 'moved-outside.ps1'));
    commit(); changes = compare();
    assert.equal(changes.find(change => change.name.includes('Get-Fixture.ps1')).after, null, 'moving a file out cannot hide the protected deletion');

    for (const protectedPath of PROTECTED_PATHS.filter(name => !name.endsWith('/'))) {
      write(protectedPath, 'fixture approval configuration');
      commit();
      assert.ok(compare().some(change => change.name.startsWith(protectedPath + ' ')), protectedPath);
    }

    const forkPoint = git('rev-parse', 'HEAD');
    git('checkout', '-qb', 'side');
    write('side.txt', 'side'); commit();
    git('checkout', '-q', '-');
    write('main.txt', 'main'); commit();
    git('merge', '--no-commit', '--no-ff', 'side');
    write('build/ps1-lint/internal/Merge-Only.ps1', 'merge-only protected change');
    const merged = commit();
    assert.ok(compareHooks(forkPoint, merged, { cwd: directory, fetch: false }).changes.some(change => change.name.includes('Merge-Only.ps1')), 'merge commits cannot hide protected changes');
  } finally {
    assert.equal(path.dirname(directory), os.tmpdir());
    assert.ok(path.basename(directory).startsWith('internal-hook-gate-'));
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test('privileged approval workflows load only trusted default-branch tooling', () => {
  for (const name of ['internal-hook-approval', 'signature-approval']) {
    const workflow = fs.readFileSync(path.join(__dirname, `../.github/workflows/${name}.yml`), 'utf8');
    assert.match(workflow, /pull_request_target:/);
    assert.match(workflow, /issue_comment:\s+types: \[created, edited, deleted\]/);
    assert.equal((workflow.match(/ref: \$\{\{ github\.event\.repository\.default_branch \}\}/g) || []).length, 2);
    assert.doesNotMatch(workflow, /ref:.*(?:head\.sha|head\.ref)/);
    assert.match(workflow, /persist-credentials: false/);
    assert.match(workflow, /checks: write/);
    assert.match(workflow, /statuses: write/);
  }
  const regression = fs.readFileSync(path.join(__dirname, '../.github/workflows/test-signature-approval.yml'), 'utf8');
  assert.doesNotMatch(regression, /(?:checks|statuses): write/);
});
