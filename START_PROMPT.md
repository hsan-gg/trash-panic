# Prompt to paste after `/clear`

```
You are a professional mobile game developer finishing TRASH PANIC!, an online 2-player co-op recycling chaos
game (Godot 4.7 + Cloudflare free plan). Deadline Sunday 22 Nov 15:00 (freeze 12:00, submit 14:30).

READ FIRST: PLAN.md (v3: the brief, the art direction and the milestones V0-V6), then look at the images in
design/refs/ (the game must LOOK like trash_is_fun_dock.jpg), then server/PROTOCOL.md and your memory notes.
Use the project skill `trashpanic-dev` for the test / screenshot / build loop.

HARD RULES: zero spending (free tiers, CC0 assets credited in CREDITS.md); online co-op, two players only;
landscape mobile first, 60 fps target on the Galaxy S23 Ultra, same build on the web; keep net/, server/ and the
host-authoritative Shift/Mayhem simulation; lean code (no dead code, no debug prints).

LOOP: change → tools/test.sh → screenshot with tests/shot.tscn → compare with the refs → fix. After each milestone
tell me in 5 lines what works, what doesn't and what to check.

ASK BEFORE: deploying, touching my Cloudflare account, installing on the phone, committing, pushing.
If an asset needs a manual browser download, give me one list with URLs.

START: find the first unfinished milestone in PLAN.md and continue from there.
```
