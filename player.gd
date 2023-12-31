extends CharacterBody3D

@onready var camera = $Camera3D
@onready var anim_player = $AnimationPlayer
@onready var flash = $Camera3D/Pistol/MuzzleFlash
@onready var ray_cast = $Camera3D/RayCast3D
@onready var sound = $Camera3D/Pistol/Sound
@onready var decal = preload("res://decal_scene.tscn")

signal health_changed(health_value)

const SPEED = 10.0
const JUMP_VELOCITY = 10.0
const GRAVITY = 20

var health = 3

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())

func _ready():
	if not is_multiplayer_authority(): return
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true

func _unhandled_input(event):
	if not is_multiplayer_authority(): return
	
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * 0.005)
		camera.rotate_x(-event.relative.y * 0.005)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2) 

	if Input.is_action_just_pressed("shoot") and anim_player.current_animation != "shoot":
		play_shoot_effects.rpc()
		if ray_cast.is_colliding():
			var hit = ray_cast.get_collider()
			var normal = ray_cast.get_collision_normal()
			var point = ray_cast.get_collision_point()
			var dec_in = decal.instantiate()
			hit.add_child(dec_in)
			dec_in.global_transform.origin = point
			if normal == Vector3.DOWN:
				dec_in.rotation_degrees.x = 90
			elif normal != Vector3.UP:
				dec_in.look_at(point - normal, Vector3(0,1,0))
			if hit is CharacterBody3D:
				hit.receive_damage.rpc_id(hit.get_multiplayer_authority())

func _physics_process(delta):
	if not is_multiplayer_authority(): return
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	if anim_player.current_animation == "shoot":
		pass
	elif input_dir != Vector2.ZERO and is_on_floor():
		anim_player.play("move")
	else:
		anim_player.play("idle")

	move_and_slide()

@rpc("call_local")
func play_shoot_effects():
	anim_player.stop()
	anim_player.play("shoot")
	flash.restart()
	flash.emitting = true
	sound.play()

@rpc("any_peer")
func receive_damage():
	health -= 1
	if health <= 0:
		health = 3
		position = Vector3.ZERO
	health_changed.emit(health)

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "shoot":
		anim_player.play("idle")
