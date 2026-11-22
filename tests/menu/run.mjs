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
  const source = read('../../ViolenceDistrictMenu.client.luau');
  state.loadstring(source, 'Zenith', true); // compile the unmodified standalone script
  const suite = `${read('mock.luau')}\nlocal function launch()\n${source}\nassert(ok,err)\nend\n${read('menu.spec.luau')}`;
  await state.loadstring(suite, 'ZenithMenuTests', true)();
} finally {
  state.destroy();
}
