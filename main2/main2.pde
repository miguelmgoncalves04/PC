import processing.net.*;

Client c;
int state = 0; // 0: Login, 1: Fila (Matchmaker), 2: Jogo
String serverMsg = "";
ArrayList<PlayerInfo> players = new ArrayList<PlayerInfo>();
String terminalBuffer = "";

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
      c.write("JOIN\n");
  } else if (msg.equals("GAME_START")) {
      state = 2; // Passa para o jogo
  } else if (msg.equals("GAME_OVER")) {  // adicionei esta linha e agora sempre que um jogo acaba começa outra vez
      state = 1;
      c.write("JOIN\n");
  } else if (msg.startsWith("(ERROR)")) {
      serverMsg = msg;
  } else if (state == 2) {
      // Se estivermos em jogo, a mensagem é o Broadcast (posições)
      // Formato esperado: "User1,10,20,0.5|User2,50,60,1.2"
      parsePhysics(msg);
  }
}

void parsePhysics(String msg) { // ISTO MTA MAL : luis: ta nada
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
    if (key == ENTER || key == RETURN) {
      if (terminalBuffer.length() > 0) {
        c.write(terminalBuffer + "\n"); // Envia o comando completo
        println("Enviado: " + terminalBuffer);  // Debug no console do Processing
        terminalBuffer = ""; // Limpa o terminal para a próxima mensagem
      }
    } else if (key != CODED) {
      terminalBuffer += key;
    }
  } else if (state == 2) {
    if (key == 'w' || keyCode == UP)    c.write("FORWARD\n");   // so pus com maiusculas xd
    if (key == 'a' || keyCode == LEFT)  c.write("LEFT\n");
    if (key == 'd' || keyCode == RIGHT) c.write("RIGHT\n");
  }
}

//a mudança que fiz é mais para ser mais facil foi chat admito, mas tava a dar-me asia ter que tar a olhar para o terminal para ver o que tava a escrever
void drawLoginScreen() {
  textAlign(CENTER);
  fill(255);
  text("ECRÃ DE LOGIN", width/2, height/2 - 40);
  text("Digita o comando (ex: LOGIN:Alice:123)", width/2, height/2);
  fill(255, 0, 0);
  text(serverMsg, width/2, height/2 + 40);
  fill(255);
  text(terminalBuffer, width/2, height/2 + 80);
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
