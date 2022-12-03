extends CharacterBody3D


const SPEED = 8.0
const JUMP_VELOCITY = 4.5

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var cam_pivot: Node3D = get_node("CameraPivot")
@onready var projection_rect: TextureRect = get_node("ProjectionRect")
@onready var viewport: SubViewport = get_node("CameraPivot/SubViewport")
@onready var camera: Camera3D = get_node("CameraPivot/SubViewport/Cam")
@onready var depth_viewport: SubViewport = get_node("CameraPivot/DepthViewport")
@onready var depth_camera: Camera3D = get_node("CameraPivot/DepthViewport/DepthCam")
@onready var depth_quad: MeshInstance3D = get_node("CameraPivot/DepthViewport/DepthQuad")

@onready var enabled_checkbox: CheckBox = get_node("ControlPanel/VBoxContainer/EnabledCheckbox")

@onready var freeze_checkbox: CheckBox = get_node("ControlPanel/VBoxContainer/FreezeCheckbox")
@onready var stretch_checkbox: CheckBox = get_node("ControlPanel/VBoxContainer/StretchCheckbox")
@onready var reproject_checkbox: CheckBox = get_node("ControlPanel/VBoxContainer/ReprojectCheckbox")

@onready var fps_slider: Slider = get_node("ControlPanel/VBoxContainer/TargetFPSSlider")
@onready var fps_label: Label = get_node("ControlPanel/VBoxContainer/HBoxContainer/TargetFPSLabel")

var is_enabled = true

var stretch_borders = false
var reproject_movement = false
var freeze_cam = false
var target_fps = 30

func _ready():
	var img = viewport.get_texture()
	var depth = depth_viewport.get_texture()
	var mat = projection_rect.material as ShaderMaterial
	mat.set_shader_parameter("cam_texture", img)
	mat.set_shader_parameter("depth_texture", depth)

	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	depth_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

	depth_quad.visible = true

	enabled_checkbox.button_pressed = is_enabled
	enabled_checkbox.toggled.connect(enable_toggled)

	freeze_checkbox.disabled = !is_enabled
	stretch_checkbox.disabled = !is_enabled
	reproject_checkbox.disabled = !is_enabled
	fps_slider.editable = !is_enabled

	freeze_checkbox.button_pressed = freeze_cam
	freeze_checkbox.toggled.connect(freeze_toggled)

	stretch_checkbox.button_pressed = stretch_borders
	stretch_checkbox.toggled.connect(stretch_toggled)

	reproject_checkbox.button_pressed = reproject_movement
	reproject_checkbox.toggled.connect(reproject_toggled)

	fps_slider.value = target_fps
	fps_label.text = "%d" % target_fps
	fps_slider.value_changed.connect(fps_slider_changed)

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func enable_toggled(val: bool):
	is_enabled = val
	freeze_checkbox.disabled = !is_enabled
	stretch_checkbox.disabled = !is_enabled
	reproject_checkbox.disabled = !is_enabled
	fps_slider.editable = !is_enabled

func freeze_toggled(val: bool):
	freeze_cam = val

func stretch_toggled(val: bool):
	stretch_borders = val

func reproject_toggled(val: bool):
	reproject_movement = val

func fps_slider_changed(val: float):
	target_fps = val
	fps_label.text = "%d" % val

var next_frame = 0

func _process(delta):

	var frame_time = 1 / target_fps

	if Input.is_action_just_pressed("toggle_all"):
		is_enabled = !is_enabled
		enabled_checkbox.button_pressed = is_enabled
		freeze_checkbox.disabled = !is_enabled
		stretch_checkbox.disabled = !is_enabled
		reproject_checkbox.disabled = !is_enabled
		fps_slider.editable = !is_enabled

	if Input.is_action_just_pressed("toggle_freeze"):
		freeze_cam = !freeze_cam
		freeze_checkbox.button_pressed = freeze_cam

	if Input.is_action_just_pressed("toggle_stretch"):
		stretch_borders = !stretch_borders
		stretch_checkbox.button_pressed = stretch_borders

	if Input.is_action_just_pressed("toggle_reprojection"):
		reproject_movement = !reproject_movement
		reproject_checkbox.button_pressed = reproject_movement

	# update camera

	var size = get_viewport().size
	var sizef = Vector2(size)
	viewport.size = size
	depth_viewport.size = size

	camera.global_transform = cam_pivot.global_transform
	depth_camera.global_transform = cam_pivot.global_transform

	var mat = projection_rect.material as ShaderMaterial
	mat.set_shader_parameter("is_enabled", is_enabled)

	if is_enabled:

		mat.set_shader_parameter("stretch_borders", stretch_borders)
		mat.set_shader_parameter("reproject_movement", reproject_movement)

		# update the projection cam in the shader with the actual camera postition
		# todo find a better way to send the camera frustum and transform to the shader
		mat.set_shader_parameter("near_clip", camera.near)
		mat.set_shader_parameter("far_clip", camera.far)
		mat.set_shader_parameter("cam_pos", camera.global_position)
		mat.set_shader_parameter("cam_forward", -camera.global_transform.basis.z)

		var projection = Projection.create_perspective(camera.fov, size.aspect(), camera.near, camera.far, false)

		var view_mat = Projection(camera.global_transform).inverse()
		var proj_mat = projection

		mat.set_shader_parameter("world_to_camera_matrix", view_mat)
		mat.set_shader_parameter("projection_matrix", proj_mat)

		var top_left = camera.project_ray_normal(Vector2.ZERO * sizef)
		var top_right = camera.project_ray_normal(Vector2.RIGHT * sizef)
		var bottom_left = camera.project_ray_normal(Vector2.DOWN * sizef)
		var bottom_right = camera.project_ray_normal(Vector2.ONE * sizef)
		mat.set_shader_parameter("top_left", top_left)
		mat.set_shader_parameter("top_right", top_right)
		mat.set_shader_parameter("bottom_left", bottom_left)
		mat.set_shader_parameter("bottom_right", bottom_right)

		if next_frame >= frame_time and not freeze_cam:
			next_frame = 0

			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			depth_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	#		await RenderingServer.frame_post_draw

			# update frozen cam position but only when we render a new frame from the camera
			mat.set_shader_parameter("frozen_cam_pos", camera.global_position)
			mat.set_shader_parameter("frozen_cam_forward", -camera.global_transform.basis.z)
			mat.set_shader_parameter("frozen_top_left", top_left)
			mat.set_shader_parameter("frozen_top_right", top_right)
			mat.set_shader_parameter("frozen_bottom_left", bottom_left)
			mat.set_shader_parameter("frozen_bottom_right", bottom_right)

			mat.set_shader_parameter("frozen_world_to_camera_matrix", Projection(view_mat))
			mat.set_shader_parameter("frozen_projection_matrix", Projection(proj_mat))

	#		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	#		depth_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		else:
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			depth_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			next_frame += delta
	else:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("move_jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

func _input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sensitivity = 0.01
		# look left/right
		self.rotate_y(event.relative.x * -sensitivity)

		# look up/down
		cam_pivot.rotate_x(event.relative.y * -sensitivity)

		# clamp head rotation
		var rot = cam_pivot.rotation
		rot.x = clamp(rot.x, -PI / 2.0, PI / 2.0)
		cam_pivot.rotation = rot

	else:

		if event.is_action_pressed("ui_cancel", false):
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED





