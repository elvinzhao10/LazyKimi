'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const { validateAgentDirectory } = require('../scripts/validate-agent-frontmatter');
const agentsRoot = path.resolve(__dirname, '../agents');

test('Given shipped native profiles When validated Then permissions and delegation are enforced structurally', () => {
  const { agents } = validateAgentDirectory(agentsRoot);
  assert.equal(agents.length, 13);
  assert.deepEqual(agents.find(a => a.name === 'explorer').tools, ['Read', 'Grep', 'Glob']);
  assert.equal(agents.find(a => a.name === 'orchestrator').subagents.length, 12);
});

test('Given hostile profile metadata When loaded Then ignored keys and widened permissions fail closed', async t => {
  for (const [name, change] of [
    ['ignored model', text => text.replace('tools:', 'model: kimi-k3\ntools:')],
    ['ignored disallowed', text => text.replace('disallowedTools:', 'disallowed: []\ndisallowedTools:')],
    ['writable reviewer', text => text.replace('  - Glob', '  - Glob\n  - Write')],
    ['shell-capable reviewer', text => text.replace('  - Glob', '  - Glob\n  - Bash')],
    ['delegating reviewer', text => text.replace('subagents: []', 'subagents: [implementer]')],
    ['missing restrictions', text => text.replace('disallowedTools:', 'unsupported:')],
    ['duplicate identity', text => text.replace('name: reviewer', 'name: reviewer\nname: explorer')],
  ]) await t.test(name, st => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'kimi-native-policy-'));
    st.after(() => fs.rmSync(root, { recursive: true, force: true }));
    fs.cpSync(agentsRoot, root, { recursive: true });
    const file = path.join(root, 'lazykimi-reviewer.md');
    fs.writeFileSync(file, change(fs.readFileSync(file, 'utf8')));
    assert.throws(() => validateAgentDirectory(root));
  });
});
