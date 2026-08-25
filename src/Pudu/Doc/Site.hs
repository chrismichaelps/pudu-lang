{-| @Doc.Site.Module — renders the documentation index as one static page -}
module Pudu.Doc.Site (renderSite) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Doc (DocIndex)
import Pudu.Doc.Json (encodeIndex)

{-| Render a complete documentation site.

    The index is embedded rather than fetched so the artifact works when it is
    opened directly from disk. Markup-opening scalars are escaped a second time
    after JSON encoding because JSON validity alone does not stop `</script>`
    from ending an HTML raw-text element. All entry rendering after that
    boundary uses DOM text nodes. -}
renderSite :: DocIndex -> Text
renderSite index =
  Text.concat
    [ documentStart
    , protectEmbeddedJson (encodeIndex index)
    , documentEnd
    ]

protectEmbeddedJson :: Text -> Text
protectEmbeddedJson =
  Text.replace "\x2029" "\\u2029"
    . Text.replace "\x2028" "\\u2028"
    . Text.replace ">" "\\u003e"
    . Text.replace "<" "\\u003c"
    . Text.replace "&" "\\u0026"

documentStart :: Text
documentStart =
  Text.unlines
    [ "<!doctype html>"
    , "<html lang='en'>"
    , "<head>"
    , "<meta charset='utf-8'>"
    , "<meta name='viewport' content='width=device-width, initial-scale=1'>"
    , "<meta name='description' content='Search Pudu declarations by name or inferred type.'>"
    , "<title>Pudu Docs — language reference</title>"
    , "<style>"
    , ":root{color-scheme:light;--paper:#f4f0e8;--card:#fffdf7;--ink:#16211f;--muted:#596562;--line:#d5d9d2;--blue:#2457e6;--blue-soft:#e8edff;--lime:#d7ff74;--shadow:0 18px 50px rgba(22,33,31,.08)}"
    , "*{box-sizing:border-box}"
    , "html{scroll-behavior:smooth}"
    , "body{margin:0;background:var(--paper);color:var(--ink);font:16px/1.55 ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif}"
    , "button,input{font:inherit}"
    , "a{color:inherit}"
    , ".shell{width:min(1120px,calc(100% - 40px));margin:0 auto}"
    , ".masthead{padding:30px 0 24px;border-bottom:1px solid var(--line)}"
    , ".nav{display:flex;align-items:center;justify-content:space-between;gap:24px}"
    , ".brand{display:flex;align-items:center;gap:12px;font-weight:800;letter-spacing:.08em;text-transform:uppercase}"
    , ".brand-mark{display:grid;place-items:center;width:34px;height:34px;border-radius:10px;background:var(--ink);color:var(--lime);font:800 18px/1 ui-monospace,SFMono-Regular,Menlo,monospace;transform:rotate(-3deg)}"
    , ".nav-note{color:var(--muted);font-size:.9rem}"
    , ".hero{padding:70px 0 46px}"
    , ".eyebrow{margin:0 0 10px;color:var(--blue);font-size:.78rem;font-weight:800;letter-spacing:.14em;text-transform:uppercase}"
    , "h1{max-width:820px;margin:0;font-size:clamp(2.6rem,7vw,5.5rem);line-height:.95;letter-spacing:-.065em}"
    , ".lede{max-width:700px;margin:24px 0 32px;color:var(--muted);font-size:clamp(1rem,2vw,1.2rem)}"
    , ".search-wrap{position:relative;max-width:880px}"
    , ".search{width:100%;border:1px solid var(--ink);border-radius:18px;background:var(--card);padding:20px 126px 20px 54px;color:var(--ink);box-shadow:var(--shadow);outline:none;font:600 clamp(1rem,2vw,1.18rem)/1.3 ui-monospace,SFMono-Regular,Menlo,monospace}"
    , ".search:focus{border-color:var(--blue);box-shadow:0 0 0 4px rgba(36,87,230,.14),var(--shadow)}"
    , ".search-icon{position:absolute;left:20px;top:50%;translate:0 -50%;color:var(--blue);font-weight:900}"
    , ".clear{position:absolute;right:10px;top:10px;bottom:10px;border:0;border-radius:11px;padding:0 18px;background:var(--ink);color:white;font-weight:750;cursor:pointer}"
    , ".clear:hover{background:var(--blue)}"
    , ".hints{display:flex;flex-wrap:wrap;gap:9px;margin-top:14px}"
    , ".hint{border:1px solid var(--line);border-radius:999px;background:transparent;padding:7px 11px;color:var(--muted);font:600 .8rem/1 ui-monospace,SFMono-Regular,Menlo,monospace;cursor:pointer}"
    , ".hint:hover,.hint:focus-visible{border-color:var(--blue);color:var(--blue);outline:none}"
    , ".bar{display:flex;align-items:end;justify-content:space-between;gap:20px;padding:24px 0 14px;border-top:1px solid var(--line)}"
    , ".bar h2{margin:0;font-size:1.05rem;letter-spacing:-.02em}"
    , ".count{color:var(--muted);font-size:.88rem}"
    , ".results{display:grid;gap:12px;padding-bottom:80px}"
    , ".result{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:18px;border:1px solid var(--line);border-radius:16px;background:var(--card);padding:20px 22px;box-shadow:0 2px 0 rgba(22,33,31,.025)}"
    , ".result:hover{border-color:#aeb8b3;translate:0 -1px}"
    , ".result-title{display:flex;align-items:baseline;flex-wrap:wrap;gap:9px;margin:0}"
    , ".name{font:750 1.05rem/1.3 ui-monospace,SFMono-Regular,Menlo,monospace}"
    , ".signature{color:var(--blue);font:600 .94rem/1.45 ui-monospace,SFMono-Regular,Menlo,monospace;overflow-wrap:anywhere}"
    , ".docs{max-width:760px;margin:10px 0 0;color:#485451;white-space:pre-line}"
    , ".provenance{display:flex;align-items:end;flex-direction:column;gap:6px;text-align:right}"
    , ".kind{border-radius:999px;background:var(--blue-soft);padding:4px 9px;color:var(--blue);font-size:.7rem;font-weight:800;letter-spacing:.06em;text-transform:uppercase}"
    , ".module{color:var(--muted);font:600 .77rem/1.3 ui-monospace,SFMono-Regular,Menlo,monospace}"
    , ".empty{border:1px dashed #aeb8b3;border-radius:18px;padding:54px 24px;text-align:center;color:var(--muted)}"
    , ".empty strong{display:block;margin-bottom:7px;color:var(--ink);font-size:1.2rem}"
    , ".noscript{margin:20px 0;border:1px solid #d79d52;border-radius:12px;background:#fff1db;padding:14px 16px}"
    , "footer{padding:24px 0 40px;border-top:1px solid var(--line);color:var(--muted);font-size:.82rem}"
    , "@media(max-width:680px){.shell{width:min(100% - 24px,1120px)}.masthead{padding-top:18px}.nav-note{display:none}.hero{padding:45px 0 34px}.search{padding:17px 46px}.clear{position:static;width:100%;margin-top:9px;padding:12px}.result{grid-template-columns:1fr}.provenance{align-items:start;flex-direction:row;text-align:left}.bar{align-items:start;flex-direction:column;gap:4px}}"
    , "@media(prefers-reduced-motion:reduce){html{scroll-behavior:auto}.result{transition:none}}"
    , "</style>"
    , "</head>"
    , "<body>"
    , "<header class='masthead'><div class='shell nav'><div class='brand'><span class='brand-mark' aria-hidden='true'>P</span><span>Pudu Docs</span></div><span class='nav-note'>Compiler-indexed language reference</span></div></header>"
    , "<main class='shell'>"
    , "<section class='hero' aria-labelledby='page-title'>"
    , "<p class='eyebrow'>Ask by name or by shape</p>"
    , "<h1 id='page-title'>Find the function you mean.</h1>"
    , "<p class='lede'>Search every declaration by its compiler-inferred type. Try a name like <code>map</code>, or describe the shape you need.</p>"
    , "<form id='search-form' role='search'>"
    , "<label for='query' class='eyebrow'>Search documentation</label>"
    , "<div class='search-wrap'><span class='search-icon' aria-hidden='true'>→</span><input class='search' id='query' name='q' type='search' autocomplete='off' spellcheck='false' placeholder='Array[a] -> a' aria-describedby='search-help'><button class='clear' type='button' id='clear'>Clear</button></div>"
    , "<div class='hints' id='search-help'><button class='hint' type='button' data-query='map'>map</button><button class='hint' type='button' data-query='Int -> Int'>Int → Int</button><button class='hint' type='button' data-query='Array[a] -> a'>Array[a] → a</button><button class='hint' type='button' data-query='-> Result[a, e]'>→ Result[a, e]</button></div>"
    , "</form>"
    , "<noscript><p class='noscript'>This static index needs JavaScript to search and render its declarations.</p></noscript>"
    , "</section>"
    , "<section aria-labelledby='results-title'><div class='bar'><h2 id='results-title'>All declarations</h2><div class='count' id='count' aria-live='polite'></div></div><div class='results' id='results'></div></section>"
    , "</main>"
    , "<footer><div class='shell'>Types come from the Pudu compiler, never from reconstructed source annotations.</div></footer>"
    , "<script id='pudu-index' type='application/json'>"
    ]

documentEnd :: Text
documentEnd =
  Text.unlines
    [ "</script>"
    , "<script>"
    , "'use strict';"
    , "const entries=JSON.parse(document.getElementById('pudu-index').textContent).entries;"
    , "const queryInput=document.getElementById('query');"
    , "const results=document.getElementById('results');"
    , "const count=document.getElementById('count');"
    , "const title=document.getElementById('results-title');"
    , "const form=document.getElementById('search-form');"
    , "const scalarList=value=>Array.from(value);"
    , "const isLetter=value=>/^\\p{L}$/u.test(value);"
    , "const isNumber=value=>/^\\p{N}$/u.test(value);"
    , "function isIdentifier(value){const chars=scalarList(value);return chars.length>0&&(isLetter(chars[0])||chars[0]==='_')&&chars.slice(1).every(char=>isLetter(char)||isNumber(char)||char==='_'||char==='.');}"
    , "function isVariableName(value){const chars=scalarList(value);return chars.length>0&&!/[A-Z]/.test(chars[0])&&(chars.length===1||chars.slice(1).every(char=>isLetter(char)||isNumber(char)));}"
    , "function splitTop(value,separator){let depth=0,part='',parts=[];for(const char of value){if(char==='['||char==='(')depth+=1;else if(char===']'||char===')')depth=Math.max(0,depth-1);if(char===separator&&depth===0){if(part.trim())parts.push(part.trim());part='';}else part+=char;}if(part.trim())parts.push(part.trim());return parts;}"
    , "function splitArrows(value){let depth=0,part='',parts=[];for(let i=0;i<value.length;i+=1){const char=value[i];if(char==='['||char==='(')depth+=1;else if(char===']'||char===')')depth=Math.max(0,depth-1);if(char==='-'&&value[i+1]==='>'&&depth===0){parts.push(part.trim());part='';i+=1;}else part+=char;}parts.push(part.trim());return parts;}"
    , "function matchingParen(value){let depth=0;for(let i=0;i<value.length;i+=1){if(value[i]==='(')depth+=1;if(value[i]===')'){depth-=1;if(depth===0)return i;}}return -1;}"
    , "function withinQueryBudget(value){const chars=scalarList(value);if(chars.length>512)return false;let depth=0;for(const char of chars){if(char==='['||char==='('){if(depth>=64)return false;depth+=1;}else if(char===']'||char===')')depth=Math.max(0,depth-1);}return true;}"
    , "function parseType(raw){const value=raw.trim();if(!value)return null;if(value==='()')return{form:'unit'};if(value==='_'||value==='?')return{form:'unknown'};if(value==='!')return{form:'never'};if(value.startsWith('&mut ')){const target=parseType(value.slice(5));return target&&{form:'ref',mutable:true,target};}if(value.startsWith('&')){const target=parseType(value.slice(1));return target&&{form:'ref',mutable:false,target};}if(value.startsWith('fn(')){const close=matchingParen(value.slice(2));if(close<0)return null;const boundary=close+2;const rest=value.slice(boundary+1).trim();if(!rest.startsWith('->'))return null;const inputs=splitTop(value.slice(3,boundary),',').map(parseType);const result=parseType(rest.slice(2));return inputs.every(Boolean)&&result?{form:'fn',inputs,result}:null;}if(value.startsWith('(')&&value.endsWith(')')){const members=splitTop(value.slice(1,-1),',').map(parseType);if(!members.every(Boolean))return null;if(members.length===0)return{form:'unit'};return members.length===1?members[0]:{form:'tuple',members};}if(value.endsWith(']')){const open=value.indexOf('[');if(open>0){const name=value.slice(0,open).trim();const typeArguments=splitTop(value.slice(open+1,-1),',').map(parseType);return isIdentifier(name)&&typeArguments.every(Boolean)?{form:'con',name,arguments:typeArguments}:null;}}if(!isIdentifier(value))return null;return isVariableName(value)?{form:'var',name:value}:{form:'con',name:value,arguments:[]};}"
    , "function parseQuery(raw){const value=raw.trim();if(!value)return null;if(!withinQueryBudget(value))return{kind:'invalid'};if(!value.includes('->'))return{kind:'name',value};let pieces=splitArrows(value);if(pieces.length>1&&!pieces[0])pieces=pieces.slice(1);if(pieces.length===0||pieces.some(part=>!part))return{kind:'invalid'};const parts=pieces.map(parseType);if(!parts.every(Boolean))return{kind:'invalid'};return{kind:'shape',signature:{arguments:parts.slice(0,-1),result:parts.at(-1)}};}"
    , "function normalise(signature){const names=new Map();let next=0;function rename(type){if(type.form==='var'){if(!names.has(type.name))names.set(type.name,'%'+next++);return{...type,name:names.get(type.name)};}if(type.form==='con')return{...type,arguments:type.arguments.map(rename)};if(type.form==='ref')return{...type,target:rename(type.target)};if(type.form==='tuple')return{...type,members:type.members.map(rename)};if(type.form==='fn')return{...type,inputs:type.inputs.map(rename),result:rename(type.result)};return type;}return{arguments:signature.arguments.map(rename),result:rename(signature.result)};}"
    , "function compatible(wanted,found){if(wanted.form==='unknown'||found.form==='unknown'||found.form==='var'||wanted.form==='never'||found.form==='never')return true;if(wanted.form==='var')return false;if(wanted.form!==found.form)return false;if(wanted.form==='con')return wanted.name===found.name&&wanted.arguments.length===found.arguments.length&&wanted.arguments.every((item,index)=>compatible(item,found.arguments[index]));if(wanted.form==='ref')return wanted.mutable===found.mutable&&compatible(wanted.target,found.target);if(wanted.form==='tuple')return wanted.members.length===found.members.length&&wanted.members.every((item,index)=>compatible(item,found.members[index]));if(wanted.form==='fn')return wanted.inputs.length===found.inputs.length&&wanted.inputs.every((item,index)=>compatible(item,found.inputs[index]))&&compatible(wanted.result,found.result);return wanted.form==='unit';}"
    , "function consumesAll(wanted,available){const rest=[...available];for(const item of wanted){const found=rest.findIndex(candidate=>compatible(item,candidate));if(found<0)return false;rest.splice(found,1);}return true;}"
    , "function shapeScore(wanted,rawFound){const found=normalise(rawFound);const sameResult=compatible(wanted.result,found.result);const sameArity=wanted.arguments.length===found.arguments.length;const sameShape=sameArity&&wanted.arguments.every((item,index)=>compatible(item,found.arguments[index]))&&sameResult;if(sameShape)return 0;if(sameArity&&sameResult&&consumesAll(wanted.arguments,found.arguments))return 40;if(sameResult&&wanted.arguments.length===0)return 60;if(sameResult&&consumesAll(wanted.arguments,found.arguments))return 50;return null;}"
    , "function subsequence(wanted,found){let offset=0;for(const char of found){if(char===wanted[offset])offset+=1;if(offset===wanted.length)return true;}return wanted.length===0;}"
    , "function nameScore(wanted,found){const query=wanted.toLowerCase(),name=found.toLowerCase();if(query===name)return 0;if(name.startsWith(query))return 10;if(name.includes(query))return 20;if(subsequence(query,name))return 30;return null;}"
    , "function ranked(raw){const query=parseQuery(raw);if(!query)return entries.map((entry,index)=>({entry,index,score:0}));if(query.kind==='invalid')return[];const wanted=query.kind==='shape'?normalise(query.signature):null;return entries.map((entry,index)=>{const score=query.kind==='name'?nameScore(query.value,entry.name):(entry.shape&&shapeScore(wanted,entry.shape));return{entry,index,score};}).filter(match=>match.score!==null&&match.score!==false).sort((left,right)=>left.score-right.score||left.index-right.index);}"
    , "function appendText(parent,className,value){const element=document.createElement('span');element.className=className;element.textContent=value;parent.append(element);}"
    , "function resultCard(entry){const card=document.createElement('article');card.className='result';const body=document.createElement('div');const heading=document.createElement('h3');heading.className='result-title';appendText(heading,'name',entry.name);if(entry.signature)appendText(heading,'signature',':: '+entry.signature);body.append(heading);if(entry.doc.length){const docs=document.createElement('p');docs.className='docs';docs.textContent=entry.doc.join(String.fromCharCode(10));body.append(docs);}const provenance=document.createElement('div');provenance.className='provenance';appendText(provenance,'kind',entry.kind);appendText(provenance,'module',entry.module);card.append(body,provenance);return card;}"
    , "function emptyState(raw){const box=document.createElement('div');box.className='empty';const strong=document.createElement('strong');strong.textContent=entries.length===0?'No declarations indexed':'No matching declaration';const detail=document.createElement('span');detail.textContent=entries.length===0?'Compile one or more Pudu modules to fill this page.':raw.includes('->')?'Check the type shape, or remove an argument to widen the search.':'Try a shorter name or search by an inferred type.';box.append(strong,detail);return box;}"
    , "function render(){const raw=queryInput.value;const matches=ranked(raw);results.replaceChildren(...(matches.length?matches.map(match=>resultCard(match.entry)):[emptyState(raw)]));const trimmed=raw.trim();title.textContent=trimmed?'Search results':'All declarations';count.textContent=matches.length+' '+(matches.length===1?'declaration':'declarations');const url=new URL(window.location.href);if(trimmed)url.searchParams.set('q',trimmed);else url.searchParams.delete('q');history.replaceState(null,'',url);}"
    , "form.addEventListener('submit',event=>{event.preventDefault();render();});"
    , "queryInput.addEventListener('input',render);"
    , "document.getElementById('clear').addEventListener('click',()=>{queryInput.value='';queryInput.focus();render();});"
    , "document.querySelectorAll('[data-query]').forEach(button=>button.addEventListener('click',()=>{queryInput.value=button.dataset.query;queryInput.focus();render();}));"
    , "queryInput.value=new URL(window.location.href).searchParams.get('q')||'';"
    , "render();"
    , "</script>"
    , "</body>"
    , "</html>"
    ]
