// Modifier definitions share the runtime content schema; do not maintain a
// second parser accepting legacy operations, nested source blocks or key maps.
const {loadAndValidate}=require('./validate_content_configs');
const {errors}=loadAndValidate();
if(errors.length){console.error(errors.join('\n'));process.exitCode=1;}
else console.log('Canonical Modifier effect validation passed.');
