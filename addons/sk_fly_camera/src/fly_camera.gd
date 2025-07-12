@icon("../icons/fly_camera.svg")
class_name FlyCamera
extends CharacterBody3D

##
## A free flying camera, handy for prototyping.
## [br][br]
##
##
## This camera allows to quickly be able to fly around at runtime.
## Just put it in a scene and it should be good to go. You can optionally
## tweak its settings in the inspector.
## [br][br]
##
## The camera node itself is not an actual camera, but a [CharacterBody3D], so
## it has no visual preview in the inspector. You can still align it to the
## camera in the 3D View, by clicking [param Perspective > Align Transform With View].
## [br][br]
##
## You will also see a warning in the [param Scene] tree about the [CharacterBody3D]
## not having a shape. Normally a flying camera doesn't need any collisions,
## and you can ignore the warning. The camera still supports collisions, though,
## either by turning on [param Use Collisions] in the inspector, or by
## manually adding a [CollisionShape3D] node with a shape of your choice.
## [br][br]
##[color=white][b]Note:[/b][/color] the collisions are added at runtime, so
## turning on [param Use Collisions] will not suppress the warning.
## [br][br]
##
## The camera controls can be changed. By default it uses the [param WASD]
## keys for movement, [param Shift] to move faster, [param Ctrl] to move slower, and
## the [param Right Mouse Button] to activate/deactivate the mouse controls
## (capturing/uncapturing the mouse pointer).
## [br][br]
##
## This camera was intended for quick use, so the default controls are easy to
## change in the camera script by hand (in the [param _actions_to_key] dictionary).
## However, if you prefer, you can also set the following input actions in
## your project settings, and the camera will automatically use them instead:
## [codeblock]
##cam_forward
##cam_backward
##cam_left
##cam_right
##cam_faster
##cam_slower
##cam_activate
## [/codeblock]
## [color=white][b]Note:[/b][/color] the mouse button used to activate the
## camera can easily be changed in the inspector, so for that end you don't
## need to use [param cam_activate] input action.
## This action is provided in case you'd like to use a keyboard key instead.
##
##


## How to activate mouse controls.
enum ActivationMode {
	ON_CLICK,  ## Click to activate, click again to deactivate.
	ON_HOLD,   ## Hold mouse button to activate, release to deactivate.
}

## Where to revert the mouse pointer when releasing mouse controls.
enum RevertMouseOption {
	CLICK_POSITION,  ## The position where the mouse was initially clicked.
	VIEWPORT_CENTER, ## The center of the viewport.
}

enum MouseButton {
	LEFT = 1,
	RIGHT,
	MIDDLE,
}


#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=

#    User Properties / Settings

#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=
#region user_settings
@export_group("Mouse Settings")

## How to activate the mouse controls.
@export var activation_mode   := ActivationMode.ON_CLICK

## Where the mouse pointer should be at when releasing mouse controls.
@export var revert_mouse_to   := RevertMouseOption.CLICK_POSITION

## Which mouse button activates mouse control.
@export var mouse_button := MouseButton.RIGHT


## The mouse sensitivity in each axis.
@export var mouse_sensitivity := Vector2(2.2, 2.2)

## If true the mouse's vertical axis will be inverted.
@export var invert_y := false

## If true, the key controls will still work when the mouse controls
## are inactive.
@export var keep_key_controls := true


@export_group("Camera Settings")
## The camera's movement speed.
@export var fly_speed := 20.0

## The camera's acceleration.
## [br][br]
## For simplicity, this also doubles as friction.
@export var acceleration : int = 10

## The factor by which to multiply or divide the camera speed in order to
## move faster or slower.
@export var speed_factor : int = 3

## Adds a sphere collision shape to the camera. You can setup
## the collision layers as you please.
@export var use_collision := false:
	set(enable):
		use_collision = enable
		_set_collisions(enable)

## If true, the camera will use the default controls and ignore any
## input actions defined in the project settings.
@export var use_default_controls := false


#endregion



#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=

#    Internals

#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=
#region internal_Stuff
const _ACTION_FORWARD  := "cam_forward"
const _ACTION_BACKWARD := "cam_backward"
const _ACTION_LEFT     := "cam_left"
const _ACTION_RIGHT    := "cam_right"
const _ACTION_FASTER   := "cam_faster"
const _ACTION_SLOWER   := "cam_slower"
const _ACTION_ACTIVATE := "cam_activate"

var _actions_to_key := {
	_ACTION_FORWARD  : KEY_W,
	_ACTION_BACKWARD : KEY_S,
	_ACTION_LEFT     : KEY_A,
	_ACTION_RIGHT    : KEY_D,
	_ACTION_FASTER   : KEY_SHIFT,
	_ACTION_SLOWER   : KEY_CTRL,
	_ACTION_ACTIVATE : mouse_button,
}

const _PITCH_LIMIT : int   = 90


var _mouse_click_pos : Vector2
var _mouse_hidden    : bool

var _coll     : CollisionShape3D
var _camera   : Camera3D          # The actual, internal camera node.
var _cam_pivot: Node3D            # The Y rotation pivot node

var _yaw   : float = 0
var _pitch : float = 0



func _ready() -> void:
	_cam_pivot = Node3D.new()
	add_child(_cam_pivot)

	_camera = Camera3D.new()
	_cam_pivot.add_child(_camera)
	_camera.current = true

	# if this node was rotated in the editor, use that as default rotation
	var rot := rotation_degrees
	rotation = Vector3.ZERO
	set_rot(rot)


func _unhandled_input(event: InputEvent) -> void:
	_check_mouse_capture(event)

	if not _mouse_hidden:
		return

	## Camera motion
	if event is InputEventMouseMotion:
		_yaw = fmod(_yaw - event.relative.x * mouse_sensitivity.x/10, 360)

		if not invert_y: _pitch = max(min(_pitch - event.relative.y * mouse_sensitivity.y/10.0, _PITCH_LIMIT), -_PITCH_LIMIT)
		else:            _pitch = max(min(_pitch + event.relative.y * mouse_sensitivity.y/10.0, _PITCH_LIMIT), -_PITCH_LIMIT)

		_cam_pivot.rotation.y = deg_to_rad(_yaw)
		_camera.rotation.x = deg_to_rad(_pitch)


func _physics_process(delta: float) -> void:
	var aim : Basis = _camera.get_camera_transform().basis

	var dir := Vector3()
	var spd := fly_speed

	if _mouse_hidden or keep_key_controls:
		if _is_cam_action_pressed(_ACTION_FORWARD):  dir -= aim[2]
		if _is_cam_action_pressed(_ACTION_BACKWARD): dir += aim[2]
		if _is_cam_action_pressed(_ACTION_LEFT):     dir -= aim[0]
		if _is_cam_action_pressed(_ACTION_RIGHT):    dir += aim[0]
		if _is_cam_action_pressed(_ACTION_FASTER):   spd *= speed_factor
		if _is_cam_action_pressed(_ACTION_SLOWER):   spd /= speed_factor

	dir = dir.normalized()

	var target := dir * spd
	velocity = velocity.lerp( target, acceleration*delta )
	move_and_slide()

	if is_zero_approx(velocity.length()):
		velocity = Vector3.ZERO


func _is_cam_action_pressed(action:String) -> bool:
	if not use_default_controls and InputMap.has_action(action):
		return Input.is_action_pressed(action)
	return Input.is_key_pressed(_actions_to_key[action])


func _set_collisions(enable:bool) -> void:
	if enable:
		_coll = CollisionShape3D.new()
		_coll.shape = SphereShape3D.new()
		add_child(_coll)
	else:
		_coll.queue_free()
		_coll = null


func _check_mouse_capture(event:InputEvent) -> void:
	var button_state := 0    # 0- unchaged, 1- pressed, 2- released

	if not use_default_controls and InputMap.has_action(_ACTION_ACTIVATE):
		if event.is_action_pressed(_ACTION_ACTIVATE):    button_state = 1
		elif event.is_action_released(_ACTION_ACTIVATE): button_state = 2
	elif event is InputEventMouseButton and event.button_index == mouse_button:
		button_state = 1 if event.pressed else 2

	if button_state == 0: return

	match activation_mode:
		ActivationMode.ON_HOLD:
			set_active(button_state == 1)
		ActivationMode.ON_CLICK:
			if button_state == 1:
				set_active(not _mouse_hidden)


func _revert_mouse_pos() -> void:
	var vp := get_viewport()
	match revert_mouse_to:
		RevertMouseOption.CLICK_POSITION:
			vp.warp_mouse( _mouse_click_pos )
		RevertMouseOption.VIEWPORT_CENTER:
			vp.warp_mouse(vp.get_visible_rect().size/2)


#endregion



#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=

#        Public API

#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=
## Returns the actual camera that is used internally.
func get_camera() -> Camera3D:
	return _camera


## Sets the FlyCamera's rotation to [param rot].
## [br][br]
## [color=white][b]Note:[/b][/color] don't set the rotation directly, as the
## rotation of the root node doesn't represent the rotation of the actual camera.
func set_rot(rot:Vector3) -> void:
	_yaw   = rot.y
	_pitch = rot.x
	_cam_pivot.rotation_degrees.y = _yaw
	_camera.rotation_degrees.x    = _pitch


## Returns the rotation of the camera.
## [br][br]
## [color=white][b]Note:[/b][/color] don't get the rotation directly, as the
## rotation of the root node doesn't represent the rotation of the actual camera.
func get_rot() -> Vector3:
	return Vector3(_camera.rotation.x, _cam_pivot.rotation.y, 0)


## Activate or deactivate the mouse controls
func set_active(enable:bool) -> void:
	if enable:
		_mouse_click_pos = get_viewport().get_mouse_position()
		_mouse_hidden = true
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_mouse_hidden = false
		_revert_mouse_pos()
