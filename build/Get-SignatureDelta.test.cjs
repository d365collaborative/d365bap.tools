const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

// Real Git objects, deliberately including code which must never be executed.
test('compares public and SDK signature inputs as data', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'signature-inputs-'));
  const git = (...args) => execFileSync('git', args, { cwd: directory, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
  const files = {
    'd365bap.tools/d365bap.tools.psd1': '@{ RootModule = "main.psm1"; FunctionsToExport = @("Get-Example"); CmdletsToExport = @(); AliasesToExport = @(); VariablesToExport = @() }',
    'd365bap.tools/functions/Get-Example.ps1': 'function Get-Example { [CmdletBinding(DefaultParameterSetName="One")] param([Alias("Old")][string]$Name = "default") process { throw "must not execute" } }',
    'd365bap.tools/d365bap.tools.psm1': 'throw "must not execute"; . "$PSScriptRoot/functions/Get-Example.ps1"',
    'd365bap.tools/internal/scripts/preimport.ps1': '"preload.ps1"',
    'd365bap.tools/internal/scripts/postimport.ps1': '"initialize-sdk.ps1"',
    'd365bap.tools/internal/sdk/commands.psd1': '@{ Resources = @(@{ Noun = "Example"; Builder = "A"; Methods = @{ Get = "GetAsync" }; Scope = "Tenant" }) }',
    'd365bap.tools/internal/scripts/initialize-sdk.ps1': 'throw "must not execute"; $parameterDefinition = "[string]$Name"',
    'd365bap.tools/internal/sdk/runtime.ps1': 'function Import-BapSdk { throw "must not execute"; $bridge = "Sdk.dll" }\nfunction Get-BapSdkParameter { throw "must not execute"; $name = $Resource.ParameterPrefix }\nfunction Invoke-Other { "body" }',
    'library/PowerPlatformSdk/PowerPlatformSdk.csproj': '<Project><PackageReference Include="Microsoft.PowerPlatform.Management" Version="1" /></Project>',
    'library/PowerPlatformSdk/SdkClient.cs': 'class SdkClient {}',
    'd365bap.tools/bin/PowerPlatformSdk/Microsoft.PowerPlatform.Management.dll': Buffer.from([0, 1, 2, 255]),
    'd365bap.tools/bin/PowerPlatformSdk/D365Bap.Tools.PowerPlatformSdk.dll': Buffer.from([0, 2, 3, 255]),
  };
  const write = (name, content) => {
    const target = path.join(directory, name);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.writeFileSync(target, content);
  };
  const commit = () => { git('add', '-A'); git('commit', '-qm', 'fixture'); };
  try {
    git('init', '-q'); git('config', 'user.name', 'Fixture'); git('config', 'user.email', 'fixture@example.test');
    git('config', 'core.autocrlf', 'false'); git('config', 'core.quotePath', 'true'); git('config', 'commit.gpgsign', 'false');
    for (const [name, content] of Object.entries(files)) write(name, content);
    commit();
    const base = git('rev-parse', 'HEAD');
    const compare = (baseRef = base) => JSON.parse(execFileSync('pwsh', ['-NoProfile', '-NonInteractive', '-File', path.join(__dirname, 'Get-SignatureDelta.ps1'), '-BaseRef', baseRef, '-HeadRef', 'HEAD'], { cwd: directory, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] })).changes;
    const reset = () => {
      for (const [name, original] of Object.entries(files)) write(name, original);
    };
    const ignored = (file, content, label) => {
      reset();
      write(file, content); commit();
      assert.deepEqual(compare(), [], label);
    };
    const gated = (file, content, expected, label) => {
      reset();
      write(file, content); commit();
      const result = compare();
      assert.equal(result.length, 1, `${label}: ${JSON.stringify(result)}`);
      assert.match(result[0].name, expected, label);
    };
    const command = 'd365bap.tools/functions/Get-Example.ps1';
    ignored(command, files[command].replace('DefaultParameterSetName="One"', 'DefaultParameterSetName="Two"'), 'parameter-set rename is compatible');
    ignored(command, files[command].replace('Alias("Old")', 'Alias("New")'), 'alias rename keeping the parameter is compatible');
    ignored(command, files[command].replace('"default"', '"changed"'), 'default change is compatible');
    ignored(command, files[command].replace('process {', 'dynamicparam { throw "must not execute" } process {'), 'dynamicparam addition is compatible');
    ignored(command, `${files[command]}\nSet-Alias ExampleAlias Get-Example`, 'top-level alias is compatible');
    ignored(command, `param([int]$ScriptOption)\n${files[command]}`, 'script-level param is compatible');
    ignored(command, files[command].replace('[string]$Name = "default"', '[string]$Name = "default", [switch]$AsExcelOutput'), 'added optional parameter is compatible');
    ignored(command, files[command].replace('[string]$Name = "default"', '[int]$Name = 1'), 'type change is compatible');
    gated(command, files[command].replace('[Alias("Old")][string]$Name = "default"', '[Alias("Old")][string]$NewName = "default"'), /Get-Example/, 'parameter rename requires acceptance');
    gated(command, files[command].replace('[Alias("Old")][string]$Name = "default"', ''), /Get-Example/, 'parameter removal requires acceptance');
    const manifest = 'd365bap.tools/d365bap.tools.psd1';
    ignored(manifest, files[manifest].replace('VariablesToExport = @()', 'VariablesToExport = @("Public")'), 'added variable export is compatible');
    ignored(manifest, files[manifest].replace('RootModule = "main.psm1"', 'RootModule = "other.psm1"'), 'RootModule change is compatible');
    gated(manifest, files[manifest].replace('FunctionsToExport = @("Get-Example")', 'FunctionsToExport = @()'), /manifest\/FunctionsToExport/, 'dropped function export requires acceptance');
    ignored(manifest, files[manifest].replace('VariablesToExport = @()', 'VariablesToExport = @("Public")'), 'added variable export remains compatible');
    for (const loader of ['d365bap.tools/d365bap.tools.psm1', 'd365bap.tools/internal/scripts/preimport.ps1', 'd365bap.tools/internal/scripts/postimport.ps1']) {
      ignored(loader, `${files[loader]}\n"other.ps1"`, `${loader} change is compatible`);
    }
    const mapping = 'd365bap.tools/internal/sdk/commands.psd1';
    ignored(mapping, files[mapping].replace('Builder = "A"', 'Builder = "B"'), 'SDK mapping change is compatible');
    ignored(mapping, files[mapping].replace('GetAsync', 'OtherAsync'), 'SDK method rename is compatible');
    const generator = 'd365bap.tools/internal/scripts/initialize-sdk.ps1';
    ignored(generator, files[generator].replace('[string]$Name', '[switch]$Name'), 'SDK generator change is compatible');
    ignored(generator, files['d365bap.tools/internal/scripts/preimport.ps1'], 'SDK generator rewrite is compatible');
    const runtime = 'd365bap.tools/internal/sdk/runtime.ps1';
    ignored(runtime, files[runtime].replace('$Resource.ParameterPrefix', '$Resource.OtherPrefix'), 'SDK parameter generator body change is compatible');
    ignored(runtime, files[runtime].replace('Sdk.dll', 'Other.dll'), 'SDK importer change is compatible');
    const project = 'library/PowerPlatformSdk/PowerPlatformSdk.csproj';
    ignored(project, files[project].replace('Version="1"', 'Version="2"'), 'SDK project change is compatible');
    const binary = 'd365bap.tools/bin/PowerPlatformSdk/Microsoft.PowerPlatform.Management.dll';
    ignored(binary, Buffer.from([0, 1, 3, 255]), 'SDK binary change is compatible');
    const bridge = 'library/PowerPlatformSdk/SdkClient.cs';
    ignored(bridge, files[bridge].replace('SdkClient', 'OtherClient'), 'SDK bridge change is compatible');
    const bridgeBinary = 'd365bap.tools/bin/PowerPlatformSdk/D365Bap.Tools.PowerPlatformSdk.dll';
    ignored(bridgeBinary, Buffer.from([0, 1, 3, 255]), 'SDK bridge binary change is compatible');

    reset();
    write(runtime, files[runtime].replace('function Invoke-Other { "body" }', 'function Invoke-Other { "changed" }'));
    commit(); assert.deepEqual(compare(), [], 'unrelated runtime body is ignored');
    write(runtime, files[runtime]);
    write('unrelated.txt', 'unrelated'); commit();
    assert.deepEqual(compare(), [], 'unrelated files do not change declarations');
    const renamed = 'd365bap.tools/functions/Get-Renamed.ps1';
    fs.renameSync(path.join(directory, command), path.join(directory, renamed)); commit();
    const renameChanges = compare();
    assert.equal(renameChanges.length, 1, 'cmdlet file rename gates the removed declaration only');
    assert.ok(renameChanges.some(change => change.name.includes('Get-Example.ps1') && change.after === null));
    assert.ok(!renameChanges.some(change => change.before === null), 'added renamed cmdlet does not require acceptance');
    fs.renameSync(path.join(directory, renamed), path.join(directory, command));
    fs.unlinkSync(path.join(directory, command)); commit();
    assert.equal(compare()[0].after, null, 'deletion is recorded');
    write(command, files[command]);
    git('add', command);
    const objectId = git('hash-object', path.join(directory, command));
    git('update-index', '--cacheinfo', `120000,${objectId},${command}`);
    git('commit', '-qm', 'symlink fixture');
    assert.throws(compare, /Unsupported Git file mode/, 'symlinks fail closed');
    git('reset', '-q', 'HEAD^');
    write(command, files[command]);
    git('add', command);
    git('update-index', '--add', '--cacheinfo', `100644,${objectId},d365bap.tools/functions/get-Example.ps1`);
    git('commit', '-qm', 'case collision fixture');
    assert.throws(compare, /Case-insensitive Git path collision/, 'case collisions fail closed');
    git('reset', '-q', 'HEAD^');
    write(command, files[command]);
    fs.unlinkSync(path.join(directory, binary)); commit();
    assert.throws(compare, /Missing SDK signature input/, 'incomplete SDK fails closed');
    write(binary, files[binary]);
    write(runtime, 'function Other { }'); commit();
    assert.throws(compare, /Expected one SDK parameter generator/, 'missing generator fails closed');
    write(runtime, files[runtime]);
    write(mapping, '@{ Resources = @('); commit();
    assert.throws(compare, /Cannot parse/, 'invalid SDK source fails closed');
    assert.throws(() => compare('HEAD'), /Cannot parse/, 'unchanged malformed input fails closed');
    write(mapping, files[mapping]);
    write(manifest, `function Decoy { @{ FunctionsToExport = @() } }\n${files[manifest]}`); commit();
    assert.throws(compare, /Expected a literal module manifest/, 'nested decoy manifest fails closed');
    write(manifest, files[manifest]);
    write('d365bap.tools/functions/Get-Éxample.ps1', 'function Get-Example { param() }'); commit();
    assert.throws(compare, /Unsupported quoted Git path/, 'quoted paths fail closed rather than being skipped');
  } finally {
    assert.equal(path.dirname(directory), os.tmpdir());
    assert.ok(path.basename(directory).startsWith('signature-inputs-'));
    fs.rmSync(directory, { recursive: true, force: true });
  }
});
