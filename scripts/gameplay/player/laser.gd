extends RayCast2D

@export var cast_speed: float = 7000.0
@export var max_length: float = 1400.0
@export var growth_time: float = 0.1
@export var color := Color.WHITE: set = set_color
@export var dig_half_width_tiles: int = 4  # tune until it is slightly wider than the trawler

@onready var line_2d: Line2D = $Line2D
@onready var casting_particles: GPUParticles2D = $CastingParticles2D
@onready var collision_particles: GPUParticles2D = $CollisionParticles2D
@onready var beam_particles: GPUParticles2D = $BeamParticles2D
@onready var fill: Line2D = $Line2D
@onready var wall: TileMapLayer = get_tree().get_first_node_in_group("wall")

var laser_damage_per_second: float = 0.0
var tween: Tween
var line_width: float
var is_casting := false: set = set_is_casting

func set_color(new_color: Color) -> void:
	color = new_color
	if line_2d == null:
		return
	line_2d.modulate = new_color

func _ready() -> void:
	enabled = true
	set_color(color)
	set_physics_process(false)
	
	# Set collision mask to detect walls (layer 4)
	collision_mask = 8  # Bit 3 = 2^3 = 8 (layer 4 = Wall)
	
	# Initialize laser damage from GameState
	laser_damage_per_second = GameState.get_laser_dps()

	if fill.points.size() < 2:
		fill.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])

	fill.points[1] = Vector2.ZERO
	line_width = fill.width

func _physics_process(delta: float) -> void:
	# grow the ray outward in its local direction (here: UP)
	target_position = (target_position + Vector2.UP * cast_speed * delta).limit_length(max_length)
	cast_beam(delta)

func set_is_casting(cast: bool) -> void:
	is_casting = cast

	if is_casting:
		target_position = Vector2.ZERO
		fill.points[1] = target_position
		appear()
	else:
		collision_particles.emitting = false
		disappear()

	set_physics_process(is_casting)
	beam_particles.emitting = is_casting
	casting_particles.emitting = is_casting

func cast_beam(delta: float) -> void:
	var cast_point := target_position

	# force raycast collision update before reading its result
	force_raycast_update()

	if is_colliding():
		var hit_world := get_collision_point()
		cast_point = to_local(hit_world)

		# orient collision particles
		var n := get_collision_normal()
		if collision_particles.process_material:
			collision_particles.process_material.direction = Vector3(n.x, n.y, 0)

		# apply damage to wall tile at hit point
		_apply_damage_to_wall(hit_world, delta)

	collision_particles.emitting = is_colliding()

	# update visuals
	fill.points[1] = cast_point
	collision_particles.position = cast_point
	beam_particles.position = cast_point * 0.5
	if beam_particles.process_material:
		beam_particles.process_material.emission_box_extents.x = cast_point.length() * 0.5

func appear() -> void:
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween()
	tween.tween_property(fill, "width", line_width, growth_time * 2.0).from(0.0)
	tween.play()

func disappear() -> void:
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween()
	tween.tween_property(fill, "width", 0.0, growth_time).from(fill.width)
	tween.play()

func _apply_damage_to_wall(hit_world: Vector2, delta: float) -> void:
	if wall == null:
		return

	var local_in_wall := wall.to_local(hit_world)
	var center_cell := wall.local_to_map(local_in_wall)

	# carve a horizontal strip centered on the ray hit
	for x in range(center_cell.x - dig_half_width_tiles, center_cell.x + dig_half_width_tiles + 1):
		var cell := Vector2i(x, center_cell.y)

		if wall.get_cell_source_id(cell) != -1 and "damage_cell" in wall:
			wall.damage_cell(cell, laser_damage_per_second * delta)
	


#
#@export var cast_speed: float = 7000.0
#@export var max_length: float = 1400.0
#@export var growth_time: float = 0.1
#
#
#@export var color := Color.WHITE: set = set_color
#
#@onready var line_2d: Line2D = $Line2D
#
#@export var laser_damage_per_second: float = GameState.get_laser_dps()
#
#@onready var casting_particles: GPUParticles2D = $CastingParticles2D
#@onready var collision_particles: GPUParticles2D = $CollisionParticles2D
#@onready var beam_particles: GPUParticles2D = $BeamParticles2D
#@onready var fill: Line2D = $Line2D
#
#@onready var wall: TileMapLayer = get_tree().get_first_node_in_group("wall")
#
#func set_color(new_color: Color) -> void:
	#color = new_color
	#if line_2d == null:
		#return
	#line_2d.modulate = new_color
#
#var tween: Tween
#var line_width: float
#
#var is_casting := false: set = set_is_casting
#
#
#func _ready() -> void:
	#enabled = true
	#set_color(color)
	#set_physics_process(false)
#
	#if fill.points.size() < 2:
		#fill.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
#
	#fill.points[1] = Vector2.ZERO
	#line_width = fill.width
#
	## debug: fire immediately so you can see it woks
	#set_is_casting(true)
#
#
#func _physics_process(delta: float) -> void:
	## grow the ray outward in its local direction (here: UP)
	#target_position = (target_position + Vector2.UP * cast_speed * delta).limit_length(max_length)
	#cast_beam(delta)
#
#func set_is_casting(cast: bool) -> void:
	#is_casting = cast
#
	#if is_casting:
		#target_position = Vector2.ZERO
		#fill.points[1] = target_position
		#appear()
	#else:
		#collision_particles.emitting = false
		#disappear()
#
	#set_physics_process(is_casting)
#
#
#func cast_beam(delta: float) -> void:
	#var cast_point := target_position
#
	## force raycast collision update before reading its result
	#force_raycast_update()
#
	#if is_colliding():
		#var hit_world := get_collision_point()
		#cast_point = to_local(hit_world)
#
		## orient collision particles
		#var n := get_collision_normal()
		#collision_particles.process_material.direction = Vector3(n.x, n.y, 0)
#
		## apply damage to wall tile at hit point
		#_apply_damage_to_wall(hit_world, delta)
#
#
	## update visuals
	#fill.points[1] = cast_point
	#collision_particles.position = cast_point
	#beam_particles.position = cast_point * 0.5
	##beam_particles.process_material.emission_box_extents.x = cast_point.length() * 0.5
#
#
#func appear() -> void:
	#if tween and tween.is_running():
		#tween.kill()
	#tween = create_tween()
	#tween.tween_property(fill, "width", line_width, growth_time * 2.0).from(0.0)
	#tween.play()
#
#
#func disappear() -> void:
	#if tween and tween.is_running():
		#tween.kill()
	#tween = create_tween()
	#tween.tween_property(fill, "width", 0.0, growth_time).from(fill.width)
	#tween.play()
#
#
#@export var dig_half_width_tiles: int = 4  # tune until it is slightly wider than the trawler
#
#func _apply_damage_to_wall(hit_world: Vector2, delta: float) -> void:
	#if wall == null:
		#return
#
	#var local_in_wall := wall.to_local(hit_world)
	#var center_cell := wall.local_to_map(local_in_wall)
#
	## carve a horizontal strip centered on the ray hit
	#for x in range(center_cell.x - dig_half_width_tiles, center_cell.x + dig_half_width_tiles + 1):
		#var cell := Vector2i(x, center_cell.y)
#
		#if wall.get_cell_source_id(cell) != -1 and "damage_cell" in wall:
			#wall.damage_cell(cell, laser_damage_per_second * delta)
