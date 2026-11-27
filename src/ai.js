import {P,N,B,R,Q,K,values,apply,isAttacked,search} from './engine.js';

export const PROFILES={
  legit:{name:'Legit',tag:'как человек',depth:5,time:900,spread:.55,noise:85,top:6,blunder:.05},
  semi:{name:'Semi',tag:'очень сильный',depth:9,time:1600,spread:.25,noise:22,top:3,blunder:.01},
  blatant:{name:'Blatant',tag:'беспощадный',depth:18,time:3000,spread:0,noise:0,top:1,blunder:0},
};

export const OPENINGS=[['random','Рандом'],['pawn','Пешка'],['knight','Конь'],['bishop','Слон'],['rook','Ладья'],['queen','Ферзь']];
const OPENING_PIECE={pawn:P,knight:N,bishop:B,rook:R,queen:Q};

export const BRILLIANT_MODES=[['off','Выкл'],['move','Ход'],['series','Серия']];

export function profileSettings(settings,profile){
  const base=PROFILES[profile]||PROFILES.semi;
  const own=settings?.profiles?.[profile]||{};
  return {
    ...base,
    time:own.time??base.time,
    spread:own.spread??base.spread,
    opening:own.opening??'random',
  };
}

export function thinkTime(profile,random=Math.random){
  const u=random();
  return Math.max(60,Math.round(profile.time*(1+profile.spread*(2*u-1))));
}

function pieceAt(state,square){return Math.abs(state.board[square]||0);}

export function isSacrifice(state,move){
  const mover=pieceAt(state,move.from);
  if(mover===P||mover===K)return false;
  const captured=pieceAt(state,move.to);
  let after;
  try{after=apply(state,move);}catch{return false;}
  const placed=Math.abs(after.board[move.to]||0);
  const given=values[placed]-values[captured]-values[move.promotion||0];
  if(given<320||state.ply<8)return false;
  if(!isAttacked(after,move.to,-state.turn))return false;
  return !isAttacked(after,move.to,state.turn);
}

function openingBonus(state,opening,move){
  if(!opening||opening==='random'||state.ply>16)return 0;
  const want=OPENING_PIECE[opening];
  if(!want)return 0;
  return Math.abs(state.board[move.from])===want?45:0;
}

export function chooseMove(state,options={}){
  const profile=profileSettings(options,options.profile||'semi');
  const brilliant=options.brilliant&&options.brilliant!=='off'?options.brilliant:'off';
  const result=search(state,{
    time:options.time??profile.time,
    spread:options.spread??profile.spread,
    maxDepth:options.maxDepth??profile.depth,
    history:options.history||[],
    onProgress:options.onProgress,
  });
  let list=(result.candidates||[]).filter(entry=>entry.move);
  if(!list.length)return {...result,brilliant:false,chosen:result.move};
  const mate=list.find(entry=>entry.score>90000);
  if(mate)return {...result,move:mate.move,chosen:mate.move,brilliant:isSacrifice(state,mate.move)};
  const scored=list.map(entry=>({
    move:entry.move,
    score:entry.score,
    rating:entry.score+openingBonus(state,profile.opening,entry.move),
    brilliant:isSacrifice(state,entry.move),
  }));
  scored.sort((a,b)=>b.rating-a.rating);
  if(brilliant!=='off'){
    const floor=scored[0].rating-40;
    const sacrifice=scored.find(entry=>entry.brilliant&&entry.rating>=floor);
    if(sacrifice)return {...result,move:sacrifice.move,chosen:sacrifice.move,brilliant:true};
  }
  if(profile.noise<=0||profile.top<=1)return {...result,move:scored[0].move,chosen:scored[0].move,brilliant:scored[0].brilliant};
  if(Math.random()<profile.blunder){
    const pool=scored.slice(0,Math.min(scored.length,profile.top));
    const pick=pool[Math.floor(Math.random()*pool.length)];
    return {...result,move:pick.move,chosen:pick.move,blunder:true,brilliant:pick.brilliant};
  }
  const pool=scored.slice(0,Math.min(scored.length,profile.top));
  let best=pool[0],top=-Infinity;
  for(const entry of pool){
    const rating=entry.rating+(Math.random()*2-1)*profile.noise;
    if(rating>top){top=rating;best=entry;}
  }
  return {...result,move:best.move,chosen:best.move,brilliant:best.brilliant};
}

export function describeProfile(name,settings){
  const profile=profileSettings(settings,name);
  return `${profile.name} · ${profile.time} мс ± ${Math.round(profile.spread*100)}%`;
}
