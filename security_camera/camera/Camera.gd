extends Node3D

enum State {Search, Track, Suspicious}

#Exported Fields
@export_range(5, 30, 1)var _viewAngle:float = 15
@export var _moveSpeedSearch:float = 1
@export var _moveSpeedTrack:float = 3
@export var _isSearchLoop:bool = false
# Fields - protected or private 
var _currentState:State
var _target:Marker3D
var _hub:MeshInstance3D
var _cam:MeshInstance3D
var _spotLight:SpotLight3D
var _rayCast:RayCast3D
var _detectionArea:Area3D
var _playerInDetectionArea:Node3D = null # Retype to your player
var _timerSuspicious:Timer
var _activeTween:Tween
var _searchPoints = []
var _currentSearchPointTargetIdx:int = 0 # The point the camera will look at next
var _searchDirection:int = 1
var _colorSearch:Color = Color.YELLOW
var _colorTrack:Color = Color.RED
var _colorSuspicious:Color = Color.ORANGE

# Called when the node enters the scene tree for the first time.
func _ready():
	_target = get_node("Target")
	_hub = get_node("Base/Hub")
	_cam = _hub.get_node("Cam")
	_spotLight = _cam.get_node("Lense/SpotLight3D")
	_detectionArea = _cam.get_node("Lense/Area3D")
	_rayCast = _cam.get_node("Lense/RayCast3D")
	_timerSuspicious = get_node("TimerSuspicious")
	_spotLight.spot_angle = _viewAngle;
	UpdateStatusColor(_colorSearch);
	
	_detectionArea.connect("body_entered", OnDetectionAreaBodyEntered)
	_detectionArea.connect("body_exited", OnDetectionAreaBodyExited)
	_timerSuspicious.connect("timeout", OnTimerSuspiciousTimeout)
	
	_currentState = State.Search
	
	if !Engine.is_editor_hint():
		for child in get_children():
			if child is SearchPoint:
				_searchPoints.append(child)
		
		_target.position = _searchPoints[0].position
		MoveLookTargetToNextSearchPoint()
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	var _isPlayerVisible:bool = IsPlayerVisible()
	#print(IsPlayerVisible());
	match (_currentState):
		State.Search:
			if _isPlayerVisible:
				print("Search")
				TransitionToTrack()

		State.Track:
			if !_isPlayerVisible:
				print("Track")
				TransitionToSuspicious()
			else:
				print("TargetPlayer")
				MoveLookTargetTowardPlayer(delta)
				# Notify other game objects of player position here with signal or some other method for updates every physics frame

		
		State.Suspicious:
			if _isPlayerVisible:
				print("Suspic")
				_timerSuspicious.stop()
				TransitionToTrack()
		
		_: 
			print("Default")

	PointAtTarget(delta)



func OnDetectionAreaBodyEntered(body:Node3D):
			print("Enter to camera")
			_playerInDetectionArea = body
			print(body.name)
			_rayCast.enabled = true

func OnDetectionAreaBodyExited(body:Node3D):
	print("Exit")
	print(body.name)
	_playerInDetectionArea = null;
	_rayCast.enabled = false;

func OnTimerSuspiciousTimeout():
	TransitionToSearch()

func PointAtTarget(delta:float):
	var targetPosXZ:Vector2 = Vector2(_target.position.x, _target.position.z)
	var forwardDir:Vector2 = Vector2(0, 1)
	var hubAngle:float = forwardDir.angle_to(targetPosXZ)
	
	_hub.rotation = Vector3(0, -hubAngle, 0)
	_cam.look_at(_target.global_position)

func IsPlayerVisible():
	if _playerInDetectionArea == null: 
		return false
	var playerRelativePosition:Vector3 = _rayCast.to_local(_playerInDetectionArea.global_position)
	var viewAngle:float = Vector3.FORWARD.angle_to(playerRelativePosition)

	var isPlayerInFOV:bool = viewAngle <= deg_to_rad(_viewAngle)
	if !isPlayerInFOV: 
		return false

	# CONSIDER: Do multiple raycasts to differeent parts of player to determine visibility
	_rayCast.target_position = _rayCast.to_local(_playerInDetectionArea.global_position + Vector3(0, 0.5, 0)) #So not casting to feet.
	_rayCast.force_raycast_update()

	print(_rayCast.get_collider())
	return !_rayCast.get_collider()

func UpdateStatusColor(newColor:Color):
	_spotLight.light_color = newColor
	_cam.set_instance_shader_parameter("color", newColor)
	
func TransitionToSearch():
	if _activeTween != null:
		_activeTween.kill()
	UpdateStatusColor(_colorSearch)
	_currentState = State.Search
	MoveLookTargetToNextSearchPoint();

func TransitionToTrack():
	if _activeTween != null: _activeTween.kill()
	UpdateStatusColor(_colorTrack);
	_currentState = State.Track;

func TransitionToSuspicious():
	if _activeTween != null: _activeTween.kill()
	UpdateStatusColor(_colorSuspicious)
	_currentState = State.Suspicious;
	_timerSuspicious.start();
	
func MoveLookTargetToNextSearchPoint():
	if _isSearchLoop:
		print("movetoNext")
		_currentSearchPointTargetIdx += _searchDirection
		if _currentSearchPointTargetIdx == _searchPoints.size():
			_currentSearchPointTargetIdx = 0
	else:
		if _currentSearchPointTargetIdx + _searchDirection == _searchPoints.size():
			_searchDirection = -1
		elif  _currentSearchPointTargetIdx + _searchDirection == -1:
			_searchDirection = 1
		_currentSearchPointTargetIdx += _searchDirection

	var _positionTarget:Vector3 = _searchPoints[_currentSearchPointTargetIdx].position
	var _translationLength:float = _target.position.distance_to(_positionTarget)
	var panTime:float = _translationLength / _moveSpeedSearch

	_activeTween = create_tween()
	_activeTween.tween_property(_target, "position", _positionTarget, panTime)
	_activeTween.tween_interval(_searchPoints[_currentSearchPointTargetIdx].waitTime)
	_activeTween.connect("finished", MoveLookTargetToNextSearchPoint)
	_activeTween.play()

func MoveLookTargetTowardPlayer(delta:float):
	var newPos:Vector3 = _target.global_position.move_toward(_playerInDetectionArea.global_position, _moveSpeedTrack * delta)
	_target.global_position = newPos
