# Credits

Only CC0 or CC-BY assets go in this project. Every CC-BY asset gets an entry
below (title, author, link, licence, what was changed).

## Code and add-ons

| What | Where | Author | Licence |
|---|---|---|---|
| Godot XR Tools 4.6.0 | `addons/godot-xr-tools/` | Bastiaan Olij and contributors | MIT (`addons/godot-xr-tools/LICENSE.txt`) |
| XR Tools hand models | `addons/godot-xr-tools/hands/` | DigitalN8m4r3 (Miodrag Sejic) | CC0 1.0 (`addons/godot-xr-tools/hands/License.md`) |
| GUT (Godot Unit Test) | `addons/gut/` | Tom "Butch" Wesley | MIT (`addons/gut/LICENSE.md`) |

## Art

| What | Where | Author | Licence | Source | Changes |
|---|---|---|---|---|---|
| "Colt Single Action Army" | `revolver/model/colt_saa/` | Foxx Assets (https://sketchfab.com/FoxxAssets) | CC-BY 4.0 | https://sketchfab.com/3d-models/colt-single-action-army-6ccdd2a5b4164e57acbaf770cc15615e | textures downscaled 4096 -> 2048 px; scaled, oriented and rigged in `tools/scene_builders.gd` |

This work is based on "Colt Single Action Army"
(https://sketchfab.com/3d-models/colt-single-action-army-6ccdd2a5b4164e57acbaf770cc15615e)
by Foxx Assets (https://sketchfab.com/FoxxAssets) licensed under CC-BY-4.0
(http://creativecommons.org/licenses/by/4.0/).

The cartridges, ammo box and range are placeholders built from primitives by
`tools/scene_builders.gd` (this project). The primitive revolver
(`revolver/RevolverPlaceholder.tscn`) is used if the model is missing.

## Sound

Every sound in `audio/generated/` is synthesised by `audio/ProceduralSounds.gd`
(this project). Real recordings go in `audio/sounds/`; add them here.

<!-- Template for a CC-BY asset:
| "<title>" | `audio/sounds/shot_crack_1.ogg` | <author> | CC-BY 4.0 | <url> | trimmed to 150 ms, normalised |
-->
