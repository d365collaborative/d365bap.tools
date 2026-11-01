const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { run, CHECK, ACCEPT, compareTestFiles, isGeneratedTestFile } = require('./test-file-approval.cjs');
const { approvalTests } = require('./maintainer-approval.tests.cjs');

approvalTests({
  run, CHECK, ACCEPT, compareOption: 'compareTestFiles',
  pendingTitle: 'Hand-written test file changes need maintainer acceptance',
  failureTitle: 'Test file comparison failed',
  countLabel: 'Total hand-written test file changes', reportPrefix: 'Test file',
});

test('the test-file command has the expected spelling', () => {
  assert.equal(ACCEPT, '/accept-test-file');
});

test('generated parameter tests are recognised by their directory', () => {
  assert.equal(isGeneratedTestFile('d365bap.tools/tests/functions/Get-Example.Tests.ps1'), true);
  assert.equal(isGeneratedTestFile('d365bap.tools/tests/behavior/Example.Tests.ps1'), false);
  assert.equal(isGeneratedTestFile('build/Example.Tests.ps1'), false);
});

test('test-file comparison rejects Git option injection', () => {
  for (const value of ['HEAD', '--upload-pack=malicious', 'a'.repeat(39), 'g'.repeat(40), null]) {
    assert.throws(() => compareTestFiles(value, 'b'.repeat(40), { fetch: false }), /full Git object ID/);
    assert.throws(() => compareTestFiles('b'.repeat(40), value, { fetch: false }), /full Git object ID/);
  }
});

test('only hand-written test files need acceptance', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'test-file-gate-'));
  const git = (...args) => execFileSync('git', args, {
    cwd: directory, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'],
  }).trim();
  const write = (name, content) => {
    const target = path.join(directory, name);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.writeFileSync(target, content);
  };
  const remove = name => fs.rmSync(path.join(directory, name));
  const commit = () => { git('add', '.'); git('commit', '-qm', 'fixture'); return git('rev-parse', 'HEAD'); };
  const existingTest = 'd365bap.tools/tests/behavior/Existing.Tests.ps1';
  const generatedTest = 'd365bap.tools/tests/functions/Generated.Tests.ps1';
  try {
    git('init', '-q'); git('config', 'user.name', 'Fixture'); git('config', 'user.email', 'fixture@example.test');
    git('config', 'core.autocrlf', 'false'); git('config', 'commit.gpgsign', 'false');
    write(existingTest, 'Describe "existing" {}');
    write(generatedTest, 'Describe "generated" {}');
    write('d365bap.tools/functions/Get-Fixture.ps1', 'param()');
    let previous = commit();
    const compare = mutate => {
      mutate();
      const head = commit();
      const changes = compareTestFiles(previous, head, { cwd: directory, fetch: false }).changes;
      previous = head;
      return changes;
    };

    let changes = compare(() => {
      write(existingTest, 'Describe "existing updated" {}');
      write('d365bap.tools/functions/Get-Fixture.ps1', 'param([switch]$New)');
    });
    assert.equal(changes.length, 1, 'editing an existing test file needs acceptance');
    assert.match(changes[0].name, /Existing\.Tests\.ps1 \(modified\)/);
    assert.equal(changes[0].before, 'Describe "existing" {}');
    assert.equal(changes[0].after, 'Describe "existing updated" {}');

    changes = compare(() => write(generatedTest, 'Describe "generated updated" {}'));
    assert.deepEqual(changes, [], 'generated parameter tests are exempt from edits too');

    changes = compare(() => write('d365bap.tools/tests/behavior/NewBehavior.Tests.ps1', 'Describe "new" {}'));
    assert.equal(changes.length, 1);
    assert.match(changes[0].name, /NewBehavior\.Tests\.ps1/);
    assert.equal(changes[0].before, null);
    assert.equal(changes[0].after, 'Describe "new" {}');

    changes = compare(() => write('d365bap.tools/tests/functions/Added.Tests.ps1', 'Describe "generated" {}'));
    assert.deepEqual(changes, [], 'generated parameter tests are exempt');

    changes = compare(() => write('build/Fixture.ps1', 'source'));
    assert.deepEqual(changes, [], 'non-test files are ignored');

    changes = compare(() => write('build/Fixture.Tests.ps1', 'Describe "build test" {}'));
    assert.equal(changes.length, 1, 'test files outside the module are still flagged');
    assert.match(changes[0].name, /build\/Fixture\.Tests\.ps1/);

    changes = compare(() => write('build/Fixture.Tests.ps1', 'Describe "build test updated" {}'));
    assert.equal(changes.length, 1, 'editing a test file outside the module is flagged');
    assert.match(changes[0].name, /build\/Fixture\.Tests\.ps1 \(modified\)/);
    assert.equal(changes[0].before, 'Describe "build test" {}');
    assert.equal(changes[0].after, 'Describe "build test updated" {}');

    changes = compare(() => write('d365bap.tools/tests/pester.ps1', 'runner'));
    assert.deepEqual(changes, [], 'test runners without the Tests suffix are ignored');

    changes = compare(() => remove(existingTest));
    assert.deepEqual(changes, [], 'deleting a test file needs no acceptance');

    changes = compare(() => fs.renameSync(
      path.join(directory, 'd365bap.tools/tests/behavior/NewBehavior.Tests.ps1'),
      path.join(directory, 'd365bap.tools/tests/behavior/Renamed.Tests.ps1'),
    ));
    assert.equal(changes.length, 1, 'a renamed test file arrives as an added path');
    assert.match(changes[0].name, /Renamed\.Tests\.ps1/);
    assert.equal(changes[0].after, 'Describe "new" {}');
  } finally {
    assert.equal(path.dirname(directory), os.tmpdir());
    assert.ok(path.basename(directory).startsWith('test-file-gate-'));
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test('privileged test-file approval workflow loads only trusted default-branch tooling', () => {
  const workflow = fs.readFileSync(path.join(__dirname, '../.github/workflows/test-file-approval.yml'), 'utf8');
  assert.match(workflow, /pull_request_target:/);
  assert.match(workflow, /issue_comment:\s+types: \[created, edited, deleted\]/);
  assert.equal((workflow.match(/ref: \$\{\{ github\.event\.repository\.default_branch \}\}/g) || []).length, 2);
  assert.doesNotMatch(workflow, /ref:.*(?:head\.sha|head\.ref)/);
  assert.match(workflow, /persist-credentials: false/);
  assert.match(workflow, /checks: write/);
  assert.match(workflow, /statuses: write/);
  assert.doesNotMatch(workflow, /(?:contents|pull-requests|issues): write/);
});
