# Exercise 2 — Preparation Notes (Task Planning & PDDL)

Personal study notes covering the PDDL domain structure and the Task 1.2 answers.

---

## Part A — How to read a PDDL domain file

PDDL uses **Lisp-style syntax**: everything is a list wrapped in `( … )`, and the
**first word inside** tells you what kind of thing the list is. Lists nest inside
lists. Indentation is only for humans — the parser cares only about parentheses.
Lines starting with `;;` are comments.

The reference domain (`tabletop.pddl`):

```lisp
(define (domain tabletop)
  (:requirements :strips :typing)

  (:types item location)

  (:predicates
    (at ?o - item ?l - location)
    (clear ?l - location)
    (holding ?o - item)
    (hand_empty)
  )

  (:action pick
    :parameters (?o - item ?from - location)
    :precondition (and (at ?o ?from) (hand_empty))
    :effect (and
              (not (at ?o ?from))
              (not (hand_empty))
              (holding ?o)
              (clear ?from)))

  (:action place
    :parameters (?o - item ?to - location)
    :precondition (and (holding ?o) (clear ?to))
    :effect (and
              (not (holding ?o))
              (not (clear ?to))
              (at ?o ?to)
              (hand_empty)))
)
```

### 1. Header

```lisp
(define (domain tabletop)
  (:requirements :strips :typing)
```

- `(define (domain tabletop) …)` — declares a domain (the reusable *rules*:
  types, predicates, actions). The specific puzzle lives in a separate *problem*
  file.
- `(:requirements …)` — which PDDL features the file uses, like `import` lines:
  - `:strips` → basic add/delete actions (classic STRIPS subset).
  - `:typing` → typed objects (lets you write `?o - item`).

### 2. Types — categories of objects

```lisp
(:types item location)
```

Every object in a problem is one of these. Types restrict which objects can fill
an action's slots (you can't `pick` a location).

### 3. Predicates — the facts that can be true or false

```lisp
(:predicates
  (at ?o - item ?l - location)
  (clear ?l - location)
  (holding ?o - item)
  (hand_empty)
)
```

The **vocabulary of the world** — every statement that can hold in any state.
Each is a template: `(name ?var - type ?var - type …)`. The `?` marks a
**variable** (a blank filled by a real object later).

| Predicate | Reads as | Arity |
|---|---|---|
| `(at ?o - item ?l - location)` | "item `?o` is at location `?l`" | 2 |
| `(clear ?l - location)` | "location `?l` is empty" | 1 |
| `(holding ?o - item)` | "the gripper holds `?o`" | 1 |
| `(hand_empty)` | "the gripper is free" | 0 |

A **state** = the set of these facts currently true; everything else is assumed
false (closed-world assumption).

### 4. Actions — rules for changing facts

Every action has the same skeleton:

```lisp
(:action NAME
  :parameters   (… the slots …)
  :precondition (… what must be true to do it …)
  :effect       (… what changes afterward …))
```

- **`:parameters`** — the slots; fill them with real objects to get a *ground
  action* (e.g. `?o=cup, ?from=loc_a` → `pick(cup, loc_a)`).
- **`:precondition (and …)`** — all listed facts must hold for the action to be
  allowed.
- **`:effect (and …)`** — how the state changes:
  - a bare fact `(holding ?o)` → **add** it (make true) = *add-effect*
  - a `(not (fact))` → **delete** it (make false) = *delete-effect*

STRIPS update rule: `s' = (s \ del) ∪ add`.

`pick` and `place` are mirror images:

| | `pick` | `place` |
|---|---|---|
| needs | item at location, hand empty | holding item, destination clear |
| adds | `holding`, `clear(from)` | `at(to)`, `hand_empty` |
| deletes | `at(from)`, `hand_empty` | `holding`, `clear(to)` |

### 5. Mental model for reading any domain

1. **What facts exist?** → `(:predicates …)`
2. **What can I do?** → each `(:action …)`
3. **For each action: when (precondition) and what changes (add + delete)?**

A planner chains actions whose preconditions are met, from the initial facts
until all goal facts are true.

---

## Part B — Task 1.2 answers (Domain Analysis)

### Q1 — Arity of each predicate

The arity = number of parameters (the `?` slots) a predicate takes.

| Predicate | Arity |
|---|---|
| `at(?o, ?l)` | 2 |
| `clear(?l)` | 1 |
| `holding(?o)` | 1 |
| `hand_empty` | 0 |

### Q2 — Ground instances with |O| objects and |L| locations

A **ground instance** = the predicate with its variables replaced by concrete
objects. Count = product of the number of type-matching objects for each slot
(empty product = 1 for arity 0).

| Predicate | Count | With \|O\|=3, \|L\|=5 |
|---|---|---|
| `at(?o, ?l)` | \|O\|·\|L\| | 15 |
| `clear(?l)` | \|L\| | 5 |
| `holding(?o)` | \|O\| | 3 |
| `hand_empty` | 1 | 1 |
| **Total** | \|O\|·\|L\| + \|L\| + \|O\| + 1 | **24** |

Rule of thumb: arity tells you how many factors you multiply, so high-arity
predicates grow multiplicatively with the number of objects — the source of the
combinatorial blow-up in planning.

### Q3 — Is `hand_empty` a 0-arity predicate? Why declare it?

Yes. `hand_empty` takes no arguments, so it is a **proposition** (a plain
true/false flag) with exactly **one** ground instance — it is simply in the state
set (gripper free) or not (gripper occupied).

It must still appear in `(:predicates …)` because PDDL requires **every**
predicate symbol to be declared before use, independent of arity; otherwise it
couldn't appear in the `pick`/`place` preconditions, effects, or the problem's
`:init`. It is used as a global "gripper free" flag because STRIPS cannot express
"no object is being held" via quantification — so the flag is maintained by hand:
`pick` deletes `hand_empty` + adds `holding(?o)`; `place` deletes `holding(?o)` +
adds `hand_empty`.

### Q4 — When is a location `clear`?

`clear(?l)` means "location `?l` has no object on it."

- **Initial state:** a fact is true only if explicitly listed in `:init`
  (closed-world assumption). In `tabletop_problem.pddl` only `loc_b` and `loc_d`
  are listed clear — the two empty cells. The occupied locations `loc_a`,
  `loc_c`, `loc_e` are **not** clear.
- **Through actions:** `pick` has add-effect `(clear ?from)`, so lifting an object
  off a location frees it; `place` has delete-effect `(not (clear ?to))`, so
  setting an object down occupies it. `clear` therefore **toggles**: `pick` frees
  a location, `place` occupies one. (That is also why `clear` is a precondition of
  `place` — you can only put an object onto an empty location.)

### Q5 — Full STRIPS operator for `pick(cup, loc_a)`

Ground the lifted `pick` schema with the substitution
`σ = { ?o ↦ cup, ?from ↦ loc_a }`:

- **pre** = { `at(cup, loc_a)`, `hand_empty` }
- **add** = { `holding(cup)`, `clear(loc_a)` }
- **del** = { `at(cup, loc_a)`, `hand_empty` }

(Here `pre = del` — common for "consume" actions: what you require is exactly
what you use up.)

Sanity check — apply `s' = (s \ del) ∪ add` to the initial state
`{ at(cup,loc_a), at(mug,loc_c), at(plate,loc_e), clear(loc_b), clear(loc_d), hand_empty }`:

1. `pre ⊆ s`? Both `at(cup,loc_a)` and `hand_empty` present → applicable.
2. Remove `del`: drop `at(cup,loc_a)`, `hand_empty`.
3. Add `add`: add `holding(cup)`, `clear(loc_a)`.

Result: `{ holding(cup), clear(loc_a), at(mug,loc_c), at(plate,loc_e), clear(loc_b), clear(loc_d) }`
— the cup is in the gripper, `loc_a` is now empty, the hand is no longer free. ✓

---

## Part C — STRIPS in a nutshell

**STRIPS** (Stanford Research Institute Problem Solver, 1971) describes a planning
problem using only **facts that are true/false** and **actions that flip facts**.
A *plan* is a sequence of actions turning the start situation into the goal.
PDDL = STRIPS with nicer syntax, types, and variables.

### The 4 ingredients — P = ⟨F, I, O, G⟩

| Symbol | Name | What it is | Tabletop example |
|---|---|---|---|
| F | Fluents | all possible facts | `at(cup,loc_a)`, `clear(loc_b)`, `hand_empty`, … |
| I | Initial state | facts true at the start | `{at(cup,loc_a), …, hand_empty}` |
| O | Operators | the actions | `pick`, `place` |
| G | Goal | facts that must be true at the end | `{at(cup,loc_c), at(mug,loc_a)}` |

A **state** = the set of facts currently true; anything not listed is false
(closed-world assumption).

### An operator = 3 sets

```
pre(o) — must ALL be true before applying o
add(o) — become true after applying o
del(o) — become false after applying o
```

The two rules that run everything:

1. **Applicability:** apply `o` in state `s` only if `pre(o) ⊆ s`.
2. **Effect (update):** `s' = (s \ del(o)) ∪ add(o)`.

### Modeling workflow (the 5 steps)

1. **Choose fluents** — the minimum facts that fully describe any situation.
2. **Write the initial state I** — list every true fact (unlisted = false).
3. **Write the goal G** — usually partial; only the facts you care about.
4. **Define operators** — for each action ask: when can I do it (pre)? what new
   facts (add)? what destroyed facts (del)? *Common bug: forgetting a
   delete-effect* — every "moved from A to B" needs both an add (at B) and a
   delete (no longer at A), or the object appears to be in two places.
5. **Let a planner search** — it repeatedly checks applicability, applies the
   update, and stops when `G ⊆ s`. (Tasks 2–3 implement this: BFS, then A* with
   h_max.)

### Solver checklist

1. State = which facts are true now?
2. Applicable? = is `pre ⊆ state`?
3. Apply = `(state − del) ∪ add`.
4. Done? = is `goal ⊆ state`? — loop 2–3 until yes.

### STRIPS vs PDDL

| | STRIPS (raw) | PDDL |
|---|---|---|
| Facts | flat ground atoms | typed predicates with variables |
| Actions | one operator per ground action | one lifted schema `pick(?o, ?from)` |
| Bridge | — | **grounding** = substitute objects into schemas (Task 2.2) |

---

## Part D — Task 1.3: Model a New Goal

A **problem** file is one specific instance of a domain. Four parts:

```lisp
(define (problem NAME)        ; name of this instance
  (:domain tabletop)          ; which domain's rules it uses (must match)
  (:objects … )               ; concrete objects, with types
  (:init … )                  ; facts true at the start
  (:goal (and … )))           ; facts that must be true at the end
```

**Task:** keep the same `:objects` and `:init`, and add `(at plate loc_b)` to the
`:goal`. The goal is a conjunction `(and …)` — all listed facts must hold at once,
so we just add a third conjunct.

```python
extended_problem = """
(define (problem tabletop-rearrange-2)
  (:domain tabletop)

  (:objects
    cup mug plate - item
    loc_a loc_b loc_c loc_d loc_e - location
  )

  ;; Same initial layout as tabletop_problem.pddl
  ;;   loc_a: cup   loc_b: (empty)   loc_c: mug   loc_d: (empty)   loc_e: plate
  (:init
    (at cup   loc_a)
    (at mug   loc_c)
    (at plate loc_e)
    (clear loc_b)
    (clear loc_d)
    (hand_empty)
  )

  ;; Goal: swap cup and mug, AND move the plate to loc_b.
  (:goal (and
    (at cup loc_c)
    (at mug loc_a)
    (at plate loc_b)
  ))
)
"""

with open("tabletop_problem_2.pddl", "w") as f:
    f.write(extended_problem)
print(extended_problem)
```

### Verification — the planner solves it in 8 steps

```
1. pick(mug, loc_c)      ┐  park the mug on empty loc_d (a temp spot)
2. place(mug, loc_d)     │  so the cup can take loc_c
3. pick(cup, loc_a)      │
4. place(cup, loc_c)     │  swap needs a temporary because cup and mug
5. pick(mug, loc_d)      │  each want the other's location
6. place(mug, loc_a)     ┘
7. pick(plate, loc_e)    ┐  then move the plate e → b
8. place(plate, loc_b)   ┘
```

**Why a temporary location is needed:** `place` requires `(clear ?to)`, so an item
can't be placed onto an occupied location. Cup wants `loc_c` (mug's spot) and mug
wants `loc_a` (cup's spot), so one must be parked on an empty location (`loc_b` or
`loc_d`) first. That is why the plain swap is 6 steps and the extended version is 8.
