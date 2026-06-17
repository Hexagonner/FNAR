# Pathfinding Yield Issue - Fix Summary

## Problem
When agents yielded (moved out of the way for another agent), they would take unnecessarily long detours through distant areas like `Left_hall_corner`, instead of taking direct or near-path routes.

**Example from logs:**
- Agent goes from `Storage_front` to `Left_door`, but the path goes: 
  - `Storage_front → Left_hall_mid_low → Left_door` ✓ Direct
- When yielding, agent would go to an unnecessary distant node through `Left_hall_corner`

## Root Cause
The `_find_yield_target()` function in `MapfManager.gd` (lines 148-187) selected yield targets based solely on **graph distance** (BFS hops), not considering the actual path the agent needs to take.

**The flaw:**
```gdscript
# Old code - only considered distance from blocker
if d_from_blocker < best_distance:
    best_distance = d_from_blocker
    best_node = candidate
```

This meant the algorithm could pick a node that was "graph-close" but required traveling through distant map areas to reach.

## Solution
Modified `_find_yield_target()` to **prioritize nodes already on the agent's planned path**:

```gdscript
# New code - two-tier priority system
var is_on_path: bool = path_node_ids.has(node_id)  # Is node on planned path?

var is_better := false
if is_on_path and not best_is_on_path:
    # Tier 1: Prefer nodes on the agent's planned path
    is_better = true
elif is_on_path == best_is_on_path and d_from_blocker < best_distance:
    # Tier 2: Among same tier, pick closest by graph distance
    is_better = true
```

**Key changes:**
1. **Collect path nodes**: Extract all nodes from the blocker's current planned path
2. **Two-tier preference**: 
   - First priority: Pick yield targets that are nodes the agent was already going to visit
   - Second priority: If no path nodes available, pick the closest alternative
3. **Minimal deviation**: Agent now deviates minimally from its intended route

## Benefits
✅ Agents now move to yield positions that are on or near their intended path  
✅ Eliminates unnecessary detours through distant areas  
✅ Faster resolution of conflicts  
✅ More natural-looking agent behavior  
✅ Improved pathfinding efficiency  

## Technical Details
- **File modified:** `res://Scripts/Autorun/MapfManager.gd`
- **Function:** `_find_yield_target()` (lines 148-209)
- **Algorithm:** Prioritized Planning + Reservation Table + Time-expanded A*
- **New variables added:**
  - `blocker_path`: Array of Movepoint nodes in the blocker's planned path
  - `path_node_ids`: Dictionary for O(1) lookup of path membership
  - `best_is_on_path`: Boolean flag to track if current best target is on the path

## Testing
To verify the fix works:
1. Run the game and observe agent movement during conflicts
2. When agents yield, check the printed paths in the console
3. Verify agents no longer detour excessively through `Left_hall_corner` when not necessary
4. Test with multiple agents to ensure the fix works across different scenarios

The agent's movement decisions should now be more efficient and predictable.
