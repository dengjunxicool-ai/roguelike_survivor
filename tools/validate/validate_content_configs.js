const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'../..');
function validateDocuments(documents,schema,exists=p=>fs.existsSync(path.join(root,p.slice(6)))){
 const errors=[]; const indexes={};
 const fail=(where,message)=>errors.push(`${where}: ${message}`);
 const kind=v=>v===null?'null':Array.isArray(v)?'array':typeof v;
 for(const entry of schema.documents){
  const doc=documents[entry.path];
  if(kind(doc)!=='object'){fail(entry.path,'root must be an object');continue;}
  for(const key of Object.keys(doc))if(!entry.keys.includes(key))fail(entry.path+'.'+key,'unknown root field');
  for(const key of entry.keys)if(!Object.hasOwn(doc,key))fail(entry.path+'.'+key,'missing root field');
  else if(!entry.root_fields[key].includes(kind(doc[key])))fail(entry.path+'.'+key,'invalid root type');
  for(const section of entry.sections){
   const items=doc[section.key]; const rule=schema.domains[section.domain];
   if(!Array.isArray(items)){fail(entry.path+'.'+section.key,'must be an array');continue;}
   indexes[section.domain]??=new Set();
   for(const [i,item]of items.entries()){
    const where=`${entry.path}.${section.key}[${item?.[section.id_key]??i}]`;
    if(kind(item)!=='object'){fail(where,'definition must be an object');continue;}
    for(const field of rule.required)if(!Object.hasOwn(item,field)||item[field]===''||item[field]===null)fail(where+'.'+field,'required nonempty field');
    for(const[key,value]of Object.entries(item)){
     if(!Object.hasOwn(rule.fields,key))fail(where+'.'+key,'unknown definition field');
     else if(!rule.fields[key].includes(kind(value)))fail(where+'.'+key,'invalid type '+kind(value));
    }
    for(const[field,fields]of Object.entries(rule.object_fields??{}))if(kind(item[field])==='object')for(const[k,v]of Object.entries(item[field])){
     if(!Object.hasOwn(fields,k))fail(where+'.'+field+'.'+k,'unknown nested field');
     else if(!fields[k].includes(kind(v)))fail(where+'.'+field+'.'+k,'invalid nested type');
    }
    for(const[field,keys]of Object.entries(rule.object_required??{}))if(kind(item[field])==='object')for(const k of keys)if(!Object.hasOwn(item[field],k))fail(where+'.'+field+'.'+k,'required nested field');
    if(section.id_key){const id=item[section.id_key];if(typeof id!=='string'||!id.trim())fail(where,'invalid ID');else if(indexes[section.domain].has(id))fail(where,'duplicate ID '+id);else indexes[section.domain].add(id);}
    if(section.domain==='skills'){
     if(!schema.skill_types.includes(item.skill_type))fail(where+'.skill_type','unknown skill type');
     if(!['active','passive'].includes(item.slot_category))fail(where+'.slot_category','unknown slot category');
     if(item.runtime_rules!=null&&kind(item.runtime_rules)!=='object')fail(where+'.runtime_rules','must be an object');
    }
    if(section.domain==='enemies'&&!schema.enemy_ranks.includes(item.enemy_rank))fail(where+'.enemy_rank','unknown rank');
   }
  }
 }
 const modifierFields=new Set(schema.modifier_fields);
 // summon_id names a transient summon node; only summon_definition_id is a catalog reference.
 const refs={starting_skill_id:'skills',replaces_skill:'skills',summon_definition_id:'summons',status_id:'statuses',status:'statuses',max_stack_status:'statuses',boss_id:'enemies',enemy_id:'enemies',character_id:'characters',map_id:'maps',target_status:'statuses',required_status:'statuses',boss_status_id:'statuses',school:'gods'};
 function visit(value,where,key='',domain=''){
  if(refs[key]&&(typeof value!=='string'||!value.trim()))fail(where,'reference must be a nonempty string');
  if(key==='fusion_school'&&value!==null&&(typeof value!=='string'||!indexes.gods?.has(value)))fail(where,'unknown fusion school');
  if(schema.resource_fields.includes(key)&&(typeof value!=='string'||value&&!value.startsWith('res://')))fail(where,'resource path must use res://');
  if(key==='scene_path'&&value==='')fail(where,'scene path cannot be empty');
  const arrayDomains={enemy_ids:'enemies',required_skills:'skills',required_schools:'gods'};
  if(arrayDomains[key]){
   if(!Array.isArray(value))fail(where,'reference list must be an array');
   else for(const id of value)if(typeof id!=='string'||!id.trim()||!indexes[arrayDomains[key]]?.has(id))fail(where,'unknown '+arrayDomains[key]+' reference '+id);
  }
  if(typeof value==='number'&&!Number.isFinite(value))fail(where,'nonfinite number');
  if(key==='range_unit_px'&&typeof value==='number'&&value<=0)fail(where,'range unit must be positive');
  if(typeof value==='number'&&['duration','tick_interval','cooldown','max_level','max_stacks','max_count','max_hp','collision_radius'].includes(key)&&value<0)fail(where,'negative '+key);
  if(typeof value==='string'&&value.startsWith('res://')&&!exists(value))fail(where,'missing resource '+value);
  if(typeof value==='string'&&value&&refs[key]&&!indexes[refs[key]]?.has(value))fail(where,'unknown '+refs[key]+' reference '+value);
  if(key==='skill_id'&&typeof value==='string'&&value&&!indexes.skills?.has(value)&&!indexes.enemy_skills?.has(value))fail(where,'unknown skill reference '+value);
  if(key==='required_skills'&&Array.isArray(value))for(const id of value)if(!indexes.skills.has(id))fail(where,'unknown required skill '+id);
  if(modifierFields.has(key)) validateModifiers(value,where);
  if(key==='level_modifiers'){
   if(!Array.isArray(value))fail(where,'level_modifiers must be an array');
   else value.forEach((level,i)=>validateModifiers(level,where+'['+i+']'));
  }
  if(kind(value)==='object'&&value.type==='add_modifier')validateModifiers([value],where);
  if(Array.isArray(value))value.forEach((v,i)=>visit(v,where+'['+i+']','',domain));
  else if(kind(value)==='object')for(const[k,v]of Object.entries(value))visit(v,where+'.'+k,k,domain);
 }
 function validateModifiers(value,where){
   if(!Array.isArray(value))fail(where,'Modifier configuration must be an effect list');
   else for(const [i,effect]of value.entries()){
    const loc=where+'['+i+']';
    if(kind(effect)!=='object'){fail(loc,'effect must be an object');continue;}
    for(const f of ['stat','op','value','scope','source'])if(!Object.hasOwn(effect,f))fail(loc+'.'+f,'required modifier field');
    for(const f of ['stat','source'])if(typeof effect[f]!=='string'||!effect[f].trim())fail(loc+'.'+f,'must be a nonempty string');
    if(!schema.modifier_operations.includes(effect.op))fail(loc+'.op','unknown modifier operation');
    if(typeof effect.value!=='number'||!Number.isFinite(effect.value))fail(loc+'.value','modifier value must be finite');
    if(kind(effect.scope)!=='object')fail(loc+'.scope','scope must be an object');
    else for(const[f,filter]of Object.entries(effect.scope)){
     if(!schema.modifier_scope_keys.includes(f))fail(loc+'.scope.'+f,'unknown scope key');
     if(typeof filter!=='string'&&!(Array.isArray(filter)&&filter.every(v=>typeof v==='string')))fail(loc+'.scope.'+f,'expected string or string array');
     if(f==='domain'&&!schema.modifier_domains.includes(filter))fail(loc+'.scope.domain','unknown modifier domain');
    }
   }
 }
 for(const [p,doc]of Object.entries(documents))visit(doc,p);
 return errors;
}
function loadAndValidate(projectRoot=root){
 const schema=JSON.parse(fs.readFileSync(path.join(projectRoot,'data/config/content_schema.json'),'utf8'));
 const documents={}; const errors=[];
 for(const {path:p}of schema.documents){try{documents[p]=JSON.parse(fs.readFileSync(path.join(projectRoot,p.slice(6)),'utf8'));}catch(error){errors.push(p+': '+error.message);}}
 errors.push(...validateDocuments(documents,schema,p=>fs.existsSync(path.join(projectRoot,p.slice(6)))));
 return {schema,documents,errors};
}
if(require.main===module){const {errors}=loadAndValidate();if(errors.length){console.error(errors.join('\n'));process.exitCode=1;}else console.log('Content configuration schema, IDs, references and resources passed.');}
module.exports={validateDocuments,loadAndValidate};
