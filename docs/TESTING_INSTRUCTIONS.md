# Testing Instructions for Yield Pathfinding Fix

## Quick Test (2 minutes)

### Setup
1. Open Godot and load the project
2. Open scene: `res://Scene/Night_game.tscn`
3. Click Play (F5) to start the game

### What to Look For
1. **Watch the agent movement in the 3D view**
   - Observe when agents encounter each other
   - One agent should yield (stop and move to the side)
   
2. **Check the Console Output**
   - Look for pathfinding debug messages
   - Format: `[path nodes list] 경로 출력  AgentName`
   - Example: `[Storage_front, Storage_door] 경로 출력  RD2`

### Expected Behavior - AFTER FIX ✓
- When an agent yields, the path should be SHORT
- The agent should move to a nearby point on its planned route
- Then the agent resumes its original movement

### Unexpected Behavior - If Still Broken ❌
- Long paths with unnecessary nodes like `Left_hall_corner`
- Agent takes detour far away from its intended destination
- Multiple hops when just 1-2 would suffice

---

## Detailed Test (5-10 minutes)

### Test 1: Basic Yield Behavior
**Objective:** Verify agents yield efficiently

**Steps:**
1. Start the game
2. Move the player to a location where two agents will collide
3. Let the agents interact naturally
4. Observe console output

**Expected Console Output Example:**
```
[Right_hall_entrance, Right_hall_middle, Main_hall_mid_right, Main_hall_mid_rightest, Front_toliet] 경로 출력  RD1
```

When RD2 blocks the path:
```
[Right_hall_middle] 경로 출력  RD1
(Agent RD1 yields to Right_hall_middle, which is on its path)
```

**Pass Criteria:**
- ✓ Yield path is very short (1-3 nodes max)
- ✓ Nodes are recognizable as being near the agent's planned route
- ✓ Agent smoothly resumes original path after yielding

---

### Test 2: Multiple Agent Collisions
**Objective:** Verify the fix works with complex interactions

**Steps:**
1. Position player to cause multiple agent interactions
2. Let 2-3 agents navigate with obstacles
3. Monitor all paths in console

**Expected Behavior:**
- Each agent's yield path should be minimal
- No agent should make a detour through `Left_hall_corner` unnecessarily
- Conflicts resolve quickly

---

### Test 3: Path Efficiency Comparison
**Objective:** Compare paths before and after fix (manual analysis)

**Method:**
1. Run the game and let agents move
2. Copy all console messages showing paths
3. Count the number of nodes in each path
4. Look for patterns:

**Good signs (Fix working):**
- Most yield paths: 1-2 nodes
- No recurring distant nodes (Left_hall_corner, etc.) in yields
- Quick recovery to original paths

**Bad signs (Fix not working):**
- Yield paths: 5+ nodes regularly
- Frequent appearance of distant nodes
- Long pauses between yields and resumption

---

## Advanced Debugging

### If you need to debug further:

**Option 1: Enable Extra Logging**
Edit `MapfManager.gd` line 149 and add:
```gdscript
func _find_yield_target(blocker: Node, blocked_from: Movepoint, blocked_to: Movepoint, requester_remaining: Array[Movepoint]) -> Movepoint:
    var blocker_id := _agent_id(blocker)
    # ... existing code ...
    
    # ADD THIS for debugging:
    print("YIELD: Agent %s choosing from %d candidates (%.0f on path)" % [
        blocker.name,
        distance_from_blocker.size(),
        float(path_node_ids.size())
    ])
    print("  Selected: ", best_node.name if best_node else "NONE", " (on_path=", best_is_on_path, ")")
```

**Option 2: Check Yield Logs**
Look for messages containing:
- `경로 출력` - Path printing messages
- Agent names (RD1, RD2, etc.)
- Node names in brackets

**Option 3: Visual Inspection**
In editor:
1. Select a character node
2. Check `_planned_path` in the debugger
3. Should be short when yielding
4. Should contain expected nodes from the route

---

## Performance Verification

The fix should NOT increase CPU load:
- Extra computation: Dictionary lookup (O(1)) per node checked
- Only happens during yield decisions (not every frame)
- Minimal impact: <1ms per yield calculation

**How to check:**
1. Monitor FPS in game (press `Show_fps` key)
2. FPS should remain stable (60 expected, 30+ acceptable)
3. No stuttering when agents yield

---

## Success Criteria

The fix is successful if ALL of the following are true:

✅ **Criterion 1:** Yield paths are significantly shorter than before
✅ **Criterion 2:** Agents don't make unnecessary detours through distant areas
✅ **Criterion 3:** Agents quickly resume their original paths after yielding
✅ **Criterion 4:** No performance degradation (FPS stable)
✅ **Criterion 5:** Multiple agent interactions work smoothly

---

## Troubleshooting

### Issue: Still seeing long yield paths

**Check:**
1. Did the file actually save? `res://Scripts/Autorun/MapfManager.gd`
2. Is Godot showing any compilation errors?
3. Is the game scene actually running the updated code?

**Solution:**
1. Force reload: Close Godot completely and reopen
2. Check for syntax errors in the file
3. Restart the play session (not just pausing)

### Issue: Agents are stuck/not yielding

**Check:**
1. Is there a valid yield target available?
2. Are movepoint connections properly set up?
3. Is the MAPF manager properly initialized?

**Solution:**
1. Check that all adjacent nodes have `neighbors` properly configured
2. Verify agents have different priority levels
3. Check console for error messages

### Issue: Performance degradation

**Check:**
1. How many agents are active?
2. Is the map very large?
3. Are yield decisions happening too frequently?

**Solution:**
1. Increase `YIELD_COOLDOWN_MS` in MapfManager (currently 1200ms)
2. Increase `YIELD_SEARCH_DEPTH` limit if needed
3. Monitor agent count (system designed for 4 agents max)

---

## Reverting the Change (if needed)

If the fix causes problems, you can revert:

**Step 1:** Open `res://Scripts/Autorun/MapfManager.gd`

**Step 2:** Find the `_find_yield_target` function (line 149)

**Step 3:** Replace the entire function with the original version from git/backup

**Step 4:** Restart Godot

The original logic is simpler and may be more stable for specific edge cases.

---

## Final Confirmation

Once you've verified the fix works:

📝 **You can confirm by these signs:**
1. Console shows short paths when agents yield
2. Visual movement looks smooth and efficient  
3. No agents making strange detours
4. Game performance is unchanged or improved

🎉 **The fix is working correctly!**
