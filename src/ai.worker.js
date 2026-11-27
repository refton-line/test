import {search} from './engine.js';
self.onmessage=({data})=>{
  try { const result=search(data.state,{...data.options,onProgress:progress=>self.postMessage({type:'progress',id:data.id,...progress})});self.postMessage({type:'result',id:data.id,...result}); }
  catch(error){self.postMessage({type:'error',id:data.id,message:error.message});}
};