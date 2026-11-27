import './styles.css';
import {BoardScene} from './scene.js';
import {initial,legal,apply,outcome,notation,key,inCheck} from './engine.js';

const LEVELS=[
  {name:'Новичок',depth:1,time:150},
  {name:'Любитель',depth:2,time:350},
  {name:'Клубный игрок',depth:3,time:800},
  {name:'Опытный',depth:4,time:1600},
  {name:'Гроссмейстер',depth:5,time:3200},
  {name:'Беспощадный',depth:6,time:6000},
];
const THEMES=[['wood','Дерево'],['marble','Мрамор'],['neon','Неон'],['minimal','Минимал']];
const SHAPES=[['square','Квадрат'],['round','Круг'],['hex','Гекс']];
const VIEWS=[['perspective','Обзор'],['white','Белые'],['black','Чёрные'],['top','Сверху']];
const SAVE='strata-chess-v1';

const app=document.getElementById('app');
app.innerHTML=`
<main id="stage">
  <div class="brand"><b>STRATA</b><span>3D-шахматы</span></div>
  <div class="turnbar"><span class="dot white" id="dot"></span><span id="turnbar">Загрузка…</span></div>
  <div class="toast" id="toast" role="status"></div>
</main>
<aside class="panel collapsed" id="panel">
  <button class="panel-toggle" id="panelToggle" aria-expanded="false" aria-controls="panelBody">
    <span id="toggleLabel">Партия</span><span class="grip"></span><span style="width:14px"></span>
  </button>
  <div class="panel-body" id="panelBody">
    <section>
      <div class="headline"><strong id="status">Партия</strong><small id="meta"></small></div>
      <button class="primary" id="newGame">Новая партия</button>
    </section>

    <section>
      <h2>ИИ</h2>
      <div class="range">
        <div class="row"><span id="levelName">Клубный игрок</span><span id="levelNum">3 / 6</span></div>
        <input type="range" id="level" min="1" max="6" step="1" value="3" aria-label="Уровень сложности ИИ">
      </div>
      <div class="range">
        <div class="row"><span>Время на ход</span><span id="timeVal">0,8 с</span></div>
        <input type="range" id="thinkTime" min="100" max="8000" step="100" value="800" aria-label="Время на размышление ИИ">
      </div>
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
        <li>Шах, мат, пат, правило 50 ходов, троекратное повторение и недостаток материала работают как в классике.</li>
        <li>Рокировка и взятие на проходе — только в классическом формате.</li>
        <li>Отмены ходов и подсказок нет: ход сделан — ход в силе.</li>
      </ul>
    </details>
  </div>
</aside>`;

const $=id=>document.getElementById(id);
const stage=$('stage'),panel=$('panel');

let settings={mode:'classic',theme:'wood',shape:'square',level:3,time:800,sound:true};
let game={history:[],moves:[],human:1};
let selected=null,lastMove=null,legalMoves=[],busy=false,over=null,workerId=0;

const saved=load();
if(saved&&Array.isArray(saved.history)&&saved.history.length){
  Object.assign(settings,saved.settings||{});
  game={history:saved.history,moves:saved.moves||[],human:1};
  lastMove=game.moves.length?game.moves[game.moves.length-1]:null;
}
if(!game.history.length)game.history=[initial(settings.mode)];

const scene=new BoardScene(stage,onSquare);
scene.theme=settings.theme;
scene.geometry=settings.shape;
scene.view='perspective';
scene.update(current());

const worker=new Worker(new URL('./ai.worker.js',import.meta.url),{type:'module'});
worker.onmessage=({data})=>{
  if(data.id!==workerId)return;
  if(data.type==='progress'){setMeta(`глубина ${data.depth} · ${Math.round(data.nodes/1000)}k узлов`);return;}
  if(data.type==='error'){busy=false;randomMove('ИИ не смог посчитать ход');return;}
  if(data.type==='result'){
    busy=false;
    const found=legal(current()).find(m=>m.from===data.move.from&&m.to===data.move.to&&(m.promotion||0)===(data.move.promotion||0));
    if(!found){randomMove('Ход ИИ не найден, взят запасной');return;}
    play(found);
  }
};
worker.onerror=()=>{busy=false;randomMove('Фоновый поток упал, сделан запасной ход')};

bindPanel();
refresh();

function current(){return game.history[game.history.length-1]}
function repetitions(){const k=key(current());return game.history.reduce((n,h)=>n+(key(h)===k?1:0),0)}
function outcomeNow(){return outcome(current(),repetitions())}

function refresh(){
  const s=current();
  const state=outcomeNow();
  over=state.over?state:null;
  legalMoves=over?[]:state.moves;
  scene.mark(selected,legalMoves.filter(m=>m.from===selected),lastMove);
  renderStatus(s);
  renderHistory();
  save();
  if(!over&&s.turn!==game.human&&!busy)aiMove();
}

function renderStatus(s=current()){
  $('dot').className='dot '+(busy?'white busy':s.turn===1?'white':'black');
  if(over){
    const text=over.winner===0?`${over.reason} — ничья`:over.winner===game.human?`${over.reason} — вы победили`:`${over.reason} — победил ИИ`;
    $('status').textContent=text;
    $('toggleLabel').textContent='Партия окончена';
    $('turnbar').textContent=text;
    setMeta('');
    return;
  }
  const check=inCheck(s)?' · шах':'';
  const text=s.turn===game.human?'Ваш ход':busy?'ИИ думает':'Ход ИИ';
  $('status').textContent=text+check;
  $('toggleLabel').textContent=over?'Партия окончена':busy?'ИИ думает…':s.turn===game.human?'Ваш ход':'Ход ИИ';
  $('turnbar').textContent=text+check;
  if(!busy)setMeta(s.half>=90?`50 ходов: ${Math.floor(s.half/2)}`:'');
}

function play(move){
  const s=current();
  const capture=Boolean(s.board[move.to]||move.ep);
  game.moves.push({...move,san:notation(s,move)});
  game.history.push(apply(s,move));
  lastMove=move;
  selected=null;
  scene.update(current(),move);
  const next=current();
  if(inCheck(next))sounds.check();else if(capture)sounds.capture();else sounds.move();
  refresh();
  if(over)sounds.end();
}

function aiMove(){
  if(over||busy)return;
  busy=true;
  renderStatus();
  setMeta('расчёт…');
  const id=++workerId;
  const level=LEVELS[settings.level-1];
  worker.postMessage({id,state:current(),options:{time:settings.time,maxDepth:level.depth,history:game.history.map(key)}});
}

function randomMove(reason){
  const moves=legal(current());
  if(!moves.length)return refresh();
  toast(reason);
  play(moves[Math.floor(Math.random()*moves.length)]);
}

function onSquare(i){
  if(busy||over)return;
  const s=current();
  if(s.turn!==game.human)return;
  if(selected!==null){
    const options=legalMoves.filter(m=>m.from===selected&&m.to===i);
    if(options.length){play(options.find(m=>m.promotion===5)||options[0]);return;}
  }
  if(legalMoves.some(m=>m.from===i)||s.board[i]*s.turn>0){
    selected=i;
    scene.mark(i,legalMoves.filter(m=>m.from===i),lastMove);
  }else{
    selected=null;
    scene.mark(null,[],lastMove);
  }
}

function newGame(){
  workerId++;
  busy=false;over=null;selected=null;lastMove=null;
  game={history:[initial(settings.mode)],moves:[],human:1};
  scene.theme=settings.theme;
  scene.geometry=settings.shape;
  scene.state=null;
  scene.view='perspective';
  scene.update(current());
  refresh();
  toast('Новая партия');
}

function bindPanel(){
  const level=$('level'),time=$('thinkTime');
  level.value=settings.level;
  time.value=settings.time;
  level.addEventListener('input',()=>{settings.level=+level.value;levelLabel();save()});
  const timeLabel=()=>$('timeVal').textContent=(settings.time/1000).toFixed(1).replace('.',',')+' с';
  time.addEventListener('input',()=>{settings.time=+time.value;timeLabel();save()});
  levelLabel();
  timeLabel();

  chips('modeChips',[['classic','8×8 классика'],['strata','Strata 5×5×3']],'mode',()=>newGame());
  chips('shapeChips',SHAPES,'shape',()=>scene.setStyle(settings.theme,settings.shape,scene.state.layers>1?2.6:1));
  chips('themeChips',THEMES,'theme',()=>scene.setStyle(settings.theme,settings.shape,scene.state.layers>1?2.6:1));
  chips('viewChips',VIEWS,'view',v=>scene.setView(v));

  $('newGame').addEventListener('click',newGame);
  $('sound').setAttribute('aria-pressed',String(settings.sound));
  $('sound').addEventListener('click',e=>{
    settings.sound=!settings.sound;
    e.currentTarget.setAttribute('aria-pressed',String(settings.sound));
    if(settings.sound)sounds.move();
    save();
  });

  const toggle=$('panelToggle');
  if(matchMedia('(max-width:860px)').matches)panel.classList.add('collapsed');
  const syncToggle=()=>toggle.setAttribute('aria-expanded',String(!panel.classList.contains('collapsed')));
  toggle.addEventListener('click',()=>{panel.classList.toggle('collapsed');syncToggle()});
  syncToggle();
  addEventListener('keydown',e=>{
    if(e.key==='Escape'&&selected!==null){selected=null;scene.mark(null,[],lastMove)}
  });
}

function chips(id,list,settingName,onPick){
  const box=$(id);
  box.innerHTML=list.map(([v,label])=>`<button class="chip" data-value="${v}">${label}</button>`).join('');
  const sync=()=>{for(const b of box.children)b.setAttribute('aria-pressed',String(b.dataset.value===String(settings[settingName])))}
  box.addEventListener('click',e=>{
    const b=e.target.closest('.chip');
    if(!b)return;
    settings[settingName]=b.dataset.value;
    sync();
    onPick(b.dataset.value);
    save();
  });
  sync();
}

function levelLabel(){
  const l=LEVELS[settings.level-1];
  $('levelName').textContent=l.name;
  $('levelNum').textContent=`${settings.level} / 6`;
}

function renderHistory(){
  const list=$('history');
  if(!game.moves.length){list.innerHTML='<li class="empty">Ходов пока нет</li>';return;}
  let html='';
  for(let i=0;i<game.moves.length;i+=2){
    html+=`<li><i>${i/2+1}.</i><span>${game.moves[i].san}</span></li>`;
    html+=`<li><span>${game.moves[i+1]?game.moves[i+1].san:''}</span></li>`;
  }
  list.innerHTML=html;
  list.scrollTop=list.scrollHeight;
}

let toastTimer;
function toast(text){
  const t=$('toast');
  t.textContent=text;
  t.classList.add('show');
  clearTimeout(toastTimer);
  toastTimer=setTimeout(()=>t.classList.remove('show'),2600);
}
function setMeta(text){$('meta').textContent=text}

function save(){
  try{localStorage.setItem(SAVE,JSON.stringify({settings,history:game.history,moves:game.moves,human:game.human}));}catch{}
}
function load(){
  try{return JSON.parse(localStorage.getItem(SAVE)||'null');}catch{return null;}
}

let actx=null;
function tone(freq,dur,type='sine',gain=.05,delay=0){
  if(!settings.sound)return;
  try{
    actx=actx||new (window.AudioContext||window.webkitAudioContext)();
    const t=actx.currentTime+delay,o=actx.createOscillator(),g=actx.createGain();
    o.type=type;
    o.frequency.value=freq;
    g.gain.setValueAtTime(0,t);
    g.gain.linearRampToValueAtTime(gain,t+.012);
    g.gain.exponentialRampToValueAtTime(.0001,t+dur);
    o.connect(g).connect(actx.destination);
    o.start(t);
    o.stop(t+dur+.03);
  }catch{}
}
const sounds={
  move:()=>tone(300,.09,'triangle',.05),
  capture:()=>{tone(190,.16,'sawtooth',.05);tone(140,.2,'triangle',.04,.04)},
  check:()=>{tone(660,.1,'square',.04);tone(880,.14,'square',.035,.1)},
  end:()=>[523,659,784].forEach((f,i)=>tone(f,.3,'sine',.045,i*.09)),
};
