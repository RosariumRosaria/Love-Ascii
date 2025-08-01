return {
    vampire = {
        name = "A vampire",
        type = "enemy",
        chars = {"V"},
        color = {0.6, 0.6, 0.65, 1},
        description = "A vampire, try attacking it!",
        transparent = true,
        stats = {        
            health = {health = 10, maxHealth = 10},
        },  
        damage = 1,
        sight = 16,
        tags = {
            solid = false,
            moveable = true,
            tilelike = true,
            blocks = true,
            attackable = true,
            walkable = false
        },
    },
    crate = {
        name = "crate",
        description = "A heavy crate, try pushing it!",
        type = "prop",
        chars = {"#"},
        color = {0.38, 0.33, 0.30},
        tags = {
            solid = false,
            moveable = true,
            tilelike = true,
            blocks = true,
            walkable = false
        }
    },
    barricade = {
        name = "barricade",
        description = "A heavy barricade, try pushing it!",
        type = "prop",
        chars = {"[ ]", "[ ]"},
        color = {0.47, 0.23, 0.23, 1},
        tags = {
            solid = true,
            moveable = true,
            tilelike = true,
            blocks = true,
            walkable = false
        }
    },
    door = {
        name = "door",
        description = "A door, try opening it!",
        type = "prop",
        chars = {"[", "["},
        color = {0.47, 0.23, 0.23, 1},
        tags = {
            moveable = false,
            solid = true,
            walkable = false,
            tilelike = true,
            interactable = true,
            blocks = false
        },
        naturalRotation = 0,
        interaction = {
        naturalRotation = 90,
            chars = {"-  -", "-  -"},
            tags = {
                solid = false,
                walkable = true
            }
        }
    }, 
    window = {
        name = "window",
        description = "A window, try opening it!",
        type = "prop",
        chars = {" ", "- -", "- -"},
        color = {0.47, 0.33, 0.23, 1},
        tags = {
            moveable = false,
            solid = true,
            walkable = false,
            tilelike = true,
            interactable = true,
            blocks = false
        },
        naturalRotation = 90,
        interaction = {
            chars = {" ","'  '","'  '"},
            naturalRotation = 90,
            tags = {
                solid = false,
                walkable = false
            }
        }
    }
}