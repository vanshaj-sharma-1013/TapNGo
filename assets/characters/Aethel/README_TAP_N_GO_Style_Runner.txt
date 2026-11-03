TAP N GO — Style Runner Character
=================================

Files
-----
TAP_N_GO_Style_Runner_Animated.glb

Format
------
- glTF 2.0 binary (.glb)
- 97 separately named mesh parts with vertex-color materials
- Node-transform animation clips embedded in the GLB:
  - Idle (2.4 seconds)
  - Run (1.0 second loop)
  - Die (1.25 seconds)

Godot 4.x
---------
1. Extract the GLB from this ZIP.
2. Copy it into your project, for example:
   res://Assets/Characters/TAP_N_GO_Style_Runner_Animated.glb
3. Let Godot import the model.
4. Open the imported scene and use its AnimationPlayer.
5. Select the clips by their exact names: Idle, Run, Die.
6. For an AnimationTree, create an AnimationNodeStateMachine and connect
   the imported clips to your gameplay states.

Implementation note
-------------------
This version uses named mesh nodes with embedded glTF transform animation
tracks (the same node-based animation approach as the previous TAP N GO
character delivery). It is not a conventional single skinned humanoid mesh
with a deforming skeleton/weight-painted joints. Individual parts are
separate nodes so the clips can be played through Godot's AnimationPlayer.
