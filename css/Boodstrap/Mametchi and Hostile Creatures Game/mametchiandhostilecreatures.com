<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Mametchi Biting Defense</title>
<style>
body {
  margin: 0;
  padding: 15px;
  background: #17152e;
  color: white;
  font-family: Arial, sans-serif;
  text-align: center;
}
h1 { color: #ffe66d; }
.panel {
  background: #29264b;
  padding: 12px;
  border-radius: 12px;
  margin: 12px auto;
  max-width: 850px;
}
canvas {
  display: block;
  width: 100%;
  max-width: 850px;
  height: auto;
  margin: auto;
  background: #253b5b;
  border: 4px solid gold;
  border-radius: 12px;
}
button {
  background: #ffe66d;
  color: #222;
  border: none;
  border-radius: 8px;
  padding: 11px;
  margin: 4px;
  cursor: pointer;
  font-weight: bold;
}
button:hover { background: orange; }
button:disabled { opacity: .5; }
</style>
</head>
<body>

<h1>🛡️ Mametchi: Biting Defense</h1>
<p>Protect Mametchi with your hostile creatures!</p>

<div class="panel">
❤️ HP: <span id="hp">100</span> |
⭐ Points: <span id="points">100</span> |
🌊 Wave: <span id="wave">1</span>
</div>

<canvas id="game" width="850" height="430"></canvas>

<div class="panel">
<h3>🐾 Recruit Your Biting Creatures</h3>
<button onclick="recruit('Dark Mouse')">🐭 Dark Mouse (10)</button>
<button onclick="recruit('Shadow Rat')">🐀 Shadow Rat (15)</button>
<button onclick="recruit('Shadow Creature')">👾 Shadow Creature (20)</button>
<button onclick="recruit('Gear Golem')">🤖 Gear Golem (25)</button>
<button onclick="recruit('Flying Creature')">🦇 Flying Creature (30)</button>
</div>

<div class="panel">
<button id="start" onclick="startWave()">▶ Start Wave</button>
<button onclick="restart()">🔄 Restart</button>
<h3 id="message">Recruit creatures to protect Mametchi!</h3>
</div>

<script>
const canvas = document.getElementById("game");
const ctx = canvas.getContext("2d");

const lanes = [105, 215, 325];

const creatures = {
  "Dark Mouse": {
    emoji:"🐭", cost:10, damage:12,
    speed:145, cooldown:0.45, range:430
  },
  "Shadow Rat": {
    emoji:"🐀", cost:15, damage:24,
    speed:120, cooldown:0.8, range:480
  },
  "Shadow Creature": {
    emoji:"👾", cost:20, damage:30,
    speed:130, cooldown:0.9, range:500
  },
  "Gear Golem": {
    emoji:"🤖", cost:25, damage:45,
    speed:90, cooldown:1.3, range:530
  },
  "Flying Creature": {
    emoji:"🦇", cost:30, damage:35,
    speed:180, cooldown:0.7, range:600
  }
};

const enemyTypes = [
  {name:"Drum", emoji:"🥁", hp:45, speed:35},
  {name:"Taiko", emoji:"🪘", hp:65, speed:28},
  {name:"Timpani", emoji:"🥁", hp:85, speed:24},
  {name:"Violin", emoji:"🎻", hp:40, speed:50},
  {name:"King", emoji:"👑", hp:130, speed:22},
  {name:"Female King", emoji:"👸", hp:150, speed:26}
];

let hp, points, wave;
let defenders = [];
let enemies = [];
let effects = [];
let running = false;
let gameOver = false;
let spawned = 0;
let spawnTimer = 0;
let lastTime = 0;

function say(message) {
  document.getElementById("message").textContent = message;
}

function updateUI() {
  document.getElementById("hp").textContent = hp;
  document.getElementById("points").textContent = points;
  document.getElementById("wave").textContent = wave;
  document.getElementById("start").disabled =
    running || gameOver;
}

function recruit(name) {
  if (gameOver) return;

  const data = creatures[name];

  if (points < data.cost) {
    say("Not enough points!");
    return;
  }

  points -= data.cost;

  const lane = defenders.length % 3;
  const homeX = 140 + Math.floor(defenders.length / 3) * 55;

  defenders.push({
    name,
    emoji: data.emoji,
    lane,
    homeX,
    x: homeX,
    y: lanes[lane],
    damage: data.damage,
    speed: data.speed,
    cooldownTime: data.cooldown,
    cooldown: 0,
    range: data.range,
    target: null,
    biteTime: 0,
    chomping: false
  });

  say(name + " joined Mametchi's army!");
  updateUI();
}

function startWave() {
  if (running || gameOver) return;

  running = true;
  spawned = 0;
  spawnTimer = 0;
  enemies = [];
  effects = [];

  say("Wave " + wave + " incoming!");
  updateUI();
}

function spawnEnemy() {
  const boss = wave % 5 === 0 && spawned === 0;

  let data;

  if (boss) {
    data = {
      name:"Female King Boss",
      emoji:"👸",
      hp:350 + wave * 30,
      speed:20
    };
  } else {
    data = enemyTypes[
      Math.floor(Math.random() * enemyTypes.length)
    ];
  }

  const lane = Math.floor(Math.random() * 3);
  const maxHp = data.hp + wave * 5;

  enemies.push({
    name:data.name,
    emoji:data.emoji,
    x:830,
    y:lanes[lane],
    lane,
    hp:maxHp,
    maxHp,
    speed:data.speed,
    boss,
    dead:false
  });

  spawned++;
}

function update(dt) {
  if (!running || gameOver) return;

  // Spawn attackers.
  const total = wave % 5 === 0 ? 1 : wave + 3;

  spawnTimer += dt;

  if (spawned < total &&
      spawnTimer >= Math.max(0.8, 1.8 - wave * 0.05)) {
    spawnEnemy();
    spawnTimer = 0;
  }

  // Move enemies toward Mametchi.
  enemies.forEach(e => {
    e.x -= e.speed * dt;

    if (e.x < 65) {
      hp -= e.boss ? 30 : 10;
      e.dead = true;
      say(e.name + " reached Mametchi!");
    }

    if (e.hp <= 0) {
      e.dead = true;
      points += e.boss ? 100 : 10;
      say(e.name + " was defeated!");
    }
  });

  enemies = enemies.filter(e => !e.dead);

  // Creature biting attacks.
  defenders.forEach(d => {
    d.cooldown -= dt;
    d.biteTime = Math.max(0, d.biteTime - dt);
    d.chomping = false;

    // Find a nearby attacker in the same lane.
    let target = enemies
      .filter(e =>
        e.lane === d.lane &&
        e.x > 65 &&
        e.x >= d.homeX - 20 &&
        e.x - d.homeX <= d.range
      )
      .sort((a,b) => a.x - b.x)[0];

    d.target = target || null;

    if (target) {
      // Chase the enemy and stop beside it.
      const destination = Math.max(75, target.x - 48);
      const distance = destination - d.x;
      const step = d.speed * dt;

      if (Math.abs(distance) > 3) {
        d.x += Math.sign(distance) *
          Math.min(Math.abs(distance), step);
      }

      // Bite when close enough.
      if (Math.abs(target.x - d.x - 48) < 18 &&
          d.cooldown <= 0) {

        target.hp -= d.damage;
        d.cooldown = d.cooldownTime;
        d.biteTime = 0.22;
        d.chomping = true;

        effects.push({
          x:target.x - 5,
          y:target.y - 35,
          text:"CHOMP!",
          time:0.45
        });
      }
    } else {
      // Return to the original guarding position.
      const distance = d.homeX - d.x;
      const step = d.speed * dt;

      if (Math.abs(distance) > 2) {
        d.x += Math.sign(distance) *
          Math.min(Math.abs(distance), step);
      }
    }
  });

  // Remove defeated enemies.
  enemies.forEach(e => {
    if (e.hp <= 0 && !e.dead) {
      e.dead = true;
      points += e.boss ? 100 : 10;
    }
  });

  enemies = enemies.filter(e => !e.dead);

  // Update CHOMP text.
  effects.forEach(e => e.time -= dt);
  effects = effects.filter(e => e.time > 0);

  if (hp <= 0) {
    hp = 0;
    gameOver = true;
    running = false;
    say("GAME OVER! Mametchi needs protection!");
  }

  if (spawned >= total && enemies.length === 0) {
    running = false;
    points += 30;
    wave++;
    say("Wave cleared! +30 bonus points!");
  }

  updateUI();
}

function draw() {
  ctx.clearRect(0,0,850,430);

  ctx.fillStyle = "#253b5b";
  ctx.fillRect(0,0,850,430);

  // Three battle lanes.
  lanes.forEach((y,i) => {
    ctx.fillStyle = i % 2 === 0 ? "#304a68" : "#29435f";
    ctx.fillRect(0,y-48,850,96);

    ctx.strokeStyle = "#66809c";
    ctx.setLineDash([8,8]);
    ctx.beginPath();
    ctx.moveTo(0,y+48);
    ctx.lineTo(850,y+48);
    ctx.stroke();
    ctx.setLineDash([]);
  });

  // Mametchi.
  ctx.font = "48px Arial";
  ctx.fillText("🐣",12,230);
  ctx.font = "14px Arial";
  ctx.fillStyle = "white";
  ctx.fillText("MAMETCHI",5,255);

  // Defenders and bite animations.
  defenders.forEach(d => {
    const lunge = d.biteTime > 0 ? 12 : 0;

    ctx.font = "36px Arial";
    ctx.fillText(d.emoji,d.x+lunge,d.y+12);

    if (d.chomping) {
      ctx.font = "bold 15px Arial";
      ctx.fillStyle = "#ffe66d";
      ctx.fillText("NOM!",d.x+8,d.y-22);
    }
  });

  // Attackers and their health bars.
  enemies.forEach(e => {
    ctx.font = e.boss ? "52px Arial" : "35px Arial";
    ctx.fillText(e.emoji,e.x,e.y+12);

    const width = e.boss ? 65 : 42;

    ctx.fillStyle = "#501b2c";
    ctx.fillRect(e.x-8,e.y-30,width,7);

    ctx.fillStyle = "#7dff85";
    ctx.fillRect(
      e.x-8,e.y-30,
      width * Math.max(0,e.hp/e.maxHp),7
    );

    if (e.boss) {
      ctx.font = "bold 13px Arial";
      ctx.fillStyle = "gold";
      ctx.fillText("BOSS",e.x,e.y-38);
    }
  });

  // Bite effects.
  effects.forEach(e => {
    ctx.font = "bold 18px Arial";
    ctx.fillStyle = "#ffe66d";
    ctx.fillText(e.text,e.x,e.y);
  });

  if (gameOver) {
    ctx.fillStyle = "rgba(0,0,0,.75)";
    ctx.fillRect(0,0,850,430);
    ctx.fillStyle = "white";
    ctx.font = "42px Arial";
    ctx.fillText("GAME OVER",300,200);
  }
}

function loop(timestamp) {
  const dt = lastTime
    ? Math.min((timestamp-lastTime)/1000,0.05)
    : 0;

  lastTime = timestamp;
  update(dt);
  draw();
  requestAnimationFrame(loop);
}

function restart() {
  hp = 100;
  points = 100;
  wave = 1;
  defenders = [];
  enemies = [];
  effects = [];
  running = false;
  gameOver = false;
  spawned = 0;
  spawnTimer = 0;

  say("Recruit creatures to protect Mametchi!");
  updateUI();
  draw();
}

// Start game.
hp = 100;
points = 100;
wave = 1;

updateUI();
draw();
requestAnimationFrame(loop);
</script>

</body>
</html>

