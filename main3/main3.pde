import processing.net.*;

Client c;
int state = 0;
String serverMsg = "";
ArrayList<PlayerInfo> players = new ArrayList<PlayerInfo>();
String terminalBuffer = "";

void setup() {
  size(800, 600);
  c = new Client(this, "127.0.0.1", 12345);
  println("Conectado ao servidor!");
}

void draw() {
  background(30);
  if (c.available() > 0) {
    String raw = c.readStringUntil('\n');
    if (raw != null) {
      handleServerMessage(raw.trim());
    }
  }

  if (state == 0) {
    drawLoginScreen();
  } else if (state == 1) {
    drawQueueScreen();
  } else if (state == 2) {
    drawGameScreen();
  }
}

void handleServerMessage(String msg) {
  println("Servidor diz: " + msg);

  if (msg.equals("<ENTRASTE>")) {
    state = 1;
    c.write("JOIN\n");                     // <-- entramos automaticamente na fila
  } else if (msg.equals("GAME_START")) {  // <-- mensagem correta tava em portugues, mas o servidor manda GAME_START
    state = 2;
  } else if (msg.startsWith("(ERROR)")) {
    serverMsg = msg;
  } else if (state == 2) {
    parsePhysics(msg);
  }
}

void parsePhysics(String msg) {
  players.clear();
  String[] parts = split(msg, '|');
  for (String p : parts) {
    String[] d = split(p, ',');
    if (d.length == 4) {
      players.add(new PlayerInfo(d[0], float(d[1]), float(d[2]), float(d[3])));
    }
  }
}

void keyPressed() {
  if (state == 0) {
    if (key == ENTER || key == RETURN) {
      if (terminalBuffer.length() > 0) {
        c.write(terminalBuffer + "\n");
        println("Enviado: " + terminalBuffer);
        terminalBuffer = "";
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
    rect(0, 0, 30, 20);
    fill(255);
    rotate(-p.angle);
    text(p.name, 0, -20);
    popMatrix();
  }
}

class PlayerInfo {
  String name;
  float x, y, angle;
  PlayerInfo(String n, float x, float y, float a) {
    name = n; x = x; y = y; angle = a;
  }
}
