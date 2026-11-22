---
name: trashpanic-dev
description: Test, screenshot, and build loop for TRASH PANIC! (Godot 4.7 co-op game in this repo). Use whenever you change game code or art, need to see the game, or build the web/Android version.
---

# TRASH PANIC! dev loop

1. **Tests**: `tools/test.sh` (GDScript tests, a 10-shift bot soak with host/guest sync checks, server `node --test`). Must print `ALL TESTS PASSED`.
   Online smoke test: `npx wrangler@4 dev --local --port 8787 --ip 127.0.0.1` in `server/`, then run two clients
   `godot --path game res://tests/net_smoke.tscn -- --play-url=ws://127.0.0.1:8787/play --name=A --seconds=40 --out=<png>`
   (and `--name=B`) and compare their DIGEST lines.
2. **See the game**: the window manager tiles windows, so always use the offline shot tool, which renders a host
   shift with an idle partner:
   `tools/shot.sh 60 <scratchpad>/shot.png`
   `--at` = shift second to fast-forward to (Rush Hour 110-135). Read the PNG and compare with `design/refs/trash_is_fun_dock.jpg`.
3. **Errors**: grep the shot run's output for `SCRIPT ERROR|Parse Error|ERROR`.
4. **Builds** (ask the user first): `tools/build_web.sh`, `tools/build_android.sh debug [--install]`.
5. **New asset**: copy into `game/core/assets/...`, run `godot --headless --path game --import`, credit it in `CREDITS.md`.

Never deploy, install on the phone, commit or push without asking.
