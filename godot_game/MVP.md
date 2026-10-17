# MVP — "3 Noites" (DOC HISTÓRICO — superado pelo GDD.md; o jogo hoje é "Guaxinim — Noites de Muriqui")

> Guaxinim faz coisas de gente pra sobreviver na natureza. Conforme **fome** e **sanidade**
> despencam, o mundo fofo dá lugar a **monstros de terror**. Sobreviva **3 dias** e derrote o
> que vem na **3ª noite**.

## Pilares
- **Sobreviver** · **Construir** (base mínima) · **Explorar**
- Camada de **terror dirigida por fome/sanidade** (o gancho — fofo virando assustador).

## Condições
- **Vitória:** derrotar o boss da 3ª noite.
- **Derrota:** vida chega a 0 (fome/dano/monstros).

## Loop central (sessão de ~3 dias)
explorar → coletar (madeira/grama/flint/comida) → craftar (machado, fogueira, tocha) →
gerenciar fome/sanidade/vida → sobreviver à noite (luz + fugir/lutar) → repetir → **boss na noite 3**.

## Já existe (reaproveita — a lógica porta pra 2.5D)
Movimento/ataque/dodge · stats (vida/fome/sanidade com decaimento) · ciclo dia-noite ·
coleta (árvore/pedra/arbusto/grama) · inventário + hotbar + mochila · crafting ·
mobs (javali/aranha) · fogueira/baú · escuridão + luz (fake) · game over + restart ·
guaxinim segura o machado.

## Must-have pra FECHAR o loop (o que falta)
1. **Comer** — ligar `PlayerStats.eat()` (existe, ninguém chama) → restaura fome. *(buraco crítico)*
2. **Terror por sanidade** *(gancho)* — sanidade baixa faz surgir inimigos-sombra que caçam o
   player; somem com sanidade alta/luz. Versão mínima: 1 tipo.
3. **Noite perigosa** — sem luz à noite, algo ataca (mobs + sombras); fogueira/tocha protege.
4. **3 dias + boss da noite 3 + tela de vitória** — contador de dias, evento de boss, win state.
   *(arte placeholder: reusar mob escalado)*
5. **Base mínima** — colocar fogueira + baú já cobre "construir" no MVP.

## Cortar / depois (não-MVP)
Sobrevivência sem fim · múltiplos bosses / boss final · base-building profundo (paredes, fazenda) ·
frio/estações/biomas/mundo grande · árvore de tech ampla · polimento de arte além do necessário.

## Ordem de implementação
- **Fase 0** — comer comida *(fecha o buraco do loop)* ← EM ANDAMENTO
- **Fase 1** — terror/sanidade + noite perigosa *(o gancho)*
- **Fase 2** — 3 dias + boss + tela de vitória
- **Fase 3** — jogar e ajustar números (decaimento, dano, spawns) → **validar se é divertido**
- **Fase 4** — migração **2.5D** (spike → portar lógica → assets pintados de IA + luz real)
- **Fase 5** — polish (arte, juice, som)

## Decisões travadas
- **Estilo final:** 2.5D estilo Don't Starve — billboards 2D **pintados** (não-pixel), gerados por **IA**.
- **Câmera:** ortográfica em ângulo **isométrico fixo** (sem rotação).
- **Sequência:** fechar o loop no engine atual (rápido, ~zero arte nova), validar diversão, e só
  então migrar pra 2.5D (a lógica é engine-agnóstica e porta quase inteira).
