# Revisión de `Throwfoodforanimalshub` (Zenith) — Throw Food for Animals

Fecha: 2026-11-23 · Place del juego: `120219252362013` · **Ronda 2 de correcciones incluida** (sección 8)

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
| Farm Animals | `Throw_Start` → `Throw_UseSandwich` → `Throw_MeterStarted` → `Throw_Resolve(power)` → `Throw_Revealed` → `Throw_Complete` | ✅ mismo orden que `ThrowController` + `SandwichThrow` (ver 8.1) |
| Auto Perfect | `ThrowMeter.Run` (SetLocked + retorno 1 / `MeterRatings[1]` = `PERFECT!`) | ✅ `MeterRatings[1]` es PERFECT (Min 0.92) |
| Instant Throw | `ThrowMeter.TestAutoTap`, `ProjectileMath.CreateArc(p1,p2,dur,grav)`, `ScreenFX.FadeOut/FadeIn/Cover/Flash/Reset`, `RevealSequence.Run` | ✅ firmas correctas |
| Auto Index / Auto Thanksgiving Index | `Player_SetThrowPower`, `AreaUtil.ComputeLanding/DistanceToAreaCenter/SubAreaForZ`, `LevelConfig.ThrowPowerForLevel/MinThrowPower`, `Thanksgiving.CanCook/SandwichCount` | ✅ |
| Auto Train / Train Between Farms | `TrainingController.Start()` / `Stop(true)` sobre el `TrainingArea` real (`Training_Start/Stop` como respaldo) | ✅ reescrito en la ronda 2 (ver 8.2) |
| Auto 2x Press | `Training_Bonus` + el botón real `TrainingSequence.TapBonusLayer.TapBonus` (`Training_TapBonus(id)` de respaldo) | ✅ reescrito en la ronda 2 (ver 8.3) |
| Auto Equip Best | `Plot_EquipBest()` | ✅ |
| Auto Claim Index Rewards | `IndexRewards.Claimable(data)` + `IndexRewards_Claim(key)` | ✅ |
| Auto Equip Best Trails | `IndexRewardsConfig.Trails[key].Bonus.Xp/Cash` + `IndexRewards_Equip(key)` | ✅ |
| Auto Upgrade Bars | `StandsConfig.Get`, `BalanceCurve.GetItemPrice`, `Stand_Upgrade()` | ✅ |
| Auto Upgrade Plot | `FenceConfig.Get(level).Price` + `Plot_UpgradeFence()` | ✅ (`FenceConfig.SignOffset` = `-8.5, 0, -24.6`) |
| Auto Upgrade Food | `FoodsConfig.Get/Count`, `Shop_Buy(i)`, `Shop_Equip(i)` | ✅ (`Shop_Buy` recibe el **índice**, igual que el hub) |
| Auto Sell / Sell Match | `Plot_SellAnimal(id)`, `Mutations.EventOnlyNames(entry)` | ✅ ahora exige `Plot_EquipBest` verificado antes de vender (ver 8.4) |
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

- `Throwfoodforanimalshub`
  - Ronda 1: chevron nuevo, captura multi-capa de `Throw_Resolve`, accesos defensivos,
    separador del banner, dedupe.
  - Ronda 2: `throwOnce()` con verificación por paso, mutex de acciones, `waitGameIdle`,
    entrenamiento sobre `TrainingController.Start/Stop`, `runTrainingSession`,
    `Auto 2x Press` sobre el botón real, `chefDo` resiliente, `Farm Thanksgiving`,
    `Auto Sell` encadenado a un `Plot_EquipBest` verificado + protección por income.
- `assets/chevron-down.png` — flecha PNG opcional (subir a Roblox y usar el ID).
- `REPORTE.md` — este documento (sección 8 = ronda 2).

---

## 8. Ronda 2 — lo que reportaste ahora y cómo quedó

> «No funcionan las opciones de farm, se rompe Thanksgiving si está activo con el
> autofarm, falta farmear Thanksgiving, `Train Between Farms` no hace nada, `Auto Sell`
> borra pets valiosas porque `Auto Equip Best` se bugea, y el 2x press no funciona.»

Todo se contrastó **otra vez** contra los scripts del place
(`ThrowController`, `TrainingController`, `SandwichThrow`, `ThanksgivingController`,
`Thanksgiving`, `ThanksgivingConfig`, `AnimalsPanel`, `FenceConfig`, `Mutations`,
`UIKit`). La extracción nueva (`Throwfoodfornaimals.rar`) es **el mismo juego**:
915 scripts vs 915, con solo 10 nombres distintos (VR, cámara, Poppercam,
ConnectionUtil, TouchJump, EngineInterface). No hay remotes nuevos que soportar.

### 8.1 Farm Animals (y por qué se “rompía”)

**Causas reales:**

1. `Throw_Complete` está **temporizado por el servidor** (el reveal real dura ~8 s de
   vuelo + secuencia). El hub esperaba `Complete Delay = 8` fijo: casi siempre llegaba
   **antes** de tiempo, el servidor devolvía un motivo distinto de `Ok` y la función
   `step()` **apagaba el farm entero** al primer rechazo. Resultado: farm que “no hace nada”.
2. Un solo `Throw_Start` fallido (`Cooldown`, `TooFar`) mataba el loop en vez de reintentar
   al segundo intento como antes.
3. La posición se restauraba **justo después** de `Throw_Start`, así que el tiro se
   resolvía con el personaje ya en otro sitio (el servidor lo aceptaba por suerte, pero
   era frágil).
4. El sándwich se armaba **después** de `Throw_Start` sin comprobar `Ok`, y el poder de
   tiro no se sincronizaba con el destino real (Thanksgiving).
5. `Train Between Farms` esperaba `Train After Throws = 30` tiros **antes** de la primera
   sesión (≈11 min con el ciclo real de ~22 s), y encima usaba `Training_Start` a pelo.

**Cómo quedó:**

- `throwOnce()` — un ciclo limpio y **verificado paso a paso**: se queda en la
  `StarterArea` (detrás de `CrossLine`, con reintento `TooFar` → cruzando la línea),
  `Throw_Start` con 3 intentos, **sándwich armado con `Ok` comprobado**, `Throw_MeterStarted`,
  `Throw_Resolve(1)`, espera `max(Reveal Delay, FlightTime + 0.8)`, `Throw_Revealed`,
  y `Throw_Complete` **con reintentos hasta 20 s** (solo abandona si el servidor dice
  `NotActive / NoThrow / Expired / Invalid`). Al final cancela si quedó algo pendiente y
  devuelve al jugador a su posición.
- `Complete Delay` por defecto ahora **14 s** y `Reveal Delay` 8 s (los valores reales del
  reveal). Con `Instant Throw` activo arranca en `FlightTime + 1` y los reintentos buscan
  la ventana, así que sigue siendo rápido cuando el servidor lo permite.
- Un **mutex de acción** (`actionAcquire/actionRelease`) serializa tiro, entrenamiento,
  chef, venta y equipar. Antes dos workers podían teletransportar al personaje a la vez:
  **esa era la causa de que el evento de Thanksgiving se rompiera con el autofarm**.
- `waitGameIdle()` espera a que `ClientState.Busy` esté libre antes de llamar a un remote
  (el juego rechaza `Thanksgiving_Action`/`Throw_*` si está ocupado).

### 8.2 Auto Train y Train Between Farms

`Training_Start` a pelo **no** reproduce la sesión del juego: no hay cámara, no hay
`runSequence`, no hay `Training_Bonus`, y `TrainingController` mantiene su propio estado
(`u2/u3`). Por eso el 2x tampoco aparecía.

Ahora se usa **el controlador real**:

```
teleport al centro de LocalPlotProps.TrainingArea  (radio real: min(Size.Y,Size.Z)/2*0.64, Δy entre -2 y 8)
  → TrainingController.Start()            (pide Stand >= 1, cierra ventanas, cámara, remotes)
  → espera el atributo del servidor LocalPlayer:GetAttribute("Training") == true
  → se mantiene N segundos (60 s por ciclo en Auto Train)
  → TrainingController.Stop(true)         (desmonta la secuencia y restaura la cámara)
  → Training_Stop de respaldo si el atributo sigue en true
  → sale del círculo para que pollCircle no la reinicie sola
```

`Train Between Farms` usa exactamente la misma rutina entre tandas de tiros
(`Train After Throws` ahora **10** por defecto) y avisa con el motivo si el servidor
la rechaza (por ejemplo «Buy a pull-up bar first»).

### 8.3 Auto 2x Press (por qué no funcionaba)

El servidor emite `Training_Bonus` con **`[repIndex, fireTime, 2]`**: llega ~4,3–4,6 s
**antes** de que el bonus esté activo. El cliente del juego (`TrainingController.show`)
crea el botón `TapBonus` en ese momento y **lo destruye exactamente en `fireTime`**;
`claim()` exige `u64 == botón mostrado` y manda `Training_TapBonus(id)`.

Dos fallos del hub anterior:

1. Reclamaba **solo si había** `Training_Bonus`, o sea **solo durante una sesión de
   entrenamiento real** — y como `Auto Train`/`Train Between Farms` estaban rotos
   (8.2), en la práctica no había ningún bonus que reclamar.
2. Si el botón no existía, llamaba al remote “a ciegas” y podía reclamar un id caducado.

**Ahora:** al activar el toggle se avisa `Auto 2x Press is armed - it fires during training`.
Al recibir el evento se espera a que exista el botón real (búsqueda directa
`PlayerGui.TrainingSequence.TapBonusLayer.TapBonus` **y** búsqueda recursiva como
respaldo), se dispara `Activated` con `firesignal` (así salen el popup «x2!», el flash y
los `ExtraReps` del juego) y solo si eso falla se llama `Training_TapBonus(id)`.
Los ids reclamados se recuerdan, y si el servidor responde «todavía no», reintenta al
llegar `fireTime`.

### 8.4 Auto Sell nunca antes de un Auto Equip Best verificado

Este era el punto peligroso. `Plot_EquipBest` devuelve `{Ok, Placed, Removed, Count}` y
**puede devolver `Ok` sin haber dejado la parcela como esperabas**; el `Auto Sell` viejo
corría en su propio `periodic` de 10 s y borraba los mejores animales que habían quedado
sin colocar.

Cadena nueva, en este orden y con prueba real:

1. `Auto Sell` **llama él mismo** a `Plot_EquipBest` (no confía en el worker).
2. Si no es `Ok` → **no vende**, avisa `Auto Sell on hold: Equip Best failed (motivo)`.
3. Espera `Sell Safety (s)` (nuevo slider, 2 s por defecto) y comprueba que nadie más
   equipó ni falló mientras tanto.
4. **Verifica en los datos**: `Count` del servidor vs animales realmente `Placed`, y que
   ningún animal sin colocar tenga más income que el peor colocado. Si falla → reintenta
   en la pasada siguiente (`requestEquip()`), **sin vender**.
5. Solo entonces recorre el inventario, y además protege por valor: **los N animales de
   mayor income (N = `FenceConfig.SlotsFor(FenceLevel)`) nunca se venden** en modo
   automático. Si todo lo que tienes cabe en la parcela, no vende nada y lo dice.
6. Los animales recién replicados se ignoran 1 s (`sellableNow`) y los rechazos
   `Placed / TooFast / Locked / Busy / Protected / NotOwned` se saltan en silencio en vez
   de matar el worker.

`Sell Match` (botón manual) sigue siendo manual: no aplica esta protección, porque ahí
tú decides con tus filtros.

### 8.5 Nueva opción: Farm Thanksgiving

`Extra → Thanksgiving → Farm Thanksgiving` (toggle nuevo).

Ciclo, todo con el mutex y en el orden del juego:

1. `chefDo("both")`: si hay recompensa pendiente → `Thanksgiving_Action("Claim")`; si
   `Thanksgiving.CanCook(estado, talla)` (3/6/9 ingredientes según
   `ThanksgivingConfig.Order`) → `Thanksgiving_Action("Talked")` + `("Cook", talla)`.
   Talla según el dropdown `Cook Size` (`Best` = Mega → Big → Regular). Respeta el
   cooldown real del chef (10 s cliente + margen) y trata `TooFast / NotEnough /
   NothingToClaim / TooFar` como “esperar”, no como error.
2. `prepareThanksgivingIndex(true)`: elige el animal **del evento** que falta, calcula el
   poder con `AreaUtil.ComputeLanding`, y **fija `Player_SetThrowPower`** para que el
   tiro caiga en esa zona/sección.
3. Lanza **con sándwich** (`Throw_UseSandwich`) si tiene; si no tiene sándwich, lanza
   normal para seguir juntando ingredientes (así el farm nunca se queda “trabado”).
4. Si ya no queda nada del índice (`Thanksgiving index complete`) se detiene y lo avisa.
5. Cada 10 tiros informa: animales del evento, sándwiches e ingredientes.

`Auto Event (claim chef rewards)` y `Auto Cook Sandwich` se reescribieron con la misma
función `chefDo` y ahora son **resilientes**: un rechazo temporal ya no apaga el toggle.

### 8.6 Otros arreglos de esta ronda

- `FarmAnimals` y `Farm Thanksgiving` son **mutuamente excluyentes** (y ambos piden
  apagar antes `Auto Train`), así no compiten por el personaje.
- `Auto Index` y `Auto Thanksgiving Index` vuelven a ser excluyentes (`elseif`), si no el
  segundo sobreescribía el poder de tiro del primero.
- Los fallos de `Train Between Farms` desactivan **solo** esa opción (no el farm entero).
- `Auto Equip Best` ahora se pide **después de cada captura** (`requestEquip()`), en vez
  de solo cada `Equip Delay`.
- `Farm Delay`, `Meter Delay`, `Reveal Delay`, `Complete Delay` siguen siendo sliders.

### 8.7 Cómo probar la ronda 2

1. `Extra → Farm`: activa `Farm Animals`. En ~25 s debe completar un tiro (log
   `Equip Best: n placed, m swapped` si `Auto Equip Best` está on).
2. `Main → Training → Auto Train`: te lleva al `TrainingSpot`, entra la cámara de
   entrenamiento y las reps suben. Con `Auto 2x Press` on, cada bonus debe reclamarse
   (popup «x2!» + XP extra).
3. `Extra → Train Between Farms` + `Train After Throws = 10`: tras la tanda entra al
   entrenamiento y vuelve solo al farm.
4. `Extra → Selling`: activa `Auto Sell` con un filtro **y** `Auto Equip Best`. Debe
   aparecer `Auto Sell on hold: waiting…`/`plot shows x/y` cuando no pueda garantizar la
   parcela, y **nunca** vender un pet mejor sin estar colocado.
5. `Extra → Thanksgiving → Farm Thanksgiving`: si el picnic está cerrado el toggle se
   apaga con el motivo; si está abierto cocina, reclama y lanza con sándwich.
6. Con `Farm Animals` + `Auto Event` + `Auto Cook Sandwich` a la vez: ya no se pelean
   (mutex + `waitGameIdle`), el evento sigue funcionando.
