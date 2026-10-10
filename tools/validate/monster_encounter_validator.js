function validate(documents){
 const errors=[], fail=(where)=>errors.push(where+': invalid encounter configuration');
 const waves=documents['res://data/waves/waves.json']?.waves??[], maps=documents['res://data/maps/maps.json']?.maps??[], enemies=documents['res://data/enemies/enemies.json']?.monsters??[];
 if(!Array.isArray(waves)||!Array.isArray(maps)||!Array.isArray(enemies))return errors;
 const enemyById=new Map(enemies.filter(e=>e&&typeof e==='object').map(e=>[e.id,e]));const waveById=new Map();const groups=new Set();
 for(const w of waves){if(!w||typeof w!=='object')continue;waveById.set(w.id,w);let previous=0,sum=0;
  if(!Array.isArray(w.spawn_stages)||w.spawn_stages.length!==3)fail('waves.'+w.id+'.spawn_stages');
  else {for(const s of w.spawn_stages){if(!s||![s.start_ratio,s.end_ratio,s.budget_ratio].every(Number.isFinite)||Math.abs(s.start_ratio-previous)>1e-6||s.end_ratio<=s.start_ratio||s.end_ratio>1||s.budget_ratio<=0){fail('waves.'+w.id+'.spawn_stages');continue;}previous=s.end_ratio;sum+=s.budget_ratio;}if(Math.abs(sum-1)>1e-6||Math.abs(previous-1)>1e-6)fail('waves.'+w.id+'.spawn_stages');}
  if(!Array.isArray(w.groups)||!w.groups.length){fail('waves.'+w.id+'.groups');continue;}
  for(const g of w.groups){groups.add(g?.id);if(!['filler','pursuit','ranged','support','charge'].includes(g?.role)||!Number.isFinite(g?.weight)||g.weight<=0)fail('waves.'+w.id+'.groups');}
 }
 const treasures=documents['res://data/waves/waves.json']?.rewards?.treasure_events??[];const seenTreasures=new Set();
 if(!Array.isArray(treasures))fail('rewards.treasure_events');
 else for(const event of treasures){if(!event||event.type!=='spawn_treasure'||!waveById.has(event.wave_id)||seenTreasures.has(event.wave_id)||!enemyById.has(event.enemy_id)||!Number.isFinite(event.chance)||event.chance<0||event.chance>1||!Number.isFinite(event.lifetime)||event.lifetime<=0||!Number.isInteger(event.max_per_run)||event.max_per_run<1||event.max_per_run>2||!Number.isFinite(event.wave_time)||event.wave_time<0||event.wave_time>Number(waveById.get(event.wave_id)?.duration_seconds??0))fail('rewards.treasure_events');seenTreasures.add(event?.wave_id);}
 for(const m of maps){const e=m?.encounter;if(!e||typeof e!=='object')continue;const where='maps.'+m.id+'.encounter';if(!['uniform','alternating_sides'].includes(e.spawn_pattern))fail(where+'.spawn_pattern');
  const overrides=e.group_weight_overrides??{};
  if(typeof overrides!=='object'||Array.isArray(overrides))fail(where+'.group_weight_overrides');
  else for(const [id,value]of Object.entries(overrides))if(!groups.has(id)||!Number.isFinite(value)||value<=0)fail(where+'.group_weight_overrides');
  if(!Array.isArray(e.elite_events)){fail(where+'.elite_events');continue;}const seen=new Set();for(const event of e.elite_events){if(!event||!waveById.has(event.wave_id)||seen.has(event.wave_id)||enemyById.get(event.enemy_id)?.enemy_rank!=='elite'||!Number.isFinite(event.wave_time)||event.wave_time<0||event.wave_time>Number(waveById.get(event.wave_id)?.duration_seconds??0))fail(where+'.elite_events');seen.add(event?.wave_id);}
 }
 return errors;
}
module.exports={validate};
