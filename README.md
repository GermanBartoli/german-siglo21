# Germán Siglo21

**Prepará tu PC antes de rendir virtualmente.** Probá la cámara, revisá qué aplicaciones siguen abiertas y elegí qué cerrar o pausar desde una configuración sencilla.

Idea y proyecto de **Germán Bartoli**. Herramienta personal e independiente para Windows, sin afiliación ni certificación de Universidad Siglo 21 o de proveedores de exámenes.

## Descargar y empezar

1. Descargá **[German-Siglo21-v1.2.0.zip](https://github.com/GermanBartoli/german-siglo21/releases/latest/download/German-Siglo21-v1.2.0.zip)** desde la [última versión](https://github.com/GermanBartoli/german-siglo21/releases/latest).
2. Hacé clic derecho sobre el ZIP → **Extraer todo**. No lo ejecutes desde adentro del ZIP.
3. Guardá tu trabajo y hacé doble clic en **MARISOL APRETA ACÁ.cmd** o **Iniciar.cmd**. Ambos cierran las aplicaciones de la lista, incluido wallpaper32.exe, y detienen los servicios de Brave que Windows permita. El inicio directo fuerza el cierre y muestra un resumen por nombre.
4. La cámara se abre en una ventana nativa con el permiso de cámara de las aplicaciones de escritorio de Windows. La ventana se cierra después de recibir cinco segundos de video.
5. Para usar el menú, abrí **Iniciar con pasos.cmd**.

**No necesita instalación, Python, Node.js ni paquetes adicionales.** Requiere Windows 10/11 con Windows PowerShell 5.1 y acceso a la cámara para aplicaciones de escritorio. Conservá todos los archivos y la carpeta `src` juntos.

> El menú usa la configuración inicial de simulación. El inicio directo realiza los cierres y vigila las reaperturas hasta restaurar, cerrar sesión o reiniciar.

## Qué hace el inicio directo, en orden

1. **Guardá tu trabajo antes del doble clic.** El cierre directo termina los procesos incluso si tienen cambios sin guardar.
2. **Detiene los servicios de Brave** `brave` y `bravem` cuando están activos y Windows lo permite.
3. **Prioriza los cierres de la sesión** de Chrome, Edge, Brave, ChatGPT, Wallpaper Engine (`wallpaper32`), Brave Crash Handler (32 y 64 bits), Brave Update y Brave Updater. Identifica el WebView2 de la lupa y de Widgets mediante la línea de comandos o su proceso padre.
4. **Cierra el resto de la lista una vez** y muestra una línea por nombre.

   | Grupo | Aplicaciones o procesos |
   | --- | --- |
   | Otros navegadores | Firefox, Opera y Opera GX, Vivaldi, Internet Explorer, Waterfox, LibreWolf, Floorp, Zen, Thorium, Chromium, Arc y DuckDuckGo |
   | Comunicación | Teams, Zoom, Discord, Skype, Slack, Telegram y WhatsApp |
   | Captura | OBS, ShareX, Snagit, Camtasia y CamRecorder |
   | Otros asistentes | Claude, Copilot y Codex |

5. **Vigila las reaperturas.** Un proceso de la sesión revisa los objetivos de los puntos 2 y 3, espera dos segundos entre revisiones y vuelve a cerrarlos si reaparecen. Pueden verse brevemente durante ese intervalo. Los WebView2 de otras aplicaciones siguen disponibles.
6. **Muestra la cámara durante cinco segundos** desde el primer cuadro. Usa video en memoria y la configuración de privacidad de Windows. La ventana se cierra y libera la cámara.
7. **Finaliza la vigilancia** al reiniciar, cerrar sesión o abrir **Restaurar.cmd**. Restaurar también intenta reactivar los servicios y componentes que quedaron registrados. Para volver a usar Chrome durante la misma sesión, abrí primero **Restaurar.cmd**.

Es una ayuda previa al examen para cerrar programas que no necesitás. **No oculta procesos, no modifica el sistema de supervisión ni evita sus controles.** No garantiza que una plataforma acepte el equipo; completá siempre su chequeo oficial y seguí sus indicaciones.

## Preparación real, paso a paso

1. Guardá documentos, conversaciones y cualquier trabajo abierto.
2. Antes de iniciar el examen, abrí `configuracion.psd1` con el Bloc de notas.
3. Cambiá `ModoSimulacion = $true` por `ModoSimulacion = $false`.
4. Activá con `$true` únicamente las acciones que necesites. Para pausar los componentes de Windows, activá `PausarBuscar` y/o `PausarWidgets`. `CerrarCodex` permanece en `$false` hasta que lo cambies explícitamente.
5. Abrí `Iniciar con pasos.cmd`, elegí **3**, revisá la lista y escribí **PREPARAR** cuando lo solicite.
6. Completá la prueba de cámara. Si falla, la preparación se cancela antes de cerrar o pausar aplicaciones.
7. Revisá los pendientes y abrí la plataforma oficial de examen.
8. Cuando termines, ejecutá **Restaurar.cmd** para reactivar lo que haya registrado el programa.

Ejecutalo desde el Explorador. Si habilitás el cierre de Codex y lo lanzás desde su terminal, el cierre de Codex puede interrumpir la ejecución y el informe final.

## Variables disponibles

Usá los valores de PowerShell **`$true`** y **`$false`**, sin comillas. El programa rechaza variables desconocidas y valores incorrectos antes de preparar el equipo.

| Variable | Inicial | Función |
| --- | --- | --- |
| `ModoSimulacion` | `$true` | Solo muestra las acciones; tampoco activa la cámara. |
| `ProbarCamara` | `$true` | Comprueba la cámara antes de la preparación real. |
| `CerrarNavegadores` | `$false` | Cierra los navegadores y componentes de Brave de la lista. |
| `CerrarComunicacion` | `$false` | Teams, Zoom, Discord, Skype, Slack, Telegram y WhatsApp. |
| `CerrarWallpaper` | `$false` | Cierra wallpaper32.exe. |
| `CerrarCaptura` | `$false` | OBS, ShareX, Snagit y componentes de Camtasia de la lista. |
| `CerrarAsistentesIA` | `$false` | ChatGPT, Claude y Copilot de escritorio. |
| `CerrarCodex` | `$false` | Codex, codex-app y codex-desktop. |
| `PausarBuscar` | `$false` | Suspende SearchHost y SearchApp hasta restaurar o reiniciar. |
| `PausarWidgets` | `$false` | Suspende Widgets y WidgetService hasta restaurar o reiniciar. |
| `CerrarWebViewWidgets` | `$false` | Cierra solo WebView2 identificado como componente de Buscar/Widgets. |
| `DetenerServiciosBrave` | `$false` | Detiene `brave` y `bravem` si están activos; puede requerir administrador. |
| `ForzarCierre` | `$false` | Fuerza el cierre si no responde al cierre normal; puede perder datos sin guardar. |
| `EsperaCierreSegundos` | `5` | Espera por aplicación antes de forzar o informar un pendiente; admite 1 a 30. |

**Buscar y Widgets son procesos de Windows; los servicios que se detienen son los de Brave.** No se cambia el tipo de inicio de servicios ni se desactiva permanentemente Windows Search, el antivirus o Windows Update.

Las listas exactas se mantienen en `src/Preparacion.ps1`. No se cierran procesos de otras sesiones de Windows. No se aplica un cierre indiscriminado a todos los procesos WebView2, porque también los usan otras aplicaciones.

## Simulación, cámara y restauración

| Archivo u opción | Comportamiento |
| --- | --- |
| `Iniciar con pasos.cmd` | Abre el menú principal. |
| `Simular.cmd` | Simula siempre, aunque hayas desactivado `ModoSimulacion`. |
| Opción 1 del menú | Activa solamente la prueba de cámara; ignora el modo de simulación porque la elegís explícitamente. |
| `Restaurar.cmd` | Restaura las acciones registradas aunque `ModoSimulacion` esté activo. |

También podés usar una terminal independiente:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\German-Siglo21.ps1 -Simular
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\German-Siglo21.ps1 -SoloCamara
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\German-Siglo21.ps1 -Restaurar
```

El permiso de ejecución se aplica solo al proceso lanzado: no se cambia la política global de PowerShell. Los scripts no tienen firma digital. Si Windows o la organización bloquean su ejecución, revisá el origen del archivo y la política del equipo; no desactives las protecciones del sistema.

## Privacidad y restauración

- La vista nativa procesa los cuadros de video en memoria. La prueba usa solo la cámara y libera el dispositivo al salir.
- Los registros de restauración se guardan en `%LOCALAPPDATA%\GermanSiglo21\estado`: contienen nombres de procesos/servicios, identificadores y la hora de inicio del proceso. No se suben al repositorio.
- La restauración comprueba el identificador y la hora de inicio antes de reanudar un proceso, para no actuar sobre otro que reutilice el mismo número.
- La restauración no vuelve a abrir programas cerrados ni recupera documentos sin guardar. Si no podés reactivar Buscar o Widgets, reiniciá Windows. No borres los registros mientras haya componentes pausados.
- La vigilancia funciona con los permisos del usuario que abrió el lanzador. Windows puede denegar el cierre de procesos elevados o la detención de servicios.

## Solución de problemas

**La cámara no funciona:** revisá conexión, obturador, el permiso de Windows para aplicaciones de escritorio, y otras aplicaciones que puedan estar usándola. La prueba espera hasta 25 segundos para obtener video y detecta interrupciones durante la vista previa. No comprueba el micrófono.

**Un programa sigue abierto:** cerralo manualmente. Algunas aplicaciones ignoran la solicitud normal de cierre; `ForzarCierre` es opcional y puede descartar trabajo.

**Acceso denegado al pausar o detener:** el programa informa el pendiente sin elevarse automáticamente. Si decidís usar esas funciones, podés ejecutar el lanzador como administrador. Para restaurar acciones elevadas puede ser necesario ejecutar `Restaurar.cmd` también como administrador y con la misma cuenta.

**No aparece una aplicación:** las listas son limitadas y los nombres de procesos pueden cambiar. Revisá el Administrador de tareas y el chequeo oficial. Desactivar una opción no significa que esa categoría esté libre de aplicaciones.

**No cambia nada:** verificá `ModoSimulacion` y las acciones que habilitaste. La configuración inicial está pensada para inspeccionar antes de actuar.

## Código y alcance de esta versión

- `German-Siglo21.ps1`: menú y coordinación.
- `configuracion.psd1`: variables editables.
- `src/Camara.ps1`: prueba local de cámara.
- `src/Preparacion.ps1`: inventario, cierre, pausa y restauración.
- `CHANGELOG.md`: historial de cambios.

La versión inicial se publica con revisión estática y de sintaxis. **No se ejecutaron pruebas funcionales de cámara, cierre, pausa o restauración**, por decisión del autor. No se afirma compatibilidad validada con un examen o proveedor concreto.

## Autoría

Creado a partir de una idea y herramienta personal de **[Germán Bartoli](https://github.com/GermanBartoli)**. Las mejoras y la documentación de esta versión se prepararon con asistencia de Codex. El repositorio es público; no incluye una licencia de software libre.

## Guías y comunidad

[Guía de uso](GUIA_DE_USO.md) · [Preguntas frecuentes](PREGUNTAS_FRECUENTES.md) · [Cómo colaborar](CONTRIBUTING.md) · [Código de conducta](CODE_OF_CONDUCT.md)
