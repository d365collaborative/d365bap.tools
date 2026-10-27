const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { run, CHECK, ACCEPT, validateRevision } = require('./signature-approval.cjs');

test('only full object IDs can be passed to Git', () => {
  for (const revision of ['a'.repeat(40), 'A'.repeat(64)]) assert.equal(validateRevision(revision), revision);
  for (const revision of ['--upload-pack=malicious', 'HEAD', 'a'.repeat(39), 'a'.repeat(41), 'g'.repeat(40), '', null]) {
    assert.throws(() => validateRevision(revision), /full Git object ID/);
  }
});

const { approvalTests } = require('./maintainer-approval.tests.cjs');

approvalTests({
  run, CHECK, ACCEPT, compareOption: 'compareSignatures',
  pendingTitle: 'Signature changes need maintainer acceptance',
  failureTitle: 'Signature comparison failed',
  countLabel: 'Total declaration changes', reportPrefix: 'Signature',
});

test('declarations are compared from Git objects without executing source', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'signature-gate-'));
  const git = (...args) => execFileSync('git', args, { cwd: directory, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
  const write = (name, content) => {
    const target = path.join(directory, name);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.writeFileSync(target, content);
  };
  const source = 'd365bap.tools/functions/Get-Example.ps1';
  const manifest = 'd365bap.tools/d365bap.tools.psd1';
  const original = 'function Get-Example { [CmdletBinding()] param([string]$Name = "hello") process { $Name } }';
  const commit = () => { git('add', '.'); git('commit', '-qm', 'fixture'); return git('rev-parse', 'HEAD'); };
  try {
    git('init', '-q'); git('config', 'user.name', 'Fixture'); git('config', 'user.email', 'fixture@example.test');
    git('config', 'core.autocrlf', 'false'); git('config', 'commit.gpgsign', 'false');
    write(source, '\ufeff' + original);
    write(manifest, '\ufeff@{ FunctionsToExport = @("Get-Example"); AliasesToExport = @(); ModuleVersion = "1.0" }');
    const base = commit();
    const compare = () => JSON.parse(execFileSync('pwsh', [
      '-NoProfile', '-File', path.join(__dirname, 'Get-SignatureDelta.ps1'), '-BaseRef', base, '-HeadRef', 'HEAD',
    ], { cwd: directory, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] })).changes;

    write(source, original.replace('process { $Name }', 'process { throw "do not execute" }').replace('param(', '# help\n param (\n'));
    write('d365bap.tools/tests/functions/Get-Example.Tests.ps1', 'regenerated test');
    commit(); assert.deepEqual(compare(), [], 'body, formatting, BOM, comments and generated tests are ignored');

    for (const declaration of [
      '[string]$Name = "hello", [switch]$AsExcelOutput',
      '[int]$Name = 1',
      '[string]$Name = "new default"',
      '[Alias("OldName")][string]$Name = "hello"',
      '[Parameter(Mandatory, Position=0, ValueFromPipeline, ParameterSetName="New")][string]$Name = "hello"',
    ]) {
      write(source, `function Get-Example { [CmdletBinding()] param(${declaration}) }`);
      commit(); assert.equal(compare().length, 1, declaration);
    }

    write(source, original.replace('[CmdletBinding()]', '[CmdletBinding(SupportsShouldProcess)]'));
    commit(); assert.equal(compare().length, 1, 'binding attributes are tracked');
    write(source, original.replace('process { $Name }', 'dynamicparam { throw "never run" } process { $Name }'));
    commit(); assert.equal(compare().length, 1, 'dynamic parameters are tracked without executing them');

    write(source, original);
    write(manifest, '@{ FunctionsToExport = @(); AliasesToExport = @(); ModuleVersion = "1.0" }');
    commit(); assert.equal(compare()[0].name, 'manifest/FunctionsToExport');

    write(manifest, '@{ FunctionsToExport = @("Get-Example"); AliasesToExport = @(); ModuleVersion = "2.0" }');
    write('d365bap.tools/functions/Get-New.ps1', 'function Get-New { param() }');
    commit(); assert.equal(compare()[0].before, null, 'new commands require acceptance');
    fs.unlinkSync(path.join(directory, 'd365bap.tools/functions/Get-New.ps1'));
    fs.unlinkSync(path.join(directory, source));
    commit(); assert.equal(compare()[0].after, null, 'removed commands require acceptance');

    write(source, 'function Get-Example { param(');
    commit(); assert.throws(compare, /Cannot parse/, 'invalid source fails closed');
  } finally {
    assert.equal(path.dirname(directory), os.tmpdir());
    assert.ok(path.basename(directory).startsWith('signature-gate-'));
    fs.rmSync(directory, { recursive: true, force: true });
  }
});
