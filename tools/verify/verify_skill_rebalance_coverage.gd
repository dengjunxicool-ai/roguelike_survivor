extends SceneTree
var failures: int=0
func _init() -> void: call_deferred("run")
func run() -> void:
 var catalog: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/skills.json")).skills
 var rows: Array=JSON.parse_string(FileAccess.get_file_as_string("res://docs/skills/skill_rebalance_coverage.json")).skills
 var cases: Array=JSON.parse_string(FileAccess.get_file_as_string("res://tools/verify/fusion_semantic_cases.json"))
 var base: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tools/verify/base_skill_behavior_cases.json"))
 var ids: Dictionary={};var accepted: int=0;var enabled: int=0
 check(catalog.size()==144 and rows.size()==144,"144 catalog and ledger rows")
 for row: Dictionary in rows:
  check(not ids.has(row.id),"unique ID "+row.id);ids[row.id]=true
  if row.status=="accepted": accepted+=1
  check(row.semantic_cases.size()>=1 and row.get("positive_case","")!="" and row.get("negative_case","")!="",row.id+" positive and semantic negative binding")
  for path: String in row.semantic_cases: check(FileAccess.file_exists("res://"+path.split("#")[0]),"executable evidence "+path)
 for skill: Dictionary in catalog:
  check(ids.has(skill.id),"preserve ID "+skill.id)
  if skill.skill_type=="fusion":
   if skill.get("offer_enabled",false): enabled+=1
   var matched: Array=cases.filter(func(c: Dictionary)->bool:return c.skill_id==skill.id)
   check(matched.size()==1 and matched[0].negative_fixtures.size()>=2,skill.id+" independent fusion cases")
  else: check(base.bindings.has(skill.id) or base.cases.any(func(c: Dictionary)->bool:return c.id==skill.id),skill.id+" real base behavior case")
 check(accepted==144,"all 144 accepted, actual "+str(accepted))
 check(enabled==60,"all 60 fusion offers enabled, actual "+str(enabled))
 if failures==0: print("[verify_skill_rebalance_coverage] PASS 144 accepted, 60 offers, positive and negative behavior evidence")
 quit(1 if failures>0 else 0)
func check(ok: bool,label: String) -> void:
 if not ok: failures+=1;print("FAIL "+label)
