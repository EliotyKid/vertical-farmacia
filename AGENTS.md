# AGENTS.md

## Project Overview

This repository contains a **3D pharmacy management game vertical slice** made in **Godot Engine**.

The purpose of the project is to validate the core gameplay loop before investing in art, polish, progression, multiplayer, large content systems, or production-ready assets.

The game has two connected layers:

1. **Front of the pharmacy**
   - Receive/buy merchandise.
   - Move boxes and products.
   - Stock shelves.
   - Receive customers.
   - Read customer orders.
   - Pick the requested products.
   - Deliver the order.
   - Receive money.

2. **Back room / laboratory**
   - Store ingredients.
   - Combine ingredients.
   - Use a cauldron and simple machines.
   - Produce homemade medicines and fictional illicit products.
   - Recipes can succeed or fail.
   - Incorrect mixtures can trigger an explosion.
   - Produced items can later be sold or used to satisfy special orders.

All chemical/recipe content in this prototype must remain **fictional and game-like**. Do not implement real-world drug synthesis instructions, realistic chemical processes, real controlled-substance recipes, or actionable chemistry.

---

# Primary Goal

Create a small but complete vertical slice where the player can perform this entire loop:

`move -> interact -> acquire product -> stock shelf -> customer arrives -> customer requests item -> player retrieves item -> delivers item -> receives money -> buys ingredients -> crafts a fictional medicine/product -> handles success or failure`

The vertical slice is successful when this loop is understandable and playable using only placeholder graphics.

---

# Development Philosophy

Prioritize:

1. Gameplay clarity.
2. Fast iteration.
3. Small reusable systems.
4. Loose coupling between gameplay objects.
5. Placeholder assets.
6. Debug visibility.
7. Completing the gameplay loop before adding depth.

Avoid:

- premature optimization;
- large inheritance hierarchies;
- unnecessary abstractions;
- complex UI before gameplay works;
- production art during the prototype;
- large item databases;
- dozens of recipes;
- realistic chemistry;
- multiplayer before the single-player loop is proven;
- procedural systems unless the vertical slice truly needs them.

When choosing between a sophisticated system and a simple system that proves the mechanic, prefer the simple system.

---

# Engine and Technical Constraints

- Engine: **Godot 4.x**
- Language: **GDScript**
- Game type: **3D**
- Initial art: **Godot primitive meshes and placeholders**
- Player: `CharacterBody3D`
- Interactable objects should preferably use composition and groups rather than deep inheritance.
- Use typed GDScript where practical.
- Prefer signals for communication between independent gameplay systems.
- Avoid hard-coded scene paths when a reference can be exported or discovered through groups.
- Use Resources for data that is shared between multiple scenes or instances.
- Keep gameplay data separate from presentation whenever practical.

---

# Prototype Visual Language

Use basic Godot primitives.

Examples:

- Player: capsule.
- Walls: boxes.
- Shelves: boxes.
- Product packages: small boxes.
- Ingredients: colored spheres/cylinders/boxes.
- Customers: capsules with different colors.
- Counter: box.
- Cauldron: cylinder placeholder.
- Machines: box meshes.
- Delivery zone: colored floor area.
- Interaction highlight: outline, material change, icon, or simple label.

Do not block gameplay progress waiting for models, textures, animation, VFX, or final UI.

---

# Recommended Project Structure

```text
res://
├── autoload/
│   ├── game_state.gd
│   └── event_bus.gd
│
├── data/
│   ├── items/
│   ├── recipes/
│   └── customers/
│
├── player/
│   ├── player.tscn
│   ├── player.gd
│   ├── interaction_controller.gd
│   └── carry_controller.gd
│
├── interaction/
│   ├── interactable.gd
│   └── interaction_prompt.tscn
│
├── items/
│   ├── item_data.gd
│   ├── world_item.tscn
│   └── world_item.gd
│
├── pharmacy/
│   ├── shelf.tscn
│   ├── shelf.gd
│   ├── counter.tscn
│   ├── checkout.gd
│   ├── storage.tscn
│   └── supplier_terminal.tscn
│
├── customers/
│   ├── customer.tscn
│   ├── customer.gd
│   ├── customer_spawner.gd
│   └── customer_order.gd
│
├── crafting/
│   ├── crafting_station.gd
│   ├── cauldron.tscn
│   ├── machine.tscn
│   ├── recipe_data.gd
│   └── explosion.tscn
│
├── economy/
│   ├── wallet.gd
│   └── shop_system.gd
│
├── ui/
│   ├── hud.tscn
│   ├── order_ui.tscn
│   ├── interaction_ui.tscn
│   └── shop_ui.tscn
│
├── levels/
│   └── pharmacy_test.tscn
│
└── debug/
	└── debug_overlay.tscn
```

This structure is a recommendation, not a rigid requirement. Keep the project understandable.

---

# Core Architecture

## Interaction System

The player should not contain custom code for every object type.

Prefer a generic interaction flow.

Possible contract:

```gdscript
func can_interact(player) -> bool
func get_interaction_text() -> String
func interact(player) -> void
```

Objects may implement this through a base script, component, group, or duck typing.

The player interaction controller should:

1. cast a ray from the camera;
2. detect an interactable;
3. show the interaction prompt;
4. call the interaction method when the input is pressed.

Do not place shelf, customer, cauldron, door, box, and register behavior directly inside `player.gd`.

---

# Item System

All products and ingredients should share one common item definition.

Recommended `ItemData` Resource fields:

```text
id
display_name
category
buy_price
sell_price
mesh/material placeholder reference
stack_size
tags
```

Suggested categories:

```text
MEDICINE
INGREDIENT
CRAFTED_PRODUCT
MISC
```

Avoid building a large inventory system for the first playable version.

The first vertical slice can use:

- one carried item in the player's hands;
- simple shelf slots;
- simple storage slots.

Only introduce a full inventory/grid/backpack if the gameplay proves it is necessary.

---

# Carry System

The player initially needs to carry only one world object at a time.

Required actions:

- pick up;
- hold;
- drop;
- place on compatible target;
- give to customer;
- insert into crafting station.

A carried item's logical data should remain identifiable through `ItemData`.

Do not make the initial carry system physics-heavy.

It is acceptable to snap the held object to a `Marker3D` in front of the player.

---

# Shelf System

A shelf is a storage/display point.

For the first implementation:

- each shelf has a fixed number of slots;
- each slot can contain one product instance or a simple count;
- placing an item snaps it into a slot;
- customers do not need to physically pick shelf items during the first vertical slice.

The player is responsible for retrieving products.

Later versions may introduce shelf capacity, product facing, visual stacking, restocking boxes, or NPC self-service.

---

# Customer System

Customers should use a small state machine.

Suggested states:

```text
ENTERING
WALKING_TO_COUNTER
WAITING
ORDER_ACTIVE
RECEIVING
LEAVING
FAILED
```

Initial customer behavior:

1. Spawn outside or near the entrance.
2. Walk to the service counter.
3. Generate a request.
4. Display requested item.
5. Wait for the player.
6. Accept or reject the delivered item.
7. Pay if correct.
8. Leave.

The first version only needs one active customer at a time.

Do not implement queues until one-customer gameplay works.

---

# Customer Orders

An order should be data, not UI-only state.

Example:

```text
requested_item
quantity
reward
patience
special_conditions
```

For the first vertical slice:

- quantity may always be `1`;
- patience can be omitted initially;
- one requested product is enough.

Later versions can support:

- multiple items;
- substitutions;
- prescriptions;
- VIP orders;
- suspicious customers;
- illegal/special orders;
- timed requests.

---

# Economy

Start with three values:

```text
player_money
item_buy_price
item_sell_price
```

Minimum loop:

1. player starts with some money;
2. player purchases merchandise or ingredients;
3. money decreases;
4. a customer pays for a valid order;
5. money increases.

Do not create taxes, salaries, rent, loans, demand curves, dynamic pricing, or accounting systems before the basic economy is fun.

---

# Supplier / Purchasing System

The first supplier can be a terminal or simple UI.

The player should be able to:

- open supplier menu;
- buy a small set of products;
- buy a small set of ingredients;
- receive purchased goods.

The first implementation can spawn the purchased item or a delivery box in a designated delivery area.

No delivery truck simulation is required.

---

# Crafting System

Crafting is one of the main differentiators of the game.

The first crafting station should be a **cauldron**.

The system should operate on fictional recipes.

Example conceptual recipe:

```text
Blue Powder + Red Herb -> Focus Syrup
```

Never use real controlled substances, real chemical compounds, real synthesis steps, real temperatures, or real-world production procedures.

Recipe matching should be data-driven.

Recommended `RecipeData` fields:

```text
id
display_name
required_ingredients
output_item
craft_time
failure_chance
station_type
```

For deterministic prototype testing, `failure_chance` may initially be `0` for correct recipes and `1` for invalid combinations.

---

# Crafting Failure

If ingredients do not match a valid recipe, the station should fail.

Initial failure result:

1. play warning feedback;
2. trigger explosion;
3. destroy or eject ingredients;
4. temporarily disable the station;
5. optionally knock the player backward;
6. optionally create a cleanup consequence.

The explosion is a gameplay event and visual effect, not realistic chemistry simulation.

Start simple:

- particle placeholder;
- sound placeholder;
- camera shake;
- Area3D knockback;
- red flash or smoke.

---

# Machine System

Do not create several complex crafting machines immediately.

Implement the cauldron first.

After the cauldron works, a generic crafting-station architecture may support:

```text
CAULDRON
PRESS
MIXER
HEATER
PACKAGING
```

Each station should reuse the same general recipe/data system where possible.

---

# Game State

Keep global state minimal.

Appropriate global state:

- money;
- current day/session state;
- global progression flags;
- shared event bus if needed.

Avoid using autoloads as storage for every gameplay variable.

Shelf contents, current customers, machine state, carried item, and local interactions should remain local to their scenes/systems.

---

# Signals

Prefer signals for events such as:

```text
item_purchased
item_picked_up
item_placed
customer_spawned
order_created
order_completed
order_failed
money_changed
craft_started
craft_completed
craft_failed
explosion_triggered
```

Signals should reduce direct dependencies between UI and gameplay.

Example:

`Customer -> emits order_created -> OrderUI displays order`

instead of:

`Customer -> searches scene tree -> directly edits Label`

---

# Vertical Slice Development Phases

## Phase 0 — Project Foundation

Goal: create a clean test environment.

Implement:

- Godot project.
- Input map.
- Main test scene.
- Graybox pharmacy.
- Front room.
- Counter.
- Back room/lab.
- Shelves.
- Delivery area.
- Placeholder lighting.
- Basic debug overlay.

Definition of done:

The player can open the test scene and clearly recognize the pharmacy front area and back laboratory.

---

## Phase 1 — Player Movement and Camera

Goal: make navigating the pharmacy feel usable.

Implement:

- `CharacterBody3D`.
- WASD movement.
- Mouse look.
- Gravity.
- Collision.
- Optional sprint.
- Basic head/camera structure.

Do not add advanced movement.

No:

- sliding;
- parkour;
- climbing;
- wall running;
- complex animation controller.

Definition of done:

The player can comfortably walk from the storefront to the laboratory without clipping through geometry.

---

## Phase 2 — Generic Interaction System

Goal: create one interaction system reused by the entire game.

Implement:

- camera raycast;
- interact input;
- interaction prompt;
- interactable detection;
- generic interaction contract.

Create test interactables:

- button;
- door;
- dummy object.

Definition of done:

The player can look at different objects and interact with them without object-specific code inside the player.

---

## Phase 3 — World Items and Carrying

Goal: allow the player to physically manipulate products.

Implement:

- `ItemData`;
- world item scene;
- pick up;
- carry;
- drop;
- basic placement.

Create three placeholder items:

```text
Basic Medicine
Red Ingredient
Blue Ingredient
```

Definition of done:

The player can pick up an item, walk around with it, and place/drop it.

---

## Phase 4 — Shelves and Stocking

Goal: establish the pharmacy stocking loop.

Implement:

- shelf slots;
- valid item placement;
- shelf visual state;
- retrieving stocked items.

Definition of done:

The player can take pharmacy merchandise from a delivery/storage area, place it on a shelf, and later retrieve it.

---

## Phase 5 — Purchasing and Money

Goal: give merchandise an economic source.

Implement:

- player wallet;
- starting money;
- supplier terminal;
- minimal buy UI;
- product prices;
- spawning purchased goods in delivery area.

Use only a few products.

Definition of done:

The player can spend money to obtain merchandise and ingredients.

---

## Phase 6 — Customer Prototype

Goal: make the pharmacy have a customer.

Implement:

- customer scene;
- NavigationAgent3D or very simple movement;
- spawn point;
- counter destination;
- customer state machine;
- leaving behavior.

Only one customer is required.

Definition of done:

A customer can enter, approach the counter, wait, and leave.

---

## Phase 7 — Orders and Customer Delivery

Goal: complete the legal pharmacy service loop.

Implement:

- customer order data;
- visible requested item;
- interaction at counter;
- validation of delivered item;
- payment;
- order completion.

Initial order:

```text
1x Basic Medicine
```

Definition of done:

The player can stock medicine, receive a customer request, retrieve the medicine, deliver it, and receive money.

At this point, the first major gameplay loop exists.

---

## Phase 8 — Ingredient Handling

Goal: prepare the back-room crafting gameplay.

Implement:

- ingredient category;
- ingredient storage;
- carrying ingredients into station;
- station input slots/container.

Start with two or three fictional ingredients.

Definition of done:

Ingredients can be bought, transported, and inserted into a crafting station.

---

## Phase 9 — Cauldron and Recipe System

Goal: create the first production mechanic.

Implement:

- cauldron;
- recipe data;
- ingredient matching;
- start crafting interaction;
- craft timer;
- output item.

Initial valid recipe:

```text
Red Ingredient + Blue Ingredient -> Experimental Medicine
```

Names should remain fictional.

Definition of done:

The player can combine the correct ingredients and receive a crafted product.

---

## Phase 10 — Failed Recipe and Explosion

Goal: establish risk and comedy/chaos.

Implement:

- invalid recipe detection;
- failure state;
- explosion event;
- visual placeholder;
- sound placeholder;
- knockback;
- station cooldown/reset.

Definition of done:

A deliberately incorrect mixture causes a clearly readable gameplay explosion and the player can recover and continue playing.

---

## Phase 11 — Crafted Product Integration

Goal: connect the laboratory to the pharmacy loop.

Implement:

- crafted product can be carried;
- crafted product can be stored;
- crafted product can be placed on a shelf or special storage;
- customer can request crafted product.

Definition of done:

A customer order can require an item that the player must manufacture in the back room before delivering it.

This is the most important vertical-slice milestone.

---

## Phase 12 — Complete Session Loop

Goal: create a short playable session.

Example session:

1. Start with limited money.
2. Buy medicine.
3. Stock shelves.
4. Serve customer.
5. Earn money.
6. Buy ingredients.
7. Craft product.
8. Serve special customer.
9. Incorrect mix may explode.
10. Reach money/order target.
11. End session.

Add:

- session goal;
- win state;
- restart;
- basic failure or low-money recovery.

Definition of done:

A new player can play a 5–15 minute session with a clear beginning, middle, and end.

---

## Phase 13 — Feedback and Game Feel

Only begin after the full loop works.

Add inexpensive feedback:

- interaction highlight;
- pickup animation;
- UI sounds;
- order completion sound;
- money popup;
- simple customer reaction;
- crafting progress;
- smoke;
- explosion shake;
- screen flash;
- placeholder particles;
- footsteps;
- object placement sound.

Definition of done:

All important actions have readable visual or audio feedback.

---

## Phase 14 — Balance and Cleanup

Goal: make the vertical slice presentable for testing.

Review:

- walking speed;
- interaction distance;
- shelf placement;
- customer timing;
- product prices;
- recipe time;
- explosion frequency;
- UI clarity;
- softlocks;
- restartability.

Remove:

- unused experiments;
- duplicated scripts;
- unnecessary nodes;
- temporary hacks that create bugs.

Do not turn this phase into a production rewrite.

---

# Minimum Content for the Vertical Slice

Keep content deliberately small.

Recommended content:

```text
2 normal medicines
3 ingredients
2 recipes
1 invalid recipe/failure path
1 cauldron
1 optional secondary machine
2 shelves
1 supplier terminal
1 counter
1 customer archetype
1 special customer/order type
```

A vertical slice with excellent interaction between 10 objects is more valuable than a prototype with 100 incomplete items.

---

# Core Gameplay Loop

The intended loop is:

```text
BUY
  ↓
RECEIVE GOODS
  ↓
STOCK
  ↓
CUSTOMER ARRIVES
  ↓
READ ORDER
  ↓
FIND / CREATE PRODUCT
  ↓
DELIVER
  ↓
GET PAID
  ↓
BUY MORE STOCK / INGREDIENTS
  ↓
CRAFT
  ↓
RISK FAILURE
  ↓
REPEAT
```

Every new mechanic should strengthen this loop.

---

# Scope Guardrails

Do not implement these before the vertical slice is complete:

- multiplayer;
- Steam networking;
- save system beyond a minimal test save;
- character customization;
- employee management;
- police AI;
- combat;
- weapons;
- open world;
- city simulation;
- advanced NPC schedules;
- reputation trees;
- skill trees;
- multiple pharmacy locations;
- dozens of customers;
- advanced procedural generation;
- realistic pharmacy simulation;
- realistic drug production;
- final graphics;
- full controller remapping;
- localization;
- achievements.

Ideas in this list may belong to later milestones, but not to the initial vertical slice.

---

# Coding Standards

Use typed variables when useful.

Prefer:

```gdscript
var current_item: ItemData
var money: int = 100
```

over ambiguous state where types are known.

Use descriptive names.

Prefer:

```gdscript
func complete_customer_order()
```

over:

```gdscript
func do_thing()
```

Keep functions focused.

If a script becomes responsible for unrelated areas, split it into components.

Avoid large manager scripts controlling the entire game.

---

# Scene Design Rules

Each scene should have a clear responsibility.

Examples:

```text
Player
  movement + interaction + carry components

Shelf
  accepts/displays items

Customer
  movement + state + current order

Cauldron
  accepts ingredients + evaluates recipes

SupplierTerminal
  purchase interaction

HUD
  visualizes state only
```

UI should not contain core gameplay authority.

A button may request a purchase, but the economy/shop system should validate whether the purchase is allowed.

---

# Data-Driven Content

Items and recipes should use custom Resources when the first hard-coded prototype is stable.

Recommended classes:

```text
ItemData
RecipeData
CustomerArchetype
```

This lets designers create content without editing gameplay scripts.

Do not over-engineer Resource schemas before at least one working gameplay example exists.

---

# Debugging Requirements

During development, provide easy ways to inspect state.

Useful debug information:

```text
FPS
player money
carried item
looked-at interactable
active customer state
current order
cauldron ingredients
matched recipe
```

Development-only cheat/debug actions are encouraged:

```text
add money
spawn item
spawn customer
reset crafting station
trigger explosion
complete current order
```

These tools must make iteration faster.

---

# Testing Checklist

Every meaningful change should avoid breaking previous gameplay.

Smoke test:

1. Launch pharmacy test scene.
2. Move through front and back rooms.
3. Interact with object.
4. Buy item.
5. Pick up item.
6. Stock shelf.
7. Spawn/receive customer.
8. Read order.
9. Retrieve requested product.
10. Deliver correct product.
11. Confirm money increases.
12. Buy ingredients.
13. Insert ingredients into cauldron.
14. Craft valid recipe.
15. Retrieve result.
16. Test invalid recipe.
17. Confirm explosion/reset.
18. Confirm player can continue playing.

If one of these stops working, fix it before adding new systems.

---

# Definition of Vertical Slice Complete

The vertical slice is complete when a player can enter the game with no explanation and reasonably discover the following:

- how to move;
- how to interact;
- how to buy stock;
- how to carry objects;
- how to place medicine on shelves;
- how to recognize a customer order;
- how to deliver the correct item;
- how money is earned;
- how ingredients are obtained;
- how ingredients are put into the cauldron;
- how a valid fictional recipe creates an item;
- how a wrong combination can explode;
- how a crafted product connects back to customer service.

The prototype does not need final art to be considered complete.

---

# Agent Instructions

When an AI coding agent works on this repository:

1. Read this file before editing code.
2. Preserve the current phase scope.
3. Do not implement future systems unless explicitly requested.
4. Before creating a new system, check whether an existing component can own the responsibility.
5. Prefer a small playable implementation over speculative architecture.
6. Do not replace working systems simply because another architecture is theoretically cleaner.
7. Explain substantial architectural changes before making them when working interactively.
8. Keep Godot scenes and scripts easy to inspect in the editor.
9. Avoid unnecessary third-party addons.
10. Avoid editor plugins during the vertical slice unless they solve a concrete blocker.
11. Never include real-world instructions for manufacturing drugs or hazardous chemical substances.
12. Fictionalize all recipes, ingredients, chemistry, quantities, and processes.
13. Preserve compatibility with Godot 4.x.
14. Do not add final art unless explicitly requested.
15. Use placeholders for new gameplay objects by default.
16. Do not add multiplayer unless explicitly requested.
17. Do not build systems outside the current milestone solely for hypothetical future reuse.
18. After implementing a feature, provide concise manual testing steps.
19. When fixing bugs, identify the root cause instead of hiding the problem with arbitrary delays or magic numbers.
20. Keep gameplay values exposed through exports or data Resources when designers are expected to tune them.

---

# Recommended Implementation Order

The canonical implementation order is:

```text
0. Graybox
1. Movement
2. Interaction
3. Carrying
4. Shelves
5. Economy / purchasing
6. Customer navigation
7. Orders / delivery
8. Ingredients
9. Cauldron
10. Recipe success
11. Recipe failure / explosion
12. Crafted orders
13. Full session loop
14. Feedback
15. Balance / cleanup
```

Do not reorder this substantially without a gameplay reason.

---

# Current Success Metric

The project should always move toward one question:

> Can the player run a pharmacy, serve a customer, go into the back room, manufacture a fictional product, survive a possible failed mixture, and sell the result in one short continuous play session?

If the answer is yes, the vertical slice has proven its core concept.
