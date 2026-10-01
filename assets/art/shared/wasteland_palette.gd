## Shared wasteland vehicle palette, matched to the concept sheet
## `assets/art/vehicles/vehicle-design.png`: teal and orange two-tone panels
## with rust flecks, orange tube frames and rims, dark knobby rubber, bone skull
## emblems, warm round lamps. Rust, scrap and gunmetal remain for underbodies,
## bumpers and engines.
##
## One place for the colours and material settings every wasteland vehicle
## concept uses, so the buggy, the motorbike and whatever comes next read as one
## kit. Call [method materials] once per model with its rust seed.
extends RefCounted

const ProceduralTextures := preload("res://assets/art/shared/procedural_textures.gd")
const Kitbash := preload("res://assets/art/shared/kitbash.gd")

const TEAL := Color(0.18, 0.60, 0.58)
const TEAL_DARK := Color(0.11, 0.40, 0.40)
const ORANGE := Color(0.90, 0.45, 0.14)
const ORANGE_DARK := Color(0.62, 0.30, 0.10)
const BONE_WHITE := Color(0.93, 0.90, 0.82)
const RUST := Color(0.50, 0.25, 0.12)
const RUST_DARK := Color(0.30, 0.16, 0.10)
const RUST_ORANGE := Color(0.70, 0.36, 0.15)
const SCRAP := Color(0.46, 0.42, 0.38)
const BONE := Color(0.78, 0.70, 0.56)
const STEEL := Color(0.66, 0.67, 0.68)
const STEEL_DARK := Color(0.30, 0.31, 0.33)
const GUNMETAL := Color(0.19, 0.20, 0.22)
const OLIVE := Color(0.36, 0.38, 0.26)
const RUBBER := Color(0.10, 0.09, 0.08)
const TREAD := Color(0.17, 0.15, 0.13)
const GLASS := Color(0.16, 0.22, 0.26)
const LEATHER := Color(0.42, 0.22, 0.13)
const FLAG_RED := Color(0.92, 0.42, 0.10)
const STRIPE := Color(0.82, 0.62, 0.16)
const LAMP := Color(1.0, 0.86, 0.60)
const HOLE := Color(0.02, 0.02, 0.02)
const CANISTER := Color(0.50, 0.60, 0.60)


## Builds the named material set for one model. Keys: teal, teal_dark, orange,
## orange_dark, rim, skull (a bone skull decal for a quad), rust, rust_dark,
## rust_orange, scrap, bone, steel, steel_dark, gunmetal, olive, rubber, tread,
## glass, leather, flag, stripe, hole, lamp, canister. Painted panels carry a
## paint-chip map (rust flecks); rust-family and bone parts the mottled rust
## map; metal, rubber and cloth the grime map.
static func materials(seed: int) -> Dictionary:
	var rust_tex := ProceduralTextures.mottle(seed,
			Color(0.45, 0.37, 0.32), Color(1.0, 0.96, 0.90), Color(1.0, 0.72, 0.42), 0.6)
	var grime_tex := ProceduralTextures.mottle(seed + 1,
			Color(0.62, 0.62, 0.60), Color(1.0, 1.0, 1.0), Color(0.85, 0.80, 0.72), 0.3)
	var paint_tex := ProceduralTextures.mottle(seed + 2,
			Color(0.80, 0.78, 0.74), Color(1.0, 1.0, 1.0), Color(0.55, 0.30, 0.16), 0.85)
	var m: Dictionary = {}
	m["teal"] = Kitbash.flat_material(TEAL, 0.7, 0.05, paint_tex, 0.9)
	m["teal_dark"] = Kitbash.flat_material(TEAL_DARK, 0.75, 0.05, paint_tex, 0.9)
	m["orange"] = Kitbash.flat_material(ORANGE, 0.7, 0.05, paint_tex, 0.9)
	m["orange_dark"] = Kitbash.flat_material(ORANGE_DARK, 0.75, 0.05, paint_tex, 0.9)
	m["rim"] = Kitbash.flat_material(ORANGE, 0.5, 0.35, grime_tex, 1.2)
	var skull := Kitbash.flat_material(BONE_WHITE, 0.8, 0.0)
	skull.albedo_texture = ProceduralTextures.skull_texture()
	skull.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	skull.alpha_scissor_threshold = 0.5
	skull.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	skull.cull_mode = BaseMaterial3D.CULL_DISABLED
	m["skull"] = skull
	var screen := Kitbash.flat_material(Color(0.80, 0.88, 0.90, 0.6), 0.15, 0.3)
	screen.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	screen.cull_mode = BaseMaterial3D.CULL_DISABLED
	m["screen"] = screen
	m["rust"] = Kitbash.flat_material(RUST, 0.95, 0.05, rust_tex, 0.6)
	m["rust_dark"] = Kitbash.flat_material(RUST_DARK, 0.95, 0.05, rust_tex, 0.8)
	m["rust_orange"] = Kitbash.flat_material(RUST_ORANGE, 0.9, 0.05, rust_tex, 0.5)
	m["scrap"] = Kitbash.flat_material(SCRAP, 0.8, 0.25, rust_tex, 0.7)
	m["bone"] = Kitbash.flat_material(BONE, 0.9, 0.0, rust_tex, 0.7)
	m["steel"] = Kitbash.flat_material(STEEL, 0.45, 0.7, grime_tex, 1.0)
	m["steel_dark"] = Kitbash.flat_material(STEEL_DARK, 0.6, 0.5, grime_tex, 1.0)
	m["gunmetal"] = Kitbash.flat_material(GUNMETAL, 0.7, 0.4, grime_tex, 0.8)
	m["olive"] = Kitbash.flat_material(OLIVE, 0.9, 0.0, grime_tex, 0.8)
	m["rubber"] = Kitbash.flat_material(RUBBER, 0.95, 0.0, grime_tex, 1.2)
	m["tread"] = Kitbash.flat_material(TREAD, 0.95, 0.0, grime_tex, 1.2)
	m["glass"] = Kitbash.flat_material(GLASS, 0.25, 0.4)
	m["leather"] = Kitbash.flat_material(LEATHER, 0.85, 0.0, grime_tex, 1.0)
	m["flag"] = Kitbash.flat_material(FLAG_RED, 0.95, 0.0, rust_tex, 1.5)
	m["stripe"] = Kitbash.flat_material(STRIPE, 0.9, 0.0, grime_tex, 1.0)
	m["hole"] = Kitbash.flat_material(HOLE, 1.0, 0.0)
	m["canister"] = Kitbash.flat_material(CANISTER, 0.7, 0.1, grime_tex, 1.5)
	var lamp := Kitbash.flat_material(LAMP, 0.3, 0.0)
	lamp.emission_enabled = true
	lamp.emission = LAMP
	lamp.emission_energy_multiplier = 0.4
	m["lamp"] = lamp
	return m
