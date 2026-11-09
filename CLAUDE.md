# Notes for Claude

- **Never commit game data.** No .DAX, .OVR, saves, PDFs or anything from the "Pool of Radiance" folder. `.gitignore` covers these; check `git status` before every commit.
- Engine: **Godot 4.7, GDScript**, Compatibility renderer (web export is a goal).
- Target: **DOS Pool of Radiance**. Reproduce the original faithfully; additions are QoL only (automap, quest tracker, quick save, mouse) unless Jeremy says otherwise.
- Reference projects (ssi-engine, Curse of the Azure Bonds port) are GPL: use them as format documentation only, don't copy code.
- The roadmap and decisions live in the `ai-business-ideas` repo: `plans/game-modernizer-roadmap.md` and `ideas/game-modernizer.md`.
- Jeremy works one step at a time: finish a step, show the result, then move on.
- Use tabs for GDScript indentation; keep files LF.
