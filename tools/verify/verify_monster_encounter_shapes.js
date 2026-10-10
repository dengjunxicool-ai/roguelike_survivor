const fs = require('fs');
const {validate} = require('../validate/monster_encounter_validator');
const documents = Object.fromEntries(['waves/waves','maps/maps','enemies/enemies'].map(p => ['res://data/'+p+'.json', JSON.parse(fs.readFileSync('data/'+p+'.json','utf8'))]));
const fixtures = JSON.parse(fs.readFileSync('tools/verify/fixtures/monster_encounter_invalid_shapes.json','utf8'));
for (const fixture of fixtures) {
 const changed=structuredClone(documents); let parent=changed[fixture.document];
 for(const key of fixture.path.slice(0,-1))parent=parent[key];
 parent[fixture.path.at(-1)]=fixture.value;
 if(!validate(changed).some(message=>message.includes(fixture.field)))throw new Error('invalid member shape accepted: '+fixture.field);
}
console.log('Monster encounter shared invalid shapes: PASS');
