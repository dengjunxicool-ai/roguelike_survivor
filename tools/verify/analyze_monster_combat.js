const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const characters=JSON.parse(fs.readFileSync(path.join(__dirname,'../../data/characters/characters.json'),'utf8')).characters;
const health=Object.fromEntries(characters.map(c=>[c.id,c.base_stats.max_hp]));
function median(values){const a=[...values].sort((a,b)=>a-b);return a.length?a[Math.floor(a.length/2)]:null;}
function normalizeAssistMetadata(report,sourcePath,sourceHash){
  if(report.sampling_scope!=='normal-health automated combat; fixed 60 Hz, time scale 1; not human win rate'||report.sampling_time_scale!==1||report.flow_assisted_kills!==0||report.player_attacks_disabled!==false||report.initial_player?.max_health!==health[report.character])throw Error('refusing to relabel assisted or unknown evidence');
  const result=structuredClone(report);
  if(result.survival_assist===true){
    result.survival_assist=false;
    result.metadata_correction={field:'survival_assist',original:true,corrected:false,reason:'Inherited writer emitted a constant true; independent code review verified both survival overrides are no-ops and normal tick never calls them. No measurements changed.',source_path:sourcePath,source_sha256:sourceHash};
  }
  return result;
}
function summarize(reports){
  const result={cases:reports.length,outcomes:{},issues:[],by_character:{},by_map:{},conditions:[],ttk_groups:[],coverage:{boss_cases:0,elite_cases:0},scope:'normal-health bot, experimental starting builds, auto movement/cards; not human acceptance'};
  const identities=new Set(),conditions=new Map(),ttk=new Map();
  for(const report of reports){
    const identity=[report.character,report.map,report.build_index,report.seed].join(':');
    if(!Object.hasOwn(health,report.character)||!['abandoned_dungeon','toxic_fog_graveyard','lava_temple','abyss_corridor'].includes(report.map)||![0,1,2].includes(report.build_index)||!Number.isInteger(report.seed))result.issues.push('invalid case '+identity);
    if(identities.has(identity))result.issues.push('duplicate '+identity);
    identities.add(identity);
    if(report.sampling_time_scale!==1||report.flow_assisted_kills!==0||report.player_attacks_disabled!==false||report.survival_assist!==false)result.issues.push('assistance '+identity);
    if(typeof report.duration_seconds!=='number'||!Number.isFinite(report.duration_seconds)||report.duration_seconds<0)result.issues.push('invalid duration '+identity);
    if(report.initial_player?.max_health!==health[report.character])result.issues.push('initial health '+identity);
    if(!['AUTOMATED_RESULT_DEFEAT','AUTOMATED_RESULT_VICTORY','CENSORED_TIME_LIMIT'].includes(report.status))result.issues.push('invalid status '+identity);
    result.outcomes[report.status]=(result.outcomes[report.status]||0)+1;
    for(const [field,key] of [['by_character',report.character],['by_map',report.map]]){
      const bucket=result[field][key]??={samples:0,outcomes:{},times:[],damage:0};
      bucket.samples++;bucket.times.push(report.duration_seconds);bucket.damage+=report.summary?.damage_taken_total||0;
      bucket.outcomes[report.status]=(bucket.outcomes[report.status]||0)+1;
    }
    const key=[report.character,report.map,report.build_index].join(':');
    const condition=conditions.get(key)||{character:report.character,map:report.map,build:report.build_index,seeds:[],times:[],outcomes:{},failure_sources:{}};
    condition.seeds.push(report.seed);condition.times.push(report.duration_seconds);
    condition.outcomes[report.status]=(condition.outcomes[report.status]||0)+1;
    condition.failure_sources[report.failure_source||report.summary?.last_damage_source||'none']=(condition.failure_sources[report.failure_source||report.summary?.last_damage_source||'none']||0)+1;
    conditions.set(key,condition);
    const rows=report.enemy_observations||[];
    if(rows.some(x=>x.rank==='boss'))result.coverage.boss_cases++;
    if(rows.some(x=>x.rank==='elite'))result.coverage.elite_cases++;
    for(const row of rows){
      if(row.ttk_seconds!=null&&(row.outcome!=='killed'||row.ttk_seconds<0))result.issues.push('invalid TTK '+identity);
      if(row.first_hit_seconds<0||row.first_hit_seconds==null)continue;
      const context=row.first_hit_context||{};
      const loadout=report.combat_loadouts?.[context.loadout_ref]||context.loadout||[];
      if(!loadout.length)result.issues.push('missing TTK loadout '+identity);
      const signature=loadout.map(s=>`${s.id}/${s.level}/${s.rarity}`).sort().join('|');
      const phase=row.first_hit_seconds<60?'0-60':row.first_hit_seconds<150?'60-150':'150+';
      const optionCount=Number(String(context.loadout_ref||'0:0').split(':')[1]);
      const growth=(report.selected_options||[]).slice(0,optionCount).map(x=>({id:x.option?.id,rarity:x.option?.rarity,payload:x.option?.payload}));
      const fields={character:report.character,map:report.map,build:report.build_index,enemy:row.enemy_id,rank:row.rank,phase,level:context.player?.level??context.level,loadout:signature,growth_options:JSON.stringify(growth)};
      const groupKey=JSON.stringify(fields);
      const group=ttk.get(groupKey)||{...fields,kills:[],censored:0,seeds:new Set(),initial_healths:new Set()};
      group.seeds.add(report.seed);group.initial_healths.add(row.initial_health);
      if(row.outcome==='killed'&&row.ttk_seconds!=null)group.kills.push(row.ttk_seconds);else group.censored++;
      ttk.set(groupKey,group);
    }
  }
  for(const field of ['by_character','by_map'])for(const bucket of Object.values(result[field])){
    bucket.median_seconds=median(bucket.times);bucket.range_seconds=[Math.min(...bucket.times),Math.max(...bucket.times)];delete bucket.times;
  }
  result.conditions=[...conditions.values()].map(c=>{const {times,...rest}=c;return {...rest,median_seconds:median(times),range_seconds:[Math.min(...times),Math.max(...times)]};});
  result.ttk_groups=[...ttk.values()].map(g=>{const {kills,seeds,initial_healths,...rest}=g;return {...rest,completed_kills:kills.length,median_ttk_seconds:median(kills),kill_range_seconds:kills.length?[Math.min(...kills),Math.max(...kills)]:null,seeds:[...seeds],initial_healths:[...initial_healths]};});
  return result;
}
function csv(rows){if(!rows.length)return '';const columns=Object.keys(rows[0]);const cell=v=>'"'+String(typeof v==='object'?JSON.stringify(v):v??'').replaceAll('"','""')+'"';return columns.map(cell).join(',')+'\n'+rows.map(r=>columns.map(k=>cell(r[k])).join(',')).join('\n')+'\n';}
if(require.main===module){
  const root=path.resolve(process.argv[2]||'E:/codex/monster-system/stage-d-final');
  if(!root.replaceAll('\\','/').toLowerCase().startsWith('e:/codex/'))throw Error('output must be under E:/codex');
  const reports=[];
  let correctionCount=0;
  for(const directory of fs.readdirSync(root)){
    const indexPath=path.join(root,directory,'screening.json');
    if(!fs.existsSync(indexPath))continue;
    const batch=JSON.parse(fs.readFileSync(indexPath,'utf8'));
    const normalizedIndex=structuredClone(batch);
    for(let i=0;i<batch.cases.length;i++){
      const item=batch.cases[i];
      const source=fs.readFileSync(item.report);
      let report=JSON.parse(source.toString('utf8'));
      if(process.argv.includes('--normalize-assist-label')){
        report=normalizeAssistMetadata(report,item.report,crypto.createHash('sha256').update(source).digest('hex'));
        const normalizedPath=path.join(path.dirname(item.report),'normalized_samples.json');
        if(!path.resolve(normalizedPath).replaceAll('\\','/').toLowerCase().startsWith(root.replaceAll('\\','/').toLowerCase()+'/'))throw Error('report outside the requested batch');
        const content=JSON.stringify(report,null,2);
        if(fs.existsSync(normalizedPath)){
          if(fs.readFileSync(normalizedPath,'utf8')!==content)throw Error('refusing to overwrite changed normalized evidence');
        }else fs.writeFileSync(normalizedPath,content,{flag:'wx'});
        normalizedIndex.cases[i].report=normalizedPath;
        if(report.metadata_correction)correctionCount++;
      }
      reports.push(report);
    }
    if(process.argv.includes('--normalize-assist-label'))fs.writeFileSync(path.join(root,directory,'normalized_screening.json'),JSON.stringify(normalizedIndex,null,2));
  }
  const result=summarize(reports);
  result.metadata_label_corrections=correctionCount;
  if(process.argv.includes('--expect-240')&&(result.cases!==240||result.conditions.length!==48||result.conditions.some(c=>JSON.stringify([...c.seeds].sort())!==JSON.stringify([618,619,620,621,622]))))result.issues.push('expected exact 4 characters x 4 maps x 3 builds x 5 seeds');
  fs.writeFileSync(path.join(root,'combat_summary.json'),JSON.stringify(result,null,2));
  fs.writeFileSync(path.join(root,'conditions.csv'),'\uFEFF'+csv(result.conditions));
  fs.writeFileSync(path.join(root,'ttk.csv'),'\uFEFF'+csv(result.ttk_groups));
  console.log(JSON.stringify({cases:result.cases,outcomes:result.outcomes,coverage:result.coverage,issues:result.issues.slice(0,10),ttk_groups:result.ttk_groups.length}));
  if(result.issues.length)process.exitCode=1;
}
module.exports={summarize,normalizeAssistMetadata};
