window.BATTLE_BOG_QUIZ = {
  sections: [
    {
      id: "north-star",
      number: "01",
      title: "Visual North Star",
      short: "North Star",
      description:
        "Calibrate the overall visual neighborhood before judging individual techniques.",
      axes: ["Dimensionality", "Surface finish", "Color energy", "Competitive clarity"]
    },
    {
      id: "creatures",
      number: "02",
      title: "Creature Rendering",
      short: "Creatures",
      description:
        "Decide how anatomy, proportions, materials and silhouettes should read at gameplay scale.",
      axes: ["Anatomy", "Exaggeration", "Surface detail", "Silhouette"]
    },
    {
      id: "motion",
      number: "03",
      title: "Scale, Height & Motion",
      short: "Motion",
      description:
        "Separate visual style from useful movement, scale and altitude solutions.",
      axes: ["Scale tiers", "Turning", "Gait", "Flight depth", "Swarms"]
    },
    {
      id: "combat",
      number: "04",
      title: "Combat & Effects",
      short: "Combat",
      description:
        "Set the target for telegraphs, hit feedback, model visibility and teamfight intensity.",
      axes: ["Telegraphs", "Impact", "Effect density", "Camera", "Target clarity"]
    },
    {
      id: "world",
      number: "05",
      title: "Wetland World",
      short: "World",
      description:
        "Find the right balance between an alive ecosystem and a readable competitive map.",
      axes: ["Water", "Shorelines", "Vegetation", "Density", "Habitat identity"]
    },
    {
      id: "lighting",
      number: "06",
      title: "Lighting & Uncertainty",
      short: "Lighting",
      description:
        "Choose how strongly day, night, fog and uncertain information should transform play.",
      axes: ["Day/night", "Fog", "Local light", "Sound cues", "Telegraph priority"]
    },
    {
      id: "hud",
      number: "07",
      title: "HUD & Objectives",
      short: "HUD",
      description:
        "Define how much information stays visible and how objectives, hunger and squad state interrupt combat.",
      axes: ["HUD density", "Minimap", "Objectives", "Squad state", "Accessibility"]
    },
    {
      id: "pipeline",
      number: "08",
      title: "Production Look",
      short: "Pipeline",
      description:
        "Judge the visible result first. Technical costs are shown as context, not as a reason to like a look.",
      axes: ["Live 3D", "Rendered sprites", "2D rigs", "Frame animation", "Hybrid exceptions"]
    }
  ],

  forcedChoices: [
    {
      id: "dimensionality",
      section: "north-star",
      prompt: "Which overall dimensional treatment is closest?",
      options: [
        "Clean modeled 3D",
        "Painted 2.5D",
        "Illustrated 2D",
        "Undecided until prototypes"
      ]
    },
    {
      id: "anchor_blend",
      section: "north-star",
      prompt: "Which sentence sounds most like Battle Bog?",
      options: [
        "Battlerite with more creature personality",
        "SUPERVIVE with calmer effects",
        "Pokemon UNITE with less toy-like anatomy",
        "A deliberate blend of all three"
      ]
    },
    {
      id: "anatomy",
      section: "creatures",
      prompt: "How natural should creature anatomy remain?",
      options: [
        "Grounded and recognizable",
        "Grounded with bold readable exaggeration",
        "Highly heroic and stylized",
        "Different by creature family"
      ]
    },
    {
      id: "size_policy",
      section: "motion",
      prompt: "How should real animal size differences be handled?",
      options: [
        "Believable size tiers with readable compression",
        "Mostly normalized competitive sizes",
        "Near-real ratios, even when tiny",
        "Decide per family"
      ]
    },
    {
      id: "flight_truth",
      section: "motion",
      prompt: "What should carry most of the flight-depth information?",
      options: [
        "Body height plus shadow",
        "Strong ground projection and landing path",
        "Larger airborne model",
        "A layered combination"
      ]
    },
    {
      id: "effect_budget",
      section: "combat",
      prompt: "Where should ordinary Battle Bog combat sit?",
      options: [
        "Battlerite-level restraint",
        "Between Battlerite and SUPERVIVE",
        "SUPERVIVE-level spectacle",
        "Quiet basics, spectacular major abilities"
      ]
    },
    {
      id: "world_density",
      section: "world",
      prompt: "How dense should the wetland feel?",
      options: [
        "Clean lanes with edge detail",
        "Balanced ecology and readability",
        "Lush and reactive throughout",
        "Density changes by gameplay region"
      ]
    },
    {
      id: "night_strength",
      section: "lighting",
      prompt: "How strongly should night transform the world?",
      options: [
        "Mild competitive tint",
        "Noticeable mood and visibility shift",
        "Dramatic physical darkness",
        "Mostly information changes, not darkness"
      ]
    },
    {
      id: "hud_density",
      section: "hud",
      prompt: "Which HUD hierarchy is closest?",
      options: [
        "Battlerite-minimal with contextual panels",
        "SUPERVIVE-layered but simplified",
        "Pokemon UNITE-large and immediate",
        "Configurable simple and expanded modes"
      ]
    },
    {
      id: "pipeline_bias",
      section: "pipeline",
      prompt: "Before prototypes, which visible result interests you most?",
      options: [
        "Restrained live 3D",
        "3D-derived painted sprites",
        "Illustrated 2D rigs",
        "No preference until direct comparison"
      ]
    }
  ],

  items: [
    {
      id: "north-battlerite",
      section: "north-star",
      game: "Battlerite",
      title: "Clean dimensional combat",
      role: "Anchor",
      image: "assets/battlerite_match.jpg",
      sourceUrl: "https://www.youtube.com/watch?v=7pQxQiIIAdk",
      contextUrl: "https://store.steampowered.com/app/504370/Battlerite/",
      sourceType: "Player gameplay thumbnail + official gallery",
      focus: "Modeled volume, restrained surfaces and compact combat framing.",
      context:
        "This is the closest direct-control 3v3 baseline. Judge the finish and camera, not its arena-only map structure.",
      question:
        "Should this clean, modeled and restrained presentation be Battle Bog's main visual anchor?",
      limits: "Does not solve animal anatomy, ecology or macro objectives."
    },
    {
      id: "north-supervive",
      section: "north-star",
      game: "SUPERVIVE",
      title: "Energetic dimensional clarity",
      role: "Anchor",
      image: "assets/supervive_match.jpg",
      sourceUrl: "https://www.youtube.com/watch?v=Fs9pGnI345E",
      contextUrl: "https://store.steampowered.com/app/1283700/SUPERVIVE/",
      sourceType: "Official full-match thumbnail + official gallery",
      focus: "Bold silhouettes, vertical terrain, energetic animation and layered effects.",
      context:
        "Use the full match to judge how far Battle Bog can push visual energy before bodies disappear.",
      question:
        "Is this the right energy and dimensionality if Battle Bog keeps ordinary attacks quieter?",
      limits: "Character designs are mostly humanoid and the peak fights are denser than 3v3."
    },
    {
      id: "north-unite",
      section: "north-star",
      game: "Pokemon UNITE",
      title: "Creature-first readability",
      role: "Anchor",
      image: "assets/pokemon_unite.jpg",
      sourceUrl: "https://www.youtube.com/watch?v=IAAmPqSdP2I",
      contextUrl: "https://unite.pokemon.com/en-us/overview/",
      sourceType: "Player gameplay thumbnail + official overview",
      focus: "Readable creatures, clean materials and approachable effects at MOBA scale.",
      context:
        "Judge creature screen occupancy, silhouettes and movement. Treat mobile controls as a separate issue.",
      question:
        "Should Battle Bog pursue this level of creature readability with less toy-like anatomy?",
      limits: "Brand-driven proportions and glossy surfaces may be too soft or synthetic."
    },
    {
      id: "north-temtem",
      section: "north-star",
      game: "Temtem: Swarm",
      title: "Softer creature-led 3D",
      role: "Neighbor",
      image: "assets/temtem_swarm.jpg",
      sourceUrl: "https://store.steampowered.com/app/2510960/Temtem_Swarm/",
      contextUrl: "https://store.steampowered.com/app/2510960/Temtem_Swarm/",
      sourceType: "Official store gameplay screenshot",
      focus: "A softer and simpler creature treatment under heavy top-down action.",
      context:
        "This tests whether Pokemon UNITE's neighborhood is right but should become even cleaner and rounder.",
      question:
        "Does this feel compatible, or does it push Battle Bog too far toward a glossy toy world?",
      limits: "Survivor-style enemy density does not match deliberate 3v3 exchanges."
    },
    {
      id: "north-evercore",
      section: "north-star",
      game: "Evercore Heroes",
      title: "Polished competitive fantasy 3D",
      role: "Neighbor",
      image: "assets/evercore.jpg",
      sourceUrl: "https://store.steampowered.com/app/2586780/Evercore_Heroes__Ascension/",
      contextUrl: "https://evercoreheroes.com/videos",
      sourceType: "Official store gameplay screenshot",
      focus: "Bright modeled materials, readable heroes and SUPERVIVE-adjacent environments.",
      context:
        "Useful for deciding whether the preferred direction is broadly colorful competitive 3D rather than creature-specific stylization.",
      question:
        "Is this polished 3D finish closer to the desired Battle Bog world than darker painterly references?",
      limits: "Generic fantasy heroes provide little real-animal anatomy evidence."
    },
    {
      id: "north-ravenswatch",
      section: "north-star",
      game: "Ravenswatch",
      title: "Painterly, darker modeled forms",
      role: "Boundary",
      image: "assets/ravenswatch.jpg",
      sourceUrl: "https://store.steampowered.com/app/2071280/Ravenswatch/",
      contextUrl: "https://www.youtube.com/watch?v=-VF8CmNeBss",
      sourceType: "Official store gameplay screenshot + player footage",
      focus: "Sculpted silhouettes, painterly materials and a darker world.",
      context:
        "A close camera and strong combat readability make this a useful test of how much mood and surface detail are acceptable.",
      question:
        "Does this richer painterly treatment still belong beside the three anchors, or already feel too dark?",
      limits: "Cooperative PvE does not test opposing team colors."
    },

    {
      id: "creature-unite",
      section: "creatures",
      game: "Pokemon UNITE",
      title: "Readable anatomical exaggeration",
      role: "Anchor",
      image: "assets/pokemon_unite_spectator.jpg",
      sourceUrl: "https://www.youtube.com/watch?v=GWFNFcPKHDA",
      contextUrl: "https://unite.pokemon.com/en-us/overview/",
      sourceType: "Official spectator thumbnail + official overview",
      focus: "Large heads, clear limbs and strong species silhouettes during a full teamfight.",
      context:
        "Ignore spectator HUD. Judge how creatures remain recognizable when effects overlap.",
      question:
        "How much of this anatomical exaggeration should Battle Bog keep for readability?",
      limits: "Spectator camera cannot establish player camera or HUD requirements."
    },
    {
      id: "creature-temtem",
      section: "creatures",
      game: "Temtem: Swarm",
      title: "Rounded, simplified creature forms",
      role: "Neighbor",
      image: "assets/temtem_swarm.jpg",
      sourceUrl: "https://store.steampowered.com/app/2510960/Temtem_Swarm/",
      contextUrl: "https://store.steampowered.com/app/2510960/Temtem_Swarm/",
      sourceType: "Official store gameplay screenshot",
      focus: "Compact bodies, soft materials and silhouette-first detailing.",
      context:
        "This is a close test of whether Battle Bog should simplify anatomy more than Pokemon UNITE.",
      question:
        "Are these surfaces pleasantly clean, or too rounded and toy-like for real wetland animals?",
      limits: "Fantasy creatures are designed for collection appeal rather than biological authenticity."
    },
    {
      id: "creature-wild-woods",
      section: "creatures",
      game: "Wild Woods",
      title: "Squat, softly modeled animals",
      role: "Boundary",
      image: "assets/wild_woods.jpg",
      sourceUrl: "https://store.steampowered.com/app/1975580/Wild_Woods/",
      contextUrl: "https://store.steampowered.com/app/1975580/Wild_Woods/",
      sourceType: "Official store gameplay screenshot",
      focus: "Small-team animal silhouettes with compact, anthropomorphic proportions.",
      context:
        "Useful for locating the line between approachable animal characters and overly toy-like bodies.",
      question:
        "Do these forms feel charming and readable, or too anthropomorphic for Battle Bog?",
      limits: "Weapon handling replaces species-authentic locomotion."
    },
    {
      id: "creature-v-rising",
      section: "creatures",
      game: "V Rising",
      title: "Detailed live-3D anatomy",
      role: "Boundary",
      image: "assets/v_rising.jpg",
      sourceUrl: "https://store.steampowered.com/app/1604030/V_Rising/",
      contextUrl: "https://www.youtube.com/watch?v=YkyZv8BwQkM",
      sourceType: "Official store screenshot + player footage",
      focus: "More natural materials, deeper shading and heavier modeled mass.",
      context:
        "This card isolates whether the clash is darkness, Gothic art direction, material detail or live 3D itself.",
      question:
        "Which part feels wrong, if any: the realism, darkness, material detail or character scale?",
      limits: "Its production budget and camera depth exceed Battle Bog's current assumptions."
    },
    {
      id: "creature-deaths-door",
      section: "creatures",
      game: "Death's Door",
      title: "Compact low-poly silhouette",
      role: "Neighbor",
      image: "assets/deaths_door.jpg",
      sourceUrl: "https://store.steampowered.com/app/894020/Deaths_Door/",
      contextUrl: "https://www.youtube.com/watch?v=vmzoMJLnbZQ",
      sourceType: "Official store screenshot + gameplay",
      focus: "Simplified dimensional forms with restrained surface detail.",
      context:
        "A useful test of whether readable low-poly bodies feel polished enough without becoming childish.",
      question:
        "Would this degree of simplification suit Battle Bog's animals, or remove too much anatomical identity?",
      limits: "A single bird avatar does not prove a 21-creature roster."
    },
    {
      id: "creature-tunic",
      section: "creatures",
      game: "TUNIC",
      title: "Diorama-scale animal form",
      role: "Boundary",
      image: "assets/tunic.jpg",
      sourceUrl: "https://store.steampowered.com/app/553420/TUNIC/",
      contextUrl: "https://store.steampowered.com/app/553420/TUNIC/",
      sourceType: "Official store gameplay screenshot",
      focus: "Tiny, highly legible character mass against a clean miniature world.",
      context:
        "This tests whether a model-set quality is appealing or too cute and sparse.",
      question:
        "Does this compact diorama treatment preserve enough animal identity for Battle Bog?",
      limits: "One upright fox cannot establish varied quadruped, bird or swarm anatomy."
    },

    {
      id: "motion-flock",
      section: "motion",
      game: "Flock",
      title: "Continuous flight and banking",
      role: "Specialist",
      image: "assets/flock.jpg",
      sourceUrl: "https://store.steampowered.com/app/1472930/Flock/",
      contextUrl: "https://www.youtube.com/watch?v=35kmUJ9BmP8",
      sourceType: "Official store screenshot + publisher walkthrough",
      focus: "Banking, formation lag, ascent, descent and ground proximity.",
      context:
        "Rate the motion idea separately from its noncombat camera and soft pastoral appearance.",
      question:
        "Should Battle Bog's birds feel this continuous and organic between attacks?",
      limits: "Does not solve attack telegraphs or competitive ground projections."
    },
    {
      id: "motion-pikmin",
      section: "motion",
      game: "Pikmin 4",
      title: "Swarms as readable groups",
      role: "Specialist",
      image: "assets/pikmin_4.jpg",
      sourceUrl: "https://www.youtube.com/watch?v=gWBWglh3BFU",
      contextUrl: "https://pikmin4.nintendo.com/",
      sourceType: "Editorial gameplay thumbnail + official overview",
      focus: "Group cohesion, individual variation, target convergence and water entry.",
      context:
        "Apply this only to mosquitoes, fireflies and clustered creatures.",
      question:
        "Should a swarm read as many individuals, one cohesive mass, or a layered combination?",
      limits: "Camera, pacing and art direction are not direct combat-style references."
    },
    {
      id: "motion-rain-world",
      section: "motion",
      game: "Rain World",
      title: "Biomechanics without style approval",
      role: "Specialist",
      image: "assets/rain_world.jpg",
      sourceUrl: "https://store.steampowered.com/app/312520/Rain_World/",
      contextUrl: "https://www.youtube.com/watch?v=tVWPtsSPhzk",
      sourceType: "Official store screenshot + developer footage",
      focus: "Long bodies, terrain contact, compression, swimming and procedural-looking weight.",
      context:
        "This card intentionally asks only about motion principles. A Useful rating does not approve its 2D look.",
      question:
        "Are these body mechanics worth mining even if the visual construction is rejected?",
      limits: "Side-view rendering and 2D silhouettes should not define Battle Bog's final appearance."
    },
    {
      id: "motion-unite",
      section: "motion",
      game: "Pokemon UNITE",
      title: "Responsive creature motion",
      role: "Anchor",
      image: "assets/pokemon_unite.jpg",
      sourceUrl: "https://www.youtube.com/watch?v=IAAmPqSdP2I",
      contextUrl: "https://unite.pokemon.com/en-us/overview/",
      sourceType: "Player gameplay thumbnail + official overview",
      focus: "Fast starts, clear attacks, readable dives and compressed scale tiers.",
      context:
        "Judge whether responsiveness should dominate over natural acceleration and weight.",
      question:
        "Should Battle Bog favor this immediate responsiveness, or preserve more natural weight?",
      limits: "Many animations prioritize franchise personality over real-animal gait."
    },
    {
      id: "motion-battlerite",
      section: "motion",
      game: "Battlerite",
      title: "Readable combat key poses",
      role: "Anchor",
      image: "assets/battlerite.jpg",
      sourceUrl: "https://store.steampowered.com/app/504370/Battlerite/",
      contextUrl: "https://www.youtube.com/watch?v=mDCP_SOcX_U",
      sourceType: "Official store screenshot + tournament footage",
      focus: "Anticipation, attack commitment, whiff recovery and movement under direct aim.",
      context:
        "This is a timing and pose reference rather than an animal-locomotion reference.",
      question:
        "Should Battle Bog attacks use similarly bold anticipation and recovery poses?",
      limits: "Humanoid champions do not answer species-specific gait questions."
    },
    {
      id: "motion-dont-starve",
      section: "motion",
      game: "Don't Starve Together",
      title: "Modular motion specialist",
      role: "Specialist",
      image: "assets/dont_starve.jpg",
      sourceUrl: "https://store.steampowered.com/app/322330/Dont_Starve_Together/",
      contextUrl: "https://www.youtube.com/watch?v=ENUSAB-h6O8",
      sourceType: "Official store screenshot + player footage",
      focus: "Concise key poses, reusable body parts and readable small-creature actions.",
      context:
        "Rate only whether its pose economy and modular animation are worth studying.",
      question:
        "Is this useful as construction research while remaining visually incompatible?",
      limits: "A Useful rating must not be interpreted as approval of the cutout look."
    },

    {
      id: "combat-battlerite",
      section: "combat",
      game: "Battlerite",
      title: "Restrained 3v3 clarity",
      role: "Anchor",
      image: "assets/battlerite_match.jpg",
      sourceUrl: "https://www.youtube.com/watch?v=7pQxQiIIAdk",
      contextUrl: "https://store.steampowered.com/app/504370/Battlerite/",
      sourceType: "Player gameplay thumbnail + official gallery",
      focus: "Partial-fill telegraphs, compact health bars and visible bodies during pressure.",
      context:
        "Treat this as the quiet end of the desired combat range.",
      question:
        "Should ordinary Battle Bog exchanges remain this visually restrained?",
      limits: "Contains little environmental or objective information."
    },
    {
      id: "combat-supervive",
      section: "combat",
      game: "SUPERVIVE",
      title: "Layered teamfight spectacle",
      role: "Anchor",
      image: "assets/supervive_match.jpg",
      sourceUrl: "https://www.youtube.com/watch?v=Fs9pGnI345E",
      contextUrl: "https://store.steampowered.com/app/1283700/SUPERVIVE/",
      sourceType: "Official full-match thumbnail + official gallery",
      focus: "Overlapping abilities, altitude, revives and off-screen information.",
      context:
        "Treat this as a candidate upper bound, not an automatic target for every ability.",
      question:
        "Should Battle Bog approach this density only for bosses and major objective fights?",
      limits: "Larger lobbies and battle-royale systems increase visual load."
    },
    {
      id: "combat-machines",
      section: "combat",
      game: "The Machines Arena",
      title: "Crisp projectile language",
      role: "Neighbor",
      image: "assets/machines_arena.jpg",
      sourceUrl: "https://store.steampowered.com/app/1539860/The_Machines_Arena/",
      contextUrl: "https://www.youtube.com/watch?v=dz46CRMcV3Y",
      sourceType: "Official store screenshot + raw gameplay",
      focus: "Sharp projectiles, cursor-facing poses, hit confirmation and camera stability.",
      context:
        "Imagine its robotic effects translated into water, mud, feather, shell and chitin materials.",
      question:
        "Is this sharper shooter-like hit language desirable for Battle Bog?",
      limits: "Robotic combat supplies little organic-material guidance."
    },
    {
      id: "combat-hades",
      section: "combat",
      game: "Hades II",
      title: "Material-impact ceiling",
      role: "Boundary",
      image: "assets/hades_ii.jpg",
      sourceUrl: "https://store.steampowered.com/app/1145350/Hades_II/",
      contextUrl: "https://www.youtube.com/watch?v=-SnaCUsUF3E",
      sourceType: "Official store screenshot + developer showcase",
      focus: "Rich hit flashes, trails, enemy reactions and material-specific effects.",
      context:
        "Use this to decide whether high-impact richness belongs everywhere or only on major attacks.",
      question:
        "Should this level of impact richness be reserved for bosses and signature abilities?",
      limits: "Solo PvE rooms tolerate more spectacle than competitive 3v3."
    },
    {
      id: "combat-omega",
      section: "combat",
      game: "Omega Strikers",
      title: "Maximum graphic cleanliness",
      role: "Boundary",
      image: "assets/omega_strikers.jpg",
      sourceUrl: "https://store.steampowered.com/app/1869590/Omega_Strikers/",
      contextUrl: "https://www.youtube.com/watch?v=VnPlvI82Y0c",
      sourceType: "Official store screenshot + player match",
      focus: "Strong team color, clean fields, large characters and immediate directional effects.",
      context:
        "This isolates whether extremely clean competitive graphics feel useful or too artificial.",
      question:
        "Should Battle Bog borrow this graphic clarity while keeping a much more organic world?",
      limits: "Sports framing and flat arenas suppress environmental complexity."
    },
    {
      id: "combat-eternal",
      section: "combat",
      game: "Eternal Return",
      title: "Clutter rejection boundary",
      role: "Boundary",
      image: "assets/eternal_return.jpg",
      sourceUrl: "https://store.steampowered.com/app/1049590/Eternal_Return/",
      contextUrl: "https://www.youtube.com/watch?v=npV8q5bDfbE",
      sourceType: "Official store screenshot + player match",
      focus: "Dense HUD, overlapping effects and reduced body visibility.",
      context:
        "A negative control can be as informative as a favorite.",
      question:
        "Is any part of this density desirable, or should it become an explicit rejection boundary?",
      limits: "Item and crafting systems create information Battle Bog does not need."
    },

    {
      id: "world-albion",
      section: "world",
      game: "Albion Online",
      title: "Grounded stylized wetlands",
      role: "Neighbor",
      image: "assets/albion.jpg",
      sourceUrl: "https://store.steampowered.com/app/761890/Albion_Online/",
      contextUrl: "https://albiononline.com/news/visual-overhaul-shorts",
      sourceType: "Official store screenshot + official visual-overhaul page",
      focus: "Muddy water, breathing plants, humid light and top-down material readability.",
      context:
        "The 2026 Radiant Wilds update is a closer wetland alternative to V Rising's Gothic world.",
      question:
        "Is this the right balance between grounded wetland material and competitive readability?",
      limits: "The selected store image may not show the exact swamp sequence; use the official biome page for context."
    },
    {
      id: "world-supervive",
      section: "world",
      game: "SUPERVIVE",
      title: "Competitive terrain hierarchy",
      role: "Anchor",
      image: "assets/supervive.jpg",
      sourceUrl: "https://store.steampowered.com/app/1283700/SUPERVIVE/",
      contextUrl: "https://www.youtube.com/watch?v=Fs9pGnI345E",
      sourceType: "Official store gameplay screenshot + full match",
      focus: "Bright landmarks, grass cover, vertical edges and readable objective spaces.",
      context:
        "Judge how much world detail survives beneath strong teamfight information.",
      question:
        "Should Battle Bog inherit this clarity while replacing the sci-fi terrain language with wetland ecology?",
      limits: "Its floating world and saturated landmarks are not thematic matches."
    },
    {
      id: "world-unite",
      section: "world",
      game: "Pokemon UNITE",
      title: "Clean creature-MOBA terrain",
      role: "Anchor",
      image: "assets/pokemon_unite_spectator.jpg",
      sourceUrl: "https://www.youtube.com/watch?v=GWFNFcPKHDA",
      contextUrl: "https://unite.pokemon.com/en-us/overview/",
      sourceType: "Official spectator thumbnail + official overview",
      focus: "Rounded shorelines, clean grass, objective pits and simple lane boundaries.",
      context:
        "This is the clean end of the environment spectrum.",
      question:
        "Are these terrain materials usefully clear, or too plastic and synthetic for Battle Bog?",
      limits: "Spectator framing and branded stadium logic differ from the player world."
    },
    {
      id: "world-ravenswatch",
      section: "world",
      game: "Ravenswatch",
      title: "Rich, moody ecology",
      role: "Boundary",
      image: "assets/ravenswatch.jpg",
      sourceUrl: "https://store.steampowered.com/app/2071280/Ravenswatch/",
      contextUrl: "https://www.youtube.com/watch?v=-VF8CmNeBss",
      sourceType: "Official store screenshot + player footage",
      focus: "Denser props, stronger mood, day/night variation and painterly materials.",
      context:
        "This tests whether more ecological richness can coexist with the preferred competitive style.",
      question:
        "Does this feel richly alive or too dark and illustrated for Battle Bog?",
      limits: "Its darkness and outlines may dominate more than Battle Bog can allow."
    },
    {
      id: "world-tribes",
      section: "world",
      game: "Tribes of Midgard",
      title: "Chunky stylized swamp",
      role: "Boundary",
      image: "assets/tribes_midgard.jpg",
      sourceUrl: "https://store.steampowered.com/app/858820/Tribes_of_Midgard/",
      contextUrl: "https://www.youtube.com/watch?v=2-tUQdmkPxo",
      sourceType: "Official store screenshot + gameplay",
      focus: "Exaggerated terrain chunks, strong biome identity and glowing night vegetation.",
      context:
        "Useful for testing how far terrain shapes can be simplified and enlarged.",
      question:
        "Is this stylized terrain appealing, or does it undermine authentic animal scale?",
      limits: "Chunky procedural landforms are not a direct competitive-map template."
    },
    {
      id: "world-v-rising",
      section: "world",
      game: "V Rising",
      title: "Naturalistic material ceiling",
      role: "Boundary",
      image: "assets/v_rising.jpg",
      sourceUrl: "https://store.steampowered.com/app/1604030/V_Rising/",
      contextUrl: "https://www.youtube.com/watch?v=YkyZv8BwQkM",
      sourceType: "Official store screenshot + player footage",
      focus: "Dense foliage, deep materials, natural light and dark atmospheric regions.",
      context:
        "Use this card to name the source of the style clash rather than accepting or rejecting it wholesale.",
      question:
        "Which part should Battle Bog mine, if any: water, materials, lighting, density or none?",
      limits: "Gothic tone and higher rendering scope can distort the comparison."
    },
    {
      id: "world-deaths-door",
      section: "world",
      game: "Death's Door",
      title: "Restrained water composition",
      role: "Specialist",
      image: "assets/deaths_door.jpg",
      sourceUrl: "https://store.steampowered.com/app/894020/Deaths_Door/",
      contextUrl: "https://www.youtube.com/watch?v=vmzoMJLnbZQ",
      sourceType: "Official store screenshot + gameplay",
      focus: "Muted water, readable bridges, shoreline framing and compact environmental detail.",
      context:
        "A composition specialist rather than a full style anchor.",
      question:
        "Is this restrained water treatment useful, or too somber and architectural?",
      limits: "Architecture dominates ecology and its rooms are smaller than Battle Bog's map."
    },

    {
      id: "light-heroes",
      section: "lighting",
      game: "Heroes of the Storm",
      title: "Competitive day/night transformation",
      role: "Specialist",
      image: "assets/heroes_storm.jpg",
      sourceUrl: "https://www.youtube.com/watch?v=6xQAdnR1Vrg",
      contextUrl: "https://news.blizzard.com/en-us/article/14806627/developer-insights-garden-of-terror",
      sourceType: "Player gameplay thumbnail + official design article",
      focus: "A visible world-phase change tied to objective information.",
      context:
        "Judge the strength of the transformation, not the older MOBA rendering.",
      question:
        "Should Battle Bog's night transform the map this visibly while preserving navigation?",
      limits: "Older rendering and click-to-move camera are not visual targets."
    },
    {
      id: "light-supervive",
      section: "lighting",
      game: "SUPERVIVE",
      title: "Information over physical darkness",
      role: "Anchor",
      image: "assets/supervive.jpg",
      sourceUrl: "https://store.steampowered.com/app/1283700/SUPERVIVE/",
      contextUrl: "https://www.youtube.com/watch?v=Fs9pGnI345E",
      sourceType: "Official store screenshot + full match",
      focus: "Strong world readability with uncertainty handled through layered information.",
      context:
        "This tests a competitive approach where the world stays legible while information changes.",
      question:
        "Should Battle Bog preserve bright physical clarity and express uncertainty mostly through cues?",
      limits: "Its information systems are not tied to a wetland day/night ecology."
    },
    {
      id: "light-v-rising",
      section: "lighting",
      game: "V Rising",
      title: "Dramatic physical lighting",
      role: "Boundary",
      image: "assets/v_rising.jpg",
      sourceUrl: "https://store.steampowered.com/app/1604030/V_Rising/",
      contextUrl: "https://www.youtube.com/watch?v=YkyZv8BwQkM",
      sourceType: "Official store screenshot + player footage",
      focus: "Strong sunlight, deep shadow and atmosphere as gameplay conditions.",
      context:
        "This is the dramatic end of the day/night spectrum.",
      question:
        "Is this physical lighting appealing, or too dark and material-heavy for fair 3v3 play?",
      limits: "Dynamic 3D lighting cost and Gothic tone are substantial confounds."
    },
    {
      id: "light-dota",
      section: "lighting",
      game: "Dota 2",
      title: "Fog and minimap information",
      role: "Specialist",
      image: "assets/dota_2.jpg",
      sourceUrl: "https://store.steampowered.com/app/570/Dota_2/",
      contextUrl: "https://www.youtube.com/watch?v=Oo5t5nBpneo",
      sourceType: "Official store screenshot + player footage",
      focus: "Visibility loss, map information and teamfight contrast under a dense natural map.",
      context:
        "Use for information hierarchy rather than copying its terrain or legacy HUD.",
      question:
        "How much fog and last-known information should Battle Bog expose explicitly?",
      limits: "Expert familiarity carries much of Dota's readability."
    },
    {
      id: "light-albion",
      section: "lighting",
      game: "Albion Online",
      title: "Humid atmospheric wetlands",
      role: "Neighbor",
      image: "assets/albion.jpg",
      sourceUrl: "https://store.steampowered.com/app/761890/Albion_Online/",
      contextUrl: "https://albiononline.com/news/visual-overhaul-shorts",
      sourceType: "Official store screenshot + official biome page",
      focus: "Atmosphere, wet surfaces and biome mood without Gothic darkness.",
      context:
        "A close test of whether Battle Bog can become more atmospheric while staying colorful.",
      question:
        "Does this mood feel compatible with the three anchors?",
      limits: "The store screenshot is broad context; inspect the official swamp clip before measurement."
    },
    {
      id: "light-ravenswatch",
      section: "lighting",
      game: "Ravenswatch",
      title: "Painterly darkness boundary",
      role: "Boundary",
      image: "assets/ravenswatch.jpg",
      sourceUrl: "https://store.steampowered.com/app/2071280/Ravenswatch/",
      contextUrl: "https://www.youtube.com/watch?v=-VF8CmNeBss",
      sourceType: "Official store screenshot + player footage",
      focus: "Dark world values with bright characters and effects.",
      context:
        "This tests whether darkness can be strong if creatures and telegraphs remain crisp.",
      question:
        "Is this contrast hierarchy useful, or is the overall tone incompatible?",
      limits: "Cooperative fantasy atmosphere is much darker than Battle Bog's current constitution."
    },

    {
      id: "hud-battlerite",
      section: "hud",
      game: "Battlerite",
      title: "Quiet combat HUD",
      role: "Anchor",
      image: "assets/battlerite_match.jpg",
      sourceUrl: "https://www.youtube.com/watch?v=7pQxQiIIAdk",
      contextUrl: "https://store.steampowered.com/app/504370/Battlerite/",
      sourceType: "Player gameplay thumbnail + official gallery",
      focus: "Compact health bars, ability strip and minimal battlefield obstruction.",
      context:
        "This is the minimal end. Battle Bog still needs hunger, stocks, swapping and objectives.",
      question:
        "Should strategic information appear contextually so ordinary combat stays this quiet?",
      limits: "Its mode has little macro information to display."
    },
    {
      id: "hud-supervive",
      section: "hud",
      game: "SUPERVIVE",
      title: "Layered strategic HUD",
      role: "Anchor",
      image: "assets/supervive_match.jpg",
      sourceUrl: "https://www.youtube.com/watch?v=Fs9pGnI345E",
      contextUrl: "https://store.steampowered.com/app/1283700/SUPERVIVE/",
      sourceType: "Official full-match thumbnail + official gallery",
      focus: "Squad state, minimap, resources, off-screen events and combat together.",
      context:
        "Judge the hierarchy, not the inventory systems Battle Bog does not need.",
      question:
        "How close should Battle Bog come to this amount of always-visible information?",
      limits: "Battle-royale inventory and revive systems inflate the HUD."
    },
    {
      id: "hud-unite",
      section: "hud",
      game: "Pokemon UNITE",
      title: "Large immediate objective HUD",
      role: "Anchor",
      image: "assets/pokemon_unite.jpg",
      sourceUrl: "https://www.youtube.com/watch?v=IAAmPqSdP2I",
      contextUrl: "https://unite.pokemon.com/en-us/overview/",
      sourceType: "Player gameplay thumbnail + official overview",
      focus: "Minimap, teammate state, carried energy, cooldowns and objective urgency.",
      context:
        "Consider the information grouping separately from mobile-sized buttons.",
      question:
        "Should Battle Bog favor similarly large immediate signals or a tighter PC-oriented HUD?",
      limits: "Touch controls occupy space that Battle Bog does not need."
    },
    {
      id: "hud-omega",
      section: "hud",
      game: "Omega Strikers",
      title: "Centralized team strip",
      role: "Neighbor",
      image: "assets/omega_strikers.jpg",
      sourceUrl: "https://store.steampowered.com/app/1869590/Omega_Strikers/",
      contextUrl: "https://www.youtube.com/watch?v=VnPlvI82Y0c",
      sourceType: "Official store screenshot + player match",
      focus: "Top portrait strip, team colors, compact cooldowns and scoring state.",
      context:
        "A useful comparison for whether squad stocks belong in one strong region.",
      question:
        "Should team information be centralized like this or stay close to each creature?",
      limits: "Sports scoring and knockback state differ from Battle Bog."
    },
    {
      id: "hud-dota",
      section: "hud",
      game: "Dota 2",
      title: "Configurable information depth",
      role: "Specialist",
      image: "assets/dota_2.jpg",
      sourceUrl: "https://store.steampowered.com/app/570/Dota_2/",
      contextUrl: "https://www.dota2.com/700/hud/",
      sourceType: "Official store screenshot + official HUD article",
      focus: "Minimap options, team portraits and expandable depth.",
      context:
        "Use as a configuration reference, not a baseline density target.",
      question:
        "Should Battle Bog have a simple default HUD with an optional expanded information mode?",
      limits: "Inventory density and expert vocabulary are inappropriate baselines."
    },
    {
      id: "hud-apex",
      section: "hud",
      game: "Apex Legends",
      title: "Directional alerts and accessibility",
      role: "Specialist",
      image: "assets/apex.jpg",
      sourceUrl: "https://www.youtube.com/watch?v=6300yq0gKNs",
      contextUrl: "https://www.ea.com/able/resources/apex-legends/pc/features",
      sourceType: "Player gameplay thumbnail + official accessibility page",
      focus: "Contextual pings, teammate danger, direction and redundant accessibility cues.",
      context:
        "The first-person look is irrelevant; rate the information behavior.",
      question:
        "Should alerts reveal exact direction and distance, approximate direction, or only general danger?",
      limits: "Camera and genre are visually incompatible with Battle Bog."
    },
    {
      id: "hud-dragon-age",
      section: "hud",
      game: "Dragon Age: Origins",
      title: "Active-creature switching",
      role: "Specialist",
      image: "assets/dragon_age.jpg",
      sourceUrl: "https://www.youtube.com/watch?v=rE8BWSnSiYY",
      contextUrl: "https://www.youtube.com/watch?v=rE8BWSnSiYY",
      sourceType: "Community tactics demonstration",
      focus: "Selection emphasis, party state and autonomous behavior after switching.",
      context:
        "This solves the solo-control communication question, not the final visual style.",
      question:
        "How visually loud should creature switching be, and should allied AI intent be shown?",
      limits: "Older interface and tactical pacing are not presentation targets."
    },

    {
      id: "pipeline-live3d",
      section: "pipeline",
      game: "V Rising",
      title: "Restrained live 3D result",
      role: "Prototype",
      image: "assets/v_rising.jpg",
      sourceUrl: "https://store.steampowered.com/app/1604030/V_Rising/",
      contextUrl: "https://www.youtube.com/watch?v=YkyZv8BwQkM",
      sourceType: "Official store screenshot + player footage",
      focus: "Continuous turning, live materials, altitude and articulated bodies.",
      context:
        "Judge the visible dimensional result. Battle Bog would use a much lighter and brighter art direction.",
      question:
        "Is a restrained live-3D result worth prototyping if the Gothic styling is removed?",
      limits: "This image does not establish indie-scale production cost."
    },
    {
      id: "pipeline-hades",
      section: "pipeline",
      game: "Hades II",
      title: "Painted rendered-sprite ceiling",
      role: "Prototype",
      image: "assets/hades_ii.jpg",
      sourceUrl: "https://store.steampowered.com/app/1145350/Hades_II/",
      contextUrl: "https://www.youtube.com/watch?v=-SnaCUsUF3E",
      sourceType: "Official store screenshot + developer showcase",
      focus: "High-end painted dimensional sprites and controlled top-down lighting.",
      context:
        "This is a quality ceiling for 3D-derived sprites, not an assumed budget.",
      question:
        "Is this painted dimensional quality closer to the desired finish than live 3D?",
      limits: "Production scale and per-character frame volume are substantially higher."
    },
    {
      id: "pipeline-dead-cells",
      section: "pipeline",
      game: "Dead Cells",
      title: "3D-to-2D production method",
      role: "Prototype",
      image: "assets/dead_cells.jpg",
      sourceUrl: "https://store.steampowered.com/app/588650/Dead_Cells/",
      contextUrl: "https://www.gamedeveloper.com/production/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-i-dead-cells-i-",
      sourceType: "Official store screenshot + developer-authored deep dive",
      focus: "Reusable 3D rigs rendered into expressive low-resolution sprite frames.",
      context:
        "Rate the production principle and motion crispness, not the side-view pixel style.",
      question:
        "Is this 3D-derived sprite method worth testing even though the shipped look is not a target?",
      limits: "Side-view animation does not prove eight- or sixteen-direction scalability."
    },
    {
      id: "pipeline-cult",
      section: "pipeline",
      game: "Cult of the Lamb",
      title: "Illustrated 2D rigs in depth",
      role: "Boundary",
      image: "assets/cult_lamb.jpg",
      sourceUrl: "https://store.steampowered.com/app/1313140/Cult_of_the_Lamb/",
      contextUrl: "https://steamcommunity.com/app/1313140/discussions/0/3448087385671383167/",
      sourceType: "Official store screenshot + developer explanation",
      focus: "Illustrated cutout deformation in a depth-aware 3D world.",
      context:
        "This is a direct test of whether the cutout look itself clashes, independent of its production efficiency.",
      question:
        "Is this visible construction wrong for Battle Bog even if its pipeline is efficient?",
      limits: "Mostly camera-facing humanoid bodies do not solve authentic animal turning."
    },
    {
      id: "pipeline-dont-starve",
      section: "pipeline",
      game: "Don't Starve Together",
      title: "Modular authored-2D boundary",
      role: "Boundary",
      image: "assets/dont_starve.jpg",
      sourceUrl: "https://store.steampowered.com/app/322330/Dont_Starve_Together/",
      contextUrl: "https://gdcvault.com/play/1020949/2D-Animation-at-Klei",
      sourceType: "Official store screenshot + primary GDC talk",
      focus: "Reusable symbols, atlases, state graphs and concise authored motion.",
      context:
        "This card should settle whether the final look is rejected while the workflow remains useful.",
      question:
        "Should Battle Bog mine only the modular workflow and explicitly reject this visible 2D construction?",
      limits: "Do not interpret pipeline usefulness as style approval."
    },
    {
      id: "pipeline-rain-world",
      section: "pipeline",
      game: "Rain World",
      title: "Procedural-motion exception",
      role: "Specialist",
      image: "assets/rain_world.jpg",
      sourceUrl: "https://store.steampowered.com/app/312520/Rain_World/",
      contextUrl: "https://rainworldgame.com/",
      sourceType: "Official store screenshot + official game page",
      focus: "Code-driven contact and body motion combined with authored presentation.",
      context:
        "This tests whether selected creatures should retain procedural components inside a different final renderer.",
      question:
        "Should long bodies and swarms remain hybrid procedural exceptions even if the overall look is dimensional?",
      limits: "Its final side-view 2D appearance is not proposed as Battle Bog's style."
    }
  ]
};
