export const P=1,N=2,B=3,R=4,Q=5,K=6;
export const values=[0,100,320,335,500,950,0];
export const idx=(x,y,z,n)=>x+n*y+n*n*z;
export function xyz(i,n){return [i%n,Math.floor(i/n)%n,Math.floor(i/(n*n))];}

const MODES={classic:{n:8,layers:1},strata:{n:5,layers:3}};
const MATE=100000;
const STOP={stop:true};

const GEO=new Map();
function geo(n,layers){
  const id=n+':'+layers;
  if(GEO.has(id))return GEO.get(id);
  const vol=n*n*layers,g={n,layers,vol};
  const inside=(x,y,z)=>x>=0&&x<n&&y>=0&&y<n&&z>=0&&z<layers;
  g.xyz=[];g.mirror=new Int16Array(vol);
  for(let i=0;i<vol;i++){const[x,y,z]=xyz(i,n);g.xyz.push([x,y,z]);g.mirror[i]=idx(n-1-x,n-1-y,layers-1-z,n);}
  g.steps=[];g.knight=[];g.orth=[];g.diag=[];g.all=[];g.pawnFrom=[[],[]];
  const dirs=[];
  for(let dx=-1;dx<=1;dx++)for(let dy=-1;dy<=1;dy++)for(let dz=-1;dz<=1;dz++){
    if(!dx&&!dy&&!dz)continue;
    if(layers===1&&dz)continue;
    dirs.push([dx,dy,dz]);
  }
  for(let z=0;z<layers;z++)for(let y=0;y<n;y++)for(let x=0;x<n;x++){
    const from=idx(x,y,z,n),steps=[],knight=[],orth=[],diag=[],all=[];
    for(const[dx,dy,dz]of dirs){
      if(inside(x+dx,y+dy,z+dz))steps.push(idx(x+dx,y+dy,z+dz,n));
      const ray=[];let a=x+dx,b=y+dy,c=z+dz;
      while(inside(a,b,c)){ray.push(idx(a,b,c,n));a+=dx;b+=dy;c+=dz;}
      if(ray.length){all.push(ray);(Math.abs(dx)+Math.abs(dy)+Math.abs(dz)===1?orth:diag).push(ray);}
    }
    for(let dx=-2;dx<=2;dx++)for(let dy=-2;dy<=2;dy++)for(let dz=-2;dz<=2;dz++){
      if(dx*dx+dy*dy+dz*dz!==5)continue;
      if(inside(x+dx,y+dy,z+dz))knight.push(idx(x+dx,y+dy,z+dz,n));
    }
    const fromW=[],fromB=[];
    for(const[dx,dz]of[[1,0],[-1,0],[0,1],[0,-1]]){
      if(inside(x+dx,y-1,z+dz))fromW.push(idx(x+dx,y-1,z+dz,n));
      if(inside(x+dx,y+1,z+dz))fromB.push(idx(x+dx,y+1,z+dz,n));
    }
    g.steps.push(steps);g.knight.push(knight);g.orth.push(orth);g.diag.push(diag);g.all.push(all);
    g.pawnFrom[0].push(fromW);g.pawnFrom[1].push(fromB);
  }
  g.cols=n*n;
  g.pawnPush=new Int16Array(vol).fill(-1);
  g.pawnPushB=new Int16Array(vol).fill(-1);
  g.pawnDouble=new Int16Array(vol).fill(-1);
  g.pawnDoubleB=new Int16Array(vol).fill(-1);
  g.pawnCaps=[];g.lateral=[];
  for(let z=0;z<layers;z++)for(let y=0;y<n;y++)for(let x=0;x<n;x++){
    const from=idx(x,y,z,n);
    if(y<n-1)g.pawnPush[from]=idx(x,y+1,z,n);
    if(y>0)g.pawnPushB[from]=idx(x,y-1,z,n);
    if(layers===1&&y===1)g.pawnDouble[from]=idx(x,3,z,n);
    if(layers===1&&y===6)g.pawnDoubleB[from]=idx(x,4,z,n);
    const capsW=[],capsB=[];
    for(const[dx,dz]of[[1,0],[-1,0],[0,1],[0,-1]]){
      if(inside(x+dx,y+1,z+dz))capsW.push(idx(x+dx,y+1,z+dz,n));
      if(inside(x+dx,y-1,z+dz))capsB.push(idx(x+dx,y-1,z+dz,n));
    }
    g.pawnCaps.push([capsW,capsB]);
    const side=[];
    if(layers>1){
      if(inside(x,y,z-1))side.push(idx(x,y,z-1,n));
      if(inside(x,y,z+1))side.push(idx(x,y,z+1,n));
    }
    g.lateral.push(side);
  }
  g.val=[0,100,320,335,500,950,0];
  g.phase=[0,0,1,1,2,4,0];
  const c=(n-1)/2,cl=(layers-1)/2;
  const dist=i=>{const[x,y,z]=g.xyz[i];return Math.abs(x-c)+Math.abs(y-c)+Math.abs(z-cl);};
  const fwd=i=>{const[,y]=g.xyz[i];return layers>1?Math.abs(y-c):y;};
  const table=fn=>{const t=new Int16Array(vol);for(let i=0;i<vol;i++)t[i]=fn(i);return t;};
  g.pstMid=[];g.pstEnd=[];
  g.pstMid[0]=g.pstMid[6]=new Int16Array(vol);
  g.pstEnd[0]=g.pstEnd[6]=new Int16Array(vol);
  g.pstMid[P]=table(i=>fwd(i)*7+(n-1-dist(i))*2);
  g.pstEnd[P]=table(i=>fwd(i)*12);
  g.pstMid[N]=table(i=>26-dist(i)*6);
  g.pstEnd[N]=table(i=>20-dist(i)*4);
  g.pstMid[B]=table(i=>18-dist(i)*3);
  g.pstEnd[B]=table(i=>16-dist(i)*3);
  g.pstMid[R]=table(i=>fwd(i)*2-dist(i));
  g.pstEnd[R]=table(i=>fwd(i)*3);
  g.pstMid[Q]=table(i=>10-dist(i)*2);
  g.pstEnd[Q]=table(i=>14-dist(i)*2);
  g.pstMid[K]=table(i=>{const[,y,z]=g.xyz[i];return (n-1-y)*4-Math.abs(z-cl)*3-dist(i)*2;});
  g.pstEnd[K]=table(i=>14-dist(i)*4);
  let seed=0x9e3779b9;
  const rnd=()=>{seed^=seed<<13;seed^=seed>>>17;seed^=seed<<5;return seed|0;};
  g.z1=[];g.z2=[];
  for(let p=0;p<12;p++){
    const a=new Int32Array(vol),b=new Int32Array(vol);
    for(let i=0;i<vol;i++){a[i]=rnd();b[i]=rnd();}
    g.z1.push(a);g.z2.push(b);
  }
  g.zTurn=new Int32Array([rnd(),rnd()]);
  g.zCastle=new Int32Array(16);
  for(let i=0;i<16;i++)g.zCastle[i]=rnd();
  g.zEp1=new Int32Array(vol);g.zEp2=new Int32Array(vol);
  for(let i=0;i<vol;i++){g.zEp1[i]=rnd();g.zEp2[i]=rnd();}
  GEO.set(id,g);
  return g;
}

class Pos{
  constructor(state){
    const g=geo(state.n,state.layers);
    this.g=g;this.n=state.n;this.layers=state.layers;this.vol=g.vol;
    this.board=Int8Array.from(state.board);
    this.turn=state.turn;this.castle=state.castle;this.ep=state.ep;this.half=state.half;this.ply=state.ply||0;
    this.kp1=-1;this.kpm1=-1;
    for(let i=0;i<this.vol;i++){
      const p=this.board[i];
      if(p===K)this.kp1=i;else if(p===-K)this.kpm1=i;
    }
    this.hash1=0;this.hash2=0;
    for(let i=0;i<this.vol;i++){const p=this.board[i];if(p)this.xorPiece(i,p);}
    this.hash1^=g.zTurn[0];this.hash2^=g.zTurn[1];
    this.hash1^=g.zCastle[this.castle];
    if(this.ep>=0){this.hash1^=g.zEp1[this.ep];this.hash2^=g.zEp2[this.ep];}
    this.ui=0;
    this.uc=new Int8Array(512);this.ucast=new Int16Array(512);this.uep=new Int16Array(512);this.uh=new Int16Array(512);
    this.uh1=new Int32Array(512);this.uh2=new Int32Array(512);this.uk1=new Int16Array(512);this.ukm1=new Int16Array(512);
    this.umv=new Int32Array(512);this.uflags=new Int8Array(512);
    this.hist=[this.hashKey()];
    this.pcW=new Int16Array(g.cols);this.pcB=new Int16Array(g.cols);
  }
  hashKey(){return this.hash1*4294967296+(this.hash2>>>0);}
  zi(p){return p>0?p-1:5-p;}
  xorPiece(sq,p){const k=this.zi(p);this.hash1^=this.g.z1[k][sq];this.hash2^=this.g.z2[k][sq];}
  inCheck(side=this.turn){
    const k=side===1?this.kp1:this.kpm1;
    if(k<0)return true;
    return this.attacked(k,-side);
  }
  attacked(sq,by){
    const b=this.board,g=this.g;
    for(const from of g.knight[sq])if(b[from]===by*N)return true;
    for(const from of g.steps[sq])if(b[from]===by*K)return true;
    for(const from of g.pawnFrom[by>0?0:1][sq])if(b[from]===by*P)return true;
    for(const ray of g.orth[sq])for(const from of ray){const p=b[from];if(p){if(p===by*R||p===by*Q)return true;break;}}
    for(const ray of g.diag[sq])for(const from of ray){const p=b[from];if(p){if(p===by*B||p===by*Q)return true;break;}}
    return false;
  }
  hasMaterial(){
    const b=this.board,turn=this.turn;
    for(let i=0;i<this.vol;i++){const p=b[i]*turn;if(p>P)return true;}
    return false;
  }
  makeNull(){
    this.ucast[this.ui]=this.castle;this.uep[this.ui]=this.ep;this.uh1[this.ui]=this.hash1;this.uh2[this.ui]=this.hash2;
    this.uflags[this.ui]=1;this.umv[this.ui]=0;this.ui++;
    if(this.ep>=0){this.hash1^=this.g.zEp1[this.ep];this.hash2^=this.g.zEp2[this.ep];this.ep=-1;}
    this.turn=-this.turn;
    this.hash1^=this.g.zTurn[0];this.hash2^=this.g.zTurn[1];
    this.hist.push(this.hashKey());
  }
  unmakeNull(){
    const u=--this.ui;
    this.hist.pop();
    this.hash1=this.uh1[u];this.hash2=this.uh2[u];this.castle=this.ucast[u];this.ep=this.uep[u];
    this.turn=-this.turn;
  }
  gen(buf,capsOnly){
    const b=this.board,g=this.g,turn=this.turn;
    let c=0;
    for(let from=0;from<this.vol;from++){
      const p=b[from];
      if(!p)continue;
      const side=p>0?1:-1;
      if(side!==turn)continue;
      const t=p>0?p:-p;
      if(t===P){
        const push=side===1?g.pawnPush[from]:g.pawnPushB[from];
        if(!capsOnly&&push>=0&&!b[push])c=this.pawnMove(buf,c,from,push);
        if(!capsOnly){
          const dbl=side===1?g.pawnDouble[from]:g.pawnDoubleB[from];
          if(dbl>=0&&!b[dbl]&&!b[side===1?g.pawnPush[from]:g.pawnPushB[from]])c=this.pawnMove(buf,c,from,dbl,2);
          for(const to of g.lateral[from])if(!b[to])buf[c++]=from|to<<7;
        }
        for(const to of g.pawnCaps[from][side===1?0:1]){
          const q=b[to];
          if(q*side<0)c=this.pawnMove(buf,c,from,to);
          else if(!q&&this.layers===1&&to===this.ep)c=this.pawnMove(buf,c,from,to,1);
        }
        continue;
      }
      if(t===N){
        for(const to of g.knight[from]){const q=b[to];if(q*side>0)continue;if(capsOnly&&!q)continue;buf[c++]=from|to<<7;}
        continue;
      }
      if(t===K){
        for(const to of g.steps[from]){const q=b[to];if(q*side>0)continue;if(capsOnly&&!q)continue;buf[c++]=from|to<<7;}
        if(!capsOnly&&this.layers===1)c=this.castles(buf,c,from,side);
        continue;
      }
      const rays=t===R?g.orth[from]:t===B?g.diag[from]:g.all[from];
      for(const ray of rays)for(const to of ray){
        const q=b[to];
        if(q*side>0)break;
        if(!capsOnly||q)buf[c++]=from|to<<7;
        if(q)break;
      }
    }
    return c;
  }
  pawnMove(buf,c,from,to,flag=0){
    const y=Math.floor(to/this.n)%this.n;
    if(y===0||y===this.n-1)for(const promo of [Q,R,B,N])buf[c++]=from|to<<7|promo<<14|flag<<17;
    else buf[c++]=from|to<<7|flag<<17;
    return c;
  }
  castles(buf,c,from,side){
    const n=this.n,row=side===1?0:7,base=side===1?0:2;
    if(from!==idx(4,row,0,n))return c;
    const kingSide=1<<base,queenSide=1<<(base+1);
    if(this.castle&kingSide){
      const path=[idx(5,row,0,n),idx(6,row,0,n)];
      if(!path.some(s=>this.board[s])&&this.board[idx(7,row,0,n)]===side*R
        &&![from,...path].some(s=>this.attacked(s,-side)))buf[c++]=from|idx(6,row,0,n)<<7|4<<17;
    }
    if(this.castle&queenSide){
      const path=[idx(3,row,0,n),idx(2,row,0,n),idx(1,row,0,n)];
      if(!path.some(s=>this.board[s])&&this.board[idx(0,row,0,n)]===side*R
        &&![from,idx(3,row,0,n),idx(2,row,0,n)].some(s=>this.attacked(s,-side)))buf[c++]=from|idx(2,row,0,n)<<7|4<<17;
    }
    return c;
  }
  make(mv){
    const from=mv&127,to=(mv>>7)&127,promo=(mv>>14)&7,flag=(mv>>17)&7;
    const b=this.board,g=this.g,u=this.ui;
    this.ucast[u]=this.castle;this.uep[u]=this.ep;this.uh[u]=this.half;
    this.uh1[u]=this.hash1;this.uh2[u]=this.hash2;this.uk1[u]=this.kp1;this.ukm1[u]=this.kpm1;
    this.umv[u]=mv;this.uflags[u]=0;this.uc[u]=0;
    this.ui++;
    if(this.ep>=0){this.hash1^=g.zEp1[this.ep];this.hash2^=g.zEp2[this.ep];this.ep=-1;}
    this.hash1^=g.zCastle[this.castle];
    const p=b[from];
    let captured=b[to],capturedSq=to,half=this.half+1;
    if(p===P||p===-P)half=0;
    if(flag&1){
      capturedSq=to-this.turn*this.n;
      captured=b[capturedSq];
      half=0;
    }
    if(captured){
      this.uc[u]=captured;
      this.xorPiece(capturedSq,captured);
      b[capturedSq]=0;
      half=0;
    }
    this.xorPiece(from,p);
    b[from]=0;
    const placed=promo?promo*this.turn:p;
    b[to]=placed;
    this.xorPiece(to,placed);
    if(p===K)this.kp1=to;else if(p===-K)this.kpm1=to;
    if(flag&2)this.ep=from+this.turn*this.n;
    if(flag&4){
      const row=Math.floor(from/this.n)%this.n;
      const rookFrom=to>from?idx(7,row,0,this.n):idx(0,row,0,this.n);
      const rookTo=to>from?idx(5,row,0,this.n):idx(3,row,0,this.n);
      const rook=b[rookFrom];
      this.xorPiece(rookFrom,rook);b[rookFrom]=0;
      b[rookTo]=rook;this.xorPiece(rookTo,rook);
    }
    if(Math.abs(p)===K)this.castle&=this.turn===1?12:3;
    if(this.layers===1){
      if(from===7||to===7)this.castle&=~1;
      if(from===0||to===0)this.castle&=~2;
      if(from===63||to===63)this.castle&=~4;
      if(from===56||to===56)this.castle&=~8;
    }
    this.hash1^=g.zCastle[this.castle];
    this.turn=-this.turn;
    this.hash1^=g.zTurn[0];this.hash2^=g.zTurn[1];
    if(this.ep>=0){this.hash1^=g.zEp1[this.ep];this.hash2^=g.zEp2[this.ep];}
    this.half=half;
    this.hist.push(this.hashKey());
  }
  unmake(){
    const u=--this.ui,mv=this.umv[u];
    this.hist.pop();
    this.hash1=this.uh1[u];this.hash2=this.uh2[u];this.castle=this.ucast[u];this.ep=this.uep[u];
    if(this.uflags[u]===1){this.turn=-this.turn;return;}
    const from=mv&127,to=(mv>>7)&127,promo=(mv>>14)&7,flag=(mv>>17)&7;
    const b=this.board;
    this.half=this.uh[u];this.kp1=this.uk1[u];this.kpm1=this.ukm1[u];
    this.turn=-this.turn;
    b[from]=promo?this.turn*P:b[to];
    b[to]=0;
    if(flag&4){
      const row=Math.floor(from/this.n)%this.n;
      const rookFrom=to>from?idx(7,row,0,this.n):idx(0,row,0,this.n);
      const rookTo=to>from?idx(5,row,0,this.n):idx(3,row,0,this.n);
      b[rookFrom]=b[rookTo];
      b[rookTo]=0;
    }
    if(flag&1)b[to-this.turn*this.n]=-this.turn*P;
    else if(this.uc[u])b[to]=this.uc[u];
  }
  repetitions(){
    const k=this.hist[this.hist.length-1];
    let n=0;
    for(let i=this.hist.length-3;i>=0;i-=2)if(this.hist[i]===k)n++;
    return n;
  }
  evaluate(){
    const b=this.board,g=this.g,n=this.n,layers=this.layers,pcW=this.pcW,pcB=this.pcB;
    pcW.fill(0);pcB.fill(0);
    let mid=0,end=0,phase=0,bishops=0,bishopsB=0;
    for(let i=0;i<this.vol;i++){
      const p=b[i];
      if(!p)continue;
      const side=p>0?1:-1,t=p>0?p:-p,sq=side>0?i:g.mirror[i];
      phase+=g.phase[t];
      mid+=side*(g.val[t]+g.pstMid[t][sq]);
      end+=side*(g.val[t]+g.pstEnd[t][sq]);
      if(t===P){const[x,,z]=g.xyz[sq];(side>0?pcW:pcB)[x+n*z]++;}
      else if(t===B){if(side>0)bishops++;else bishopsB++;}
    }
    if(bishops>1)mid+=16;
    if(bishopsB>1)mid-=16;
    for(let z=0;z<layers;z++)for(let x=0;x<n;x++){
      for(const[sign,pc]of[[1,pcW],[-1,pcB]]){
        const c=pc[x+n*z];
        if(!c)continue;
        if(c>1)mid-=sign*(c-1)*9;
        const left=x>0?pc[x-1+n*z]:0,right=x<n-1?pc[x+1+n*z]:0;
        const back=z>0?pc[x+n*(z-1)]:0,front=z<layers-1?pc[x+n*(z+1)]:0;
        if(!left&&!right&&!back&&!front)mid-=sign*7;
      }
    }
    if(this.kp1>=0)mid+=this.shield(this.kp1,1)*4;
    if(this.kpm1>=0)mid-=this.shield(this.kpm1,-1)*4;
    for(let i=0;i<this.vol;i++){
      const p=b[i];
      if(p!==R&&p!==-R)continue;
      const[x,,z]=g.xyz[p>0?i:g.mirror[i]];
      const own=p>0?pcW[x+n*z]:pcB[x+n*z];
      if(own)continue;
      let enemy=0;
      for(let dz=-1;dz<=1&&!enemy;dz++)for(let dx=-1;dx<=1;dx++){
        const xx=x+dx,zz=z+dz;
        if(xx<0||xx>=n||zz<0||zz>=layers)continue;
        if(pcW[xx+n*zz]||pcB[xx+n*zz]){enemy=1;break;}
      }
      mid+=p>0?(enemy?6:11):-(enemy?6:11);
    }
    const ph=Math.min(1,phase/24);
    const total=mid*ph+end*(1-ph);
    return Math.round((this.turn>0?total:-total)+8);
  }
  shield(k,side){
    const g=this.g,b=this.board;
    const[x,y,z]=g.xyz[k];
    let score=0;
    for(const[dx,dz]of[[-1,0],[0,0],[1,0]]){
      for(let d=0;d<=1;d++){
        const yy=y+(side>0?1+d:-1-d),xx=x+dx,zz=z+dz;
        if(xx<0||xx>=this.n||zz<0||zz>=this.layers||yy<0||yy>=this.n)continue;
        if(b[idx(xx,yy,zz,this.n)]===side*P)score++;
      }
    }
    return score;
  }
}

export function initial(mode='classic'){
  const conf=MODES[mode]||MODES.classic,n=conf.n,layers=conf.layers;
  const board=Array(n*n*layers).fill(0);
  if(mode==='strata'){
    const set=(x,y,z,p)=>{board[idx(x,y,z,n)]=p;};
    const white=[[0,0,0,R],[4,0,2,R],[1,0,0,N],[3,0,2,N],[0,0,1,B],[4,0,1,B],[2,0,0,B],[1,0,1,Q],[2,0,1,K]];
    for(const[x,y,z,p]of white){set(x,y,z,p);set(n-1-x,n-1-y,layers-1-z,-p);}
    for(let z=0;z<layers;z++)for(let x=0;x<n;x++)if(x!==2){set(x,1,z,P);set(x,n-2,z,-P);}
    return {mode:'strata',n,layers,board,turn:1,castle:0,ep:-1,half:0,ply:0};
  }
  const back=[R,N,B,Q,K,B,N,R];
  for(let x=0;x<n;x++){
    board[idx(x,0,0,n)]=back[x];
    board[idx(x,1,0,n)]=P;
    board[idx(x,n-1,0,n)]=-back[x];
    board[idx(x,n-2,0,n)]=-P;
  }
  return {mode:'classic',n,layers,board,turn:1,castle:15,ep:-1,half:0,ply:0};
}

export function key(s){
  let out='';
  for(let i=0;i<s.board.length;i++)out+=String.fromCharCode(s.board[i]+40);
  return out+'|'+s.turn+'|'+s.castle+'|'+s.ep;
}

function decode(mv){
  const m={from:mv&127,to:(mv>>7)&127};
  const promo=(mv>>14)&7;
  if(promo)m.promotion=promo;
  const flag=(mv>>17)&7;
  if(flag&1)m.ep=true;else if(flag&2)m.double=true;else if(flag&4)m.castle=true;
  return m;
}
function encode(m,pos){
  let flag=0;
  if(m.ep)flag|=1;else if(m.double)flag|=2;else if(m.castle)flag|=4;
  else if(pos&&Math.abs(pos.board[m.from])===P&&Math.abs(m.to-m.from)===2*pos.n)flag|=2;
  return m.from|m.to<<7|((m.promotion||0)<<14)|flag<<17;
}
export function apply(s,m){
  const p=new Pos(s);
  p.make(encode(m,p));
  return {mode:p.layers>1?'strata':'classic',n:p.n,layers:p.layers,board:Array.from(p.board),turn:p.turn,castle:p.castle,ep:p.ep,half:p.half,ply:(s.ply||0)+1};
}
export function legal(s){
  const p=new Pos(s),buf=new Int32Array(256),out=[];
  const count=p.gen(buf,false);
  for(let i=0;i<count;i++){
    const mv=buf[i];
    p.make(mv);
    const bad=p.inCheck(-p.turn);
    p.unmake();
    if(!bad)out.push(decode(mv));
  }
  return out;
}
export function isAttacked(s,square,side){return new Pos(s).attacked(square,side);}
export function inCheck(s,side=s.turn){return new Pos(s).inCheck(side);}
export function deadPosition(s){
  const pieces=[];
  for(let i=0;i<s.board.length;i++){const p=Math.abs(s.board[i]);if(p&&p!==K)pieces.push({p,i});}
  if(!pieces.length)return true;
  if(pieces.length===1&&(pieces[0].p===N||pieces[0].p===B))return true;
  return pieces.every(a=>a.p===B)&&new Set(pieces.map(a=>{const[x,y]=xyz(a.i,s.n);return(x+y)%2;})).size===1;
}
export function outcome(s,repetitions=1){
  const p=new Pos(s),buf=new Int32Array(256);
  const count=p.gen(buf,false);
  let hasMove=false;
  for(let i=0;i<count;i++){
    p.make(buf[i]);
    const bad=p.inCheck(-p.turn);
    p.unmake();
    if(!bad){hasMove=true;break;}
  }
  const check=p.inCheck();
  if(!hasMove)return check?{over:true,reason:'Мат',winner:-s.turn}:{over:true,reason:'Пат',winner:0};
  if(s.half>=100)return {over:true,reason:'Правило 50 ходов',winner:0};
  if(repetitions>=3)return {over:true,reason:'Троекратное повторение',winner:0};
  if(deadPosition(s))return {over:true,reason:'Недостаточно материала',winner:0};
  return {over:false,check};
}
export function squareName(i,s){const[x,y,z]=xyz(i,s.n);return String.fromCharCode(97+x)+(y+1)+(s.layers>1?'·'+(z+1):'');}
export function notation(s,m){
  if(m.castle)return m.to>m.from?'O-O':'O-O-O';
  const names=['','','К','С','Л','Ф','Кр'];
  const capture=Boolean(s.board[m.to]||m.ep);
  return names[Math.abs(s.board[m.from])]+squareName(m.from,s)+(capture?'×':'–')+squareName(m.to,s)+(m.promotion?'='+names[m.promotion]:'');
}
export function evaluate(s){return new Pos(s).evaluate();}

const TT=new Map();
const TT_LIMIT=300000;

export function search(state,{time=1500,maxDepth=7,history=[],onProgress=()=>{}}={}){
  const started=performance.now(),deadline=started+time;
  const f=new Pos(state);
  for(const entry of history){
    if(entry&&typeof entry==='object'&&entry.board)f.hist.push(new Pos(entry).hashKey());
    else if(typeof entry==='number')f.hist.push(entry);
  }
  const searcher=makeSearcher(f,deadline);
  const rootBuf=new Int32Array(256),rootCount=f.gen(rootBuf,false);
  const rootMoves=[];
  for(let i=0;i<rootCount;i++){
    const mv=rootBuf[i];
    f.make(mv);
    const ok=!f.inCheck(-f.turn);
    f.unmake();
    if(ok)rootMoves.push(mv);
  }
  if(!rootMoves.length)return {move:null,depth:0,nodes:0,score:0,elapsed:performance.now()-started};
  const scores=new Map();
  let order=rootMoves.slice(),best=rootMoves[0],bestScore=0,completed=0,nodes=0,mate=false;
  for(let depth=1;depth<=maxDepth;depth++){
    let alpha=-MATE,beta=MATE,iterationBest=best,aborted=false;
    try{
      for(let i=0;i<order.length;i++){
        const mv=order[i];
        f.make(mv);
        let value;
        try{
          if(i===0)value=-searcher(depth-1,-beta,-alpha,1,true);
          else{
            value=-searcher(depth-1,-alpha-1,-alpha,1,true);
            if(value>alpha&&value<beta)value=-searcher(depth-1,-beta,-alpha,1,true);
          }
        }finally{f.unmake();}
        scores.set(mv,value);
        if(value>alpha){alpha=value;iterationBest=mv;}
      }
    }catch(e){
      if(e!==STOP)throw e;
      aborted=true;
    }
    if(aborted)break;
    best=iterationBest;bestScore=alpha;completed=depth;nodes=searcher.nodes;
    order=order.slice().sort((a,b)=>(scores.get(b)??-MATE)-(scores.get(a)??-MATE));
    onProgress({depth,nodes,score:bestScore,elapsed:performance.now()-started});
    if(Math.abs(bestScore)>MATE-1000){mate=true;break;}
    if(performance.now()>deadline)break;
  }
  nodes=searcher.nodes;
  return {move:decode(best),depth:completed,nodes,score:bestScore,mate,elapsed:performance.now()-started};
}

function makeSearcher(f,deadline){
  const g=f.g;
  const killers=new Int32Array(2048);
  const hist=new Int32Array(16384);
  const bufs=Array.from({length:200},()=>new Int32Array(256));
  const scoreBuf=new Int32Array(256);
  const val=g.val;
  let nodes=0;
  const ttMoveOf=entry=>entry?entry.move:0;

  function orderMoves(buf,count,ply,ttMove){
    const b=f.board;
    for(let i=0;i<count;i++){
      const mv=buf[i],from=mv&127,to=(mv>>7)&127,promo=(mv>>14)&7;
      let s=0;
      if(mv===ttMove)s+=1000000;
      const victim=b[to];
      if(victim)s+=10000+val[victim>0?victim:-victim]*8-val[b[from]>0?b[from]:-b[from]];
      if(promo)s+=8000+val[promo]*4;
      if((mv>>17)&1)s+=9000;
      if(!victim&&!promo){
        if(killers[ply*2]===mv)s+=6000;
        else if(killers[ply*2+1]===mv)s+=5000;
        else s+=Math.min(4000,hist[((from<<7)|to)&16383]);
      }
      scoreBuf[i]=s;
    }
    for(let i=1;i<count;i++){
      const mv=buf[i],sv=scoreBuf[i];
      let j=i-1;
      while(j>=0&&scoreBuf[j]<sv){buf[j+1]=buf[j];scoreBuf[j+1]=scoreBuf[j];j--;}
      buf[j+1]=mv;scoreBuf[j+1]=sv;
    }
  }

  function quiesce(alpha,beta,ply,qd){
    nodes++;
    if((nodes&1023)===0&&performance.now()>deadline)throw STOP;
    if(ply>=150)return f.evaluate();
    const inChk=f.inCheck();
    let best;
    if(!inChk){
      best=f.evaluate();
      if(best>=beta)return beta;
      if(best>alpha)alpha=best;
    }else best=alpha;
    if(qd>6)return best;
    const buf=bufs[ply],count=f.gen(buf,!inChk);
    orderMoves(buf,count,ply,0);
    let legalCount=0;
    for(let i=0;i<count;i++){
      const mv=buf[i];
      f.make(mv);
      if(f.inCheck(-f.turn)){f.unmake();continue;}
      legalCount++;
      const value=-quiesce(-beta,-alpha,ply+1,qd+1);
      f.unmake();
      if(value>=beta)return beta;
      if(value>alpha)alpha=value;
    }
    if(inChk&&!legalCount)return -MATE+ply;
    return alpha;
  }

  function negamax(depth,alpha,beta,ply,allowNull){
    nodes++;
    if((nodes&1023)===0&&performance.now()>deadline)throw STOP;
    if(ply>=150)return f.evaluate();
    if(f.repetitions()>=1||f.half>=100)return 0;
    const check=f.inCheck();
    if(check)depth++;
    if(depth<=0)return quiesce(alpha,beta,ply,0);
    const alphaOrig=alpha,betaOrig=beta;
    const ttKey=f.hashKey(),entry=TT.get(ttKey);
    const ttMove=ttMoveOf(entry);
    if(entry&&entry.depth>=depth){
      const score=entry.score>MATE-1000?entry.score-ply:entry.score<-MATE+1000?entry.score+ply:entry.score;
      if(entry.flag===0)return score;
      if(entry.flag===1&&score>alpha)alpha=score;
      else if(entry.flag===2&&score<beta)beta=score;
      if(alpha>=beta)return score;
    }
    if(allowNull&&!check&&depth>=3&&ply>0&&beta<MATE-1000&&f.hasMaterial()){
      f.makeNull();
      let value;
      try{value=-negamax(depth-3,-beta,-beta+1,ply+1,false);}
      finally{f.unmakeNull();}
      if(value>=beta){
        if(TT.size<TT_LIMIT)TT.set(ttKey,{depth,score:beta,flag:1,move:0});
        return beta;
      }
    }
    const buf=bufs[ply],count=f.gen(buf,false);
    orderMoves(buf,count,ply,ttMove);
    let bestScore=-MATE,legalCount=0,searched=0,bestMove=buf[0];
    for(let i=0;i<count;i++){
      const mv=buf[i];
      const to=(mv>>7)&127,promo=(mv>>14)&7,flag=(mv>>17)&7;
      const capture=flag&1?true:Boolean(f.board[to]);
      f.make(mv);
      if(f.inCheck(-f.turn)){f.unmake();continue;}
      legalCount++;
      const quiet=!capture&&!promo;
      let value;
      if(searched===0){
        value=-negamax(depth-1,-beta,-alpha,ply+1,true);
      }else{
        value=-negamax(depth-1,-alpha-1,-alpha,ply+1,true);
        if(value>alpha&&value<beta)value=-negamax(depth-1,-beta,-alpha,ply+1,true);
      }
      f.unmake();
      searched++;
      if(value>bestScore){bestScore=value;bestMove=mv;}
      if(value>alpha)alpha=value;
      if(alpha>=beta){
        if(quiet){
          killers[ply*2+1]=killers[ply*2];
          killers[ply*2]=mv;
          hist[((mv&127)<<7|((mv>>7)&127))&16383]+=depth*depth;
        }
        break;
      }
    }
    if(!legalCount)return check?-MATE+ply:0;
    if(TT.size>TT_LIMIT)TT.clear();
    const stored=bestScore>MATE-1000?bestScore+ply:bestScore<-MATE+1000?bestScore-ply:bestScore;
    TT.set(ttKey,{depth,score:stored,move:bestMove,flag:bestScore<=alphaOrig?2:bestScore>=betaOrig?1:0});
    return bestScore;
  }

  return Object.defineProperty(negamax,'nodes',{get:()=>nodes});
}
