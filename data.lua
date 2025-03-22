--data.lua

local combinator = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
combinator.name = "spoilage-scanner"
combinator.sprites = make_4way_animation_from_spritesheet({ 
  layers ={
    {
      scale = 0.5,
      filename = "__spoilage-scanner__/graphics/entity/spoilage-scanner.png",
      width = 114,
      height = 102,
      shift = util.by_pixel(0, 5)
    },
    {
      scale = 0.5,
      filename = "__spoilage-scanner__/graphics/entity/spoilage-scanner-shadow.png",
      width = 98,
      height = 66,
      shift = util.by_pixel(8.5, 5.5),
      draw_as_shadow = true
    }
  }
})
combinator.sprites.north, combinator.sprites.south = combinator.sprites.south, combinator.sprites.north
combinator.sprites.east, combinator.sprites.west = combinator.sprites.west, combinator.sprites.east
combinator.activity_led_sprites.north, combinator.activity_led_sprites.south = combinator.activity_led_sprites.south, combinator.activity_led_sprites.north
combinator.activity_led_sprites.east, combinator.activity_led_sprites.west = combinator.activity_led_sprites.west, combinator.activity_led_sprites.east
combinator.circuit_wire_connection_points[1], combinator.circuit_wire_connection_points[3] = combinator.circuit_wire_connection_points[3], combinator.circuit_wire_connection_points[1]
combinator.circuit_wire_connection_points[2], combinator.circuit_wire_connection_points[4] = combinator.circuit_wire_connection_points[4], combinator.circuit_wire_connection_points[2]
combinator.minable.result = "spoilage-scanner"

local combinator_item = table.deepcopy(data.raw["item"]["constant-combinator"])
combinator_item.name = "spoilage-scanner"
combinator_item.place_result = "spoilage-scanner"
combinator_item.icon = "__spoilage-scanner__/graphics/icons/spoilage-scanner.png"

local combinator_recipe = {
  type = "recipe",
  name = "spoilage-scanner",
  enabled = false,
  ingredients =
  {
    {type = "item", name = "copper-cable", amount = 5},
    {type = "item", name = "advanced-circuit", amount = 2}
  },
  results = {{type="item", name="spoilage-scanner", amount=1}}
}

if mods["pyalternativeenergy"] then
  combinator_recipe.ingredients = {
    {type = "item", name = "copper-cable", amount = 5},
    {type = "item", name = "electronic-circuit", amount = 2},
    {type = "item", name = "battery-mk01", amount = 1}
  }
end

table.insert(data.raw["technology"]["advanced-combinators"].effects, { type = "unlock-recipe", recipe = "spoilage-scanner" } )


data:extend(
  {
    combinator,
    combinator_item,
    combinator_recipe,
  })