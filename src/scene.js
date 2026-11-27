import * as THREE from 'three';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
import {RoomEnvironment} from 'three/addons/environments/RoomEnvironment.js';
import {xyz} from './engine.js';

export const palettes={
  wood:{light:0xcbbda1,dark:0x5f4d3d,frame:0x2f2822,white:0xf7efdd,black:0x2f2b26,ink:0x8a6a45,glow:0xd8a86b,bg:0xf0efea},
  marble:{light:0xe6e5dd,dark:0x6f7a74,frame:0x2f3a35,white:0xfffdf5,black:0x25352e,ink:0x7f9490,glow:0x9fc4b4,bg:0xeeeef0},
  neon:{light:0x8fc3c0,dark:0x1f3d46,frame:0x0e2831,white:0xd8fff2,black:0x123844,ink:0x3fd6b8,glow:0x4ff0cc,bg:0x0e1116},
  minimal:{light:0xebe9e3,dark:0x8f9089,frame:0x43453f,white:0xfffdf7,black:0x2c332e,ink:0x9aa27f,glow:0xb8c39a,bg:0xf6f6f6},
};

const reduced=()=>matchMedia('(prefers-reduced-motion: reduce)').matches;

export class BoardScene{
  constructor(container,onSelect){
    this.container=container;this.onSelect=onSelect;
    this.theme='wood';this.geometry='square';this.gap=2.6;this.view='perspective';
    this.meshes=new Map();this.animations=[];this.targets=[];this.visible=true;this.fps=0;
    this.cache=new Map();this.hover=-1;this.selection=null;this.moves=[];this.last=null;

    this.scene=new THREE.Scene();
    const bg=new THREE.Color(0xf0efea);
    this.scene.background=bg;this.scene.fog=new THREE.Fog(bg,30,62);
    this.camera=new THREE.PerspectiveCamera(34,1,.1,120);
    this.camera.position.set(9,11,14);
    this.cameraTarget=new THREE.Vector3(0,0,0);
    this.viewAnim=null;

    this.renderer=new THREE.WebGLRenderer({antialias:true,powerPreference:'high-performance'});
    this.renderer.setPixelRatio(Math.min(devicePixelRatio,innerWidth<620?1.6:2));
    this.renderer.shadowMap.enabled=true;this.renderer.shadowMap.type=THREE.PCFSoftShadowMap;
    this.renderer.toneMapping=THREE.ACESFilmicToneMapping;this.renderer.toneMappingExposure=1.12;
    this.renderer.outputColorSpace=THREE.SRGBColorSpace;
    this.renderer.domElement.setAttribute('role','img');
    this.renderer.domElement.setAttribute('aria-label','Трёхмерная шахматная доска. Нажмите на фигуру, затем на подсвеченную клетку.');
    container.append(this.renderer.domElement);

    const pmrem=new THREE.PMREMGenerator(this.renderer),room=new RoomEnvironment();
    this.environment=pmrem.fromScene(room).texture;this.scene.environment=this.environment;
    room.dispose();pmrem.dispose();

    this.controls=new OrbitControls(this.camera,this.renderer.domElement);
    Object.assign(this.controls,{enableDamping:true,dampingFactor:.075,enableZoom:false,enablePan:false,rotateSpeed:.75});
    this.controls.minPolarAngle=.08;this.controls.maxPolarAngle=Math.PI*.48;

    this.scene.add(new THREE.HemisphereLight(0xffffff,0x9c8a72,1.9));
    const key=new THREE.DirectionalLight(0xfff7ea,3.6);
    key.position.set(-6,14,8);key.castShadow=true;key.shadow.mapSize.set(2048,2048);
    Object.assign(key.shadow.camera,{left:-12,right:12,top:12,bottom:-12,near:.5,far:48});
    key.shadow.bias=-.0006;key.shadow.normalBias=.025;
    this.scene.add(key);
    const rim=new THREE.DirectionalLight(0xcfe3ff,.7);rim.position.set(7,6,-9);this.scene.add(rim);

    const floor=this.floor=new THREE.Mesh(new THREE.PlaneGeometry(220,220),new THREE.MeshStandardMaterial({color:0xf0efea,roughness:.96}));
    floor.rotation.x=-Math.PI/2;floor.position.y=-.44;floor.receiveShadow=true;this.scene.add(floor);

    this.boardGroup=new THREE.Group();this.pieceGroup=new THREE.Group();
    this.markGroup=new THREE.Group();this.hoverGroup=new THREE.Group();
    this.scene.add(this.boardGroup,this.pieceGroup,this.markGroup,this.hoverGroup);

    this.raycaster=new THREE.Raycaster();this.pointer=new THREE.Vector2();
    const el=this.renderer.domElement;let down=null;
    el.addEventListener('pointerdown',e=>{down={x:e.clientX,y:e.clientY};});
    el.addEventListener('pointerup',e=>{
      if(!down||Math.hypot(e.clientX-down.x,e.clientY-down.y)>8)return;
      down=null;
      const hit=this.pick(e);
      if(hit!==null)this.onSelect(hit);
    });
    el.addEventListener('pointermove',e=>this.onHover(e));
    el.addEventListener('pointerleave',()=>this.setHover(-1));

    this.resize=new ResizeObserver(()=>this.resizeView());this.resize.observe(container);
    this.observer=new IntersectionObserver(entries=>{this.visible=entries[0].isIntersecting;});
    this.observer.observe(container);

    this.frames=0;this.lastFrame=performance.now();
    this.renderer.setAnimationLoop(()=>this.tick());
    this.resizeView();
  }

  tick(){
    if(!this.visible||document.hidden)return;
    const now=performance.now();
    this.frames++;
    if(now-this.lastFrame>=600){this.fps=Math.round(this.frames*1000/(now-this.lastFrame));this.frames=0;this.lastFrame=now;}
    if(this.viewAnim){
      const t=Math.min(1,(now-this.viewAnim.start)/this.viewAnim.duration),e=1-(1-t)**3;
      this.camera.position.lerpVectors(this.viewAnim.from,this.viewAnim.to,e);
      this.controls.target.lerpVectors(this.viewAnim.targetFrom,this.viewAnim.targetTo,e);
      if(t>=1)this.viewAnim=null;
    }
    this.controls.update();
    this.animations=this.animations.filter(a=>{
      const t=Math.min(1,(now-a.start)/a.duration),e=1-(1-t)**3;
      if(a.capture){
        a.obj.scale.setScalar(Math.max(.001,1-e));
        a.obj.position.y=a.from.y-e*.5;
        if(t>=1){a.obj.removeFromParent();this.disposeGroup(a.obj);}
      }else{
        a.obj.position.lerpVectors(a.from,a.to,e);
        a.obj.position.y+=Math.sin(t*Math.PI)*.55;
      }
      return t<1;
    });
    this.renderer.render(this.scene,this.camera);
  }

  pick(event){
    const r=this.renderer.domElement.getBoundingClientRect();
    this.pointer.set((event.clientX-r.left)/r.width*2-1,-(event.clientY-r.top)/r.height*2+1);
    this.raycaster.setFromCamera(this.pointer,this.camera);
    const hits=this.raycaster.intersectObjects(this.targets,true);
    for(const hit of hits){
      let o=hit.object;
      while(o&&o.userData.square===undefined)o=o.parent;
      if(o)return o.userData.square;
    }
    return null;
  }

  onHover(event){
    if(!this.state||reduced())return;
    const square=this.pick(event);
    this.setHover(square);
  }

  setHover(square){
    if(this.hover===square)return;
    this.hover=square;
    this.renderer.domElement.style.cursor=square===null?'default':'pointer';
    this.clear(this.hoverGroup);
    if(square===null)return;
    const mat=new THREE.MeshBasicMaterial({color:palettes[this.theme].glow,transparent:true,opacity:.16});
    const tile=new THREE.Mesh(new THREE.BoxGeometry(.97,.012,.97),mat);
    tile.position.copy(this.position(square));tile.position.y+=.052;
    this.hoverGroup.add(tile);
  }

  resizeView(){
    const{width,height}=this.container.getBoundingClientRect();
    if(!width||!height)return;
    this.camera.aspect=width/height;this.camera.updateProjectionMatrix();
    this.renderer.setSize(width,height);
    this.frame(false);
  }

  position(i){
    const[x,y,z]=xyz(i,this.state.n),c=(this.state.n-1)/2;
    return new THREE.Vector3(x-c,z*this.gap,c-y);
  }

  computeCamera(){
    const layers=this.state.layers,n=this.state.n;
    const h=(layers-1)*this.gap/2;
    const base=layers>1?16.5:15.5;
    const ratio=this.camera.aspect/.95;
    const d=base*(ratio<1?Math.min(3.4,1.42/ratio):1);
    const v=this.view==='top'?[0,d*1.02,.001]
      :this.view==='white'?[0,d*.62,d*.9]
      :this.view==='black'?[0,d*.62,-d*.9]
      :[d*.52,d*.66,d*.8];
    return {position:new THREE.Vector3(v[0],h+v[1],v[2]),target:new THREE.Vector3(0,h,0)};
  }

  frame(animate=true){
    if(!this.state)return;
    const{position,target}=this.computeCamera();
    const dist=position.distanceTo(target);
    this.scene.fog.near=dist*.95;this.scene.fog.far=dist*2.2;
    if(this.camera.aspect!==this.lastAspect){this.lastAspect=this.camera.aspect;animate=false;}
    if(animate&&!reduced()){
      this.viewAnim={from:this.camera.position.clone(),to:position,targetFrom:this.controls.target.clone(),targetTo:target,start:performance.now(),duration:520};
    }else{
      this.camera.position.copy(position);this.controls.target.copy(target);this.viewAnim=null;
    }
    this.controls.update();
  }

  setView(view){this.view=view;this.frame();}

  setStyle(theme,geometry,gap){
    const changed=this.theme!==theme||this.geometry!==geometry||this.gap!==gap||this.state?.layers>1!==gap>1;
    this.theme=theme;this.geometry=geometry;this.gap=gap;this.cache.clear();
    const bg=palettes[theme].bg;this.scene.background.setHex(bg);this.scene.fog.color.setHex(bg);this.floor.material.color.setHex(bg);
    if(!this.state)return;
    if(changed){this.buildBoard();this.rebuildPieces();this.mark(this.selection,this.moves,this.last);this.frame();}
  }

  geometryFor(key,maker){
    if(!this.cache.has(key))this.cache.set(key,maker());
    return this.cache.get(key);
  }

  material(color,extra={}){return new THREE.MeshStandardMaterial({color,roughness:this.theme==='neon'?.22:.42,metalness:this.theme==='neon'?.35:.05,...extra});}

  tileSize(){return this.geometry==='hex'?.52:this.geometry==='round'?.475:.492;}

  buildBoard(){
    this.clear(this.boardGroup);
    const s=this.state,p=palettes[this.theme],n=s.n;
    const inset=this.gap>1?.9:.62;
    for(let z=0;z<s.layers;z++){
      const frame=new THREE.Mesh(
        this.geometryFor('frame'+n+this.geometry,()=>new THREE.BoxGeometry(n+inset,.28,n+inset)),
        this.material(p.frame,{roughness:.55})
      );
      frame.position.y=z*this.gap-.19;frame.receiveShadow=true;frame.castShadow=true;
      this.boardGroup.add(frame);
      const lip=new THREE.Mesh(
        this.geometryFor('lip'+n,()=>new THREE.BoxGeometry(n+inset+.06,.05,n+inset+.06)),
        this.material(p.ink,{roughness:.35,metalness:this.theme==='neon'?.6:.1})
      );
      lip.position.y=z*this.gap-.045;this.boardGroup.add(lip);

      for(let y=0;y<n;y++)for(let x=0;x<n;x++){
        const i=x+n*y+n*n*z;
        const shape=this.geometry==='round'
          ?this.geometryFor('tileR',()=>new THREE.CylinderGeometry(.475,.475,.09,40))
          :this.geometry==='hex'
            ?this.geometryFor('tileH',()=>new THREE.CylinderGeometry(.535,.535,.09,6))
            :this.geometryFor('tileS',()=>new THREE.BoxGeometry(.985,.09,.985));
        const dark=(x+y)%2===1;
        const tile=new THREE.Mesh(shape,this.material(dark?p.dark:p.light,{roughness:this.theme==='marble'?.2:.5,metalness:this.theme==='neon'?.15:.03}));
        tile.position.copy(this.position(i));tile.position.y-=.005;
        tile.userData.square=i;tile.receiveShadow=true;
        this.boardGroup.add(tile);
      }
      if(s.layers>1)this.boardGroup.add(this.layerLabel(z,s));
    }
    for(let a=0;a<n;a++){
      const file=this.label(String.fromCharCode(97+a),p.ink);
      file.position.set(a-(n-1)/2,0,s.n/2+(this.gap>1?.22:.19));
      file.position.y=-.02;this.boardGroup.add(file);
      const rank=this.label(String(a+1),p.ink);
      rank.position.set(-s.n/2-(this.gap>1?.23:.18),-.02,(n-1)/2-a);this.boardGroup.add(rank);
    }
    this.collectTargets();
  }

  layerLabel(z,s){
    const mesh=this.label('СЛОЙ '+(z+1),palettes[this.theme].ink,true);
    mesh.position.set(0,z*this.gap-.03,-s.n/2-(this.gap>1?.42:.3));
    mesh.scale.multiplyScalar(1.1);
    return mesh;
  }

  label(text,color='#a1917a',wide=false){
    const c=document.createElement('canvas');c.width=wide?256:128;c.height=64;
    const ctx=c.getContext('2d');
    ctx.font=(wide?'500 30px':'500 36px')+' ui-sans-serif, system-ui, sans-serif';
    ctx.textAlign='center';ctx.textBaseline='middle';
    ctx.fillStyle=color;ctx.fillText(text,c.width/2,34);
    const texture=new THREE.CanvasTexture(c);
    texture.colorSpace=THREE.SRGBColorSpace;texture.anisotropy=4;
    const mesh=new THREE.Mesh(
      new THREE.PlaneGeometry(wide?.9:.44,wide?.22:.22),
      new THREE.MeshBasicMaterial({map:texture,transparent:true,depthWrite:false})
    );
    mesh.rotation.x=-Math.PI/2;
    return mesh;
  }

  piece(type,side){
    const key='p'+type+side+this.theme;
    if(this.cache.has(key))return this.cache.get(key).clone(true);
    const group=new THREE.Group();
    const p=palettes[this.theme];
    const isWhite=side===1;
    const color=isWhite?p.white:p.black;
    const mat=this.theme==='neon'
      ?new THREE.MeshPhysicalMaterial({color,roughness:.18,metalness:.25,clearcoat:.9,clearcoatRoughness:.15,emissive:new THREE.Color(isWhite?0x0f4a3f:0x0a2530),emissiveIntensity:.6})
      :new THREE.MeshStandardMaterial({color,roughness:this.theme==='marble'?.22:.36,metalness:this.theme==='marble'?.12:.05});
    const accent=this.material(p.ink,{roughness:.4,metalness:this.theme==='neon'?.7:.15});
    const add=(geometry,y,rotation=0,material=mat,scale=null)=>{
      const m=new THREE.Mesh(geometry,material);
      m.position.y=y;m.rotation.y=rotation;m.castShadow=true;m.receiveShadow=true;
      if(scale)m.scale.copy(scale);
      group.add(m);return m;
    };
    const profiles={
      1:[[.26,0],[.30,.05],[.29,.11],[.20,.16],[.15,.21],[.11,.38],[.19,.41],[.175,.47],[.115,.50]],
      2:[[.30,0],[.33,.06],[.31,.13],[.22,.19],[.19,.25]],
      3:[[.30,0],[.32,.06],[.29,.13],[.20,.21],[.13,.44],[.21,.50],[.185,.56],[.10,.60]],
      4:[[.30,0],[.33,.07],[.30,.14],[.22,.20],[.185,.53],[.27,.59],[.27,.69]],
      5:[[.31,0],[.34,.07],[.31,.15],[.21,.22],[.13,.54],[.23,.60],[.20,.66],[.26,.82]],
      6:[[.32,0],[.35,.07],[.32,.15],[.22,.22],[.15,.62],[.24,.67],[.23,.74],[.14,.78]],
    };
    add(new THREE.LatheGeometry(profiles[type].map(([r,y])=>new THREE.Vector2(r,y)),36),.05);
    add(new THREE.CylinderGeometry(profiles[type][0][0]*1.02,profiles[type][0][0]*1.06,.045,32),.02,0,accent);
    if(type===1)add(new THREE.SphereGeometry(.175,26,18),.63);
    if(type===2){
      const shape=new THREE.Shape();
      shape.moveTo(-.2,.24);shape.lineTo(.19,.24);
      shape.bezierCurveTo(.24,.4,.06,.49,.13,.62);
      shape.lineTo(.32,.65);shape.lineTo(.36,.79);shape.lineTo(.13,.96);
      shape.lineTo(.08,1.12);shape.lineTo(-.04,1.0);
      shape.bezierCurveTo(-.27,.9,-.34,.61,-.2,.24);
      const g=new THREE.ExtrudeGeometry(shape,{depth:.19,bevelEnabled:true,bevelThickness:.035,bevelSize:.035,bevelSegments:3,steps:1});
      g.translate(0,.05,-.095);
      add(g,0,Math.PI/2);
      add(new THREE.SphereGeometry(.05,12,10),.62,0,accent).position.x=.16;
      add(new THREE.SphereGeometry(.05,12,10),.62,0,accent).position.x=-.16;
    }
    if(type===3){
      const head=add(new THREE.SphereGeometry(.19,26,18),.78);head.scale.set(.78,1.4,.78);
      add(new THREE.SphereGeometry(.062,14,10),1.06,0,accent);
    }
    if(type===4){
      for(let a=0;a<6;a++){
        const tooth=add(new THREE.BoxGeometry(.125,.15,.13),.79,a*Math.PI/3);
        tooth.position.x=Math.sin(a*Math.PI/3)*.205;
        tooth.position.z=Math.cos(a*Math.PI/3)*.205;
      }
    }
    if(type===5){
      for(let a=0;a<7;a++){
        const bead=add(new THREE.SphereGeometry(.068,14,10),.91);
        bead.position.x=Math.sin(a*Math.PI*2/7)*.235;
        bead.position.z=Math.cos(a*Math.PI*2/7)*.235;
      }
      add(new THREE.SphereGeometry(.09,16,12),.97,0,accent);
    }
    if(type===6){
      add(new THREE.BoxGeometry(.095,.32,.09),1.0);
      add(new THREE.BoxGeometry(.3,.09,.09),1.06);
      add(new THREE.SphereGeometry(.058,14,10),1.14,0,accent);
    }
    this.cache.set(key,group);
    return group.clone(true);
  }

  rebuildPieces(){
    this.clear(this.pieceGroup);this.meshes.clear();
    const s=this.state;
    for(let i=0;i<s.board.length;i++){
      const p=s.board[i];
      if(!p)continue;
      const obj=this.piece(Math.abs(p),Math.sign(p));
      obj.userData.square=i;
      obj.position.copy(this.position(i));obj.position.y+=.065;
      this.pieceGroup.add(obj);this.meshes.set(i,obj);
    }
    this.collectTargets();
  }

  collectTargets(){
    this.targets=[...this.boardGroup.children,...this.pieceGroup.children,...this.markGroup.children];
  }

  update(state,move=null){
    const previous=this.state;
    this.state=state;
    const layoutChanged=!previous||previous.mode!==state.mode||previous.layers!==state.layers;
    if(layoutChanged){
      this.gap=state.layers>1?2.6:1.02;
      this.animations=[];
      this.buildBoard();
      this.rebuildPieces();
      this.frame();
    }else if(move){
      this.applyMove(move);
    }else{
      this.rebuildPieces();
    }
    this.collectTargets();
  }

  applyMove(move){
    const s=this.state;
    const quiet=reduced();
    const moving=this.meshes.get(move.from);
    if(move.castle){
      const row=Math.floor(move.from/s.n),kingSide=move.to>move.from;
      const rookFrom=kingSide?row*s.n+s.n-1:row*s.n;
      const rookTo=kingSide?row*s.n+s.n-3:row*s.n+2;
      const rook=this.meshes.get(rookFrom);
      if(rook){
        this.meshes.delete(rookFrom);
        rook.userData.square=rookTo;
        const from=this.position(rookFrom),to=this.position(rookTo);
        from.y+=.065;to.y+=.065;
        if(quiet)rook.position.copy(to);
        else this.animations.push({obj:rook,from,to,start:performance.now(),duration:340});
        this.meshes.set(rookTo,rook);
      }
    }
    const capturedSquare=move.ep?move.to-s.turn*s.n:move.to;
    const captured=this.meshes.get(capturedSquare);
    if(captured&&captured!==moving){
      this.meshes.delete(capturedSquare);
      captured.userData.square=undefined;
      if(quiet){captured.removeFromParent();this.disposeGroup(captured);}
      else{
        const from=captured.position.clone(),to=from.clone();
        this.animations.push({obj:captured,from,to,start:performance.now(),duration:260,capture:true});
      }
    }
    if(moving){
      this.meshes.delete(move.from);
      moving.userData.square=move.to;
      const from=this.position(move.from),to=this.position(move.to);
      from.y+=.065;to.y+=.065;
      if(quiet)moving.position.copy(to);
      else this.animations.push({obj:moving,from,to,start:performance.now(),duration:330});
      this.meshes.set(move.to,moving);
    }
    const piece=s.board[move.to];
    if(move.promotion&&moving){
      moving.removeFromParent();this.disposeGroup(moving);
      this.meshes.delete(move.to);
      const obj=this.piece(Math.abs(piece),Math.sign(piece));
      obj.userData.square=move.to;
      obj.position.copy(this.position(move.to));obj.position.y+=.065;
      this.pieceGroup.add(obj);this.meshes.set(move.to,obj);
    }
    this.collectTargets();
  }

  mark(selection,moves=[],last=null){
    this.selection=selection;this.moves=moves;this.last=last;
    this.clear(this.markGroup);
    if(!this.state)return;
    const p=palettes[this.theme];
    const add=(i,type)=>{
      let mesh;
      if(type==='target'){
        mesh=new THREE.Mesh(new THREE.CylinderGeometry(.12,.12,.02,30),new THREE.MeshBasicMaterial({color:p.glow,transparent:true,opacity:.9}));
      }else if(type==='capture'){
        mesh=new THREE.Mesh(new THREE.TorusGeometry(.34,.035,12,40),new THREE.MeshBasicMaterial({color:p.glow,transparent:true,opacity:.95}));
        mesh.rotation.x=-Math.PI/2;
      }else if(type==='selected'){
        mesh=new THREE.Mesh(new THREE.BoxGeometry(.94,.02,.94),new THREE.MeshBasicMaterial({color:p.glow,transparent:true,opacity:.42}));
      }else{
        mesh=new THREE.Mesh(new THREE.BoxGeometry(.94,.014,.94),new THREE.MeshBasicMaterial({color:p.ink,transparent:true,opacity:.34}));
      }
      mesh.position.copy(this.position(i));mesh.position.y+=.055;
      mesh.userData.mark=true;
      this.markGroup.add(mesh);
    };
    if(last){add(last.from,'last');add(last.to,'last');}
    if(selection!==null&&selection!==undefined)add(selection,'selected');
    for(const m of moves){
      const occupied=this.state.board[m.to]||m.ep;
      add(m.to,occupied?'capture':'target');
    }
    this.collectTargets();
  }

  disposeGroup(group){
    group.traverse(o=>{
      o.geometry?.dispose();
      if(o.material){
        for(const m of(Array.isArray(o.material)?o.material:[o.material])){m.map?.dispose();m.dispose();}
      }
    });
  }
  clear(group){
    for(const child of [...group.children]){this.disposeGroup(child);group.remove(child);}
  }

  dispose(){
    this.renderer.setAnimationLoop(null);
    this.resize.disconnect();this.observer.disconnect();this.controls.dispose();
    this.disposeGroup(this.scene);this.environment.dispose();this.renderer.dispose();
    this.renderer.domElement.remove();
  }
}
