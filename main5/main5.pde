//Agora usa-se flags tipo leftFlag para dizer se tamos a clicar na tecla ou não e o 
//draw() envia os comandos consuante se tiver true ou não.
//Fica Flase se não tivermos a clicar na tecla isso é a keyReleaded. 
//É uma forma de o game-session saber quando é para desacelerar.

//O taveira colocaou no game_session o novo formato que é 
//"P,Nome,x,y,ângulo,massa,score|...|O,F/V,x,y,raio|...". e eu adaptedei tudo para
//essa cena tbm.

//Nova classe ObjectInfo para desenhar o venono e comida.


//Agora são desenhados cirulos em ves de retangulos nos jogadores.
//O raio desses é simplesmente sqrt(mass/PI) e usa-se a nova variavel myUsername 
//para saber qual pintar de azul


//Pedi ao chat para comentar o codigo tbm hjahjah
//Btw foi mais ele do que eu que fiz isto, mas tá certo acho kk, por isso yha eu n saia do sitio kkkk.


import processing.net.*;

// ==================== VARIÁVEIS GLOBAIS ====================
Client c;                           // ligação TCP com o servidor Erlang
int state = 0;                      // ecrã atual: 0=Login, 1=Fila de espera, 2=Jogo
String serverMsg = "";              // mensagem de erro ou aviso do servidor
ArrayList<PlayerInfo> players = new ArrayList<PlayerInfo>();   // lista de jogadores recebidos
ArrayList<ObjectInfo> objects = new ArrayList<ObjectInfo>();   // lista de objetos (comida/veneno)
ArrayList<TopPlayer> topPlayers = new ArrayList<TopPlayer>();
String terminalBuffer = "";         // buffer para escrever comandos no ecrã de login
String myUsername = "";             // nome do jogador local (capturado no LOGIN)

// Flags para movimento contínuo (enquanto a tecla está premida)
boolean leftFlag = false, rightFlag = false, forwardFlag = false;

// ==================== SETUP ====================
void setup() {
  size(800, 600);                                    // janela 800x600
  c = new Client(this, "127.0.0.1", 12345);         // liga ao servidor local na porta 12345
  println("Conectado ao servidor!");
}

// ==================== LOOP PRINCIPAL (executado a cada frame) ====================
void draw() {
  background(30);                    // fundo escuro

  // --- 1. Ler todas as linhas enviadas pelo servidor ---
  if (c.available() > 0) {
    String raw = c.readStringUntil('\n');
    if (raw != null) {
      handleServerMessage(raw.trim());
    }
  }

  // --- 2. Enviar comandos de movimento CONTINUAMENTE se as teclas estiverem premidas ---
  if (state == 2) {
    if (leftFlag)   c.write("LEFT\n");
    if (rightFlag)  c.write("RIGHT\n");
    if (forwardFlag) c.write("FORWARD\n");
  }

  // --- 3. Desenhar o ecrã correto de acordo com o estado ---
  if (state == 0) {
    drawLoginScreen();
  } else if (state == 1) {
    drawQueueScreen();
  } else if (state == 2) {
    drawGameScreen();
  }
}

// ==================== TRATAMENTO DE MENSAGENS DO SERVIDOR ====================
void handleServerMessage(String msg) {
  println("Servidor diz: " + msg);    // mostra no terminal (debug)
  
  if (msg.startsWith("{\"top\":")) {
    parseTop(msg);
    return;
  }
  if (msg.equals("<ENTRASTE>")) {
    // Login bem-sucedido → muda para ecrã de espera e entra na fila
    state = 1;
    c.write("JOIN\n");
  } else if (msg.equals("GAME_START")) {
    // A partida começou → muda para ecrã de jogo
    state = 2;
  } else if (msg.equals("GAME_OVER")) {
    // A partida terminou → volta à fila automaticamente
    state = 1;
    leftFlag = rightFlag = forwardFlag = false;   // para enviar comandos "fantasma"
    c.write("JOIN\n");
  } else if (msg.startsWith("(ERROR)")) {
    // Mostra erro no ecrã de login
    serverMsg = msg;
  } else if (state == 2) {
    // Durante o jogo, as mensagens são o estado do mundo (jogadores + objetos)
    parseGameState(msg);
  }
}


void parseTop(String msg) {
    topPlayers.clear();
    JSONObject json = parseJSONObject(msg);
    JSONArray arr = json.getJSONArray("top");
    for (int i = 0; i < arr.size(); i++) {
        JSONObject item = arr.getJSONObject(i);
        String name = item.getString("username");
        int score = item.getInt("score");
        topPlayers.add(new TopPlayer(name, score));
    }
}


// ==================== PARSE DO ESTADO DO JOGO ====================
// Formato: P,Nome,x,y,angulo,massa,score|P,...|O,F/V,x,y,raio|O,...
void parseGameState(String msg) {
  players.clear();
  objects.clear();

  String[] parts = split(msg, '|');           // separa pelo símbolo '|'
  for (String p : parts) {
    if (p.length() == 0) continue;
    String[] d = split(p, ',');               // cada parte separada por ','
    if (d.length == 0) continue;

    if (d[0].equals("P") && d.length >= 6) {
      // Jogador → 6 campos: P,Username,x,y,angle,mass,score
      String name = d[1];
      float x = float(d[2]);
      float y = float(d[3]);
      float angle = float(d[4]);
      float mass = float(d[5]);
      int score = int(d[6]);
      players.add(new PlayerInfo(name, x, y, angle, mass, score));
    } else if (d[0].equals("O") && d.length >= 5) {
      // Objeto → 5 campos: O,Tipo(F/V),x,y,raio
      String type = d[1];          // "F" = food, "V" = poison
      float x = float(d[2]);
      float y = float(d[3]);
      float size = float(d[4]);    // raio do objeto
      objects.add(new ObjectInfo(type, x, y, size));
    }
  }
  println("Jogadores: " + players.size() + "  Objetos: " + objects.size());
}

// ==================== INPUT DO TECLADO ====================
void keyPressed() {
  if (state == 0) {
    // ---------- ECRÃ DE LOGIN ----------
    if (key == ENTER || key == RETURN) {
      if (terminalBuffer.length() > 0) {
        // Extrai o username se for comando LOGIN:username:password
        String[] loginParts = split(terminalBuffer, ':');
        if (loginParts.length >= 2 && loginParts[0].equals("LOGIN")) {
          myUsername = loginParts[1];
        }
        c.write(terminalBuffer + "\n");
        println("Enviado: " + terminalBuffer);
        terminalBuffer = "";
      }
    } else if (key != CODED) {
      terminalBuffer += key;       // acumula caracteres digitados
    }
  } else if (state == 2) {
    // ---------- DURANTE O JOGO ----------
    // Ativa flags (o envio real é feito no draw())
    if (key == 'w' || keyCode == UP)    forwardFlag = true;
    if (key == 'a' || keyCode == LEFT)  leftFlag = true;
    if (key == 'd' || keyCode == RIGHT) rightFlag = true;
  }
}

void keyReleased() {
  if (state == 2) {
    // Desativa as flags quando a tecla é solta
    if (key == 'w' || keyCode == UP)    forwardFlag = false;
    if (key == 'a' || keyCode == LEFT)  leftFlag = false;
    if (key == 'd' || keyCode == RIGHT) rightFlag = false;
  }
}

// ==================== ECRÃ DE LOGIN ====================
void drawLoginScreen() {
  textAlign(CENTER);
  fill(255);
  text("ECRÃ DE LOGIN", width/2, height/2 - 40);
  text("Digita o comando (ex: LOGIN:Alice:123)", width/2, height/2);
  fill(255, 0, 0);
  text(serverMsg, width/2, height/2 + 40);    // mensagem de erro
  fill(255);
  text(terminalBuffer, width/2, height/2 + 80); // mostra o que estás a escrever
}

// ==================== ECRÃ DE FILA DE ESPERA ====================
void drawQueueScreen() {
    textAlign(CENTER);
    fill(255, 255, 0);
    text("NA FILA DE ESPERA...", width/2, 50);
    text("À espera de jogadores (mínimo 3)...", width/2, 70);
    
    fill(255);
    text("Top de pontuações:", width/2, 110);
    for (int i = 0; i < topPlayers.size(); i++) {
        TopPlayer tp = topPlayers.get(i);
        text(tp.name + "  " + tp.score, width/2, 130 + i * 20);
    }
}

// ==================== ECRÃ DE JOGO ====================
void drawGameScreen() {
  // --- Desenhar objetos (comida = verde, veneno = vermelho) ---
  for (ObjectInfo obj : objects) {
    if (obj.type.equals("F")) {
      fill(0, 255, 0);                // verde para comida
    } else {
      fill(255, 0, 0);                // vermelho para veneno
    }
    noStroke();
    ellipse(obj.x, obj.y, obj.size * 2, obj.size * 2);  // círculo com diâmetro 2*raio
  }

  // --- Desenhar jogadores ---

  players.sort((p1, p2) -> Float.compare(p1.mass, p2.mass)); // desenhar o gajo pequeno pro grande naqueles pique
  for (PlayerInfo p : players) {
    pushMatrix();
    translate(p.x, p.y);              // move o sistema de coordenadas para o centro do jogador

    // Raio visual = sqrt(mass / PI)  --> igual à hitbox real do servidor
    float r = (float)(Math.sqrt(p.mass / Math.PI));

    fill(0);
    // Borda azul para o próprio, vermelha para os outros
    if (p.name.equals(myUsername)) {
      stroke(0, 0, 255);              // azul
    } else {
      stroke(255, 0, 0);              // vermelho
    }
    strokeWeight(2);
    ellipse(0, 0, r * 2, r * 2);      // desenha o círculo do jogador

    // Linha de direção (indica para onde o jogador está virado)
    rotate(p.angle);
    stroke(255);                       // branca
    line(0, 0, r, 0);

    // Nome e pontuação (desenha fora da rotação)
    rotate(-p.angle);
    fill(255);
    textAlign(CENTER);
    text(p.name, 0, -r - 5);           // nome por cima do círculo
    text("Score: " + p.score, 0, r + 12); // score por baixo

    popMatrix();
  }
}

// ==================== CLASSES DE DADOS ====================
class PlayerInfo {
  String name;
  float x, y, angle;
  float mass;
  int score;

  PlayerInfo(String n, float x, float y, float a, float m, int s) {
    name = n; this.x = x; this.y = y; angle = a; mass = m; score = s;
  }
}

class ObjectInfo {
  String type;   // "F" (food) ou "V" (veneno)
  float x, y, size;  // size = raio do objeto

  ObjectInfo(String t, float x, float y, float s) {
    type = t; this.x = x; this.y = y; size = s;
  }
}

class TopPlayer {
    String name;
    int score;
    TopPlayer(String n, int s) { name = n; score = s; }
}
