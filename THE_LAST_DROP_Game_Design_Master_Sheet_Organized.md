# THE LAST DROP

## Game Design Master Document

*Pre-development reference · Green Hackathon 2026*

> **A survival adventure in a world buried by its own waste.**

---

## How to use this document

This document brings together the current game direction, narrative, worldbuilding, gameplay systems, chapter concepts, and development priorities. It is intended to give the team one shared reference before implementation.

- **Core direction** describes what the game must preserve.
- **Proposed design** describes mechanics and story elements that can still be adjusted.
- **Optional / provisional ideas** are brainstorms, not established canon.
- **Open questions** require a team decision before or during development.

The document covers the full-game vision, but the recommended hackathon deliverable is a polished vertical slice of Chapter 1: *The Great Dump*.

## Contents

1. [THE GAME IN ONE PAGE](#the-game-in-one-page)
2. [DESIGN PILLARS AND NON-NEGOTIABLE DIRECTION](#design-pillars-and-non-negotiable-direction)
3. [WORLD AND BACKSTORY](#world-and-backstory)
4. [OPTIONAL WORLD EXPANSION: THE FUTURE-EARTH / MARS IDEA](#optional-world-expansion-the-future-earth--mars-idea)
5. [THE MAIN STORY](#the-main-story)
6. [THE PROTAGONIST, FRU-01, AND STORYTELLING](#the-protagonist-fru-01-and-storytelling)
7. [CORE GAMEPLAY SYSTEMS](#core-gameplay-systems)
8. [MOBILE CONTROLS AND USER INTERFACE](#mobile-controls-and-user-interface)
9. [THE FIVE CHAPTERS](#the-five-chapters)
10. [CHAPTER-TO-CHAPTER CONNECTION](#chapter-to-chapter-connection)
11. [EDUCATIONAL DESIGN AND SCIENTIFIC ACCURACY](#educational-design-and-scientific-accuracy)
12. [CHOICES, CONSEQUENCES, AND PLAYER AGENCY](#choices-consequences-and-player-agency)
13. [VISUAL AND AUDIO DIRECTION](#visual-and-audio-direction)
14. [SCOPE: FULL GAME VS. HACKATHON PROTOTYPE](#scope-full-game-vs-hackathon-prototype)
15. [DEVELOPMENT PRINCIPLES AND PRODUCTION NOTES](#development-principles-and-production-notes)
16. [IDEAS DISCUSSED BUT NOT YET CANON](#ideas-discussed-but-not-yet-canon)
17. [OPEN QUESTIONS TO SETTLE BEFORE FULL DEVELOPMENT](#open-questions-to-settle-before-full-development)
18. [FINAL DESIGN NORTH STAR](#final-design-north-star)

---

## 1. The Game in One Page

**TITLE**
**THE LAST DROP**

**TAGLINE**
A survival adventure in a world buried by its own waste.

**GENRE**
2D top-down survival and exploration adventure, environmental education, resource recovery, and narrative mystery.

**PLATFORM AND PRESENTATION**
- Mobile-first game.
- Landscape orientation.
- 2D top-down pixel-art presentation.
- Touchscreen-first controls.
- The game should be easy to understand without requiring prior scientific knowledge.

**THE CENTRAL IDEA**
Humanity has turned waste into its environment. The player explores the remains of a damaged world, recovers useful materials, sorts waste, handles hazardous objects responsibly, repairs abandoned systems, and gradually discovers how the world reached this state.

The player initially appears to be searching for a legendary source of clean water: the Last Drop. The journey gradually reveals that the real problem is much larger than finding water. The world has been damaged by accumulated decisions, neglected waste systems, pollution, overconsumption, and the failure to use solutions that already existed.

The Last Drop is ultimately revealed to be an ecological restoration initiative/facility: a place containing knowledge, research, equipment, and systems that can help communities restore water, soil, and ecosystems. It is not a magical reservoir and cannot instantly heal the planet.

**THE GAME'S MAIN GOAL**
The central gameplay goal is to make responsible waste management and resource recovery necessary to progress. The player must learn to:
- Recognize and classify different kinds of waste.
- Separate reusable/recyclable materials from hazardous waste.
- Recover materials instead of treating every discarded object as useless.
- Reuse, repair, and recycle appropriately.
- Understand that waste handling affects water, soil, health, energy, and ecosystems.
- Make decisions with limited resources and visible consequences.

The game must remain focused on recycling and waste management. Water, soil, food, energy, and ecosystem restoration are connected consequences and applications of that central theme, not unrelated game modes.

**DESIGN PROMISE**
The player does not learn through long lectures or disconnected quizzes. They learn because understanding waste and resource recovery helps solve an immediate problem in the game.

**CORE GAMEPLAY LOOP**
Explore -> Inspect/Scan -> Collect -> Classify and Sort -> Recover/Process -> Reuse/Craft/Repair -> Restore a system -> Discover the environmental principle -> Progress.

**THE PLAYER'S TRANSFORMATION**
At the beginning, the player sees discarded objects mainly as potential resources needed for personal survival. By the end, the player understands that waste is not simply an inconvenience: how a society produces, consumes, discards, sorts, reuses, and treats materials shapes the condition of its environment and the future of its communities.

## 2. Design Pillars And Non-Negotiable Direction

**1. WASTE MANAGEMENT IS THE GAMEPLAY, NOT DECORATION**
Recycling cannot be a small optional minigame inside a generic survival game. Waste identification, sorting, safe handling, recovery, reuse, and repair must drive the main progression.

**2. LEARN BY DOING**
Every important environmental lesson should be embedded in an action, a choice, and a consequence. Explanations should be short and contextual.

**3. RESOURCES HAVE VALUE**
Discarded material can become useful, but not every object is reusable, recyclable, safe, or suitable for every purpose. The player must evaluate materials and their condition.

**4. SYSTEMS ARE CONNECTED**
Recovered materials can repair equipment; restored energy can power a recovery station; organic waste can support composting and soil restoration; responsible hazardous-waste handling can reduce contamination risks. These connections should feel causal rather than like five separate minigames.

**5. STORY SUPPORTS THE GAMEPLAY**
The mystery gives the player a reason to explore, but it must never overshadow the practical experience of waste management and environmental restoration.

**6. CONSEQUENCES WITHOUT PERMANENT DEATH**
The player is not meant to repeatedly die from survival meters. Mistakes can cost time, materials, access, or temporary performance. The player should be able to recover and continue.

**7. NO INSTANT PLANETARY FIX**
Restoration is gradual. The Last Drop is a starting point and a source of knowledge, not a magic solution.

**8. KEEP THE SCOPE CONTROLLED**
The full concept can contain five regions, but a hackathon prototype should demonstrate one polished, complete vertical slice rather than five unfinished chapters.

## 3. World And Backstory

**THE WORLD**
The setting is a dystopian Earth in which waste has become part of the landscape. Abandoned urban areas are buried beneath accumulated plastic, scrap, discarded electronics, and debris. Rivers and drainage systems are contaminated. Soil in some regions is degraded. Infrastructure is failing. Clean water, reliable food production, energy, and safe materials are difficult to access.

The world should be environmentally damaged but believable. It is more credible to portray accumulated waste, abandoned industrial zones, degraded ecosystems, failing infrastructure, regional shortages, and difficult access to resources than to claim that every resource on Earth has literally disappeared or that the entire planet is uniformly covered in rubbish.

**THE COLLAPSE**
There was no single event that destroyed the world. The collapse developed over decades through interconnected decisions:
- Production and consumption continued to increase.
- Cheap production and convenience were repeatedly prioritized.
- Waste-management and recycling systems were neglected or underfunded.
- Hazardous waste was mishandled.
- Pollution accumulated in water and soil.
- Environmental policies and maintenance were postponed.
- Repair and reuse lost ground to replacement and disposal.
- Institutions and individuals repeatedly expected someone else to solve the problem.

**THE FIRST MAJOR REVELATION**
Humanity did not lose the world because no solutions existed. It lost the world because it repeatedly failed to use, maintain, and share them.

This is not a story about one evil person or one villainous machine. Industries, institutions, governments, communities, and individuals all contributed in different ways. The story should avoid reducing a complex environmental collapse to a single villain.

**THE PROTAGONIST'S STARTING POINT**
The player controls a survivor from an isolated settlement. The settlement's resources and infrastructure are under pressure. Its water filtration system is failing or running low, and the community has only a limited reserve of usable water.

The protagonist hears a weak transmission or old emergency signal referring to the “Last Drop”, believed to be a source of clean water or a way to restore access to it. The protagonist leaves the settlement to investigate.

The player initially understands the journey as a search for water. The wider purpose is revealed gradually through places, objects, recordings, records, and the systems the player restores.

**THE SETTLEMENT**
The settlement is the player's emotional anchor and gives the journey an immediate purpose. It should feel small and relatively stable compared with the wider abandoned world, but dependent on limited supplies and fragile infrastructure.

The settlement can be revisited or referenced between chapters. Its condition may reflect the player's progress, but the game should not require a large settlement-building simulator.

**THE FIVE SURVIVAL SYSTEMS**
The submitted concept named five connected systems:
- WATER: access to usable water and functioning treatment systems.
- FOOD: food production and organic-waste recovery, including composting.
- SHELTER: repairing or reinforcing structures with suitable recovered materials.
- ENERGY: restoring and managing power for essential systems.
- HEALTH: recognizing hazards and avoiding unsafe exposure.

These are connected applications of the environmental theme. They should not become five independent simulation systems. The most important system for the game's identity remains waste management and material recovery.

## 4. Optional World Expansion: The Future-Earth / Mars Idea

This was brainstormed as a possible deeper science-fiction layer. It is NOT yet mandatory canon.

**POSSIBLE REVEAL**
The story could take place around the year 3026. Humanity gradually established settlements on Mars and other off-world locations. Migration happened over generations rather than in one sudden evacuation:
- Early space expansion was presented as opportunity and progress.
- Wealthier and specialized populations migrated first.
- Investment and maintenance on Earth gradually declined.
- More people left as infrastructure and environmental conditions worsened.
- Some communities remained on Earth, believing that abandoning the planet was not the same as solving the problem.

**POSSIBLE PEOPLE WHO STAYED**
Those who remained need not be a formal army, elite resistance, or group of scientists. They could be ordinary families, farmers, workers, teachers, and communities attached to Earth and convinced that it was still worth restoring.

**POSSIBLE SANCTUARY HISTORY**
The Last Sanctuary may have been built or maintained collectively across generations by people who stayed. It preserved records, knowledge, seeds, restoration research, and practical methods.

**POSSIBLE THEMATIC QUESTION**
Did humanity learn from its mistakes, or did it simply find another planet on which to repeat them?

**IMPORTANT LIMITS**
- Do not make the Mars idea the main plot if it distracts from recycling and waste management.
- Do not portray every person who migrated as evil. Some may have believed migration was necessary to preserve humanity.
- If the story uses a date around 3026, the long time gap can explain why the protagonist has incomplete knowledge of the old world.
- The exact date, the fate of Mars, and the protagonist's connection to the people who stayed remain OPEN.
- A plausible version is that Earth contains fragmented communities, some relatively stable settlements, and large abandoned or unexplored regions.

## 5. The Main Story

### Act I — The Signal

The protagonist lives in an isolated settlement whose water system is failing. A weak signal refers to the Last Drop. The protagonist leaves with limited equipment and eventually reaches an abandoned municipal recovery centre in a vast waste site.

The player finds an old field device, FRU-01, once used by an environmental maintenance worker. The device is damaged, its storage is corrupted, and some functions are unavailable.

The first area teaches the player that discarded materials are not all the same. Some can be recovered; some require processing; some must be separated and handled through a special route.

### Act Ii — The World's Systems

As the player follows the signal, they explore five regions:
**1. The Great Dump — waste management and material recovery.**
**2. The Dead River — water pollution and treatment.**
**3. The Silent Fields — soil degradation, organic waste, composting, and food.**
**4. The Forgotten Industry — industrial waste, hazardous materials, repair, and resource recovery.**
**5. The Last Sanctuary — the truth behind the collapse and the Last Drop.**

Each region contains a practical environmental challenge and fragments of the past. The player restores systems, learns how failures are connected, and progressively unlocks more of FRU-01.

### Act Iii — The Truth

At the Last Sanctuary, the player discovers two connected truths.

**REVELATION ONE: THERE WAS NO SINGLE CATASTROPHE**
The world deteriorated through years of choices and neglect. The solutions existed, but they were repeatedly ignored, underfunded, or not maintained.

**REVELATION TWO: THE LAST DROP IS NOT A MAGICAL WATER SOURCE**
The Last Drop is the name associated with an ecological restoration initiative/facility. It contains research, equipment, records, and knowledge intended to help restore water systems, regenerate soil, and support ecosystem recovery.

The facility does not reverse a thousand years of damage. It provides a starting point. It needs maintenance, appropriate resources, local knowledge, long-term work, and cooperation.

**THE FINAL CHOICE**
The protagonist must decide what to do with the discovery:
- PRESERVE THE DISCOVERY: keep the facility and its knowledge for the protagonist's own settlement. This may offer more immediate protection but leaves the wider world fragmented.
- SHARE THE KNOWLEDGE: transmit the findings and invite other communities to cooperate. This creates the possibility of wider restoration but introduces uncertainty, disagreement, and the risk of misuse.

The final outcome can also reflect the player's previous actions: responsible resource use, help given to communities, and environmental systems restored.

**POSSIBLE ENDING TIERS**
- A SAFE HAVEN: the discovery is kept for the protagonist's settlement.
- A NEW BEGINNING: knowledge is shared more widely.
- THE NETWORK REBORN: a stronger collective outcome if the player has restored key regional systems and helped connect communities.

These are proposed ending labels and can be revised. The moral choice should not be presented as a simplistic “selfish bad / sharing good” button. Protecting a vulnerable settlement has understandable short-term reasons; sharing knowledge carries real uncertainty.

**FINAL MESSAGE**
“The world wasn't destroyed in a single day. And it won't be rebuilt in one either.”

## 6. The Protagonist, FRU-01, And Storytelling

**THE PROTAGONIST**
The protagonist is currently an unnamed survivor. Giving the protagonist a name, identity, and personal history was discussed, but no final name or backstory was chosen.

Recommended narrative direction:
- Keep the protagonist's identity understandable and relatable.
- Reveal their past gradually through small details if it serves the story.
- Do not let a complicated ancestry mystery displace the environmental plot.
- The player should be able to inhabit the character without needing a long exposition sequence.

**FRU-01 — FIELD RECOVERY UNIT 01**
FRU-01 is the protagonist's most important tool and recurring companion. It was formerly used by a municipal/environmental maintenance worker.

Its role:
- Identify and classify materials.
- Inspect objects and report their condition.
- Flag known hazards and uncertainty.
- Suggest appropriate recovery routes.
- Access old facility records and archived information.
- Record field observations and discoveries.
- Locate relevant stations or objectives.
- Communicate with restored recovery/maintenance systems.

**FRU-01 SHOULD NOT SOLVE EVERYTHING**
It should provide clues, classifications, warnings, and partial information. The player still needs to inspect the environment, compare evidence, choose a solution, and perform the task.

**FRU-01 PERSONALITY**
A subtle personality was discussed as an option: precise, dry, curious, and occasionally expressive. It should not become a comic sidekick that breaks the atmosphere. Its personality can emerge through short remarks and gradually recovered records.

**FRU-01 MYSTERY**
Possible questions:
- Why did this unit remain operational?
- Who was its former owner?
- What information was deleted or corrupted?
- Why does it have access to the signal network?

These are optional narrative threads. They should support the main plot rather than create a second unrelated mystery.

**PROGRESSIVE DEVICE FUNCTIONS**
- Early: basic material identification and simple records.
- Later: contamination indicators, recovery potential, and more detailed analysis.
- Later still: industrial records, ecosystem monitoring, restoration planning, and network access.

**STORYTELLING METHODS**
- Environmental storytelling: the state of a place tells the story of what happened there.
- Short recordings and archived messages.
- Maintenance logs, labels, warning signs, production records, and personal objects.
- Selective protagonist monologues.
- A small number of side characters or community voices where they add meaning.

The first chapter should largely preserve solitude so the player can learn the world and establish a relationship with FRU-01. Side characters can appear later if they serve a specific purpose.

**EASTER EGGS**
Optional discoveries may reward attentive players:
- Objects from our present-day world, such as a plastic bottle with a 2026 date.
- Historical or scientific references.
- Small gaming references.
- Hidden recordings or environmental details.
- Harmless references to the development team.

Easter eggs must remain optional, subtle, and secondary. They must not interrupt the main mission or turn the game into a collection of unrelated jokes.

## 7. Core Gameplay Systems

### 7.1 Exploration

The player explores compact, readable top-down areas. Important objects are visible in the environment. Exploration should reward observation without requiring pixel-perfect searching.

Possible interactable objects:
- Discarded materials.
- Sorting containers.
- Damaged machines.
- Workbenches and processing stations.
- Electrical panels and relays.
- Records, signs, terminals, and recordings.
- Hazardous objects and restricted areas.

### 7.2 Inspection And Scanning

The player uses FRU-01 to inspect nearby objects. Scanning should be quick and mobile-friendly.

Proposed flow:
**1. The player approaches an object.**
**2. The nearby object can be highlighted or indicated.**
**3. The player taps Scan.**
**4. FRU-01 displays a concise result: material/type, condition, hazard warning if known, and possible next step.**
**5. The player decides what to do.**

Scanning should not automatically collect the object or complete the puzzle.

### 7.3 Collection

The player collects suitable objects and adds them to inventory.

Interaction direction:
- Use proximity prompts and a contextual Action button.
- Common, harmless small objects may optionally be collected automatically when the player walks close enough, but the default direction is clear player control.
- Hazardous, large, or special objects should require an explicit interaction.
- Avoid precision dragging or tiny tap targets.

### 7.4 Inventory

A simple grid-based inventory inspired by familiar survival/crafting games was discussed.

Suggested categories:
- Raw waste/materials.
- Recovered/processed materials.
- Equipment and tools.
- Special mission objects.

Design rules:
- Stack common resources.
- Keep carrying capacity limited enough to make choices meaningful, but not frustrating.
- Make item names and icons clear.
- Distinguish raw material from processed/recovered material.
- Do not create a huge inventory-management simulation.

### 7.5 Waste Classification And Sorting

This is one of the game's defining systems.

Potential categories:
- Metals: iron/steel, aluminium, copper.
- Plastics.
- Glass.
- Paper/cardboard.
- Organic waste.
- Electronic waste.
- Batteries and other hazardous/special waste.
- Contaminated or mixed waste that needs further handling.

The player must learn that different categories have different routes. Batteries and electronic waste must not be casually placed in ordinary waste. Contamination and condition affect whether a material can be recovered.

Sorting should include feedback:
- Correct route: safe handling and appropriate recovery progress.
- Incorrect route: contamination, lost time, blocked processing, or a clear explanation.
- Leaving hazardous waste untreated may leave a problem unresolved.

Do not teach that every item can be recycled everywhere. Actual recycling routes vary by material, contamination, and available infrastructure.

### 7.6 Processing And Material Recovery

Raw waste is not always directly usable. The player may need to use a dedicated station to sort, clean, dismantle, or process material.

Potential stations:
- Sorting/recovery station.
- Metal recovery station.
- Plastic processing station.
- Electronic component recovery station.
- Composting area for suitable organic waste.

For the first playable version, implement only the stations needed to demonstrate the loop. Do not attempt a full industrial simulation.

### 7.7 Crafting, Repair, And Reuse

Crafting should be simpler than Minecraft. The player should not need dozens of recipes or craft anywhere.

Direction:
- Crafting/assembly happens at designated workbenches.
- Repairs happen at the relevant machine or object.
- Recipes use a small number of meaningful recovered materials.
- The game distinguishes repair, reuse, dismantling, and recycling.

Possible recipe/use examples (provisional and subject to technical/scientific review):
- Recovered copper or suitable wiring to repair an electrical connection.
- Recovered metal to reinforce a damaged structure.
- Suitable electronic components to repair FRU-01's antenna or relay.
- Appropriate recovered materials to repair a machine housing.
- A basic water-filter task using suitable filter media, where the science and limitations are explained correctly.

Do not imply that any random plastic, charcoal, cloth, or scrap can make unsafe water drinkable. Treatment recipes must be scientifically checked.

### 7.8 Repair Versus Dismantle

A recurring decision:
- REPAIR/REUSE: preserve an object or machine and regain its function.
- DISMANTLE: sacrifice the object to recover components or raw materials.

This creates meaningful resource decisions. A working machine may be more valuable operationally than the materials obtained by dismantling it. Conversely, a machine beyond repair may be a useful source of components.

Do not make one choice always correct. The best choice depends on the player's immediate objective and available alternatives.

### 7.9 Limited Resources And Priorities

Materials, energy, and time are limited. The player must decide where to spend them.

Examples:
- Use recovered copper to repair a relay or another essential machine.
- Restore power to a recovery station or a water pump first.
- Keep a useful machine running or dismantle it for parts.
- Spend time processing a material now or explore for a better source.

Avoid soft-locks: essential progression should not become permanently impossible because the player used one item incorrectly. Provide alternative routes, recoverable materials, or a way to undo non-critical mistakes.

### 7.10 Difficulty And Pressure

Difficulty should increase through complexity, not arbitrary punishment.

Three dimensions:
- RESOURCE PRESSURE: fewer materials, limited energy, carrying capacity, or competing uses.
- ENVIRONMENTAL PRESSURE: damaged infrastructure, unstable machinery, contaminated zones, or weather-related constraints.
- DECISION PRESSURE: choosing between two useful objectives or deciding whether to repair, dismantle, or reserve materials.

Time pressure can be used selectively:
- A machine may overheat or operate for a limited time.
- A temporary power reserve may run down.
- A storm or environmental event may create a deadline.
- A task may need to be completed before a system shuts down.

Do not put a timer on every task. Pressure should be understandable and fair.

### 7.11 Consequences Without Permanent Death

No permanent player death and no conventional health-bar survival loop are required by the current design direction.

Mistakes can cause:
- Lost time.
- Wasted or contaminated materials.
- Temporary loss of access to a machine or route.
- Reduced efficiency.
- Temporary equipment malfunction.
- Mild temporary condition effects after unsafe exposure.

The player should recover through appropriate actions, rest, protective equipment, or treatment where relevant. Do not make every contact with a contaminated object cause instant sickness. Different hazards have different risks, and the game should avoid misleading medical claims.

### 7.12 Progression And Rewards

Progression comes from:
- Unlocking new areas and stations.
- Recovering new FRU-01 functions.
- Learning new material categories and processes.
- Restoring infrastructure.
- Discovering story records.
- Making decisions that change access, resources, or the ending.

Rewards should reinforce the theme: a recovered facility, safer environment, functioning system, new knowledge, or a community connection.

## 8. Mobile Controls And User Interface

**PLATFORM DIRECTION**
Mobile-first, landscape orientation, 2D top-down.

**PROPOSED EXPLORATION HUD**
- LEFT: virtual joystick for movement.
- RIGHT: contextual Action button.
- SCAN: dedicated FRU-01 scan button.
- SMALL TOP-AREA ICONS: Inventory and FRU-01/device interface.
- PROXIMITY PROMPT: a short label such as COLLECT, OPEN, INSPECT, REPAIR, or TALK when relevant.

**CONTEXTUAL ACTION**
One Action button changes meaning based on the nearby object. This avoids filling the screen with many permanent controls.

Examples:
- Near loose scrap: COLLECT.
- Near a container: OPEN.
- Near a machine: INSPECT or REPAIR.
- Near a character: TALK.
- Near a terminal: ACTIVATE.

**FRU-01 INTERFACE**
Opening FRU-01 can expose tabs or panels:
- OBJECTIVES: current tasks.
- INVENTORY: collected materials and equipment.
- FIELD NOTES: discoveries and environmental explanations.
- SIGNAL/NETWORK: communication status and recovered signals.

**SCANNING**
A tap-based nearby-object selection is preferred over precise touchscreen aiming:
**1. Tap Scan.**
**2. The nearest suitable object is highlighted.**
**3. Tap Scan again or confirm to inspect it.**
The exact interaction can be simplified after testing, but it must work comfortably on a phone.

**INVENTORY SCREEN**
- Grid layout.
- Clear icons and names.
- Stack counts.
- Category separation.
- Clear indication of raw versus recovered material.
- Item details with relevant use or hazard information.

**PROCESSING SCREEN**
A simple station interface should show:
- What material is being processed.
- What the station accepts.
- What output is expected.
- Whether the input is contaminated or unsuitable.
- A clear confirmation before consuming rare resources.

**CRAFTING/REPAIR SCREEN**
Show the target object, required materials, available quantities, and the result. Avoid hidden recipes that make the player guess without clues.

**UI PRINCIPLES**
- Large touch targets.
- Minimal permanent buttons.
- Readable text on a phone.
- Clear visual feedback.
- No precision dragging as a required action.
- Do not hide essential information behind many menus.

## 9. The Five Chapters

### Chapter 1 — The Great Dump

Theme: waste management, sorting, reuse, recycling, hazardous waste, and material recovery.

**SETTING**
The remains of a megacity and an abandoned municipal recovery centre, buried among plastic, metal, discarded electronics, and mixed waste.

**STORY SETUP**
The settlement's water filters are nearly exhausted. A weak emergency transmission points toward an old municipal recovery network and the rumoured Last Drop. The protagonist reaches the landfill/recovery centre and discovers FRU-01, a damaged Field Recovery Unit.

**POSSIBLE ZONES**
**1. Settlement exit / approach.**
**2. Outer dump.**
**3. Sorting and recovery centre.**
**4. Maintenance and communication centre.**

**MISSIONS**
**A. THE SIGNAL**
- Establish the settlement's resource pressure.
- Receive the weak transmission.
- Leave to investigate the signal.

**B. NOTHING IS REALLY USELESS**
- Discover and scan objects such as a plastic bottle, aluminium can, cardboard, metal scrap, and electronic waste.
- Learn that objects have different material types and recovery routes.
- Collect suitable materials.
- Use recovered metal or another appropriate component to open/repair a blocked route.

**C. SORTING CHALLENGE**
- Sort a set of mixed waste into appropriate categories.
- Show how incorrect sorting can contaminate a batch or prevent recovery.
- Explain the difference between reuse, recycling, and recovery in context.

**D. DANGEROUS DISCOVERY**
- Find a damaged battery or electronic waste.
- FRU-01 warns that it requires special handling.
- The player places it in a designated hazardous-waste collection point rather than an ordinary waste pile.
- Explain why batteries and e-waste should be separated and appropriately collected.

**E. REPAIR THE SIGNAL**
- Recover suitable components.
- Repair FRU-01 or a relay/communication unit.
- Restore the signal and reveal the next destination: the water-treatment station in Sector 02.

**LEARNING OUTCOMES**
- Waste does not simply disappear when discarded.
- Some waste contains recoverable materials.
- Reuse, repair, recycling, and recovery are related but different.
- Sorting matters because contamination can reduce recovery.
- Batteries and electronic waste require special collection and handling.
- Repair and reuse can reduce the need for new materials.

**CHAPTER 1 PROTOTYPE PRIORITY**
This chapter is the recommended hackathon vertical slice. It should demonstrate:
- A compact settlement/landfill environment.
- Mobile character movement.
- Proximity-based interaction.
- FRU-01 scanning.
- A small inventory.
- A handful of collectible waste types.
- One sorting challenge.
- One hazardous-waste interaction.
- One processing/recovery or repair task.
- A short narrative reveal and signal transition.

The prototype does not need the entire chapter at full length. A polished sequence proving the core loop is more valuable.

### Chapter 2 — The Dead River

Theme: water pollution, contamination indicators, treatment, and responsible water use.

**SETTING**
A polluted river system and an abandoned water-treatment facility.

**POSSIBLE ZONES**
**1. River entrance.**
**2. Abandoned village.**
**3. Industrial drainage area.**
**4. Water-treatment station.**

**FRU-01 EXPANSION**
- Water sample records.
- pH, turbidity, and conductivity indicators.
- Treatment-station diagnostics.
- Historical pollution records.

**MISSIONS**
**A. RIVER SAMPLES**
- Collect samples from different locations.
- Compare indicators.
- Example illustrative values discussed: a river sample around pH 7.2 with high turbidity; a suspected industrial drainage sample around pH 4.8 with high conductivity.
- These values are illustrative game data, not universal real-world thresholds.

**B. TRACE THE SOURCE**
- Follow drainage paths and compare samples.
- Identify likely contamination sources using multiple clues.
- Avoid pretending that one measurement identifies a specific pollutant.

**C. DIAGNOSE THE TREATMENT STATION**
- Inspect damaged treatment stages and records.
- Identify missing or malfunctioning equipment.
- Recover appropriate materials/components to restore the system.

**D. RESTORE THE TREATMENT SEQUENCE**
- Teach the purpose and order of appropriate stages, such as screening, sedimentation, filtration, disinfection, and monitoring.
- The player must restore or configure the station rather than press one magic “clean water” button.

**E. FINAL QUALITY CHECK**
- Test the treated water.
- Discover that one indicator remains problematic and that an additional suitable treatment stage may be required.
- Activated carbon was discussed as a possible stage for certain dissolved organic contaminants, not a universal solution.

**LEARNING OUTCOMES**
- Water can look clear and still be unsafe.
- pH, turbidity, and conductivity provide different information.
- Conductivity indicates dissolved ions but does not identify the pollutant.
- Treatment depends on the type of contamination.
- Treatment systems need multiple stages and monitoring.
- No single filter removes every contaminant.

**SCIENTIFIC CAUTION**
pH, turbidity, and conductivity are indicators, not complete drinking-water safety tests. Do not claim that these three measurements alone certify water as safe.

### Chapter 3 — The Silent Fields

Theme: soil degradation, organic-waste recovery, composting, and sustainable food production.

**SETTING**
Abandoned farmland, a neglected village, an organic-waste facility, a research station, and a damaged greenhouse.

**FRU-01 EXPANSION**
- Soil sample records.
- Moisture, pH, conductivity, and organic-matter estimates.
- Growth monitoring and restoration notes.

**MISSIONS**
**A. COMPARE SOIL SAMPLES**
- Compare different areas with different moisture, pH, salinity/conductivity, and organic-matter conditions.
- Example illustrative pH values discussed: 7.4, 8.6, and 6.8. These are scenario values, not universal diagnoses.

B. RECONSTRUCT THE LAND'S HISTORY
- Use field records, abandoned equipment, and environmental clues to understand how the land was used and degraded.

**C. SORT ORGANIC WASTE**
- Separate suitable compostable organic material from unsuitable or contaminated waste.
- Show that not every discarded material belongs in compost.

**D. RESTORE THE COMPOSTING SYSTEM**
- Balance suitable carbon-rich and nitrogen-rich inputs.
- Manage moisture and aeration.
- Explain that composting takes time; the game may use a time skip, but should not imply instant maturation.

**E. RESTORE THE GREENHOUSE**
- Diagnose soil limitations rather than adding random fertilizer.
- Improve the growing medium with suitable mature compost and appropriate management.
- Allocate limited irrigation.
- Select crops suited to the local conditions.
- Achieve a small first harvest, not instant agricultural abundance.

**LEARNING OUTCOMES**
- Soil health depends on more than one measurement.
- Organic waste can become a resource when properly managed.
- Composting needs suitable inputs, moisture, aeration, and time.
- Excess additions are not automatically beneficial.
- Salinity, drainage, compaction, and low organic matter require different responses.
- Sustainable food production depends on healthy soil and responsible resource use.

**SCIENTIFIC CAUTION**
pH and conductivity alone do not fully diagnose soil fertility or safety. Adding water to saline soil may worsen problems if drainage and water quality are not considered.

### Chapter 4 — The Forgotten Industry

Theme: industrial waste, hazardous materials, repair culture, resource recovery, and energy efficiency.

**SETTING**
An abandoned industrial complex with production halls, hazardous-waste storage, a recovery centre, and an energy-control area.

**FRU-01 EXPANSION**
- Material-condition analysis.
- Hazard warnings.
- Industrial maintenance records.
- Energy monitoring and facility logs.

**MISSIONS**
**A. RESTORE ACCESS**
- Repair an entrance terminal or access mechanism using suitable recovered components.

**B. REPAIR OR REPLACE**
- Inspect a damaged machine.
- Decide whether to repair a failed controller or worn belt while preserving a functioning motor, rather than automatically replacing the entire machine.
- Show the value of maintenance and repair.

**C. HAZARDOUS WASTE**
- Identify hazardous storage and warning signs.
- Separate known waste streams and isolate an unsafe area.
- Do not ask the player to handle unknown chemicals casually. The correct action may be to secure the area and use an appropriate specialist procedure.

**D. MATERIAL RECOVERY**
- Distinguish recoverable steel, aluminium, copper, and electronic components from contaminated materials and residues.
- Process only what the facility can safely handle.

**E. ENERGY PRIORITY**
- Restore a limited power supply.
- Decide whether to prioritize hazard monitoring, ventilation, recovery machinery, or another essential system.
- The player must understand that energy is limited and priorities have consequences.

**F. THE INDUSTRIAL RECORD**
- Discover records showing a culture of replacement over repair, underfunded recovery systems, and hazardous-waste capacity being exceeded.
- The records should reveal systemic failure, not just a single villain.

**LEARNING OUTCOMES**
- Production is not inherently bad; design, maintenance, material use, and waste treatment matter.
- Repair and reuse can preserve valuable components.
- Industrial waste may require specialized treatment.
- Not every material is directly recoverable.
- Contamination changes what can safely be processed.
- Energy efficiency and prioritization affect environmental systems.

### Chapter 5 — The Last Sanctuary

Theme: ecological restoration, biodiversity, cooperation, and the final truth.

**SETTING**
A forgotten research/restoration complex containing archives, a seed/biodiversity vault, restoration laboratories, and a central network facility.

**FRU-01 EXPANSION**
- Ecosystem monitoring.
- Restoration planning.
- Access to the final archive.
- Network communication and coordination.

**MISSIONS**
**A. ENTER THE SANCTUARY**
- Repair access systems and recover records.

**B. RECONSTRUCT THE COLLAPSE**
- Connect evidence from the earlier regions.
- Discover that the collapse was gradual and preventable.

**C. RESTORE THE ARCHIVE / SEED VAULT**
- Recover and protect relevant records, seeds, or biodiversity resources.
- Avoid portraying seeds as a magic instant forest.

**D. PLAN RESTORATION**
- Choose locally suitable/native species for different conditions, such as dry exposed land, degraded farmland, and seasonal riverbanks.
- Match restoration actions to local conditions and long-term monitoring.

**E. CONNECT THE REGIONAL SYSTEMS**
- Integrate lessons and infrastructure from waste recovery, water treatment, soil restoration, and industrial recovery.
- Restore the network in stages, with limited energy and resources.

**F. DISCOVER THE LAST DROP**
- Reveal that it is an ecological restoration initiative/facility, not a magical source of water.
- The facility contains knowledge and tools, but requires people to maintain and apply them.

**G. FINAL DECISION**
- Preserve the discovery for the protagonist's settlement or share the knowledge with other communities.
- Earlier actions may influence the outcome.

**LEARNING OUTCOMES**
- Biodiversity contributes to ecosystem resilience.
- Restoration must use locally suitable species and conditions.
- Ecosystems recover over time and need monitoring.
- Cooperation and knowledge-sharing matter.
- Environmental recovery is a long-term process.

## 10. Chapter-To-Chapter Connection

The five chapters should feel like parts of one connected recovery journey, not unrelated educational levels.

**THE GREAT DUMP -> THE DEAD RIVER**
Waste and hazardous materials are connected to pollution pathways. The restored communication network reveals the next water-treatment location.

**THE DEAD RIVER -> THE SILENT FIELDS**
Water quality and treatment affect the possibility of restoring agriculture and soil.

**THE SILENT FIELDS -> THE FORGOTTEN INDUSTRY**
Organic-waste recovery and food production reveal the need to restore industrial systems and recover appropriate materials and energy.

**THE FORGOTTEN INDUSTRY -> THE LAST SANCTUARY**
Industrial records and restored network infrastructure lead to the final archive and restoration initiative.

**THE LAST SANCTUARY**
The player sees how waste management, water, soil, energy, and ecosystems interact. The conclusion returns to the central theme: a society's material choices and waste systems shape the world it leaves behind.

## 11. Educational Design And Scientific Accuracy

**THE LEARNING LOOP**
**1. ENCOUNTER: the player faces a practical environmental problem.**
**2. EXPERIMENT: the player inspects, sorts, tests, or chooses a solution.**
**3. CONSEQUENCE: the game shows what the choice changes.**
**4. PRINCIPLE: FRU-01 or the environment provides a short explanation.**
**5. REAL-WORLD CONNECTION: a concise practical note explains why the lesson matters outside the game.**

**EXAMPLE: BATTERY DISCOVERY**
- Encounter scattered batteries.
- Scan and identify them.
- Wrong choice: put them into ordinary waste. The game shows an unsafe/incorrect route and explains the risk.
- No solution: leave them where they are; the hazard remains and the objective cannot be completed.
- Responsible choice: use the designated hazardous-waste collection route.
- Learning: batteries should be kept separate from ordinary waste and handled through appropriate collection and treatment.

**GENERAL RULES**
- Teach practical distinctions, not slogans.
- Do not say all waste is recyclable.
- Do not imply recycling alone solves pollution, climate change, or water scarcity.
- Show that reducing consumption, reusing, repairing, sorting, recycling, and safe treatment are complementary.
- Make clear that contaminated materials may need special handling.
- Scientific claims and recipes should be reviewed before being encoded into gameplay.
- Keep explanations short and tied to what the player just did.

## 12. Choices, Consequences, And Player Agency

The player should make meaningful choices, not merely follow highlighted instructions.

**CHOICE TYPES**
- Which material to recover first.
- Which system receives scarce energy.
- Whether to repair or dismantle a machine.
- Whether to spend time sorting a contaminated batch.
- Whether to secure a hazardous area or take a risky shortcut.
- Which community or facility to help.
- Whether to preserve or share the final discovery.

**CONSEQUENCE TYPES**
- Time cost.
- Resource cost.
- Temporary access restrictions.
- Different available routes.
- A machine or station becoming temporarily unavailable.
- Optional discoveries or assistance becoming unavailable.
- Changes in the final restoration outcome.

**DESIGN LIMIT**
Mistakes should teach and create consequences, not permanently block the game. Essential objects and materials need alternative paths or recoverable solutions.

## 13. Visual And Audio Direction

**VISUAL STYLE**
- 2D top-down pixel art.
- Readable silhouettes and interactable objects.
- Strong visual distinction between material categories.
- Distinct visual language for hazardous objects and collection points.
- Environments should tell stories through accumulated waste, broken infrastructure, abandoned signs, and traces of former activity.
- The world should feel damaged but not visually monotonous; each chapter needs a recognizable palette, structure, and environmental identity.

**USER INTERFACE**
The UI should feel like a practical field-recovery device rather than a collection of unrelated game menus. FRU-01 can provide a consistent visual identity for scanning, objectives, field notes, and records.

**AUDIO**
Audio can reinforce environmental atmosphere: wind, distant machinery, electrical hum, water, footsteps, and subtle device sounds. Audio should support exploration and tension without overwhelming the player.

## 14. Scope: Full Game Vs. Hackathon Prototype

**FULL-GAME VISION**
- Five regions/chapters.
- A complete environmental restoration mystery.
- Connected systems for waste, water, food/soil, shelter, energy, and hazards.
- Inventory, sorting, processing, repair, limited crafting, and meaningful choices.
- FRU-01 progression and archived story fragments.
- A final choice and outcomes reflecting player actions.

**RECOMMENDED HACKATHON BUILD**
A polished vertical slice of CHAPTER 1 — THE GREAT DUMP.

The prototype should prove the central loop:
**EXPLORE -> SCAN -> COLLECT -> SORT -> RECOVER -> REPAIR -> DISCOVER.**

**MINIMUM PLAYABLE SEQUENCE**
**1. The player enters a small abandoned dump/recovery-centre area.**
**2. The player moves using touchscreen controls.**
**3. The player approaches and inspects several discarded objects.**
**4. FRU-01 identifies materials and gives concise information.**
**5. The player collects suitable materials.**
**6. The player sorts a small mixed batch.**
**7. The player identifies a battery/e-waste item and sends it to the special collection point.**
**8. The player uses recovered material or components to repair a device, station, or relay.**
**9. The restored system activates and reveals a short story fragment or the next signal.**

**WHAT NOT TO BUILD FIRST**
- All five chapters.
- A huge open world.
- Multiplayer.
- A complex survival simulation.
- Dozens of crafting recipes.
- A large branching dialogue system.
- Multiple fully developed endings.
- A complicated health/disease simulation.
- A full industrial or water-treatment simulator.

A complete, understandable, polished short experience is the priority.

## 15. Development Principles And Production Notes

**ENGINE DIRECTION DISCUSSED**
Godot 4.x with GDScript was proposed for development. The final technical choice should be confirmed by the team based on skills and available time.

**PROJECT ORGANIZATION**
The game should be built from reusable systems where practical:
- Player movement and collision.
- Interaction/proximity detection.
- Interactable object definitions.
- Item and inventory data.
- FRU-01 scanning and information display.
- Sorting logic.
- Processing/repair interactions.
- Objectives and progression.
- Dialogue/recording system.
- Save/state handling if scope permits.

**CONTENT AND ASSET RULES**
For the hackathon, follow the event's rules on pre-existing code, designs, assets, and content. Declare any pre-existing material when required. Use assets the team has permission to use, and keep track of asset sources and licenses. The submitted concept is the accepted proposal; actual pre-existing implementation materials must still be treated according to the event rules.

**IMPLEMENTATION PRIORITY**
**1. Make movement and interaction reliable on mobile.**
**2. Implement the waste-item data model and scanning.**
**3. Implement collection and inventory.**
**4. Implement one sorting challenge with feedback.**
**5. Implement one recovery/repair interaction.**
**6. Add a short narrative sequence.**
**7. Polish feedback, sound, UI, and transitions.**

**DESIGN TEST**
For every proposed feature, ask:
- Does it support recycling, waste management, recovery, or environmental restoration?
- Does it create a meaningful player action?
- Does it teach or reinforce a real principle?
- Does it fit the mobile control scheme?
- Is it necessary for the current prototype?
If the answer to these questions is mostly no, defer or remove the feature.

## 16. Ideas Discussed But Not Yet Canon

These ideas were explored and may be valuable, but should not be treated as final decisions without team agreement.

- The protagonist's exact name, age, personality, and detailed personal backstory.
- The exact year of the story, including the possible year 3026.
- The Mars migration storyline and the fate of people who left Earth.
- The protagonist being descended from people who chose to stay on Earth.
- Tombs or graves in the Last Sanctuary belonging to people who protected it.
- The Sanctuary being deliberately kept secret or treated as a myth.
- The exact reason the Sanctuary was hidden.
- The exact fate and social structure of the wider surviving population.
- The precise personality and mystery of FRU-01.
- The number and identity of side characters.
- The exact easter eggs and references.
- The exact number and naming of endings.
- The precise inventory capacity, resource quantities, timers, and numerical balancing.
- The exact crafting recipes and processing mechanics.
- The exact health/condition effects after unsafe exposure.

These should be selected only if they strengthen the central experience. Do not add all of them simply because they were discussed.

## 17. Open Questions To Settle Before Full Development

**STORY**
- Is the future-Earth/Mars idea part of canon, or should the story remain focused on a more immediate post-collapse future?
- What is the protagonist's identity and personal motivation beyond helping the settlement?
- How much of the Sanctuary's history should be revealed?
- Are there side characters, and what concrete role do they play?
- Is the final choice the only major branching decision, or do earlier choices shape the ending more subtly?

**GAMEPLAY**
- What exact objects and material categories appear in Chapter 1?
- Which objects are automatically collected, and which require explicit action?
- What is the inventory capacity?
- Which single processing station is essential for the prototype?
- What exact repair objective best demonstrates reuse/recovery?
- How should the player recover from a wrong sorting choice?
- Which pressure mechanic, if any, belongs in the first prototype?

**MOBILE UX**
- Exact joystick and button positions.
- Whether scan requires one tap or a two-step nearby-object confirmation.
- Whether FRU-01 and inventory are separate screens or panels.
- Text size and interaction feedback on the target phone screen.

**SCIENTIFIC CONTENT**
- Validate every material classification and recovery route.
- Validate every hazardous-waste instruction.
- Validate water-treatment and soil-restoration mechanics.
- Ensure that game simplifications are clearly framed as simplified models rather than universal real-world rules.

## 18. Final Design North Star

THE LAST DROP is not a generic survival game with recycling added as a side activity.

It is a mobile exploration and recovery game in which the player moves through a world damaged by irresponsible production, consumption, and waste management. The player identifies discarded materials, separates useful resources from hazardous waste, recovers and reuses what can be recovered, repairs abandoned systems, and discovers how these actions connect to water, soil, energy, and ecosystem restoration.

The mystery of the Last Drop gives the journey purpose. FRU-01 gives the player a practical guide and a connection to the past. The five regions expand the environmental consequences of waste and resource mismanagement. The final revelation shows that the Last Drop is not a magical source of water but a restoration initiative whose success depends on people applying and sharing knowledge.

The game's message is not that recycling alone can repair the planet. Its message is that responsible material use, sorting, recovery, reuse, repair, safe treatment, and cooperation are essential parts of preventing further damage and rebuilding systems.

The player begins by searching for a way to save one settlement. The player ends by understanding that a settlement, a river, a field, a factory, and an ecosystem are connected — and that the future depends on what people choose to do with the resources and knowledge they still have.

**THE WORLD WASN'T DESTROYED IN A SINGLE DAY.**
**AND IT WON'T BE REBUILT IN ONE EITHER.**

**END OF MASTER SHEET**
