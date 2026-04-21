float x, y;          // Posição do jogador
float vx, vy;        // Velocidade
float r = 20;        // Raio do jogador
float speed = 5;     // Velocidade de movimento

void setup() {
  size(800, 600);
  x = width/2;
  y = height/2;
}

void draw() {
  background(30);
  
  // 1. Capturar inputs (Movimento Tangencial Nativo)
  updateVelocity();
  
  // 2. Aplicar a velocidade à posição
  x += vx;
  y += vy;
  
  // 3. Restrição de Fronteira (Clamping)
  // Subtraímos/Somamos o raio 'r' para que a borda do círculo respeite o limite,
  // e não apenas o seu centro.
  x = constrain(x, r, width - r);
  y = constrain(y, r, height - r);
  
  // 4. Desenhar o jogador
  fill(0, 200, 255);
  noStroke();
  ellipse(x, y, r*2, r*2);
}

void updateVelocity() {
  vx = 0;
  vy = 0;
  
  if (keyPressed) {
    if (key == 'w' || keyCode == UP)    vy = -speed;
    if (key == 's' || keyCode == DOWN)  vy = speed;
    if (key == 'a' || keyCode == LEFT)  vx = -speed;
    if (key == 'd' || keyCode == RIGHT) vx = speed;
  }
}