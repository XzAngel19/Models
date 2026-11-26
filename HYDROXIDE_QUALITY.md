# Hydroxide: calidad antes que nuevas funciones

## Estado real

Versión experimental: no se ha ejecutado este loader en Roblox desde el sandbox.
No garantiza captura completa ni equivalencia con Cobalt. Los hooks instalados no
son pruebas de entrega. Usar en experiencias propias o con autorización.

La ausencia de BindableEvent en el último log no prueba que el filtro sea correcto:
la misma sesión tampoco contiene llamadas salientes estándar.

## Cambios de esta revisión

- Estado real de instalación del parche checkCaller, separado de su configuración.
- Contadores de registros guardados por tipo y reloj monotónico por registro.
- Buffer incompleto/no legible marca el registro como incompleto globalmente.
- `getgenv().HydroxideLogSaver.health()` devuelve diagnóstico sin escribir.
- `.checkpoint()` guarda el diagnóstico; `.stop()` guarda resumen final.
- `python3 tools/validate_hydroxide_log.py archivo.jsonl` detecta JSON roto,
  saltos de secuencia y contenido incompleto. No prueba cobertura de red.

## Matriz obligatoria antes de declarar estable

En una experiencia de prueba propia, usar un LocalScript normal (no el ejecutor,
porque checkCaller lo filtra) y un Script de servidor. Cada envío debe llevar
un identificador único y el servidor debe registrar los identificadores recibidos.
Comparar conjuntos exactos, no solo cantidades. Ejecutar sin spy y con spy.

| Prueba | Criterio |
| --- | --- |
| RemoteEvent, llamadas con punto y dos puntos | Cada ID recibido corresponde a un registro, sin duplicados |
| UnreliableRemoteEvent | Comparar emisiones locales y recepciones por separado: la red permite pérdida |
| RemoteFunction | Argumentos, nil intermedio/final y retornos múltiples intactos |
| Errores y yields en InvokeServer | Misma conducta observable con y sin spy |
| OnClientEvent | Todos los eventos entregados tras conectar el observador aparecen |
| OnClientInvoke / BindableFunction | Pendiente de implementar y validar; no declarar soporte |
| Buffer vacío, binario, 64 KiB y mayor | Bytes exactos o truncamiento explícito |
| Tablas con ciclos y referencias compartidas | Grafo intacto o límite explícito |
| Remotos creados después de iniciar | Detectados y conectados sin reiniciar |
| Carga sostenida | Contadores, latencia, memoria y escritura comparados con baseline |
| Stop y segunda ejecución | Sin callbacks duplicados ni registros posteriores al cierre |
| Actor paralelo | Cobertura pendiente, no asumir captura desde otro contexto |

No activar dos RemoteSpies simultáneamente para validar duplicados: sus hooks pueden
interferir. Repetir el mismo fixture por separado para cada spy.

## Trabajo restante (no implementado)

1. Sustituir el parche por patrones del código remoto por un núcleo local versionado.
2. Identidad por llamada y un único pipeline para deduplicar namecall/dotcall sin
   eliminar dos envíos legítimos con argumentos iguales.
3. Observación segura de callbacks y resultados con política explícita de errores,
   yields, cambios posteriores de callback y nils finales.
4. Cola acotada de snapshots, métricas de pérdida, flush y límites de memoria.
5. Separar visualización, bloqueo y captura: el filtro de UI no debe perder datos.
6. Ciclo de vida por generación para hooks persistentes y reinyección.
7. Adaptador de Actor solo donde la API disponible permita instrumentación autorizada;
   informar contextos no cubiertos. No incluir evasión de anticheat.

El modo pasivo debe ser el predeterminado: ninguna mejora de registro debe bloquear,
repetir o modificar tráfico del juego. No prometer "superior" antes de pasar la matriz.
