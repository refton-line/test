export const P=1,N=2,B=3,R=4,Q=5,K=6;
export const values=[0,100,320,340,510,950,20000];
export const idx=(x,y,z,n)=>x+n*y+n*n*z;
export function xyz(i,n){return [i%n,Math.floor(i/n)%n,Math.floor(i/(n*n))];}
export function initial(mode='classic'){
  const n=mode==='classic'?8:5, layers=mode==='classic'?1:3, board=Array(n*n*layers).fill(0);
  const back=n===8?[R,N,B,Q,K,B,N,R]:[R,N,K,Q,R], z=n===8?0:1;
  for(let x=0;x<n;x++){board[idx(x,0,z,n)]=back[x];board[idx(x,1,z,n)]=P;board[idx(x,n-1,z,n)]=-back[x];board[idx(x,n-2,z,n)]=-P;}
  if(layers>1) for(const x of [1,3]){board[idx(x,0,0,n)]=B;board[idx(x,4,2,n)]=-B;}
  return {mode,n,layers,board,turn:1,castle:n===8?15:0,ep:-1,half:0,ply:0};
}
export function key(s){return s.board.join(',')+'|'+s.turn+'|'+s.castle+'|'+s.ep;}
function inside(x,y,z,s){return x>=0&&x<s.n&&y>=0&&y<s.n&&z>=0&&z<s.layers;}
const vectors=[];
for(let x=-1;x<=1;x++)for(let y=-1;y<=1;y++)for(let z=-1;z<=1;z++)if(x||y||z)vectors.push([x,y,z]);
function pseudo(s,side,attacks=false){
  const out=[], {n,board}=s;
  function add(from,to,extra={}){if(!attacks&&Math.abs(board[to])===K)return;const p=board[from]; if(!attacks&&Math.abs(p)===P&&xyz(to,n)[1]===(side===1?n-1:0)){for(const promotion of [Q,R,B,N])out.push({from,to,promotion,...extra});}else out.push({from,to,...extra});}
  for(let from=0;from<board.length;from++){
    const p=board[from];if(Math.sign(p)!==side)continue;
    const type=Math.abs(p),[x,y,z]=xyz(from,n);
    if(type===P){
      const captures=[[1,side,0],[-1,side,0],...(s.layers>1?[[0,side,1],[0,side,-1]]:[])];
      for(const [dx,dy,dz] of captures){if(!inside(x+dx,y+dy,z+dz,s))continue;const to=idx(x+dx,y+dy,z+dz,n);if(attacks||board[to]*side<0)add(from,to);else if(to===s.ep&&s.layers===1)add(from,to,{ep:true});}
      if(attacks)continue;
      if(inside(x,y+side,z,s)&&board[idx(x,y+side,z,n)]===0){add(from,idx(x,y+side,z,n));if(s.layers===1&&y===(side===1?1:n-2)&&board[idx(x,y+2*side,z,n)]===0)add(from,idx(x,y+2*side,z,n),{double:true});}
      if(s.layers>1)for(const dz of [-1,1])if(inside(x,y,z+dz,s)&&board[idx(x,y,z+dz,n)]===0)add(from,idx(x,y,z+dz,n));
      continue;
    }
    if(type===N){
      for(let dx=-2;dx<=2;dx++)for(let dy=-2;dy<=2;dy++)for(let dz=s.layers===1?0:-2;dz<=(s.layers===1?0:2);dz++){
        if(dx*dx+dy*dy+dz*dz!==5||!inside(x+dx,y+dy,z+dz,s))continue;const to=idx(x+dx,y+dy,z+dz,n);if(attacks||board[to]*side<=0)add(from,to);
      }continue;
    }
    for(const [dx,dy,dz] of vectors){
      const axes=Math.abs(dx)+Math.abs(dy)+Math.abs(dz);if(s.layers===1&&dz)continue;if(type===R&&axes!==1)continue;if(type===B&&axes<2)continue;
      for(let step=1;step<n;step++){
        const a=x+dx*step,b=y+dy*step,c=z+dz*step;if(!inside(a,b,c,s))break;const to=idx(a,b,c,n);
        if(attacks||board[to]*side<=0)add(from,to);if(board[to]||type===K)break;
      }
    }
    if(type===K&&!attacks&&s.layers===1){
      const row=side===1?0:7,base=side===1?0:2;
      if(from===idx(4,row,0,n)&&!isAttacked(s,from,-side))for(const kingSide of [true,false]){
        const bit=1<<(base+(kingSide?0:1)),rook=idx(kingSide?7:0,row,0,n),path=kingSide?[5,6]:[3,2,1];
        if(!(s.castle&bit)||board[rook]!==side*R||path.some(a=>board[idx(a,row,0,n)]))continue;
        if([kingSide?5:3,kingSide?6:2].some(a=>isAttacked(s,idx(a,row,0,n),-side)))continue;
        add(from,idx(kingSide?6:2,row,0,n),{castle:true});
      }
    }
  }return out;
}
export function isAttacked(s,square,side){return pseudo(s,side,true).some(m=>m.to===square);}
export function inCheck(s,side=s.turn){const king=s.board.indexOf(side*K);return king<0||isAttacked(s,king,-side);}
export function apply(s,m){
  const t={...s,board:s.board.slice(),turn:-s.turn,ep:-1,half:s.half+1,ply:s.ply+1},p=t.board[m.from],captured=t.board[m.to];
  t.board[m.to]=m.promotion?m.promotion*s.turn:p;t.board[m.from]=0;
  if(Math.abs(p)===P||captured)t.half=0;
  if(m.ep)t.board[m.to-s.turn*s.n]=0;
  if(m.double)t.ep=m.from+s.turn*s.n;
  if(m.castle){const row=Math.floor(m.from/8),kingSide=m.to>m.from; t.board[idx(kingSide?5:3,row,0,8)]=s.turn*R;t.board[idx(kingSide?7:0,row,0,8)]=0;}
  if(Math.abs(p)===K)t.castle&=s.turn===1?12:3;
  for(const [square,bit]of [[7,1],[0,2],[63,4],[56,8]])if(m.from===square||m.to===square)t.castle&=~bit;
  return t;
}
export function legal(s){return pseudo(s,s.turn).filter(m=>!inCheck(apply(s,m),s.turn));}
export function deadPosition(s){
  const pieces=s.board.map((p,i)=>({p:Math.abs(p),i})).filter(a=>a.p&&a.p!==K);
  if(!pieces.length)return true;if(s.layers>1)return false;
  if(pieces.length===1&&[N,B].includes(pieces[0].p))return true;
  return pieces.every(a=>a.p===B)&&new Set(pieces.map(a=>{const [x,y]=xyz(a.i,s.n);return(x+y)%2;})).size===1;
}
export function outcome(s,repetitions=1){
  const moves=legal(s);if(!moves.length)return inCheck(s)?{over:true,reason:'Мат',winner:-s.turn}:{over:true,reason:'Пат',winner:0};
  if(s.half>=100)return {over:true,reason:'Правило 50 ходов',winner:0};
  if(repetitions>=3)return {over:true,reason:'Троекратное повторение',winner:0};
  if(deadPosition(s))return {over:true,reason:'Недостаточно материала',winner:0};
  return {over:false,moves,check:inCheck(s)};
}
export function squareName(i,s){const[x,y,z]=xyz(i,s.n);return String.fromCharCode(97+x)+(y+1)+(s.layers>1?'·'+(z+1):'');}
export function notation(s,m){if(m.castle)return m.to>m.from?'O-O':'O-O-O';const names=['','','К','С','Л','Ф','Кр'];return names[Math.abs(s.board[m.from])]+squareName(m.from,s)+(s.board[m.to]||m.ep?'×':'–')+squareName(m.to,s)+(m.promotion?'='+names[m.promotion]:'');}
export function evaluate(s){
  let score=0;const center=(s.n-1)/2;
  for(let i=0;i<s.board.length;i++){
    const p=s.board[i];if(!p)continue;const side=Math.sign(p),type=Math.abs(p),[x,y,z]=xyz(i,s.n),dist=Math.abs(x-center)+Math.abs(y-center)+(s.layers>1?Math.abs(z-1)*1.6:0);
    let v=values[type];if(type!==K)v+=(s.n-dist)*(type===N||type===B?9:4);
    if(type===P){v+=(side===1?y:s.n-1-y)*9;for(const dx of [-1,1])if(inside(x+dx,y-side,z,s)&&s.board[idx(x+dx,y-side,z,s.n)]===side*P)v+=12;}
    if(type===K){for(const dx of [-1,0,1])if(inside(x+dx,y+side,z,s)&&s.board[idx(x+dx,y+side,z,s.n)]===side*P)v+=22; if(s.layers===1&&((side===1&&y===0)||(side===-1&&y===7))&&(x===6||x===2))v+=40;}
    score+=side*v;
  }return score*s.turn;
}
export function search(s,{time=1500,maxDepth=5,history=[] ,onProgress=()=>{}}={}){
  const started=performance.now(),deadline=started+time,table=new Map(),path=new Map();let nodes=0,completed=0,best=null,bestScore=0;
  for(const k of history)path.set(k,(path.get(k)||0)+1);
  const rootKey=key(s);if(!path.has(rootKey))path.set(rootKey,1);
  const STOP=Symbol('deadline');
  const same=(a,b)=>a&&b&&a.from===b.from&&a.to===b.to&&a.promotion===b.promotion;
  function order(pos,moves,pv){return moves.sort((a,b)=>rank(b)-rank(a));function rank(m){return(same(m,pv)?100000:0)+(pos.board[m.to]?10*values[Math.abs(pos.board[m.to])]-values[Math.abs(pos.board[m.from])]:0)+(m.ep?1000:0)+(m.promotion?values[m.promotion]:0);}}
  function visit(pos,depth,alpha,beta,ply,qdepth=0){
    nodes++;if(performance.now()>=deadline)throw STOP;
    const k=key(pos);if(pos.half>=100||(path.get(k)||0)>=3||deadPosition(pos))return 0;
    const check=inCheck(pos),moves=legal(pos);if(!moves.length)return check?-100000+ply:0;
    const original=alpha,ttKey=k+'|'+pos.half,entry=table.get(ttKey),repeated=[...path.values()].some(v=>v>1);
    if(depth>0&&!repeated&&entry&&entry.depth>=depth&&Math.abs(entry.score)<90000){if(entry.flag===0)return entry.score;if(entry.flag===1)alpha=Math.max(alpha,entry.score);else beta=Math.min(beta,entry.score);if(alpha>=beta)return entry.score;}
    let candidates=moves;
    if(depth<=0){const stand=evaluate(pos);if(qdepth>=5)return stand;if(!check){if(stand>=beta)return stand;alpha=Math.max(alpha,stand);candidates=moves.filter(m=>pos.board[m.to]||m.ep||m.promotion);}}
    let localBest=null;
    for(const m of order(pos,candidates,entry?.move)){
      const next=apply(pos,m),nk=key(next);path.set(nk,(path.get(nk)||0)+1);let val;
      try{val=-visit(next,depth-1,-beta,-alpha,ply+1,depth<=0?qdepth+1:0);}finally{path.set(nk,path.get(nk)-1);if(!path.get(nk))path.delete(nk);}
      if(val>alpha){alpha=val;localBest=m;}if(alpha>=beta)break;
    }
    if(depth>0&&!repeated){if(table.size>40000)table.clear();table.set(ttKey,{depth,score:alpha,move:localBest,flag:alpha<=original?2:alpha>=beta?1:0});}
    return alpha;
  }
  const moves=legal(s);if(!moves.length)return {move:null,depth:0,nodes,elapsed:performance.now()-started};best=moves[0];
  for(let depth=1;depth<=maxDepth;depth++){
    let iterationBest=best,alpha=-Infinity;
    try{
      for(const m of order(s,moves,best)){
        if(performance.now()>=deadline)throw STOP;
        const next=apply(s,m),nk=key(next);path.set(nk,(path.get(nk)||0)+1);let value;
        try{value=-visit(next,depth-1,-Infinity,-alpha,1);}finally{path.set(nk,path.get(nk)-1);if(!path.get(nk))path.delete(nk);}
        if(value>alpha){alpha=value;iterationBest=m;}
      }
      best=iterationBest;bestScore=alpha;completed=depth;onProgress({depth,nodes,elapsed:performance.now()-started});if(alpha>90000)break;
    }catch(e){if(e!==STOP)throw e;break;}
  }
  return {move:best,depth:completed,nodes,score:bestScore,elapsed:performance.now()-started};
}