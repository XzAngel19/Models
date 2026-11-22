import { readFileSync } from 'node:fs';
import { LuauState } from 'luau-web';

const read = path => readFileSync(new URL(path, import.meta.url), 'utf8');
function unpack(value) {
  if (value === null || typeof value !== 'object') return value;
  if (Array.isArray(value)) return value.map(unpack);
  return Object.fromEntries(Array.from(value.keys(), key => [key, unpack(value.get(key))]));
}
const state = await LuauState.createAsync({
  print: console.log, warn: console.warn,
  jsonEncode: value => JSON.stringify(unpack(value)), jsonDecode: JSON.parse,
});
try {
  for (const [name, file, extraFixture, spec] of [
    ['Zenith', 'ViolenceDistrictMenu.client.luau', '', 'menu.spec.luau'],
    ['Snowpaw', 'SnowpawMenu.client.luau', read('snowpaw-fixture.luau'), 'snowpaw.spec.luau'],
  ]) {
    const source = read('../../' + file);
    state.loadstring(source, name, true); // compile the unmodified standalone script
    const suite = `${read('mock.luau')}\n${extraFixture}\nlocal function launch()\n${source}\nassert(ok,err)\nend\n${read(spec)}`;
    await state.loadstring(suite, name + 'MenuTests', true)();
  }
} finally {
  state.destroy();
}
