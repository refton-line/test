import './styles.css';
import {BoardScene} from './scene.js';
import {initial,legal,apply,outcome,notation,key,inCheck} from './engine.js';
import {PROFILES,OPENINGS,BRILLIANT_MODES,profileSettings,describeProfile,chooseMove} from './ai.js';
import AIWorker from './ai.worker.js?worker&inline';

const PROFILE_ORDER=['legit','semi','blatant'];
const THEMES=[['wood','Дерево'],['marble','Мрамор'],['neon','Неон'],['minimal','Минимал']];
const SHAPES=[['square','Квадрат'],['round','Круг'],['hex','Гекс']];
const VIEWS=[['perspective','Обзор'],['white','Белые'],['black','Чёрные'],['top','Сверху']];
const SIDES=[['1','Белые'],['-1','Чёрные']];
const SAVE='strata-chess-v2';

const app=document.getElementById('app');
app.innerHTML=`
<main id="stage">
  <div class="brand"><b>STRATA</b><span>3D-шахматы</span></div>
  <div class="turnbar" aria-live="polite"><span class="dot white" id="dot"></span><span id="turnbar">Загрузка…</span></div>
  <div class="toast" id="toast" role="status" aria-live="polite"></div>
  <div class="promo" id="promo" hidden role="dialog" aria-label="Выбор фигуры для превращения">
    <p>Превращение</p>
    <div class="promo-row" id="promoRow"></div>
  </div>
</main>
<aside class="panel collapsed" id="panel">
  <button class="panel-toggle" id="panelToggle" aria-expanded="false" aria-controls="panelBody">
    <span id="toggleLabel">Партия</span><span class="grip"></span><span style="width:14px"></span>
  </button>
  <div class="panel-body" id="panelBody">
    <section>
      <div class="headline"><strong id="status" aria-live="polite">Партия</strong><small id="meta"></small></div>
      <button class="primary" id="newGame">Новая партия</button>
    </section>

    <section>
      <h2>Профиль ИИ</h2>
      <div class="chips" id="profileChips" role="group" aria-label="Профиль ИИ"></div>
      <p class="hint" id="profileTag"></p>
      <div class="range">
        <div class="row"><span>Время на ход</span><span id="timeVal">1,6 с</span></div>
        <input type="range" id="thinkTime" min="100" max="8000" step="100" value="1600" aria-label="Время на размышление ИИ">
      </div>
      <div class="range">
        <div class="row"><span>Разброс времени</span><span id="spreadVal">25%</span></div>
        <input type="range" id="spread" min="0" max="100" step="5" value="25" aria-label="Разброс времени на ход">
      </div>
      <h2>Дебют</h2>
      <div class="chips" id="openingChips" role="group" aria-label="Стиль дебюта"></div>
      <h2>Бриллиантовый ход</h2>
      <div class="chips" id="brilliantChips" role="group" aria-label="Бриллиантовые ходы"></div>
      <h2>Ваша сторона</h2>
      <div class="chips" id="sideChips" role="group" aria-label="Ваша сторона"></div>
    </section>

    <section>
      <h2>Доска</h2>
      <div class="chips" id="modeChips" role="group" aria-label="Формат доски"></div>
      <div class="chips" id="shapeChips" role="group" aria-label="Геометрия клеток"></div>
      <div class="chips" id="themeChips" role="group" aria-label="Тема оформления"></div>
    </section>

    <section>
      <h2>Ракурс</h2>
      <div class="chips" id="viewChips" role="group" aria-label="Ракурс камеры"></div>
    </section>

    <section>
      <div class="headline"><h2>История партии</h2><button class="chip" id="sound" aria-pressed="true">Звук</button></div>
      <ol class="history" id="history"><li class="empty">Ходов пока нет</li></ol>
    </section>

    <details>
      <summary>Правила 3D-шахмат</summary>
      <p>Классика — обычные шахматы на доске 8×8. Формат «Strata» — три слоя 5×5: ферзь, ладья, слон и конь ходят в трёх измерениях, а пешка умеет шагать на соседний слой.</p>
      <ul>
        <li>Ладья в «Strata» бьёт по трём осям, слон — по всем диагоналям куба, ферзь — по всем линиям сразу.</li>
        <li>Конь прыгает на (2,1) в любой из трёх плоскостей, король — на одну клетку в любом направлении.</li>
        <li>Пешка рубит по трём диагоналям вперёд и превращается на последней горизонтали любого слоя.</li>
        <li>В «Strata» у каждой стороны один король, рокировки и взятия на проходе нет.</li>
        <li>Шах, мат, пат, правило 50 ходов, троекратное повторение и недостаток материала работают как в классике.</li>
        <li>Отмены ходов и подсказок нет: ход сделан — ход в силе.</li>
      </ul>
    </details>
  </div>
</aside>`;

const $=id=>document.getElementById(id);
const stage=$('stage'),panel=$('panel');

const defaults={mode:'classic',theme:'wood',shape:'square',profile:'semi',brilliant:'off',sound:true,human:1,view:'perspective',
  profiles:{
    legit:{time:900,spread:.55,opening:'random'},
    semi:{time:1600,spread:.25,opening:'random'},
    blatant:{time:3000,spread:0,opening:'random'},
  }};
let settings={...defaults};
let state={history:[],moves:[],human:1,view:'perspective'};
let selected=null,lastMove=null,legalMoves=[],busy=false,over=null,taskId=0,pendingPromotion=null;
const CHIP_SYNC=[];

restore();

const scene=new BoardScene(stage,onSquare);
scene.view=state.view;
scene.setStyle(settings.theme,settings.shape,current().layers>1?2.6:1.02);
scene.update(current());
scene.mark(null,[],null);

let worker=createWorker();

bindPanel();
refresh();

function createWorker(){
  try{
    const w=new AIWorker();
    w.onmessage=({data})=>{
      if(data.id!==taskId)return;
      if(data.type==='progress'){setMeta(`глубина ${data.depth} · ${formatNodes(data.nodes)}`);return;}
      if(data.type==='error'){finishThinking();randomMove('ИИ не смог посчитать ход');return;}
      if(data.type==='result'){finishThinking();acceptEngineMove(data);}
    };
    w.onerror=()=>{worker=null;if(busy){busy=false;aiMove();}};
    return w;
  }catch{return null;}
}

function restore(){
  try{
    const saved=JSON.parse(localStorage.getItem(SAVE)||'null');
    if(saved&&saved.settings){
      const {profiles,...flat}=saved.settings;
      Object.assign(settings,flat);
      for(const name of PROFILE_ORDER)settings.profiles[name]={...defaults.profiles[name],...(profiles&&profiles[name]||{})};
      if(!PROFILES[settings.profile])settings.profile='semi';
      if(!['off','move','series'].includes(settings.brilliant))settings.brilliant='off';
    }
    if(saved&&Array.isArray(saved.history)&&saved.history.length&&saved.history[0]?.board?.length){
      state={history:saved.history,moves:saved.moves||[],human:saved.human||settings.human,view:saved.view||'perspective'};
      lastMove=state.moves.length?state.moves[state.moves.length-1]:null;
    }
  }catch{}
  if(!state.history.length)state.history=[initial(settings.mode)];
}

function current(){return state.history[state.history.length-1]}
function repetitions(){const k=key(current());return state.history.reduce((n,h)=>n+(key(h)===k?1:0),0)}
function profile(){return profileSettings(settings,settings.profile)}

function refresh(){
  const s=current();
  const result=outcome(s,repetitions());
  over=result.over?result:null;
  legalMoves=over?[]:legal(s);
  scene.mark(selected,selected===null?[]:legalMoves.filter(m=>m.from===selected),lastMove);
  renderStatus(s);
  renderHistory();
  persist();
  if(!over&&s.turn!==state.human&&!busy)aiMove();
}

function renderStatus(s=current()){
  $('dot').className='dot '+(busy?'busy':s.turn===1?'white':'black');
  if(over){
    const text=over.winner===0?`${over.reason} — ничья`:over.winner===state.human?`${over.reason} — вы победили`:`${over.reason} — победил ИИ`;
    $('status').textContent=text;
    $('toggleLabel').textContent='Партия окончена';
    $('turnbar').textContent=text;
    setMeta('');
    return;
  }
  const suffix=inCheck(s)?' · шах':'';
  const text=s.turn===state.human?'Ваш ход':busy?'ИИ думает':'Ход ИИ';
  $('status').textContent=text+suffix;
  $('toggleLabel').textContent=busy?'ИИ думает…':text;
  $('turnbar').textContent=text+suffix;
  if(!busy)setMeta(s.half>=90?`50 ходов: ${Math.floor(s.half/2)}`:'');
}

function play(move){
  const s=current();
  const capture=Boolean(s.board[move.to]||move.ep);
  state.moves.push({...move,san:notation(s,move)});
  state.history.push(apply(s,move));
  lastMove=move;
  selected=null;
  scene.update(current(),move);
  const next=current();
  if(move.brilliant)toast('Бриллиантовый ход');
  if(inCheck(next))sounds.check();
  else if(capture)sounds.capture();
  else sounds.move();
  refresh();
  if(over)sounds.end();
}

function aiMove(){
  if(over||busy)return;
  busy=true;
  renderStatus();
  setMeta('расчёт…');
  const id=++taskId;
  const current_=current();
  const payload={id,state:current_,options:{
    profile:settings.profile,
    brilliant:settings.brilliant,
    time:profile().time,
    spread:profile().spread,
    opening:profile().opening,
    maxDepth:profile().depth,
    history:state.history.slice(-40),
  }};
  if(worker){
    worker.postMessage(payload);
  }else{
    setTimeout(()=>{
      try{
        const result=chooseMove(payload.state,payload.options);
        if(id!==taskId)return;
        finishThinking();
        acceptEngineMove({type:'result',...result});
      }catch(error){
        finishThinking();
        randomMove('ИИ не смог посчитать ход');
      }
    },30);
  }
}

function acceptEngineMove(data){
  const move=data.move;
  if(!move||over){finishThinking();return;}
  const found=legal(current()).find(m=>m.from===move.from&&m.to===move.to&&(m.promotion||0)===(move.promotion||0));
  if(!found){randomMove('Ход ИИ не найден, взят запасной');return;}
  found.brilliant=Boolean(data.brilliant);
  busy=false;
  play(found);
}

function finishThinking(){
  busy=false;
  renderStatus();
}

function randomMove(reason){
  const moves=legal(current());
  if(!moves.length){finishThinking();refresh();return;}
  toast(reason);
  busy=false;
  play(moves[Math.floor(Math.random()*moves.length)]);
}

function onSquare(i){
  if(busy||over||pendingPromotion)return;
  const s=current();
  if(s.turn!==state.human)return;
  if(selected!==null){
    const options=legalMoves.filter(m=>m.from===selected&&m.to===i);
    if(options.length){
      if(options.length>1&&options[0].promotion!==options[1].promotion){askPromotion(options);return;}
      play(options[0]);
      return;
    }
  }
  if(legalMoves.some(m=>m.from===i)){
    selected=i;
    scene.mark(i,legalMoves.filter(m=>m.from===i),lastMove);
    if(navigator.vibrate)navigator.vibrate(8);
  }else{
    selected=null;
    scene.mark(null,[],lastMove);
  }
}

function askPromotion(options){
  pendingPromotion=true;
  const names={5:'Ферзь',4:'Ладья',3:'Слон',2:'Конь'};
  const letters={5:'♛',4:'♜',3:'♝',2:'♞'};
  const row=$('promoRow');
  row.innerHTML='';
  for(const piece of [5,4,3,2]){
    const move=options.find(m=>m.promotion===piece);
    if(!move)continue;
    const button=document.createElement('button');
    button.className='promo-btn';
    button.type='button';
    button.innerHTML=`<span aria-hidden="true">${letters[piece]}</span>${names[piece]}`;
    button.addEventListener('click',()=>{
      $('promo').hidden=true;
      pendingPromotion=null;
      play(move);
    });
    row.append(button);
  }
  $('promo').hidden=false;
  $('promo').querySelector('button')?.focus();
}

function newGame(){
  taskId++;
  busy=false;over=null;selected=null;lastMove=null;pendingPromotion=null;
  $('promo').hidden=true;
  state.history=[initial(settings.mode)];
  state.moves=[];
  state.human=settings.human;
  state.view=settings.view;
  scene.state=null;
  scene.view=state.view;
  scene.setStyle(settings.theme,settings.shape,current().layers>1?2.6:1.02);
  scene.update(current());
  scene.mark(null,[],null);
  refresh();
  toast('Новая партия');
}

function bindPanel(){
  const time=$('thinkTime'),spread=$('spread');
  const timeLabel=()=>$('timeVal').textContent=(profile().time/1000).toFixed(1).replace('.',',')+' с';
  const spreadLabel=()=>$('spreadVal').textContent=Math.round(profile().spread*100)+'%';
  const syncInputs=()=>{time.value=profile().time;spread.value=Math.round(profile().spread*100);timeLabel();spreadLabel();$('profileTag').textContent=describeProfile(settings.profile,settings)};
  time.addEventListener('input',()=>{settings.profiles[settings.profile].time=+time.value;timeLabel();persist()});
  spread.addEventListener('input',()=>{settings.profiles[settings.profile].spread=+spread.value/100;spreadLabel();persist()});
  syncInputs();

  chips('profileChips',PROFILE_ORDER.map(name=>[name,PROFILES[name].name]),'profile',()=>{syncInputs();syncAllChips();newGame()});
  chips('openingChips',OPENINGS,{get:()=>settings.profiles[settings.profile].opening,set:value=>settings.profiles[settings.profile].opening=value},()=>{syncAllChips()});
  chips('brilliantChips',BRILLIANT_MODES,'brilliant',()=>{});

  chips('modeChips',[['classic','8×8 классика'],['strata','Strata 5×5×3']],'mode',()=>newGame());
  chips('sideChips',SIDES,'human',value=>{settings.human=+value;newGame()},String);
  chips('shapeChips',SHAPES,'shape',()=>scene.setStyle(settings.theme,settings.shape,scene.state.layers>1?2.6:1.02));
  chips('themeChips',THEMES,'theme',()=>{scene.setStyle(settings.theme,settings.shape,scene.state.layers>1?2.6:1.02);document.body.dataset.theme=settings.theme;});
  chips('viewChips',VIEWS,'view',value=>{state.view=value;scene.setView(value)});

  $('newGame').addEventListener('click',newGame);
  $('sound').setAttribute('aria-pressed',String(settings.sound));
  $('sound').addEventListener('click',event=>{
    settings.sound=!settings.sound;
    event.currentTarget.setAttribute('aria-pressed',String(settings.sound));
    if(settings.sound)sounds.move();
    persist();
  });

  const toggle=$('panelToggle');
  if(matchMedia('(max-width:860px)').matches)panel.classList.add('collapsed');
  const syncToggle=()=>toggle.setAttribute('aria-expanded',String(!panel.classList.contains('collapsed')));
  toggle.addEventListener('click',()=>{panel.classList.toggle('collapsed');syncToggle()});
  syncToggle();

  addEventListener('keydown',event=>{
    if(event.key==='Escape'){
      if(!$('promo').hidden){$('promo').hidden=true;pendingPromotion=null;return;}
      if(selected!==null){selected=null;scene.mark(null,[],lastMove);}
    }
  });
  document.body.dataset.theme=settings.theme;
}

function chips(id,list,settingName,onPick,stringify){
  const box=$(id);
  const read=()=>typeof settingName==='object'?settingName.get():settings[settingName];
  const write=value=>{if(typeof settingName==='object')settingName.set(value);else settings[settingName]=value;};
  box.innerHTML=list.map(([value,label])=>`<button class="chip" data-value="${value}" type="button">${label}</button>`).join('');
  const sync=()=>{
    for(const button of box.children){
      const value=stringify?stringify(read()):String(read());
      button.setAttribute('aria-pressed',String(button.dataset.value===value));
    }
  };
  box.addEventListener('click',event=>{
    const button=event.target.closest('.chip');
    if(!button)return;
    write(stringify?+button.dataset.value:button.dataset.value);
    sync();
    onPick(button.dataset.value);
    persist();
  });
  CHIP_SYNC.push(sync);
  sync();
}
function syncAllChips(){for(const sync of CHIP_SYNC)sync()}


function renderHistory(){
  const list=$('history');
  if(!state.moves.length){list.innerHTML='<li class="empty">Ходов пока нет</li>';return;}
  let html='';
  for(let i=0;i<state.moves.length;i+=2){
    html+=`<li><i>${i/2+1}.</i><span>${state.moves[i].san}</span></li>`;
    html+=`<li><span>${state.moves[i+1]?state.moves[i+1].san:''}</span></li>`;
  }
  list.innerHTML=html;
  list.scrollTop=list.scrollHeight;
}

function formatNodes(nodes){return nodes>=1000?`${Math.round(nodes/1000)}k узлов`:`${nodes} узлов`;}
function setMeta(text){$('meta').textContent=text;}

let toastTimer;
function toast(text){
  const element=$('toast');
  element.textContent=text;
  element.classList.add('show');
  clearTimeout(toastTimer);
  toastTimer=setTimeout(()=>element.classList.remove('show'),2600);
}

function persist(){
  try{localStorage.setItem(SAVE,JSON.stringify({settings,history:state.history,moves:state.moves,human:state.human,view:state.view}));}catch{}
}

let audio=null;
function tone(freq,duration,type='sine',gain=.05,delay=0){
  if(!settings.sound)return;
  try{
    audio=audio||new (window.AudioContext||window.webkitAudioContext)();
    const t=audio.currentTime+delay,osc=audio.createOscillator(),amp=audio.createGain();
    osc.type=type;osc.frequency.value=freq;
    amp.gain.setValueAtTime(0,t);
    amp.gain.linearRampToValueAtTime(gain,t+.012);
    amp.gain.exponentialRampToValueAtTime(.0001,t+duration);
    osc.connect(amp).connect(audio.destination);
    osc.start(t);osc.stop(t+duration+.03);
  }catch{}
}
const sounds={
  move:()=>tone(320,.09,'triangle',.05),
  capture:()=>{tone(190,.16,'sawtooth',.05);tone(140,.2,'triangle',.04,.04)},
  check:()=>{tone(660,.1,'square',.04);tone(880,.14,'square',.035,.1)},
  end:()=>[523,659,784].forEach((f,i)=>tone(f,.3,'sine',.045,i*.09)),
};
