-- runtime global settings

data:extend{
    {
        type = "bool-setting",
        name = "spoilage-sensor-invert-output",
        setting_type = "runtime-global",
        default_value = false,
        order = "a"
    },
    {
        type = "int-setting",
        name = "spoilage-sensor-signal-update-interval",
        setting_type = "runtime-global",
        default_value = 20,
        minimum_value = 1,
        maximum_value = 36000,
        order = "b"
    },
    {
        type = "int-setting",
        name = "spoilage-sensor-signal-scan-interval",
        setting_type = "runtime-global",
        default_value = 240,
        minimum_value = 1,
        maximum_value = 36000,
        order = "c"
    },
}