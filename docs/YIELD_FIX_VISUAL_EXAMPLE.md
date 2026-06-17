# Visual Example: Yield Pathfinding Fix

## Before the Fix ❌

Agent RD is walking: Storage_front → Storage_door → Storage → Left_hall_entrance → ...

Player appears and blocks the path at: Left_hall_entrance

### What happened before:
```
Agent's Original Plan:
Storage_front ──→ Storage_door ──→ Storage ──→ Left_hall_entrance (BLOCKED) ──→ ...

YIELD TARGET SELECTION (Old Logic):
- Algorithm: "Find closest node by graph distance (BFS hops)"
- Ignores: The agent's planned path
- Result: Picks Left_hall_corner (happens to be ~6-10 hops away)

Agent's Actual Movement:
Storage_front ──→ Left_hall_mid_low ──→ Left_door ──→ Left_hall_corner
                                                           ↑
                                    UNNECESSARY DETOUR!
                                    (Far away from intended path)

Status: 😞 Agent takes long detour
```

---

## After the Fix ✅

Same scenario as above.

### What happens now:
```
Agent's Original Plan:
Storage_front ──→ Storage_door ──→ Storage ──→ Left_hall_entrance (BLOCKED) ──→ ...

YIELD TARGET SELECTION (New Logic):
- Algorithm: Two-tier priority
  1. Tier 1: Find nodes already on the agent's planned path (PREFERRED)
  2. Tier 2: If none available, pick closest by graph distance
- Result: Picks Storage_door or Storage (already on planned path)

Agent's Actual Movement:
Storage_front ──→ Storage_door  ← WAIT HERE (just move 1 step)
                                   ↓
                              (Player passes)
                                   ↓
                    Storage_door ──→ Storage ──→ Left_hall_entrance ──→ Continue

Status: 😊 Agent waits briefly on its planned path, then continues
```

---

## Key Comparison

| Aspect | Before | After |
|--------|--------|-------|
| **Yield Location** | `Left_hall_corner` (distant) | `Storage_door` (on path) |
| **Detour Distance** | 4+ nodes | 0 nodes |
| **Time to Resume** | Longer (agent at wrong location) | Short (agent stays on track) |
| **Pathfinding Quality** | Poor | Excellent |
| **Natural Feel** | Awkward detour | Smooth pause & resume |

---

## Algorithm Details

### Old Priority Selection
```
For each candidate node:
    distance = BFS_distance_from_blocker_to_candidate
    if distance < best_distance:
        select this candidate
```
**Problem:** Ignores whether node is useful for agent's goal.

### New Priority Selection
```
For each candidate node:
    is_on_agent_path = candidate in planned_path_nodes?
    
    if is_on_agent_path and NOT best_is_on_path:
        # TIER 1: Found a path node, use it!
        select this candidate
    elif is_on_agent_path == best_is_on_path:
        # TIER 2: Same category, pick closest
        if distance < best_distance:
            select this candidate
```

**Benefit:** Nodes on the planned path are always preferred, minimizing deviation.

---

## Test Cases

### Case 1: Yield target available on path ✓
- Agent's path: A → B → C (blocked) → D
- Available on path: B
- **Result:** Yield to B (no deviation)

### Case 2: No nodes on path available
- Agent's path: A → B → C (blocked) → D
- Available on path: None (all blocked)
- **Result:** Pick closest alternative (tier 2)
- **Behavior:** Minimal deviation to nearest open area

### Case 3: Multiple nodes on path available
- Agent's path: A → B → C (blocked) → D
- Available on path: A, B
- **Result:** Pick closest on path (B is closer)
- **Behavior:** Wait as close as possible to destination

---

## Expected Console Output Changes

### Before Fix:
```
[Storage_front, Left_hall_mid_low, Left_door, Left_hall_corner, ...] 경로 출력 RD2
(Long unnecessary path)
```

### After Fix:
```
[Storage_front, Storage_door] 경로 출력 RD2
(Short wait location, then resumes original path)
```

The agent now yields to a nearby position on its planned route, then continues efficiently.
