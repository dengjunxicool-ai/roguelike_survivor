const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'../..');
function verifyBoundary(consumers){
  const facade=fs.readFileSync(path.join(root,'scripts/game/game_data.gd'),'utf8');
  assert(!/JsonDataLoader|FileAccess|_document_cache|_load_document|has_method/.test(facade),'query facade must have one explicit owner');
  assert(facade.includes('DataManager'),'facade requires owner');
  assert(!fs.existsSync(path.join(root,'scripts/core/game_data_access.gd')),'fallback helper must be removed');
  for(const consumer of consumers){
    const file=path.join(root,consumer);
    assert(fs.existsSync(file),`missing consumer ${consumer}`);
    const code=fs.readFileSync(file,'utf8');
    assert(code.includes('GameData'),`${consumer} must query owner through facade`);
    assert(!/JsonDataLoaderScript\.load|FileAccess\.open/.test(code),`${consumer} must not create a second config read path`);
  }
  console.log('Single-owner config boundary passed.');
}
module.exports={verifyBoundary};
