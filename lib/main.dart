<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>صحوة - منبه لا يطفي</title>
<style>
body{background:#0f0f13;color:#fff;font-family:tahoma;text-align:center;padding:20px}
.card{background:#1c1c22;border-radius:20px;padding:25px;max-width:380px;margin:auto;box-shadow:0 10px 30px rgba(0,0,0,.5)}
h1{color:#a855f7;margin:0}
.time{font-size:55px;font-weight:bold;margin:15px 0;letter-spacing:2px}
input{width:90%;padding:15px;border-radius:12px;border:none;background:#2a2a33;color:#fff;font-size:20px;margin:10px 0}
button{width:95%;padding:16px;border-radius:14px;border:none;font-size:18px;font-weight:bold;cursor:pointer;margin-top:10px}
.btn-set{background:#a855f7;color:#fff}
.btn-stop{background:#ef4444;color:#fff}
#alarmScreen{display:none;position:fixed;inset:0;background:#ef4444;z-index:99;flex-direction:column;justify-content:center;align-items:center;padding:20px}
#alarmScreen h2{font-size:35px;animation:shake .3s infinite}
@keyframes shake{0%{transform:rotate(-2deg)}50%{transform:rotate(2deg)}100%{transform:rotate(-2deg)}}
.math-box{background:#fff;color:#000;padding:20px;border-radius:15px;margin:15px;width:90%;max-width:320px}
</style>
</head>
<body>
<div class="card">
<h1>⏰ صحوة</h1>
<p>منبه ما يطفي إلا إذا صحصحت</p>
<div class="time" id="clock">--:--:--</div>
<input type="time" id="alarmTime">
<button class="btn-set" onclick="setAlarm()">ضبط المنبه - com.almlhan.sahwa</button>
<p id="status" style="color:#a855f7;margin-top:15px">ما فيه منبه مضبوط</p>
<button onclick="testAlarm()" style="background:#333;color:#aaa;font-size:13px">تجربة الصوت</button>
</div>

<div id="alarmScreen">
<h2>🚨 اصحى يا بطل! 🚨</h2>
<p>حل المسألة عشان يطفي المنبه</p>
<div class="math-box">
<h3 id="question">5 + 3 = ?</h3>
<input type="number" id="answer" placeholder="اكتب الجواب">
<button class="btn-stop" onclick="checkAnswer()">إيقاف</button>
</div>
</div>

<script>
let alarmT=null,ringing=false,audioCtx,osc,gain;
let n1,n2,correct;
const clock=document.getElementById('clock');
setInterval(()=>{const d=new Date();clock.textContent=d.toLocaleTimeString('ar-SA');if(alarmT){const now=d.getHours().toString().padStart(2,'0')+':'+d.getMinutes().toString().padStart(2,'0');if(now===alarmT && !ringing)startRing()}},1000);

function setAlarm(){const t=document.getElementById('alarmTime').value;if(!t){alert('اختر الوقت أول');return}alarmT=t;document.getElementById('status').textContent='✅ المنبه مضبوط على '+t; if('Notification' in window)Notification.requestPermission();}

function genMath(){n1=Math.floor(Math.random()*20)+5;n2=Math.floor(Math.random()*10)+2;correct=n1+n2;document.getElementById('question').textContent=n1+' + '+n2+' = ?';document.getElementById('answer').value='';}

function startRing(){ringing=true;genMath();document.getElementById('alarmScreen').style.display='flex';playSound();navigator.vibrate&&navigator.vibrate([1000,200,1000,200,1000]);}
function playSound(){try{audioCtx=new(window.AudioContext||window.webkitAudioContext)();osc=audioCtx.createOscillator();gain=audioCtx.createGain();osc.type='square';osc.frequency.value=880;gain.gain.value=0.5;osc.connect(gain);gain.connect(audioCtx.destination);osc.start();setInterval(()=>{if(!ringing)return;osc.frequency.value=osc.frequency.value==880?1200:880},400)}catch(e){}}

function checkAnswer(){const v=parseInt(document.getElementById('answer').value);if(v===correct){stopRing()}else{genMath();document.getElementById('answer').placeholder='غلط! حاول مرة ثانية';document.getElementById('answer').value='';if(navigator.vibrate)navigator.vibrate(500)}}
function stopRing(){ringing=false;document.getElementById('alarmScreen').style.display='none';try{osc&&osc.stop();audioCtx&&audioCtx.close()}catch(e){}alarmT=null;document.getElementById('status').textContent='ما فيه منبه مضبوط';alert('كفوو صحصحت! 🔥');}
function testAlarm(){genMath();startRing();setTimeout(()=>{if(ringing){document.getElementById('answer').value=correct}},1000)}
</script>
</body>
</html>