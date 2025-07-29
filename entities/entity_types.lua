return {
    vampire = {
        name = "vampire",
        char = "V",
        description = "A vampire, try attacking it!",
        transparent = true,
        health = 10,
        moveable = false,
        walkable = false,
        attackable = true,
        defaultInteraction = "attack"
    },
    crate = {
        name = "crate",
        description = "A heavy crate, try pushing it!",
        char = "#",
        transparent = false,
        moveable = true,
        walkable = false,
    },
    door = {
        name = "door",
        char = "+",
        description = "A door, try opening it!",
        moveable = false,
        transparent = false,
        walkable = false,
        interactable = true,
        interaction = {
            char = "'",
            transparent = true,
            walkable = true
        }
    },
    dummy = { -- TODO
        name = "dummy",
        char = "~",
        transparent = true,
        moveable = true,
        walkable = true
    }
}