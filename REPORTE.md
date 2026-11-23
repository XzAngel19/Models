# Revisión de `Throwfoodforanimalshub` (Zenith) — Throw Food for Animals

Fecha: 2026-11-23 · Place del juego: `120219252362013`

---

## 1. Qué revisé

| Fuente | Qué saqué |
|---|---|
| `Throwfoodforanimalshub` (3370 líneas) | Script completo: GUI, farm, selling, visuales |
| `Place_120219252362013.rar` → `Place_120219252362013.rbxlx` | 961 ModuleScripts + 18 Scripts del juego: remotes, controllers, configs |
| `Place_4924922222.rar` | **Otro juego distinto** (ver punto 5) |
| Log `120219252362013_EE67BD0C-….txt` | 87 `remote_call`, 699 `incoming_event` reales del juego: sirven para confirmar nombres/clases de remotes |

Todo lo que afirma este reporte está contrastado contra el código real del place
(`ReplicatedStorage.Shared.*`, `ReplicatedStorage.Config.*`,
`PlayerScripts.Client.Controllers.*`), no contra suposiciones.

---

## 2. Fallos que reportaste (ya corregidos)

### 2.1 «Any ▢» en Selling y «Xp ▢» en Rewards

**Causa:** el script escribía el carácter `▾` / `▴` (U+25BE / U+25B4) dentro del
`TextLabel`. La fuente `SourceSans` de Roblox **no tiene esos glifos**, así que el
motor dibuja el cuadro vacío. No es un error de lógica: es un carácter inexistente
en la fuente.

**Arreglo:** se agregó un chevron real dibujado con UI (dos barras redondeadas que
forman una «V»), que además **gira 180° con tween** al abrir/cerrar:

- `Selling → Sell Mutations / Sell Rarities / Sell Animals` — usa el nuevo chevron.
- `Rewards → Trail Priority (Xp / Cash)` — igual.
- `Thanksgiving → Cook Size` — igual (era el mismo dropdown, también salía con cuadro).

Detalle del código:

```lua
local ARROW_ICON_ID = ""   -- deja vacío = chevron vectorial (siempre se ve)
                           -- o pon "rbxassetid://TU_ID" para usar el PNG
```

**PNG listo para subir:** `assets/chevron-down.png` (128×128, fondo transparente,
color `#C6C6CC`). Para usarlo:

1. Sube el PNG en Roblox → Creator Dashboard → *Development Items → Images*
   (o en Studio: *Asset Manager → Images → Import*).
2. Copia el ID y pégalo en `ARROW_ICON_ID` como `"rbxassetid://123456789"`.
3. Si lo dejas vacío, el chevron vectorial se ve idéntico y nunca puede fallar
   (no depende de un asset publicado).

También cambié el separador del banner de `•` (U+2022) a `·` (U+00B7, Latin-1,
sí existe en SourceSans) para evitar otro cuadro.

### 2.2 «Instantly View Throw» no funcionaba

**Por qué podía fallar** (la versión anterior tenía una sola vía y fallaba en silencio):

1. Solo interceptaba `Instance.new("RemoteFunction").InvokeServer` con
   `hookfunction`. Varios ejecutores devuelven un *closure por instancia*, así que
   ese hook **no** atrapa las llamadas del juego.
2. El otro camino era parchear `Remotes.Invoke`. Si el módulo `Remotes` viene
   congelado (`table.freeze`) o el `require` del executor devuelve otra tabla, la
   asignación fallaba y — como estaba fuera de `pcall` — **abortaba todo el toggle**.
3. Cualquier error dentro del armado del banner ocurría dentro de `task.defer` ⇒ se
   perdía en el log y el usuario solo veía “el toggle está en ON y no pasa nada”.
4. Los accesos a config no eran defensivos: `rarityCfg.Get(rarity).Color` revienta
   si `Get` devuelve `nil`.

**Cómo quedó (varias vías, la primera que dispare muestra el banner):**

| Capa | Qué hace |
|---|---|
| `invoke` | Hook de `InvokeServer` (global o por instancia de `Throw_Resolve`) |
| `namecall` | `hookmetamethod(game, "__namecall", …)` — atrapa **todo** `:InvokeServer()` |
| `remotes` | Parchea `Remotes.Invoke` (con `pcall`, tolera tablas congeladas) |
| `reveal` | Envuelve `RevealSequence.Run` y lee `params.Result` (se ejecuta en cada throw) |
| `inventory watch` | Solo si **ninguna** capa de arriba se pudo instalar: vigila `data.Animals` y avisa de los animales nuevos (ignora los comprados) |

Además:

- Un único punto de entrada `captureThrowResult(res)` con **dedupe** (1,5 s) para no
  mostrar el mismo animal dos veces cuando dos capas disparan a la vez.
- Errores del banner ya no se pierden: `warn` + toast.
- Accesos a `AnimalEconomy`, `RarityConfig`, `Mutations.Income/Weight` protegidos.
- Al activar el toggle verás un toast real:
  `Instant view armed: invoke + namecall + remotes + reveal`.
  Si tu ejecutor bloquea todos los hooks, verás `Instant view armed: inventory watch`
  y el aviso se genera igual leyendo el inventario replicado.

---

## 3. Auditoría del resto del script (lo que sí está bien)

Verifiqué cada llamada contra el código del juego. **Todas coinciden:**

| Feature del hub | Llamada real | Verificado |
|---|---|---|
| Farm Animals | `Throw_Start` → `Throw_MeterStarted` → `Throw_Resolve(power)` → `Throw_Revealed` → `Throw_Complete` | ✅ mismo orden que `ThrowController` |
| Auto Perfect | `ThrowMeter.Run` (SetLocked + retorno 1 / `MeterRatings[1]` = `PERFECT!`) | ✅ `MeterRatings[1]` es PERFECT (Min 0.92) |
| Instant Throw | `ThrowMeter.TestAutoTap`, `ProjectileMath.CreateArc(p1,p2,dur,grav)`, `ScreenFX.FadeOut/FadeIn/Cover/Flash/Reset`, `RevealSequence.Run` | ✅ firmas correctas |
| Auto Index / Auto Thanksgiving Index | `Player_SetThrowPower`, `AreaUtil.ComputeLanding/DistanceToAreaCenter/SubAreaForZ`, `LevelConfig.ThrowPowerForLevel/MinThrowPower`, `Thanksgiving.CanCook/SandwichCount` | ✅ |
| Auto Train / Train Between Farms | `Training_Start()`, `Training_Stop()`, `ClientState.Busy` | ✅ (el controller del juego usa `ClientState.Busy` igual) |
| Auto 2x Press | `Training_Bonus` + `Training_TapBonus(id)` | ✅ |
| Auto Equip Best | `Plot_EquipBest()` | ✅ |
| Auto Claim Index Rewards | `IndexRewards.Claimable(data)` + `IndexRewards_Claim(key)` | ✅ |
| Auto Equip Best Trails | `IndexRewardsConfig.Trails[key].Bonus.Xp/Cash` + `IndexRewards_Equip(key)` | ✅ |
| Auto Upgrade Bars | `StandsConfig.Get`, `BalanceCurve.GetItemPrice`, `Stand_Upgrade()` | ✅ |
| Auto Upgrade Plot | `FenceConfig.Get(level).Price` + `Plot_UpgradeFence()` | ✅ (`FenceConfig.SignOffset` = `-8.5, 0, -24.6`) |
| Auto Upgrade Food | `FoodsConfig.Get/Count`, `Shop_Buy(i)`, `Shop_Equip(i)` | ✅ (`Shop_Buy` recibe el **índice**, igual que el hub) |
| Auto Sell / Sell Match | `Plot_SellAnimal(id)`, `Mutations.EventOnlyNames(entry)` | ✅ `SellShop` usa exactamente `Plot_SellAnimal(entry.Id)` |
| Auto Event / Auto Cook Sandwich | `Thanksgiving_Action("Talked" / "Cook", size / "Claim")` | ✅ las tallas son `"Regular" | "Big" | "Mega"` |
| Animal ESP | tag `PlotAnimal` | ✅ el juego usa ese tag |
| WalkSpeed / Fly | local | ✅ |

Datos del jugador usados (`data.Animals`, `data.Index`, `data.Trails.Owned/Equipped`,
`data.OwnedFoods`, `data.FenceLevel`, `data.Stand`, `data.Money`, `data.ThrowPower`)
también existen con esos nombres.

**Nota:** el log que subiste no trae errores (`kind` = captura de remotes, no consola),
así que no había ningún stacktrace que arreglar; los fallos eran los tres de arriba.

---

## 4. Limitaciones que dejé como están (a propósito)

- **`Instantly View Throw` depende de hooks.** Sin `hookfunction`/`hookmetamethod`
  el script lo dice y apaga el toggle en vez de fingir que funciona.
- **El farm asume que el servidor valida distancia.** Si el juego cambia la
  `CrossLine` o mete validación nueva, el farm se detiene solo con el motivo en el toast
  (no se queda en loop infinito).
- **Los “Xp/Cash” de Trail Priority** solo se usan en `Auto Equip Best Trails`.

---

## 5. Sobre las dos places que subiste

- `Place_120219252362013.rar` → **Throw Food for Animals**. Es la única donde el hub
  funciona (`GAME_PLACE_ID = 120219252362013`).
- `Place_4924922222.rar` → **es otro juego completamente distinto.** Tiene su propio
  `GameConstants.PlaceIds.Live = 4924922222`, y sus scripts son de vehículos, avatar,
  housing y accesorios (`VehicleController`, `AccessoryAdjustments*`, `AvatarEditor`…).
  **No tiene** `ReplicatedStorage.Remotes`, ni `Throw_*`, ni `IndexRewards`, ni
  `Plot_SellAnimal`, ni `MeterRatings`.

  ⇒ No hay nada que “portar” de ahí: el hub detecta `game.PlaceId ~= GAME_PLACE_ID`
  y desactiva todo con el mensaje *“Join Throw Food for Animals first”*. Eso es
  correcto, no es un bug.

---

## 6. Cómo probar rápido

1. Ejecuta el script en el place `120219252362013`.
2. `Visuals → Instantly View Throw` → debe salir el toast `Instant view armed: …`.
3. Lanza un tiro manual (o `Farm Animals`): aparece la tarjeta abajo al centro con
   nombre, mutación, rareza, income, peso y área.
4. `Extra → Selling`: los tres filtros ahora muestran `Any ⌄` con flecha real y giran
   al abrir. En `Rewards → Trail Priority` igual.
5. Si algo falla, mira la consola (`F9`): ahora todo error del hub se imprime como
   `[Throw Food Hub] …`.

---

## 7. Archivos tocados

- `Throwfoodforanimalshub` — chevron nuevo, captura multi-capa de `Throw_Resolve`,
  accesos defensivos, separador del banner, dedupe.
- `assets/chevron-down.png` — flecha PNG opcional (subir a Roblox y usar el ID).
- `REPORTE.md` — este documento.
