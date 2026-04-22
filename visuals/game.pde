import processing.net.*;

Client myClient;
String data;
String[] players;

void setup() {
  size(800, 600);
  // Conecta ao servidor Erlang na porta escolhida
  myClient = new Client(this, "127.0.0.1", 12345); 
}

void draw() {
  background(0);
  
  // 1. Verificar se há dados novos do Erlang
  if (myClient.available() > 0) {
    data = myClient.readStringUntil('\n'); // Lê a linha completa
    if (data != null) {
      players = split(data.trim(), '|'); // Divide os jogadores
    }
  }

  // 2. Desenhar os jogadores baseados nos dados recebidos
  if (players != null) {
    for (String p : players) {
      String[] stats = split(p, ',');
      if (stats.length == 4) {
        String name = stats[0];
        float x = float(stats[1]);
        float y = float(stats[2]);
        float angle = float(stats[3]);
        
        drawPlayer(x, y, angle, name);
      }
    }
  }
}

void drawPlayer(float x, float y, float a, String name) {
  pushMatrix();
  translate(x, y);
  rotate(a);
  fill(0, 255, 0);
  rectMode(CENTER);
  rect(0, 0, 30, 20); // Representação do jogador
  fill(255);
  text(name, 15, 15);
  popMatrix();
}

// 3. Enviar input para o Erlang
void keyPressed() {
  if (key == 'w' || keyCode == UP) myClient.write("forward\n");
  if (key == 'a' || keyCode == LEFT) myClient.write("left\n");
  if (key == 'd' || keyCode == RIGHT) myClient.write("right\n");
}