import {it,expect} from 'vitest';
import {parseBlueprintV2} from '../src/modules/content/blueprint-catalog';
const row={entryId:'e',exerciseId:'custom',executionMode:'videoGuidedTimed',sets:3,durationSeconds:45,restSeconds:30};
const blueprint=(rows:unknown[])=>({schemaVersion:2,name:'Valid',sessionDurationMin:30,days:[{dayNumber:1,exercises:rows}]});
it('bounds v2 authoring and rejects duplicate entries or mixed targets',()=>{expect(parseBlueprintV2(blueprint([row])).name).toBe('Valid');for(const rows of [[row,row],[{...row,reps:1}],[{...row,durationSeconds:0}],[{...row,executionMode:'invented'}],Array.from({length:21},(_,i)=>({...row,entryId:`e${i}`}))])expect(()=>parseBlueprintV2(blueprint(rows))).toThrow();});
it('supports the fifty total row publication budget',()=>{const days=Array.from({length:5},(_,d)=>({dayNumber:d+1,exercises:Array.from({length:10},(_,r)=>({...row,entryId:`e${d}_${r}`}))}));expect((parseBlueprintV2({...blueprint([]),days}).days as unknown[])).toHaveLength(5);days[0].exercises.push({...row,entryId:'overflow'});expect(()=>parseBlueprintV2({...blueprint([]),days})).toThrow();});
