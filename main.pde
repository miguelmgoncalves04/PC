import processing.net.*;

Client c;
int state = 0; // 0: Login, 1: Fila (Matchmaker), 2: Jogo
String serverMsg = "";
ArrayList<PlayerInfo> players = new ArrayList<PlayerInfo>();

void setup() { // na teoria isto está bem
  size(800, 600);
  // Conecta ao servidor Erlang
  c = new Client(this, "127.0.0.1", 12345); 
  println("Conectado ao servidor!");
}

void draw() {
  background(30);
  
  // 1. ESCUTAR O SERVIDOR
  if (c.available() > 0) {
    String raw = c.readStringUntil('\n');
    if (raw != null) {
      handleServerMessage(raw.trim());
    }
  }

  // 2. DESENHAR INTERFACE BASEADA NO ESTADO
  if (state == 0) {
    drawLoginScreen();
  } else if (state == 1) {
    drawQueueScreen();
  } else if (state == 2) {
    drawGameScreen();
  }
}

// Lógica para processar o que o Erlang envia
void handleServerMessage(String msg) {
  println("Servidor diz: " + msg);
  
  if (msg.equals("<ENTRASTE>")) {
    state = 1; // Passa para a fila
  } 
  else if (msg.equals("<JOGO_COMECOU>")) {
    state = 2; // Passa para o jogo
  } 
  else if (msg.startsWith("(ERROR)")) {
    serverMsg = msg;
  } 
  else if (state == 2) {
    // Se estivermos em jogo, a mensagem é o Broadcast (posições)
    // Formato esperado: "User1,10,20,0.5|User2,50,60,1.2"
    parsePhysics(msg);
  }
}

void parsePhysics(String msg) { // ISTO MTA MAL 
  players.clear();
  String[] parts = split(msg, '|');
  for (String p : parts) {
    String[] d = split(p, ',');
    if (d.length == 4) {
      players.add(new PlayerInfo(d[0], float(d[1]), float(d[2]), float(d[3])));
    }
  }
}

// COMANDOS DE TECLADO
void keyPressed() {
  if (state == 0) {
    if (key == 'l') c.write("LOGIN:PauloPicas:cartas123\n");
    if (key == 'r') c.write("REGIST:PauloPicas:cartas123\n");
  } 
  else if (state == 2) {
    if (key == 'w' || keyCode == UP)    c.write("forward\n");
    if (key == 'a' || keyCode == LEFT)  c.write("left\n");
    if (key == 'd' || keyCode == RIGHT) c.write("right\n");
  }
}

// --- INTERFACES VISUAIS ---

void drawLoginScreen() {
  textAlign(CENTER);
  fill(255);
  text("ECRÃ DE LOGIN", width/2, height/2 - 40);
  text("Carrega em 'L' para Login ou 'R' para Registar", width/2, height/2);
  fill(255, 0, 0);
  text(serverMsg, width/2, height/2 + 40);
}

void drawQueueScreen() {
  textAlign(CENTER);
  fill(255, 255, 0);
  text("NA FILA DE ESPERA...", width/2, height/2);
  text("À espera de jogadores (mínimo 3)...", width/2, height/2 + 20);
}

void drawGameScreen() {
  for (PlayerInfo p : players) {
    pushMatrix();
    translate(p.x, p.y);
    rotate(p.angle);
    rectMode(CENTER);
    fill(0, 255, 0);
    rect(0, 0, 30, 20); // O "carro" do jogador
    fill(255);
    rotate(-p.angle);
    text(p.name, 0, -20);
    popMatrix();
  }
}

// Classe simples para guardar os dados dos jogadores
class PlayerInfo { // isto pra ja dica assim
  String name;
  float x, y, angle;
  PlayerInfo(String n, float x, float y, float a) {
    name = n; x = x; y = y; angle = a;
  }
}