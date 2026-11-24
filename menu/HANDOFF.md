# Menú "Zenith Home" — paquete completo

Todo lo necesario para **usar o seguir el menú en otra conversación / otro proyecto**.
Réplica del GUI de referencia (la captura del menú con Continue / News / Updates y la
columna de Clearance · Division · Balance · Time Played · Online Friends).

```
menu/
├── ZenithMenu.lua        ← el menú completo (772 líneas, sin dependencias)
├── make_icons.py         ← genera los PNG transparentes (128x128)
├── assets/               ← PNGs ya generados, listos para subir a Roblox
│   ├── division-logo.png         logo original, fondo blanco ya quitado
│   ├── division-logo-vector.png  recreación vectorial (respaldo)
│   ├── house.png
│   ├── people.png
│   └── paper.png
└── HANDOFF.md            ← este documento
```

---

## 1. Estado actual

| Pieza | Estado |
|---|---|
| Diseño / layout | **cerrado** — lienzo de diseño 1224×780, escalado automático |
| `ZenithMenu.lua` | **escrito y compilado** (`luau-compile` exit 0) |
| Glyphs | vectoriales por defecto + PNGs generados para sustituirlos |
| Logo de división | PNG con alfa transparente (blanco eliminado, lilas conservados) |
| Integración con `Throwfoodforanimalshub` | **no hecha** (el menú es standalone) |

## 2. Especificación que pidió el usuario (para no perderla)

- Recrear el menú de la captura "idéntico, sin ninguna falla".
- Donde está la **Q naranja** arriba a la izquierda → **Z naranja**.
- Mantener: **casa** (sobre cuadro ámbar), **papel doblado**, **E**, **Home** con
  separadores verticales.
- La imagen grande de **News** debe mostrar **la foto del juego en el que estás**
  (detectado por script) y en **TITLE** el **nombre de ese juego**.
- Mantener **Continue**, **News**, **Updates**.
- Barra inferior: **F → Updates**, **X → Soon**, **C → Soon** (antes "Something").
- Arriba a la derecha: **CLEARANCE = ZNTH** y **DIVISION = el logo adjunto**, con el
  **fondo blanco quitado** (transparente).
- Reemplazar "Balance" por **Standard** / **12 Hours - Remaining** con **contador real**.
- "**Time Played**": igual que en la captura, pero funcionando.
- "21 Online Friends" → **Active users = 69**.
- Abajo: **usuario real de Roblox** y **foto de perfil real**.
- Sin dependencias raras; igual en cualquier resolución.

## 3. Decisiones técnicas (no re-discutir sin motivo)

1. **Cero librerías externas.** Ni Rayfield, ni WindUI, ni Fluent: ninguna reproduce
   este layout exacto y `loadstring(game:HttpGet(...))` es un punto de fallo en muchos
   executors. Todo se dibuja con primitivas y helpers propios.
2. **Glyphs vectoriales por defecto**, con `CONFIG.ICONS` para cambiar a PNG cuando
   estén subidos (`"rbxassetid://…"`). Así funciona hoy, sin assets inventados.
3. **Escalado**: coordenadas en px sobre lienzo 1224×780 dentro de un Frame con
   `UIScale = clamp(min(vx/1224, vy/780), 0.35, 2)`, recalculado al cambiar el viewport.
4. **Miniatura del juego**: `rbxthumb://type=GameIcon&id=<PlaceId>&w=512&h=512`
   (nativo, sin HTTP); si el executor tiene `writefile`+`getcustomasset`, antes se
   intenta bajar la 512×512 de `thumbnails.roblox.com`. Fallback: degradado + inicial.
5. **Nombre del juego**: `MarketplaceService:GetProductInfo(game.PlaceId).Name`,
   luego `game.Name`, luego `"Place <id>"`.
6. **Avatar/usuario**: `rbxthumb://type=AvatarBust&id=<UserId>&w=420&h=420` +
   `DisplayName` + `@Name`. Nada hardcodeado.
7. **Contador**: `os.time() + 12h`, persistido en `ZenithStandard.txt` y en `shared`
   para que no se reinicie al re-ejecutar; `"N Hours - Remaining"` + reloj
   `HH:MM:SS` cada 0.5 s; a cero muestra `Expired`.
8. **Time Played**: tiempo real desde que arranca el menú (`Xd Xh Xm`).
9. **Continue** cierra el menú y deja una **Z** flotante para reabrirlo
   (`CONFIG.ALLOW_CLOSE = false` para desactivar).

Paleta del logo (medida sobre el PNG original): `#D8C1D8`, `#B676B6`, `#A24BA2`.
Acento del menú: `#F6A520`. Panel `#07080B` al 10 % de transparencia, borde `#94979F` al 45 %.
Tipografías: `Oswald` (títulos/valores), `SourceSans` (descripción), `RobotoMono` (reloj).

## 4. Cómo usarlo

```lua
-- 1. Pegar menu/ZenithMenu.lua en el executor (o en un LocalScript).
-- 2. (Opcional) subir los PNG y pegar las ids:
CONFIG.ICONS = {
    House    = "rbxassetid://…",
    People   = "rbxassetid://…",
    Paper    = "rbxassetid://…",
    Division = "rbxassetid://…",
}
```

Los PNG se regeneran desde el logo original con:

```bash
python3 menu/make_icons.py download.png menu/assets
```

## 5. Pendientes

- [ ] Subir los 5 PNG a Roblox y pegar las ids (único punto donde aún no es 100 %
      idéntico: los vectoriales se ven bien pero no son los originales).
- [ ] (Opcional) hover/animaciones en Continue y Updates.
- [ ] (Opcional) integrarlo como pantalla inicial de `Throwfoodforanimalshub`.
- [ ] (Opcional) pantallas detrás de los tabs (Home/News/Updates con listas y scroll).

## 6. Referencias

- Captura de referencia: `542d5bdaa05f00117c4dc50bdb9200ff783bf534.jpeg`
  (adjunta en la conversación original).
- Logo original: `download.png` (196×196, fondo blanco, lilas).
- Nota de escala: para el resto del menú, ~700–850 líneas es el costo real de una
  pantalla de este tipo dibujada píxel a píxel sin librería; este archivo tiene 772.
