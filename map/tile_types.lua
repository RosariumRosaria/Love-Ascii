return {
    grass = {
        name = "grass",
        chars = {"."},
        walkable = true,
        color = {0.2, 0.5, 0.2, 1},
        transparent = true
    },

    shrub = {
        name = "shrub",
        chars = {"*"},
        walkable = true,
        color = {0.3, 0.6, 0.3, 1},
        transparent = true
    },

    hWall = {
        name = "wall",
        chars = {"|"},
        walkable = false,
        color = {0.6, 0.6, 0.65, 1},
        transparent = false
    },

    vWall = {
        name = "wall",
        chars = {"---"},
        walkable = false,
        color = {0.6, 0.6, 0.65, 1},
        transparent = false
    },

    cWall = {
        name = "wall",
        chars = {"+"},
        walkable = false,
        color = {0.6, 0.6, 0.65, 1},
        transparent = false
    },

    water = {
        name = "water",
        chars = {"~"},
        walkable = false,
        color = {0.2, 0.4, 0.8, 1},
        transparent = true
    },

    floor = {
        name = "floor",
        chars = {"::"},
        walkable = true,
        color = {0.6, 0.5, 0.4, 1},
        transparent = true
    },

    air = {
        name = "air",
        chars = {" "},
        walkable = true,
        color = {0.9, 0.9, 1.0, 0.0},
        transparent = true
    }
}
