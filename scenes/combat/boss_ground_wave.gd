class_name BossGroundWave
extends Node3D
## 巨兽的行进震波/根须地刺：预警、逐圈传播、可跳过震波、每个区域只伤害一次。
var boss: Node3D
var age := 0.0
var delay := 0.0
var radius := 9.0
var damage := 24.0
var roots := false
var hit := false
var pieces: Array[Node3D] = []
var ring: Node3D
static func spawn(owner_boss: Node3D, center: Vector3, wait: float, extent: float, amount: float, root := false) -> BossGroundWave:
	var wave := BossGroundWave.new()
	wave.boss=owner_boss;wave.delay=wait;wave.radius=extent;wave.damage=amount;wave.roots=root
	owner_boss.get_parent().add_child(wave)
	wave.global_position=center+Vector3.UP*0.08
	wave.add_to_group("boss_hazard")
	wave.ring=(load("res://art/models/prop/boss_shock_ring.glb") as PackedScene).instantiate()
	wave.add_child(wave.ring)
	wave.ring.scale=Vector3(extent,0.5,extent)
	var packed := load("res://art/models/prop/boss_root_spike.glb" if root else "res://art/models/prop/boss_debris.glb") as PackedScene
	for i in 24:
		var piece := packed.instantiate() as Node3D
		wave.add_child(piece);wave.pieces.append(piece)
		piece.rotation.y=TAU*i/24
		if root:piece.rotation.z=randf_range(-0.18,0.18)
		var a := TAU*i/24
		piece.position=Vector3(cos(a)*extent,0,sin(a)*extent)
		piece.scale=Vector3(0.3,0.12,0.3)
	return wave
func _physics_process(delta: float) -> void:
	if not is_instance_valid(boss) or not DartCombat.alive(boss) or (boss.boss!=null and boss.boss.is_staggered()):
		queue_free();return
	age += delta
	var t := age-delay
	if t<0:
		for piece in pieces: piece.scale.y=0.12+0.12*(1+sin(age*12))
		return
	var r := radius if roots else clampf(t/0.75,0.0,1.0)*radius
	ring.scale=Vector3(maxf(0.1,r),maxf(0.0,1.0-t),maxf(0.1,r))
	for i in pieces.size():
		var a := TAU*i/pieces.size()
		var local_radius := r*(0.35+0.325*(i%3)) if roots else r
		pieces[i].position=Vector3(cos(a)*local_radius,0.0 if roots else maxf(0.0,sin(t*PI/0.8))*0.35,sin(a)*local_radius)
		pieces[i].scale=Vector3.ONE*maxf(0.0,1.0-t/(1.0 if roots else 0.95))
		if roots: pieces[i].scale.y=maxf(0.0,sin(t*PI/1.05))*1.2
	var target := boss._get_player() as PlayerController
	if damage>0.0 and not hit and target!=null and not target.is_dead():
		var offset := target.global_position-global_position
		var distance := Vector2(offset.x,offset.z).length()
		var contact := distance<=radius if roots else absf(distance-r)<0.65 and distance<=radius+0.3
		if contact and (roots or offset.y<0.7):
			hit=true
			target.take_damage(damage,boss)
			if roots: target.apply_effect("rooted",1.0,1.0)
			else: target.apply_external_knockback(offset.normalized(),4.5)
			target.add_camera_shake(0.06,0.22)
	if t>1.05:queue_free()
