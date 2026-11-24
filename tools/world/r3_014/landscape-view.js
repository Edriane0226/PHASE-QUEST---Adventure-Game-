// Original editable vector landscape. This is geography, not a collage of level screenshots.
function drawLandscape(D,svg,el,options={}){
 const ns='http://www.w3.org/2000/svg';svg.setAttribute('xmlns',ns);svg.replaceChildren();
 const pts=p=>p.map(q=>q.join(',')).join(' '),poly=(p,fill,extra={},parent=svg)=>el('polygon',{points:pts(p),fill,...extra},parent);
 const path=p=>`M${p[0]} C${p[1]} ${p[2]} ${p[3]}`;
 const text=(s,x,y,size,extra={},parent=svg)=>{const t=el('text',{x,y,'font-size':size,'font-family':'system-ui,sans-serif',fill:'#304533',...extra},parent);t.textContent=s;return t};
 const defs=el('defs',{}),clip=el('clipPath',{id:'land-clip'},defs);poly(D.landscape.mainland,'white',{},clip);
 el('rect',{x:0,y:0,width:21000,height:10000,fill:'#8db0b6'});
 poly(D.landscape.mainland,'#537a75',{transform:'translate(20 110)'});poly(D.landscape.mainland,'#d7d5b0',{stroke:'#dbe8d9','stroke-width':100,'stroke-linejoin':'round'});
 const land=el('g',{'clip-path':'url(#land-clip)'});poly(D.landscape.mainland,'#a9be82',{},land);
 // Shared biome masses blend by terrain features, not rectangular location outlines.
 el('path',{d:'M0 0H11200L10100 1800 9400 2600 8100 3500 7500 4800 7200 5800 6400 6900 4200 7400 0 6500Z',fill:'#dce6dc'},land);
 el('path',{d:'M13000 700L15500 0 20200 1700 20500 6800 17900 8200 15300 7000 14600 5700 14100 4200Z',fill:'#b8c7b5'},land);
 el('path',{d:'M12500 2200Q14600 900 17700 1500L19400 3000 19000 5900 17200 7000 15100 6000 14600 4300Z',fill:'#c5d0bd'},land);
 for(const [i,spine]of D.landscape.ridge_spines.entries()){
  const points=spine.map(p=>p.join(',')).join(' ');el('polyline',{points,fill:'none',stroke:'#718d7c','stroke-opacity':'.22','stroke-width':480,'stroke-linecap':'round','stroke-linejoin':'round'},land);
  for(let j=0;j<spine.length;j++){const [x,y]=spine[j],h=320+(j%2)*180;poly([[x-280,y+130],[x,y-h],[x+330,y+160]],'#91a395',{},land);poly([[x,y-h],[x+330,y+160],[x+30,y+80]],'#728d83',{},land);poly([[x-100,y-h+160],[x,y-h],[x+130,y-h+185],[x+20,y-h+145]],i===0?'#f4f5e7':'#e2e6d6',{},land)}
 }
 for(const lake of D.landscape.lakes){el('ellipse',{cx:lake.center[0],cy:lake.center[1],rx:lake.radii[0]+40,ry:lake.radii[1]+40,fill:'#ced5b3'},land);el('ellipse',{cx:lake.center[0],cy:lake.center[1],rx:lake.radii[0],ry:lake.radii[1],fill:'#80aeb2'},land)}
 for(const r of D.landscape.waterways){const points=pts(r.points);el('polyline',{points,fill:'none',stroke:'#d3dfc7','stroke-width':r.width+58,'stroke-linejoin':'round','stroke-linecap':'round'},land);el('polyline',{points,fill:'none',stroke:'#7da9b1','stroke-width':r.width,'stroke-linejoin':'round','stroke-linecap':'round'},land);el('polyline',{points,fill:'none',stroke:'#b8d6d1','stroke-width':18,'stroke-opacity':'.7','stroke-linejoin':'round'},land)}
 function tree(x,y,s,snow=false){const g=el('g',{transform:`translate(${x} ${y}) scale(${s})`},land);el('ellipse',{cx:30,cy:40,rx:90,ry:34,fill:'#597b61','fill-opacity':'.18'},g);poly([[-12,0],[15,0],[15,55],[-12,47]],'#78694e',{},g);poly([[-85,-15],[0,-65],[80,-15],[0,30]],snow?'#d4e0cd':'#93ad6c',{},g);poly([[-85,-15],[0,30],[0,65],[-85,20]],snow?'#9eb5a1':'#658d58',{},g);poly([[0,30],[80,-15],[80,20],[0,65]],snow?'#89a89b':'#4f7a54',{},g)}
 for(const [i,c]of D.landscape.forest_centers.entries())for(let j=0;j<10;j++){const a=j*2.4+i*0.6,r=100+(j%4)*150,x=c[0]+Math.cos(a)*r,y=c[1]+Math.sin(a)*r*.65;if(D.regions.every(s=>Math.hypot(s.center[0]-x,s.center[1]-y)>340))tree(x,y,0.7+(j%3)*.2,c[0]<7500)}
 for(const road of D.landscape.trails){const extra=road.role==='alternate exploration/backtracking';el('path',{d:path(road.points),fill:'none',stroke:'#75886b','stroke-width':extra?72:112,'stroke-opacity':'.25','stroke-linecap':'round'},land);el('path',{d:path(road.points),fill:'none',stroke:road.kind==='crafted boat passage'?'#e5ecd7':'#e4d6a7','stroke-width':extra?43:69,'stroke-linecap':'round','stroke-dasharray':road.kind==='crafted boat passage'?'100 80':road.kind==='crafted skybridge lift'?'75 35':'none'},land);
  for(const crossing of road.water_crossings||[]){if(crossing.kind.includes('boat'))continue;const[x,y]=crossing.at;el('rect',{x:x-80,y:y-85,width:160,height:170,rx:12,fill:'#ad9470',stroke:'#6e7960','stroke-width':16},land);for(let n=-1;n<=1;n++)el('line',{x1:x-70,y1:y+n*45,x2:x+70,y2:y+n*45,stroke:'#d3be94','stroke-width':12},land)}
 }
 for(const p of D.landscape.settlement_approaches){if(p.curve==='polyline')el('polyline',{points:pts(p.points),fill:'none',stroke:'#dfd5ae','stroke-width':36,'stroke-linejoin':'round','stroke-linecap':'round'},land);else el('path',{d:path(p.points),fill:'none',stroke:'#dfd5ae','stroke-width':36,'stroke-linecap':'round'},land)}
 const visible=id=>!options.fog||D.regions.findIndex(r=>r.id===id)<=options.progress;
 for(const branch of D.landscape.local_branches||[]){if(!visible(branch.subregion))continue;el('polyline',{points:pts(branch.points),fill:'none',stroke:'#e9dfba','stroke-width':25,'stroke-linejoin':'round','stroke-linecap':'round',class:'local-branch'},land);for(const span of branch.water_crossings){const p=span.from,q=span.to;el('line',{x1:p[0],y1:p[1],x2:q[0],y2:q[1],stroke:'#aa906a','stroke-width':62},land);el('line',{x1:p[0],y1:p[1],x2:q[0],y2:q[1],stroke:'#d0bb91','stroke-width':36,'stroke-dasharray':'14 12'},land)}}
 if(options.regions)for(const r of D.regions)poly(r.permission_polygon,'#5f8064',{'fill-opacity':'.07',stroke:'#425f4b','stroke-opacity':'.45','stroke-width':13,'stroke-dasharray':'55 40'},land);
 if(options.fog)D.regions.forEach((r,i)=>{if(i>options.progress)poly(r.permission_polygon,'#e7ece4',{'fill-opacity':'.85'},land)});
 if(options.cargo)for(const r of D.regions)for(const p of r.local_cargo_paths){const points=pts(p.points);el('polyline',{points,fill:'none',stroke:'#93733e','stroke-width':16,'stroke-dasharray':'40 24'},land)}
 if(options.stations)for(const s of D.stations){if(s.kind==='catalog reservation')continue;const f=s.footprint;const marker=el('rect',{x:f[0],y:f[1],width:f[2],height:f[3],fill:'#fcf4d9','fill-opacity':'.3',stroke:'#7a573c','stroke-width':12},land);marker.style.cursor='pointer';marker.onclick=()=>options.onStation?.(s)}
 // Existing routes are optional measurement overlays; default world remains one shared terrain.
 if(options.source)for(const r of D.regions.slice(0,2))el('polyline',{points:pts(r.internal_route),fill:'none',stroke:'#334e4a','stroke-width':18,'stroke-dasharray':'30 20'},land);
 // Default meaningful points of interest, separate from technical footprint rectangles.
 function marker(s,extra=false){if(!visible(s.subregion))return;const [x,y]=s.ground_xy,k=s.kind,practice=k==='free practice'||k==='optional minigame',checkpoint=k==='checkpoint',prof=k==='professor',finn=k==='assessor';
  const color=practice?'#b67c3b':prof?'#806694':checkpoint?'#75876b':extra?'#6b8875':'#387b80',g=el('g',{transform:`translate(${x} ${y})`,class:extra?'exploration-stop':'required-station','data-id':s.id,tabindex:'0',role:'button','aria-label':`${s.name} · ${k}`},land);
  const title=el('title',{},g);title.textContent=`${s.name} · ${k}`;el('circle',{cx:0,cy:0,r:extra?78:checkpoint?47:82,fill:'#f7f0d7',stroke:color,'stroke-width':16},g);
  if(practice){poly([[0,-48],[16,-16],[49,-12],[25,13],[31,46],[0,30],[-31,46],[-25,13],[-49,-12],[-16,-16]],color,{},g)}
  else if(prof){el('path',{d:'M-43-30Q-12-42 0-18Q12-42 43-30V32Q15 20 0 41Q-15 20-43 32Z',fill:color},g);el('line',{x1:0,y1:-18,x2:0,y2:33,stroke:'#f7f0d7','stroke-width':9},g)}
  else if(extra){if(k==='rest overlook'){el('path',{d:'M-42 0H42M-30 0V35M30 0V35M-36-18H36',fill:'none',stroke:color,'stroke-width':13},g)}else{el('path',{d:'M-30-39H30V40H-30Z',fill:color},g);el('path',{d:'M-17-15H17M-17 4H17M-17 23H8',stroke:'#f7f0d7','stroke-width':8},g)}}
  else if(finn){text('F',0,25,72,{'text-anchor':'middle',fill:color,'font-weight':800},g)}
  else if(checkpoint){el('circle',{cx:0,cy:0,r:17,fill:color},g)}
  else{el('path',{d:'M-17-42H17M-11-40V-9L-38 34Q0 49 38 34L11-9V-40',fill:color,stroke:color,'stroke-width':10},g);el('path',{d:'M-20 18H20',stroke:'#f7f0d7','stroke-width':10},g)}
  const open=()=>extra?options.onStop?.(s):options.onStation?.(s);g.style.cursor='pointer';g.onclick=e=>{e.stopPropagation();open()};g.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();open()}};
  if(options.selected===s.subregion&&!checkpoint)text(s.name.length>32?s.name.slice(0,30)+'…':s.name,x,y+135,83,{'text-anchor':'middle',fill:color,stroke:'#f4f1df','stroke-width':16,'paint-order':'stroke'},land);
 }
 for(const s of D.stations){if(['catalog reservation','entry','exit'].includes(s.kind))continue;marker(s)}
 if(options.activities!==false)for(const s of D.landscape.exploration_stops||[])marker(s,true);
 function building(parent,x,y,type){const g=el('g',{transform:`translate(${x} ${y})`},parent);el('ellipse',{cx:20,cy:70,rx:175,ry:60,fill:'#4f6e5a','fill-opacity':'.2'},g);
  if(type==='garden'||type==='orchard'){tree(x-100,y+20,1.3,type==='garden');tree(x+100,y-30,1.1,type==='garden');el('path',{d:`M${x-120} ${y+120}Q${x} ${y+170} ${x+140} ${y+100}`,fill:'none',stroke:'#e6d9ae','stroke-width':35},parent)}
  else if(type==='dock'){el('path',{d:'M-150 30L140 90 180 45-110-20Z',fill:'#b59b70',stroke:'#716c53','stroke-width':12},g);el('path',{d:'M-70 105Q45 175 150 100L120 155Q20 210-70 105',fill:'#d6c6a0',stroke:'#65786a','stroke-width':12},g)}
  else{poly([[-130,0],[0,-70],[135,0],[0,75]],type==='lab'?'#c1d3cb':'#b5a57c',{},g);poly([[-130,0],[0,75],[0,155],[-130,80]],type==='lab'?'#8ea9a3':'#91866c',{},g);poly([[0,75],[135,0],[135,80],[0,155]],type==='lab'?'#779c99':'#7c7b60',{},g);poly([[-155,0],[0,-125],[165,-5],[0,50]],type==='lab'?'#dce7dc':'#829c79',{stroke:'#597667','stroke-width':12},g);el('path',{d:'M-35 135V75L5 95V153',fill:'#526e62'},g);if(type==='mill'){el('circle',{cx:138,cy:100,r:75,fill:'none',stroke:'#8f8260','stroke-width':20},g);for(let j=0;j<6;j++){const a=j*Math.PI/3;el('line',{x1:138,y1:100,x2:138+Math.cos(a)*70,y2:100+Math.sin(a)*70,stroke:'#8f8260','stroke-width':11},g)}}}
 }
 const names=['Melting Garden','Frozen Mill','Stillwater Crossing','Two-State Canal','Snowbound Workshop','Frozen Dock','Sunlit Landing','Drying Orchard','Dewglass Greenhouse','Returning Stream','Steamworks Garden','Skybridge Engine','Vanishing Ice Lab','Sample Sorting','Frostprint Chamber','Reversible Circuit','Six-Change Observatory','Phaseworks Core'];
 D.regions.forEach((r,i)=>{const[x,y]=r.center;building(land,x,y,i===0?'garden':i===1?'mill':i===7?'orchard':i===5||i===6?'dock':i>=12?'lab':'house');const hit=el('circle',{cx:x,cy:y,r:290,fill:'transparent',class:'landmark','data-region':r.id},land);hit.style.cursor='pointer';hit.onclick=()=>options.onRegion?.(r);if(options.selected===r.id)el('ellipse',{cx:x,cy:y+50,rx:250,ry:180,fill:'none',stroke:'#375c4b','stroke-width':25},land);
  let lines=[''],line=0;for(const word of names[i].split(' ')){if((lines[line]+' '+word).trim().length>18){lines.push('');line++}lines[line]=(lines[line]+' '+word).trim()}lines.forEach((s,j)=>text(s,x,y+285+j*150,130,{'text-anchor':'middle',stroke:'#e9ecda','stroke-width':22,'paint-order':'stroke','font-weight':600},land));
 });
 for(const v of D.menu_viewpoints){if(!options.viewpoints)continue;el('circle',{cx:v.target[0],cy:v.target[1],r:70,fill:'#a6813d'},land);text(v.id,v.target[0]+100,v.target[1],110,{},land)}
 if(options.camera&&options.selected){const r=D.regions.find(r=>r.id===options.selected),p=r.entry;el('rect',{x:p[0]-206.45,y:p[1]-116.13,width:412.9,height:232.26,fill:'none',stroke:'#204f41','stroke-width':15},land)}
 text('THE MELTING GARDENS',2500,850,230,{'letter-spacing':30,'font-weight':600});text('SUNPETAL VALE',9700,8250,240,{'letter-spacing':35,'font-weight':600});text('PHASEWORKS RIDGE',15200,1250,230,{'letter-spacing':25,'font-weight':600});
 text('Shared mainland · trails suggest routes; broad earned terrain stays explorable',10500,9700,155,{'text-anchor':'middle',fill:'#f3f3df'});
 return svg;
}
