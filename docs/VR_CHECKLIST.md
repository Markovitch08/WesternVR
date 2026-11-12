# Please try in VR

Things the headless tests can't judge: feel, scale, sound balance. Tick them
off with Quest Link (press Play in the editor) or on the headset.

## Step 1: Rig
- [ ] Floor height is right (local-floor): the bench top is at hip height (91 cm).
- [ ] Hands track and collide with the bench instead of passing through it.
- [ ] Right thumbstick snap-turns 30 deg; comfortable? (Smooth: set
      `Player/RightHand/MovementTurn` turn_mode to Smooth.)
- [ ] Frame rate: the log says "display + physics rate set to 90 Hz"; if it
      later says it fell back to 72 Hz, the scene wasn't holding 90.

## Step 2: Physical grab
- [ ] Grip near the gun's grip picks it up and it sits naturally in the hand.
      If the angle is off, rotate `Revolver/GripPoint` (default -15 deg pitch).
- [ ] Letting go drops it; throwing it works and it tumbles believably.
- [ ] Holding the gun, push it into the bench: it stops at the top, doesn't
      jitter or sink, and the drawn hand stays on the gun.
- [ ] Knock the gun off the bench with your other hand.
- [ ] Swinging fast: the gun keeps up without wobbling or lagging.

## Step 3: Firing and ballistics
- [ ] Aim at the 15 m plate with the blade in the groove, top level: hits
      land on the point of aim. Elsewhere they land slightly low: about 8 mm
      at 5 m, 5 mm at 7 m, 2 mm at 10 m, 2 mm at 20 m, 7 mm at 25 m (so any
      bigger miss is your hold, or a sign the zero is off).
- [ ] Impacts: dust on the ground, splinters on posts, sparks on the plates;
      small holes/lead splashes stay where you hit.
- [ ] Plates swing when hit. Shallow shots off a plate edge sometimes ricochet.

## Step 4: Mechanics
- [ ] A/X cocks: two clicks, cylinder turns one chamber, hammer goes back.
- [ ] Trigger does nothing until the hammer is fully cocked.
- [ ] B/Y half-cock, stick click opens the gate (it swings right), a stick
      flick turns the cylinder one chamber with a click.
- [ ] Are the default buttons comfortable? (Change them on the Revolver node,
      "Controls" group.)
- [ ] Haptics: strong kick on the shot, light ticks on clicks.

## Step 5: Reloading
- [ ] Half-cock, open gate: a brass case head shows in the gate.
- [ ] Other hand near the ejector head (front of the rod under the barrel) +
      its trigger: the case pops out backward and tinks on the ground.
- [ ] Close the other hand in the ammo box: you hold one round; bring it to
      the gate and it slides in. Is the 3 cm insert radius too fussy or too easy?
- [ ] Close the gate, cock, fire the new round.

## Step 6: Recoil, effects, sound
- [ ] Recoil feels like a big black-powder .45: ~25 deg flip, small push back,
      back on target in about a second. Tune on the Revolver node, "Recoil"
      group (recoil_impulse, arm_absorbs, extra_flip, hold_after_shot).
- [ ] Muzzle flash is a quick flash, not a lingering sprite; the light
      flickers on the bench.
- [ ] Smoke cloud: big, white-grey, drifts to the right with the wind, gone
      in ~3 s.
- [ ] Gunshot: crack and boom feel loud and close, the echo comes back from
      the rock wall (~0.22 s) and the building; reverb is subtle.
- [ ] Mechanical sounds are audible but not too loud next to your ear.
- [ ] Rapid fire: no sound cut-outs or stacking.

## Step 7: Range
- [ ] Scale feels right: bench, posts, plates at 7/12/15/18/25 m, rock wall at 40 m.
- [ ] Holds 72 FPS on Quest 2 (and 90 if it can). Check with the OVR Metrics Tool.
