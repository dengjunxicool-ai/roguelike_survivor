extends SceneTree
var failed := false
class DamageReceiver extends Node2D:
	var tracker: RunStatsTracker
	var packets: Array[DamagePacket]=[]
	func take_damage(packet: DamagePacket) -> void:
		packets.append(packet)
		tracker.record_damage_taken(int(packet.raw_amount),{},packet)
func _init() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failed=true
		push_error("[MonsterMetrics] "+message)
func run() -> void:
	var tracker := RunStatsTracker.new()
	root.add_child(tracker)
	expect(tracker.has_method("record_enemy_attack_event") and tracker.has_method("record_wave_snapshot"),"monster and wave metric interfaces exist")
	if not tracker.has_method("record_enemy_attack_event"):
		tracker.queue_free()
		await process_frame
		quit(1)
		return
	tracker.reset_run(&"mage",&"abandoned_dungeon")
	tracker.call("record_enemy_attack_event",&"bomber",&"contact",&"attempt",false)
	tracker.call("record_enemy_attack_event",&"bomber",&"bug_explosion",&"warning",false)
	var enemy := preload("res://scenes/enemies/enemy.tscn").instantiate() as EnemyBase
	enemy.enemy_id=&"bomber"
	enemy.process_mode=Node.PROCESS_MODE_DISABLED
	root.add_child(enemy)
	var builder := preload("res://scripts/enemies/combat/enemy_damage_packet_builder.gd")
	var packet: DamagePacket=builder.build(enemy,17,"explosion",&"bug_explosion")
	tracker.record_damage_taken(17,{"damage_type":"area_direct"},packet)
	var summary := tracker.get_summary()
	expect(summary.has("monster_metrics") and summary.has("wave_metrics"),"summary extends existing fields")
	expect(summary.monster_metrics.bomber.attacks.contact.attempt.events==1,"contact actions remain separate")
	expect(summary.monster_metrics.bomber.attacks.bug_explosion.hit.damage==17,"real packet origin and skill receive damage attribution")
	tracker.call("record_wave_snapshot",{"wave_id":"wave_1","normal_budget":35,"normal_spawned":10,"alive_blocking":8,"mandatory_events_remaining":0})
	tracker.call("record_wave_snapshot",{"wave_id":"wave_1","normal_budget":35,"normal_spawned":35,"alive_blocking":2,"mandatory_events_remaining":0})
	expect(tracker.get_summary().wave_metrics.wave_1.peak_alive==8,"wave snapshot retains peak rather than last density")
	tracker.call("record_monster_lifecycle",enemy,&"natural_escape",{})
	tracker.call("record_monster_lifecycle",enemy,&"recycle",{})
	expect(tracker.get_summary().monster_metrics.bomber.lifecycle.natural_escape==1 and tracker.kill_count==0,"escape and recycle are separate from kills")
	var world := Node2D.new()
	world.process_mode=Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	var receiver := DamageReceiver.new()
	receiver.tracker=tracker
	receiver.add_to_group("player")
	world.add_child(receiver)
	var bomber := preload("res://scenes/enemies/enemy.tscn").instantiate() as EnemyBase
	bomber.enemy_id=&"bomber"
	world.add_child(bomber)
	bomber.target=receiver
	bomber.position=Vector2(40,0)
	var explosion_damage: int=bomber.contact_damage
	bomber.call("_update_behavior",0.1)
	bomber.call("_update_behavior",0.8)
	var actual: Dictionary=tracker.get_summary().monster_metrics.bomber.attacks
	var configured_explosion := String(GameData.get_enemy(&"bomber").skills[0].skill_id)
	expect(receiver.packets.size()==1 and String(receiver.packets[0].get_value("source_skill_id"))==configured_explosion,"real completed fuse carries configured skill identity")
	var explosion_metrics: Dictionary=actual.get(configured_explosion,{})
	expect(explosion_metrics.get("self_explode",{}).get("events",0)==1 and explosion_metrics.get("hit",{}).get("damage",0)==explosion_damage,"actual explosion cast and damage share one skill bucket")
	var charger := preload("res://scenes/enemies/enemy.tscn").instantiate() as EnemyBase
	charger.enemy_id=&"skeleton_captain"
	world.add_child(charger)
	charger.target=receiver
	charger.position=Vector2(30,0)
	charger.call("_apply_contact_damage")
	charger.call("_update_behavior",0.1)
	charger.call("_update_behavior",1.0)
	charger.call("_apply_contact_damage")
	var charge_metrics: Dictionary=tracker.get_summary().monster_metrics.skeleton_captain.attacks
	expect(receiver.packets.size()==3 and receiver.packets[1].get_value("source_skill_id")==&"contact" and receiver.packets[2].get_value("source_skill_id")==&"charge","real contact and charging packets have separate identities")
	expect(charge_metrics.get("charge",{}).get("start",{}).get("events",0)==1,"completed charge warning records one attack start")
	world.queue_free()
	tracker.reset_run(&"ranger",&"abyss_corridor")
	expect(tracker.get_summary().monster_metrics.is_empty() and tracker.get_summary().wave_metrics.is_empty(),"restart clears all added metrics")
	enemy.queue_free()
	tracker.queue_free()
	await process_frame
	quit(1 if failed else 0)
