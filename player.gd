extends CharacterBody3D


const SPEED = 8.0
const JUMP_VELOCITY = 4.5

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var projection_rect: TextureRect = get_node("%ProjectionRect")

@onready var cam_pivot: Node3D = get_node("CameraPivot")
@onready var viewport: SubViewport = get_node("CamViewport")
@onready var camera: Camera3D = get_node("%Cam")
@onready var depth_viewport: SubViewport = get_node("%DepthViewport")
@onready var depth_camera: Camera3D = get_node("%DepthCam")
@onready var depth_quad: MeshInstance3D = get_node("%DepthQuad")
@onready var compare_cam: Camera3D = get_node("%CompareCam")
@onready var compare_viewport: SubViewport = get_node("%CompareViewport")
@onready var compare_viewport_container: SubViewportContainer = get_node("%CompareViewportContainer")

@onready var vsync_button: OptionButton = get_node("%VsyncOptionButton")
@onready var enabled_checkbox: CheckBox = get_node("%EnabledCheckbox")
@onready var timewarp_settings: VBoxContainer = get_node("%TimewarpSettings")

@onready var freeze_checkbox: CheckBox = get_node("%FreezeCheckbox")
@onready var stretch_checkbox: CheckBox = get_node("%StretchCheckbox")
@onready var reproject_checkbox: CheckBox = get_node("%ReprojectCheckbox")
@onready var compare_checkbox: CheckBox = get_node("%CompareCheckbox")

@onready var target_fps_slider: Slider = get_node("%TargetFPSSlider")
@onready var target_fps_label: Label = get_node("%TargetFPSLabel")

@onready var limit_fps_slider: Slider = get_node("%LimitFPSSlider")
@onready var limit_fps_label: Label = get_node("%LimitFPSLabel")

@onready var fps_label: Label = get_node("%FpsLabel")

# default settings

var timewarp_enabled = true

var stretch_borders = true
var reproject_movement = true
var freeze_cam = false
var target_fps = 30
var compare_enabled = true

func _ready():

	var img = viewport.get_texture()
	var depth = depth_viewport.get_texture()
	var compare_tex = compare_viewport.get_texture()

	var mat = projection_rect.material as ShaderMaterial
	mat.set_shader_parameter("cam_texture", img)
	mat.set_shader_parameter("depth_texture", depth)
	mat.set_shader_parameter("compare_texture", compare_tex)

	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	depth_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	compare_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

	depth_quad.visible = true

	enabled_checkbox.button_pressed = timewarp_enabled
	enabled_checkbox.toggled.connect(enable_toggled)

	timewarp_settings.visible = timewarp_enabled

	freeze_checkbox.button_pressed = freeze_cam
	freeze_checkbox.toggled.connect(freeze_toggled)
	stretch_checkbox.button_pressed = stretch_borders
	stretch_checkbox.toggled.connect(stretch_toggled)
	reproject_checkbox.button_pressed = reproject_movement
	reproject_checkbox.toggled.connect(reproject_toggled)
	compare_checkbox.button_pressed = compare_enabled
	compare_checkbox.toggled.connect(compare_toggled)

	target_fps_slider.value = target_fps
	target_fps_label.text = "%d" % target_fps
	target_fps_slider.value_changed.connect(fps_slider_changed)

	limit_fps_slider.value = Engine.max_fps
	if Engine.max_fps == 0:
		limit_fps_label.text = "none"
	else:
		limit_fps_label.text = "%d" % Engine.max_fps
	limit_fps_slider.value_changed.connect(fps_limit_slider_changed)

	vsync_button.selected = DisplayServer.window_get_vsync_mode()
	vsync_button.item_selected.connect(vsync_button_changed)

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func enable_toggled(val: bool):
	timewarp_enabled = val
	timewarp_settings.visible = timewarp_enabled

func freeze_toggled(val: bool):
	freeze_cam = val

func stretch_toggled(val: bool):
	stretch_borders = val

func reproject_toggled(val: bool):
	reproject_movement = val

func fps_slider_changed(val: float):
	target_fps = val
	target_fps_label.text = "%d" % val

func fps_limit_slider_changed(val: float):
	Engine.max_fps = val
	if Engine.max_fps == 0:
		limit_fps_label.text = "none"
	else:
		limit_fps_label.text = "%d" % Engine.max_fps

func compare_toggled(val: bool):
	compare_enabled = val

func vsync_button_changed(val: int):
	DisplayServer.window_set_vsync_mode(val)

var next_frame = 0

func _process(delta):

	var frame_time = 1 / float(target_fps)

	var size = get_viewport().size

	fps_label.text = "%dx%d @ %d FPS" % [size.x, size.y, Engine.get_frames_per_second()]

	if Input.is_action_just_pressed("toggle_all"):
		timewarp_enabled = !timewarp_enabled
		enabled_checkbox.button_pressed = timewarp_enabled
		timewarp_settings.visible = timewarp_enabled

	if Input.is_action_just_pressed("toggle_freeze"):
		freeze_cam = !freeze_cam
		freeze_checkbox.button_pressed = freeze_cam

	if Input.is_action_just_pressed("toggle_stretch"):
		stretch_borders = !stretch_borders
		stretch_checkbox.button_pressed = stretch_borders

	if Input.is_action_just_pressed("toggle_reprojection"):
		reproject_movement = !reproject_movement
		reproject_checkbox.button_pressed = reproject_movement

	if Input.is_action_just_pressed("toggle_compare"):
		compare_enabled = !compare_enabled
		compare_checkbox.button_pressed = compare_enabled

	# update camera

	var sizef = Vector2(size)
	viewport.size = size
	depth_viewport.size = size
	compare_viewport.size = size

	camera.global_transform = cam_pivot.global_transform
	depth_camera.global_transform = cam_pivot.global_transform
	compare_cam.global_transform = cam_pivot.global_transform

	var fov = camera.fov
	var near = camera.near
	var far = camera.far

	depth_camera.fov = fov
	depth_camera.near = near
	depth_camera.far = far
	compare_cam.fov = fov
	compare_cam.near = near
	compare_cam.far = far

	if compare_enabled:
		compare_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	else:
		compare_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

	var mat = projection_rect.material as ShaderMaterial
	mat.set_shader_parameter("is_enabled", timewarp_enabled)
	mat.set_shader_parameter("compare_enabled", compare_enabled)

	if timewarp_enabled:

		mat.set_shader_parameter("stretch_borders", stretch_borders)
		mat.set_shader_parameter("reproject_movement", reproject_movement)

		# update the projection cam in the shader with the actual camera postition
		mat.set_shader_parameter("near_clip", near)
		mat.set_shader_parameter("far_clip", far)
		mat.set_shader_parameter("cam_pos", camera.global_position)
		mat.set_shader_parameter("cam_forward", -camera.global_transform.basis.z)

		var projection = Projection.create_perspective(fov, size.aspect(), near, far, false)
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

			# todo
			# this will update the viewports in the next frame and not this frame.
			# this means the uniforms we are sending here are 1 frame out of date.
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			depth_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

			# update frozen cam position but only when we render a new frame from the camera
			mat.set_shader_parameter("frozen_cam_pos", camera.global_position)
			mat.set_shader_parameter("frozen_cam_forward", -camera.global_transform.basis.z)
			mat.set_shader_parameter("frozen_top_left", top_left)
			mat.set_shader_parameter("frozen_top_right", top_right)
			mat.set_shader_parameter("frozen_bottom_left", bottom_left)
			mat.set_shader_parameter("frozen_bottom_right", bottom_right)

			mat.set_shader_parameter("frozen_world_to_camera_matrix", Projection(view_mat))
			mat.set_shader_parameter("frozen_projection_matrix", Projection(proj_mat))

		else:
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			depth_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			next_frame += delta
	else:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		depth_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

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





