# Assets: what the real files must be

Everything in the game runs on placeholders now. This page says exactly what
real art and sound must look like so it drops in without code changes.
Licences: **CC0, or CC-BY with an entry in `CREDITS.md`.** Nothing else.

## 1. The revolver model (.glb)

### Swapping it in
1. Put the file anywhere, e.g. `revolver/model/colt_saa.glb`.
2. Open `revolver/Revolver.tscn`, delete the child named `Model`, drag the
   .glb in as a child and rename it **`Model`**.
3. Move/rotate the `Model` node (not the parts) until the gun lines up with the
   collision shapes (`BarrelShape`, `CylinderShape`, `FrameShape`, `GripShape`
   ...). If the real gun differs, resize those shapes to match.
4. Run `tools/test.bat -gselect=test_model_swap` and `-gselect=test_revolver`.

The gun finds its parts **by name, anywhere under `Model`**, so the glTF
importer's extra nodes don't matter. Its sights are zeroed automatically from
the `SightRear` / `SightFront` / `Muzzle` markers (the bore direction is solved
so the bullet meets the sight line at 15 m).

### Scale and axes
- **Metres, real size.** 1 unit = 1 m. Overall length about 0.33 m; barrel
  0.1905 m (7.5") from the cylinder's front face to the muzzle.
- **Godot axes:** barrel points **-Z**, top is **+Y**, the loading-gate side
  (the gun's right) is **+X**.
- **In Blender** (glTF export, "+Y Up" on): barrel along **Blender +Y**, top
  along **+Z**, gate side **+X**. Apply all transforms (Ctrl+A) before export.
- Preferred origin: on the bore axis at the barrel breech (the cylinder's front
  face). Any origin works if you align `Model` as in step 3.

### Required parts (exact names)
Moving parts must be **separate objects whose origin is the real pivot** and
whose local axes match the gun's axes (apply rotation in Blender). The code
rotates/slides them from their rest pose:

| Node | Pivot (origin) | Motion applied by code |
|---|---|---|
| `Frame` | anywhere | static |
| `Barrel` | anywhere | static (include the ejector housing here or in Frame) |
| `Grip` | anywhere | static (walnut panels + backstrap) |
| `Cylinder` | on the cylinder axis, mid-length | rotates about local **Z**; clockwise seen from behind; 60 deg per chamber. In the rest pose one chamber is at 12 o'clock (in line with the bore). Cylinder axis 13.5 mm below the bore (`RevolverSpec.CHAMBER_RADIUS`) |
| `Hammer` | the hammer screw | rotates about local **+X**; positive = spur back. Half-cock 22 deg, full cock 48 deg (`RevolverSpec`) |
| `Trigger` | the trigger screw | rotates about local **+X**; pulled = -14 deg |
| `LoadingGate` | its hinge at the gate's lower edge (fore-aft axis) | rotates about local **Z**; open = -95 deg (swings out to the right) |
| `EjectorRod` | anywhere on the rod, rod at rest | slides along local **+Z** (toward the shooter) 48 mm |
| `Muzzle` | empty at the muzzle crown, on the bore axis | marker: bullets start here |
| `SightRear` | empty at the **top edges of the rear-sight groove** in the top strap | marker for zeroing |
| `SightFront` | empty at the **top of the front blade** | marker for zeroing |

Chamber states are drawn by the code (brass heads at the back of the
cylinder), so the model's cylinder should have open chambers or plain recesses.

### Budget (Quest 2/3)
- 8k to 20k triangles; one material if possible (albedo + normal + ORM),
  2048 px max (1024 is plenty at arm's length).
- Blued barrel/cylinder, case-hardened frame, walnut grip, brass trigger guard.
- No animations or armature needed.

### Optional: cartridge model
`ammo/Cartridge.tscn` has a `Model` node with `Case`, `Rim`, `Primer` and
`Bullet`. A .45 Colt is 40.6 mm long (case 32.5 mm, rim 13 mm diameter).
Keep those four names; `Bullet` is hidden on spent cases and `Primer` turns
dark.

## 2. Sounds

Put real files in `audio/sounds/` named after the key below:
`<key>.ogg` (or `.wav`), or variations `<key>_1.ogg`, `<key>_2.ogg`... (one is
picked at random each time). They override the placeholders in
`audio/generated/` automatically; nothing else to change.

Format: **mono** (they are positional 3D sounds), 44.1 or 48 kHz, OGG Vorbis
q6+ or 16-bit WAV, no silence at the start, peak around -1 dBFS. Each play
gets a small random pitch/volume shift; variations sound better still.

| Key | What it should be | Length | Variations |
|---|---|---|---|
| `shot_crack` | The close, sharp front of a revolver shot, close-miked. Only the first ~100-150 ms, cut before the room/echo. A .45 Colt black-powder revolver is ideal; any large-bore revolver works | 0.1-0.2 s | 3 |
| `shot_boom` | The low-end body of the same shot: low-pass at ~300 Hz, or a separate low "thump" recording | 0.8-1.5 s | 2 |
| `shot_tail` | Distant outdoor gunshot tail / echo off a hillside or building, with the direct transient removed. Played from the rock wall and the building, delayed by distance | 1.5-3 s | 3 |
| `hammer_half_cock` | Hammer drawn to the first notch: a light click | <0.1 s | 2 |
| `hammer_full_cock` | Hammer to full cock: the louder "click" with the cylinder ratchet (SAA cocking is famously "four clicks": C-O-L-T) | 0.1-0.2 s | 2 |
| `hammer_lower` | Hammer eased down under the thumb | <0.2 s | 1 |
| `trigger_break` | The sear letting go: tiny crisp click | <0.05 s | 2 |
| `dry_fire` | Hammer falling on an empty chamber / spent primer: metallic snap | <0.15 s | 2 |
| `gate_open` / `gate_close` | Loading gate snapping open / shut | <0.1 s | 1 each |
| `cylinder_click` | One pawl click as the free cylinder turns a chamber | <0.05 s | 3 |
| `ejector_rod` | Ejector rod sliding back through the chamber (spring scrape) | 0.1-0.2 s | 2 |
| `case_eject` | The case pushed out past the gate (brass on steel) | <0.1 s | 2 |
| `round_insert` | Cartridge sliding into the chamber and seating | 0.1-0.2 s | 2 |
| `case_land_dirt` / `_wood` / `_metal` / `_rock` | An empty pistol case dropping on that surface (dull tick on dirt, hollow tock on wood, bright ring on steel) | 0.1-0.5 s | 3 each |
| `gun_land_dirt` / `_wood` / `_metal` / `_rock` | A heavy steel pistol dropped on that surface | 0.2-0.6 s | 2 each |
| `hit_dirt` / `hit_wood` / `hit_metal` / `hit_rock` | Bullet impacts: thud in dirt, crack in wood, the classic steel-target "ping" (ringing, ~1 s), chip on rock | 0.2-1 s | 3 each |
| `ricochet` | Ricochet whine | 0.4-0.8 s | 3 |

If you only find full outdoor gunshot recordings: the first 120 ms is the
crack, a 300 Hz low-pass of the first second is the boom, and everything after
~150 ms (faded in) is a usable tail.

## 3. Range textures (optional)

The range uses flat colours and one noise texture. For a better look at low
cost, CC0 PBR sets (1k, ORM packed) for: desert ground / dry sand, weathered
wood planks, sandstone/cliff rock, painted steel. Apply to the materials in
`tools/scene_builders.gd` (`build_range`) or directly in `range/Range.tscn`.

## 4. Where to look

I couldn't browse or verify specific listings from here, so check each
licence on the page itself before downloading:

- **Model:** Sketchfab with "Downloadable" and the CC0 or "CC Attribution"
  licence filter, search "Colt Single Action Army" / "Colt Peacemaker" /
  "Colt 1873". Prefer models whose hammer, trigger, cylinder, gate and
  ejector are separate objects; otherwise separate them in Blender. Poly Pizza
  (CC0 / CC-BY) for simpler versions.
- **Textures and sky:** ambientCG and Poly Haven (both CC0).
- **Sounds:** Freesound.org with the "Creative Commons 0" licence filter (or
  "Attribution", then credit it). Search terms: "black powder revolver",
  "45 colt", "single action revolver cock", "revolver hammer", "dry fire",
  "revolver cylinder spin", "shell casing drop" (+ dirt / wood / concrete),
  "steel target ping", "ricochet", "gunshot echo distant".
