return {
    trail = {
        name = "trail",
        lifespan = .6,
        initialSpan = .6,
        i = 1,
        decay = true,
        colors = {{0.75, 0.75, 0.75, 0.5}},
        sizes = {1,1,1}
    },
    oldTrail = { -- Around mostly to keep the previous syntax marked
        name = "oldTrail",
        decays = nil,
        i = 1,
        lifespan = 0.2,
        initialSpan = 0.2,
        colors = {{0.5, 0.5, 0.5, 0.25}, {0.25, 0.25, 0.25, 0.15} ,{0.1, 0.1, 0.1, 0.1}}
    }
}