import * as THREE from 'three';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
import {RoomEnvironment} from 'three/addons/environments/RoomEnvironment.js';
import {xyz} from './engine.js';
export const palettes={wood:{light:0xc9b999,dark:0x66503e,frame:0x342b25,white:0xf3ead7,black:0x332e29,accent:0xb88857},marble:{light:0xe2e1da,dark:0x707b75,frame:0x35433d,white:0xfffcf2,black:0x273a32,accent:0x88a392},neon:{light:0x91bfbd,dark:0x24454b,frame:0x122e37,white:0xd6ffef,black:0x163f50,accent:0x5be7c6},minimal:{light:0xe7e5df,dark:0x969690,frame:0x4b4d49,white:0xfffdf4,black:0x303631,accent:0xa1aa82}};
const reduced=()=>matchMedia('(prefers-reduced-motion: reduce)').matches;
export class BoardScene{
  constructor(container,onSelect){
    this.container=container;this.onSelect=onSelect;this.theme='wood';this.geometry='square';this.gap=2.6;this.view='perspective';this.meshes=[];this.animations=[];this.targets=[];this.visible=true;
    this.scene=new THREE.Scene();this.scene.background=new THREE.Color(0xf0efea);this.scene.fog=new THREE.Fog(0xf0efea,27,55);
    this.camera=new THREE.PerspectiveCamera(34,1,.1,100);this.camera.position.set(8,10,13);
    this.renderer=new THREE.WebGLRenderer({antialias:true,alpha:false,powerPreference:'high-performance'});
    this.renderer.setPixelRatio(Math.min(devicePixelRatio,innerWidth<600?1.5:2));this.renderer.shadowMap.enabled=true;this.renderer.shadowMap.type=THREE.PCFSoftShadowMap;this.renderer.toneMapping=THREE.ACESFilmicToneMapping;this.renderer.toneMappingExposure=1.15;this.renderer.outputColorSpace=THREE.SRGBColorSpace;
    this.renderer.domElement.setAttribute('role','img');this.renderer.domElement.setAttribute('aria-label','Интерактивная шахматная доска. Нажмите на фигуру, затем на подсвеченную клетку.');container.append(this.renderer.domElement);
    const pmrem=new THREE.PMREMGenerator(this.renderer),room=new RoomEnvironment();this.environment=pmrem.fromScene(room).texture;this.scene.environment=this.environment;room.dispose();pmrem.dispose();
    this.controls=new OrbitControls(this.camera,this.renderer.domElement);this.controls.enableDamping=true;this.controls.dampingFactor=.08;this.controls.enableZoom=false;this.controls.enablePan=false;this.controls.minPolarAngle=.12;this.controls.maxPolarAngle=Math.PI*.48;
    this.scene.add(new THREE.HemisphereLight(0xffffff,0x8e7b64,2.1));const key=new THREE.DirectionalLight(0xfff8eb,4);key.position.set(-5,12,7);key.castShadow=true;key.shadow.mapSize.set(1024,1024);Object.assign(key.shadow.camera,{left:-10,right:10,top:10,bottom:-10,near:.5,far:40});key.shadow.bias=-.001;key.shadow.normalBias=.03;this.scene.add(key);
    const floor=new THREE.Mesh(new THREE.PlaneGeometry(150,150),new THREE.MeshStandardMaterial({color:0xf0efea,roughness:.94}));floor.rotation.x=-Math.PI/2;floor.position.y=-.42;floor.receiveShadow=true;this.scene.add(floor);
    this.boardGroup=new THREE.Group();this.pieceGroup=new THREE.Group();this.markGroup=new THREE.Group();this.scene.add(this.boardGroup,this.pieceGroup,this.markGroup);
    this.raycaster=new THREE.Raycaster();const pointer=new THREE.Vector2();let down=null;
    this.renderer.domElement.addEventListener('pointerdown',e=>{down={x:e.clientX,y:e.clientY};});
    this.renderer.domElement.addEventListener('pointerup',e=>{if(!down||Math.hypot(e.clientX-down.x,e.clientY-down.y)>7)return;down=null;const r=this.renderer.domElement.getBoundingClientRect();pointer.set((e.clientX-r.left)/r.width*2-1,-(e.clientY-r.top)/r.height*2+1);this.raycaster.setFromCamera(pointer,this.camera);const hits=this.raycaster.intersectObjects(this.targets,true);if(hits.length){let o=hits[0].object;while(o&&o.userData.square===undefined)o=o.parent;if(o)this.onSelect(o.userData.square);}});
    this.resize=new ResizeObserver(()=>{const {width,height}=container.getBoundingClientRect();if(!width||!height)return;this.camera.aspect=width/height;this.camera.updateProjectionMatrix();this.renderer.setSize(width,height);this.frame(false);});this.resize.observe(container);
    this.observer=new IntersectionObserver(entries=>{this.visible=entries[0].isIntersecting;});this.observer.observe(container);
    this.frames=0;this.lastFrame=performance.now();this.fps=0;this.renderer.setAnimationLoop(()=>{if(!this.visible||document.hidden)return;const now=performance.now();this.frames++;if(now-this.lastFrame>=1000){this.fps=Math.round(this.frames*1000/(now-this.lastFrame));this.frames=0;this.lastFrame=now;}
      this.controls.update();this.animations=this.animations.filter(a=>{const t=Math.min(1,(now-a.start)/320),ease=1-(1-t)**3;a.obj.position.lerpVectors(a.from,a.to,ease);if(a.capture){a.obj.scale.setScalar(1-ease);if(t===1){a.obj.removeFromParent();this.disposeGroup(a.obj);}}else a.obj.position.y+=Math.sin(t*Math.PI)*.4;return t<1;});
      this.renderer.render(this.scene,this.camera);
    });
  }
  disposeGroup(group){group.traverse(o=>{o.geometry?.dispose();if(o.material){for(const m of(Array.isArray(o.material)?o.material:[o.material])){m.map?.dispose();m.dispose();}}});}
  clear(group){for(const child of [...group.children]){this.disposeGroup(child);group.remove(child);}}
  position(i){const[x,y,z]=xyz(i,this.state.n),c=(this.state.n-1)/2;return new THREE.Vector3(x-c,z*this.gap,c-y);}
  frame(reset=true){if(!this.state)return;const h=(this.state.layers-1)*this.gap/2;this.controls.target.set(0,h,0);const narrow=this.camera.aspect<.8;const d=this.state.layers>1?17:17;const factor=narrow?1.35:1;if(reset||!this.framed){const v=this.view==='top'?[0, d*factor,.01]:this.view==='white'?[0,d*.65*factor,d*.87*factor]:this.view==='black'?[0,d*.65*factor,-d*.87*factor]:[d*.48*factor,d*.64*factor,d*.78*factor];this.camera.position.set(v[0],h+v[1],v[2]);this.framed=true;this.controls.update();}}
  setView(view){this.view=view;this.frame();}
  setStyle(theme,geometry,gap){const changed=this.theme!==theme||this.geometry!==geometry||this.gap!==gap;this.theme=theme;this.geometry=geometry;this.gap=gap;if(changed&&this.state){this.drawBoard();this.drawPieces();this.mark(this.selection,this.moves,this.last);this.frame();}}
  material(color,extra={}){return new THREE.MeshStandardMaterial({color,roughness:this.theme==='neon'?.2:.4,metalness:this.theme==='neon'?.3:.04,...extra});}
  label(text,color='#a9957c'){
    const c=document.createElement('canvas');c.width=128;c.height=64;const ctx=c.getContext('2d');ctx.font='500 34px sans-serif';ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillStyle=color;ctx.fillText(text,64,32);const texture=new THREE.CanvasTexture(c);texture.colorSpace=THREE.SRGBColorSpace;const mesh=new THREE.Mesh(new THREE.PlaneGeometry(.48,.24),new THREE.MeshBasicMaterial({map:texture,transparent:true,depthWrite:false}));mesh.rotation.x=-Math.PI/2;return mesh;
  }
  drawBoard(){
    this.clear(this.boardGroup);const s=this.state,p=palettes[this.theme];this.tiles=[];
    for(let z=0;z<s.layers;z++){
      const base=new THREE.Mesh(new THREE.BoxGeometry(s.n+.64,.27,s.n+.64),this.material(p.frame));base.position.y=z*this.gap-.18;base.receiveShadow=true;base.castShadow=true;this.boardGroup.add(base);
      for(let y=0;y<s.n;y++)for(let x=0;x<s.n;x++){
        const i=x+s.n*y+s.n*s.n*z,shape=this.geometry==='round'?new THREE.CylinderGeometry(.475,.475,.08,32):this.geometry==='hex'?new THREE.CylinderGeometry(.53,.53,.08,6):new THREE.BoxGeometry(.985,.08,.985);
        const tile=new THREE.Mesh(shape,this.material((x+y)%2?p.light:p.dark));tile.position.copy(this.position(i));tile.position.y-=.01;tile.userData.square=i;tile.receiveShadow=true;this.boardGroup.add(tile);this.tiles.push(tile);
      }
      for(let a=0;a<s.n;a++){
        const l=this.label(String.fromCharCode(97+a));l.position.set(a-(s.n-1)/2,z*this.gap-.035,s.n/2+.16);this.boardGroup.add(l);
        const r=this.label(String(a+1));r.position.set(-s.n/2-.17,z*this.gap-.035,(s.n-1)/2-a);this.boardGroup.add(r);
      }
    }
    this.targets=[...this.tiles,...this.meshes];
  }
  piece(type,side){
    const group=new THREE.Group(),p=palettes[this.theme],material=this.material(side===1?p.white:p.black,{roughness:this.theme==='marble'?.24:.32,metalness:this.theme==='neon'?.4:.08});
    const add=(geometry,y,rotation=0)=>{const m=new THREE.Mesh(geometry,material.clone());m.position.y=y;m.rotation.y=rotation;m.castShadow=true;m.receiveShadow=true;group.add(m);return m;};
    const profiles={1:[[.25,0],[.29,.045],[.28,.1],[.19,.15],[.14,.2],[.1,.37],[.18,.4],[.17,.46],[.11,.49]],2:[[.29,0],[.32,.05],[.3,.12],[.21,.18],[.18,.24]],3:[[.29,0],[.31,.05],[.28,.12],[.19,.2],[.12,.43],[.2,.49],[.18,.55],[.1,.59]],4:[[.29,0],[.32,.06],[.29,.13],[.21,.19],[.18,.52],[.26,.58],[.26,.68]],5:[[.3,0],[.33,.06],[.3,.14],[.2,.21],[.12,.53],[.22,.59],[.19,.65],[.25,.81]],6:[[.31,0],[.34,.06],[.31,.14],[.21,.21],[.14,.61],[.23,.66],[.22,.73],[.13,.77]]};
    add(new THREE.LatheGeometry(profiles[type].map(([r,y])=>new THREE.Vector2(r,y)),32),.05);
    if(type===1)add(new THREE.SphereGeometry(.17,24,16),.62);
    if(type===3){const head=add(new THREE.SphereGeometry(.18,24,16),.77);head.scale.set(.78,1.35,.78);add(new THREE.SphereGeometry(.06,12,8),1.03);}
    if(type===4){for(let a=0;a<6;a++){const tooth=add(new THREE.BoxGeometry(.13,.14,.14),.78,a*Math.PI/3);tooth.position.x=Math.sin(a*Math.PI/3)*.2;tooth.position.z=Math.cos(a*Math.PI/3)*.2;}}
    if(type===5){for(let a=0;a<7;a++){const bead=add(new THREE.SphereGeometry(.065,12,8),.9);bead.position.x=Math.sin(a*Math.PI*2/7)*.23;bead.position.z=Math.cos(a*Math.PI*2/7)*.23;}add(new THREE.SphereGeometry(.09,16,12),.96);}
    if(type===6){add(new THREE.BoxGeometry(.09,.3,.085),.98);add(new THREE.BoxGeometry(.28,.085,.085),1.035);}
    if(type===2){
      const shape=new THREE.Shape();shape.moveTo(-.2,.24);shape.lineTo(.19,.24);shape.bezierCurveTo(.24,.4,.06,.49,.13,.62);shape.lineTo(.32,.65);shape.lineTo(.36,.79);shape.lineTo(.13,.96);shape.lineTo(.08,1.12);shape.lineTo(-.04,1.0);shape.bezierCurveTo(-.27,.9,-.34,.61,-.2,.24);
      const g=new THREE.ExtrudeGeometry(shape,{depth:.19,bevelEnabled:true,bevelThickness:.035,bevelSize:.035,bevelSegments:2,steps:1});g.translate(0,.05,-.095);const horse=add(g,0);horse.rotation.y=side===1?Math.PI/2:-Math.PI/2;
    }
    material.dispose();return group;
  }
  drawPieces(move){
    const oldMeshes=this.meshes;this.meshes=[];
    for(let i=0;i<this.state.board.length;i++){
      const p=this.state.board[i];if(!p)continue;const obj=this.piece(Math.abs(p),Math.sign(p));obj.userData.square=i;obj.position.copy(this.position(i));obj.position.y+=.065;
      if(move&&i===move.to&&!reduced()){const from=this.position(move.from);from.y+=.065;const to=obj.position.clone();obj.position.copy(from);this.animations.push({obj,from,to,start:performance.now()});}
      this.pieceGroup.add(obj);this.meshes.push(obj);
    }
    for(const obj of oldMeshes){if(move&&obj.userData.square===move.to&&!reduced()){const from=obj.position.clone(),to=from.clone();to.y-=.25;this.animations.push({obj,from,to,start:performance.now(),capture:true});}else{obj.removeFromParent();this.disposeGroup(obj);}}
    this.targets=[...this.tiles,...this.meshes];
  }
  update(state,move=null){const geometryChanged=!this.state||this.state.mode!==state.mode;this.animations=[];for(const obj of [...this.pieceGroup.children])if(!this.meshes.includes(obj)){obj.removeFromParent();this.disposeGroup(obj);}this.state=state;if(geometryChanged){this.drawBoard();this.framed=false;}this.drawPieces(move);if(geometryChanged)this.frame();}
  mark(selection,moves=[],last=null){
    this.selection=selection;this.moves=moves;this.last=last;this.clear(this.markGroup);if(!this.state)return;
    const add=(i,type)=>{let mesh;if(type==='available'){mesh=new THREE.Mesh(new THREE.CylinderGeometry(.115,.115,.02,28),new THREE.MeshBasicMaterial({color:0xc6a777,transparent:true,opacity:.92}));}else{mesh=new THREE.Mesh(new THREE.BoxGeometry(.95,.015,.95),new THREE.MeshBasicMaterial({color:type==='selected'?0xd6a268:0xb5a17c,transparent:true,opacity:type==='selected'?.55:.32}));}mesh.position.copy(this.position(i));mesh.position.y+=.05;this.markGroup.add(mesh);};
    if(last){add(last.from,'last');add(last.to,'last');}if(selection!==null&&selection!==undefined)add(selection,'selected');for(const m of moves)add(m.to,'available');
  }
  dispose(){this.renderer.setAnimationLoop(null);this.resize.disconnect();this.observer.disconnect();this.controls.dispose();this.disposeGroup(this.scene);this.environment.dispose();this.renderer.dispose();this.renderer.domElement.remove();}
}