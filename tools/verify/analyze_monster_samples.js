// Read captured evidence; never launches Godot or touches a save file.
const fs=require('fs'), path=require('path');
const [mode,root]=process.argv.slice(2);
if(!root?.replaceAll('\\','/').toLowerCase().startsWith('e:/codex/'))throw new Error('Output must stay under E:/codex');
const read=file=>JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,''));
if(mode==='flow'){
 const records=[],issues=[],keys=new Set();
 const replacement=process.argv[4];
 const batches=[];
 for(let shard=0;shard<4;shard++){
  batches.push(...read(path.join(root,`shard-${shard}`,'screening.json')).cases.filter(r=>!replacement||r.case.map!=='abyss_corridor'));
  if(replacement)batches.push(...read(path.join(replacement,`shard-${shard}`,'screening.json')).cases);
 }
 const expectedBudgets=read('data/waves/waves.json').waves;
 for(const record of batches){
   const data=read(record.report), key=[data.character,data.map,data.build_index,data.seed].join('/');
   if(keys.has(key))issues.push(key+': duplicate condition');keys.add(key);
   if(data.status!=='AUTOMATED_RESULT_VICTORY')issues.push(key+': '+data.status);
   if(data.final_wave?.delivery_failures?.length)issues.push(key+': delivery failures');
   const waves=Object.entries(data.summary.wave_metrics??{});
   if(waves.length!==8)issues.push(key+': missing wave metrics');
   let budget=0,delivered=0;
   for(const [id,wave] of waves){
    const snap=wave.snapshot??{};budget+=snap.normal_budget??0;delivered+=snap.normal_spawned??0;
    if(snap.normal_spawned!==snap.normal_budget||snap.mandatory_events_remaining!==0||snap.pending_spawn_count!==0||snap.pending_reveal_count!==0)issues.push(key+'/'+id+': incomplete delivery');
    const authored=expectedBudgets.find(w=>w.id===id);
    const expected=Math.round(authored.total_count*(data.map==='abyss_corridor'?1.12:1));
    if(snap.normal_budget!==expected)issues.push(key+'/'+id+': map pressure drift');
   }
   const treasure=data.summary.monster_metrics?.gem_slime?.lifecycle??{};
   if((treasure.created??0)>2)issues.push(key+': treasure cap exceeded');
   records.push({character:data.character,map:data.map,build:data.build_index,seed:data.seed,status:data.status,budget,delivered,treasures_created:treasure.created??0,treasures_escaped:treasure.natural_escape??0,wall_seconds:data.wall_seconds,assisted_kills:data.flow_assisted_kills,report:record.report});
 }
 if(records.length!==240)issues.push('Expected 240 unique conditions');
 const summary={scope:'16x high-health assisted flow; player automatic attacks disabled; not normal combat balance or human win rate',conditions:records.length,issues,by_map:{},records};
 for(const map of [...new Set(records.map(r=>r.map))]){const group=records.filter(r=>r.map===map);summary.by_map[map]={conditions:group.length,ordinary_budget:group.reduce((sum,r)=>sum+r.budget,0),ordinary_delivered:group.reduce((sum,r)=>sum+r.delivered,0),treasures_created:group.reduce((sum,r)=>sum+r.treasures_created,0)};}
 fs.writeFileSync(path.join(root,'summary.json'),JSON.stringify(summary,null,2));
 const fields=['character','map','build','seed','status','budget','delivered','treasures_created','treasures_escaped','wall_seconds','assisted_kills'];
 fs.writeFileSync(path.join(root,'summary.csv'),fields.join(',')+'\n'+records.map(r=>fields.map(f=>r[f]).join(',')).join('\n')+'\n');
 console.log(JSON.stringify({conditions:summary.conditions,issues:summary.issues,by_map:summary.by_map},null,2));
 if(issues.length)process.exitCode=1;
}else if(mode==='performance'){
 const records=[],regressions=[];
 for(const scenario of ['normal','boss']){
  const before=read(path.join(root,`before-${scenario}`,'latest_samples.json')),after=read(path.join(root,`after-${scenario}`,'latest_samples.json'));
  if(before.seed!==after.seed||before.rendering_method!==after.rendering_method||before.status!=='PASS'||after.status!=='PASS')throw new Error('Incompatible or failed performance samples');
  if(JSON.stringify(before.initial_loadout)!==JSON.stringify(after.initial_loadout)||JSON.stringify(before.initial_loadout)!==JSON.stringify(before.final_loadout)||JSON.stringify(after.initial_loadout)!==JSON.stringify(after.final_loadout))throw new Error('Performance skill builds changed or differ');
  const changes={};
  for(const field of ['p50_frame_ms','p95_frame_ms','p99_frame_ms']){changes[field]=(after[field]/before[field]-1)*100;if(changes[field]>10)regressions.push({scenario,field,percent:changes[field]});}
  records.push({scenario,before,after,percent_changes:changes});
 }
 fs.writeFileSync(path.join(root,'comparison.json'),JSON.stringify({records,regressions},null,2));
 console.log(JSON.stringify({records:records.map(r=>({scenario:r.scenario,before:{p50:r.before.p50_frame_ms,p95:r.before.p95_frame_ms,p99:r.before.p99_frame_ms,peaks:r.before.per_frame_peaks},after:{p50:r.after.p50_frame_ms,p95:r.after.p95_frame_ms,p99:r.after.p99_frame_ms,peaks:r.after.per_frame_peaks},percent_changes:r.percent_changes})),regressions},null,2));
 if(regressions.length)process.exitCode=1;
}else throw new Error('Use flow or performance');
