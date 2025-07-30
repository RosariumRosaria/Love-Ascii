return {
    vampire = {
        name = "vampire",
        chars = {"V"},
        color = {0.6, 0.6, 0.65, 1},
        description = "A vampire, try attacking it!",
        transparent = true,
        stats = {        
            health = {health = 10, maxHealth = 10},
        },  
        damage = 1,
        moveable = false,
        walkable = false,
        attackable = true,
        blocks = true,
        defaultInteraction = "attack"
    },
    crate = {
        name = "crate",
        description = "A heavy crate, try pushing it!",
        chars = {"#"},
        color = {0.38, 0.33, 0.30},
        transparent = true,
        moveable = true,
        blocks = true,
        walkable = false
    },
    barricade = {
        name = "barricade",
        description = "A heavy barricade, try pushing it!",
        chars = {"[ ]", "[ ]"},
        color = {0.74, 0.66, 0.60},
        transparent = false,
        moveable = true,
        tilelike = true,
        blocks = true,
        walkable = false
    },
    door = {
        name = "door",
        chars = {"[ ]", "[ ]"},
        color = {0.6, 0.6, 0.65, 1},
        description = "A door, try opening it!",
        moveable = false,
        transparent = false,
        walkable = false,
        tilelike = true,
        interactable = true,
        blocks = true,
        interaction = {
            chars = {"=", "="},
            transparent = true,
            walkable = true
        }
    },
    window = {
        window = "window",
        chars = {"", "-"},
        color = {0.5, 0.5, 0.75, 1},
        description = "A window, try opening it!",
        moveable = false,
        transparent = false,
        walkable = false,
        tilelike = true,
        interactable = true,
        blocks = false,
        interaction = {
            chars = {"", "'"},
            transparent = true,
            walkable = true
        }
    },
    dummy = { -- TODO
        name = "dummy",
        chars = {"~"},
        color = {0.6, 0.6, 0.65, 1},
        transparent = true,
        moveable = true,
        blocks = true,
        walkable = true
    }
}