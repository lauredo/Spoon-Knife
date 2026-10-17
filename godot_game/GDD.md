# GDD — Guaxinim na Cidade (documento-mestre)

> **Este é o documento de design vigente.** Consolida o brief completo do jogador (2026-06-25), as
> decisões do [MUNDO.md](MUNDO.md) (formato do mundo/pivô de tema) e do [MVP.md](MVP.md) (o loop,
> histórico). Onde houver conflito, **vale o GDD**.

## Conceito

Survival RPG **2.5D top-down** (referências: Core Keeper, Don't Starve, Project Zomboid — gráficos
mais simples). Você é um **guaxinim** numa grande cidade costeira. Começa numa pequena mata na
periferia e sobrevive com o que encontrar. O foco: **sentir-se um animal num mundo dominado por
humanos** — pequeno, oportunista, por baixo.

**Sem fim** (não há vitória; placar = dias sobrevividos). O que dá direção são as **missões**, e o
que dá profundidade é o **gradiente da cidade** (abaixo).

## O princípio organizador: GRADIENTE DE PRESENÇA HUMANA *(travado 2026-06-25)*

A dominância humana é **espacial**, não temporal. Um mapa, dois jogos:

| Zona | Estado | Perigo | Gameplay |
|---|---|---|---|
| **Centro / Subúrbio** | vivos, iluminados, patrulhados | humanos, guardas, exterminadores | **furtividade** — roubar sem ser visto |
| **Industrial / Favela / Esgoto** | abandonados, escuros | bichos ferais, sombras | **horror** — sanidade drena, luz importa |
| **Porto / fronteiras** | meio-termo | ambos | transição |

- Luz elétrica = segurança contra bichos **mas** exposição a humanos.
- Comida boa mora no **vivo** (roubo furtivo); material mora no **morto** (saque no escuro).
- O antigo "apagão global permanente" (MUNDO.md) é **substituído** por: zonas mortas são
  permanentemente escuras (a versão espacial do apagão) + **apagões locais** como evento (um
  quarteirão vivo perde luz por uma noite = janela de saque + terror temporário).
- Futuro: fronteiras dinâmicas (humanos reconquistam/abandonam bairros conforme ações do jogador).

## Mundo

**Formato:** faixa costeira 18.000px (mata → cidade → mar), quarteirões ~1.400px, prédios andáveis
(~200-400px) com **teto-que-some** (interiores no mesmo mundo; travado). Maré regida pela **lua**
(sizígia abre a Orla a pé; travado). Balsa = portão do late-game + upgrade de velocidade.

**Bairros são FAIXAS; lugares grandes são PRÉDIOS-ÂNCORA** *(decisão de escopo)*: os "13 bairros" do
brief viram 6-7 faixas + âncoras + 1 subsolo — mesma variedade, um terço do custo.

| Faixa | Presença humana | Recursos | Âncoras (landmarks c/ interior) |
|---|---|---|---|
| **Mata / Parque** (spawn, toca) | nenhuma | madeira, comida natural, caça | Zoológico (borda), Árvore Anciã |
| **Subúrbio** | média (gradiente p/ centro) | lixeiras, quintais, utensílios | Hospital (borda c/ Centro) |
| **Centro** | ALTA — furtividade | a melhor comida, itens raros | Supermercado, Shopping, Restaurante, Universidade |
| **Favela** | baixa/abandonada | sucata, tecido, segredos | — |
| **Industrial / Ferro-velho** | abandonada — horror | metal, vidro, componentes | Ferro-velho (arena) |
| **Porto / Orla alagada** | abandonada + maré | loot raro, pesca | Torre alagada |
| **Esgoto** (subsolo, entra por bueiros) | nenhuma — horror denso | cogumelos, segredos, atalhos | covil do Jacaré |

## Sobrevivência (stats — entram em FASES; barra nova só se criar decisão)

| Fase | Sistema | Nota |
|---|---|---|
| ✅ hoje | **Vida · Fome · Sanidade** | sanidade FICA (diferencial-horror; brief a omitia) |
| S5a | **Energia+Sono (1 sistema)** | energia cai com esforço; dormir na toca restaura mas queima tempo — decisão real |
| S5b | **Temperatura** | pega carona no clima existente (chuva molha → frio → fogueira seca) |
| S5c | **Condições** (doenças+ferimentos, 1 sistema) | comida crua/estragada → doença; briga → sangramento; usa bandagem/pomada existentes |
| talvez | Sede | só se não virar "fome nº 2"; cantil/bebedouros/poças de chuva |

Teto de barras visíveis: **5**. Mais que isso = micromanutenção (lição PZ).

## Furtividade (novo sistema — núcleo do Centro; desenhar no slice 2b)

Detecção por **visão + ruído**, modificada por luz/noite/esconderijo (arbusto, lixeira, sombra).
Visto → alerta → perseguição/vassourada. Guaxinim não luta com humano de igual: **foge, se esconde,
distrai** (jogar objeto). Simples primeiro: círculo de detecção com modificadores; cones depois.

## Combate (simples e divertido; armas improvisadas)

Mordida/garras (base) · pedras/paus · lança improvisada · **estilingue** (ranged barato) ·
armadilhas · **bombas caseiras** (o carvão já espera por isso). Inimigos por zona: cães/gatos/ratos/
pombos (vivo+morto), humanos/guardas/exterminadores (vivo), ferais/sombras (morto).

## Chefes — moram em LUGARES, largam DROPS ÚNICOS *(travado)*

Cada um com lore, arena, padrões, fraqueza, recompensa única. Roster inicial (1 por região):

| Chefe | Onde | Sabor |
|---|---|---|
| **Cachorro Alfa** | Ferro-velho | matilha, arena de sucata |
| **Jacaré do Esgoto** | Esgoto | água rasa, escuridão |
| **Exterminador Veterano** | Centro | "chefe de furtividade" — caçada invertida |
| **Urso fugitivo do Zoo** | Zoológico | tanque, força bruta |
| **Chef Enlouquecido** | Restaurante (Centro) | cozinha como arena, fogo |

## Missões *(travado: são a estrutura de objetivo do jogo sem fim)*

Dadas pela **colônia de guaxinins** (painel via CrowTrader, o corvo — sem árvore de diálogo). Corrente:
**missão → lugar → chefe → drop único → missão mais funda.** Tipos: investigação, furtividade,
exploração, puzzle ambiental, sobrevivência, **escolhas com consequência**. "Múltiplos finais" =
**questlines têm finais** (permanentes no mundo); o jogo não acaba.

## Progressão (sem classes fixas)

Equipamentos + **melhorias da toca** (base = logística: postos avançados) + receitas desbloqueadas +
**reputação** (colônia/NPCs → preços, missões, áreas) + **perks em marcos** (escolha A-ou-B ao
atingir marcos; evita grind de skill-por-uso) + novas áreas pela geografia (balsa/maré/esgoto).

## NPCs

Colônia (missões, toca), comerciante ✅, mestres (ensinam receitas), vendedor de mapas (revela
regiões no mapa), humanos como AMBIENTE/ameaça — não conversáveis.

## Loop

explorar → coletar → **roubar comida** → sobreviver → construir → evoluir → missões → chefes →
desbloquear regiões → repetir.

## Diretrizes (do jogador — valem pra tudo)

Diversão > realismo · mecânicas que conversam · progressão constante · exploração recompensadora ·
liberdade · decisões interessantes · baixa repetição · sistemas modulares. Toda mecânica proposta
explica: objetivo / como funciona / interações / anti-repetição / futuro. **Crítica às próprias
sugestões sempre.**

## Roadmap (continua os slices; cada um validado)

- **S2a — Saque** ✅ *(2026-06-25)*: contêineres (lixeira/geladeira/armário/prateleira) com loot por
  zona + esgotamento permanente; ratos como ameaça de interior; itens urbanos (pizza velha, rosquinha,
  enlatado, sucata, pano, coisa brilhante) com usos imediatos (bandagem de pano, faca de sucata,
  troca de brilhante).
- **S2b — Humanos + furtividade v0** ✅ *(2026-06-25)*: 44 humanos patrulham Residencial/Comercial
  **de dia** (à noite vão pra casa — a janela de roubo). Cone de visão desenhado no chão + line of
  sight física (parede/árvore/muro bloqueiam a vista); vasculhar contêiner faz barulho → investigam
  ("?"); vistos → perseguem e batem ("!"); muito feridos → fogem. Mais lentos que o guaxinim correndo.
- **S3 — Lua + maré + apagão** ✅ *(2026-06-25)*: ciclo lunar de 8 dias (dia 2 = cheia, junto da Lua
  de Sangue); 2 marés/dia com amplitude pela fase — sizígia abre a Orla A PÉ, quadratura não; maré
  subindo afoga quem ficar (a armadilha). 118 postes nos distritos vivos (poça de luz = santuário de
  sanidade): noite 1 todos, noite 2 metade morre, noite 3+ blackout eterno. Lua + seta de maré no
  relógio do HUD. Boss agendado REMOVIDO (B de debug fica); morte mostra dias sobrevividos.
- **S4 — Missões + chefes** ✅ *(2026-06-25; Esgoto adiado)*: quadro de missões na colônia (corrente
  autoral: Despensa → Alfa → Jacaré, cada uma mais longe — a última exige a balsa); rastreador no HUD;
  2 chefes-de-lugar com covis descobríveis: **Cachorro Alfa** (fim oeste da estrada, invoca a matilha,
  sem aura) e **Jacaré** (caverna da Ilha, aura de pavor). Drops únicos = VERBOS: **Colar do Alfa**
  (cães te ignoram) e **Escama do Jacaré** (você nada; balsa segue mais rápida).
- **S5 — Stats novos** ✅ COMPLETO *(2026-08-07)*: energia/sono ✅ + temperatura ✅ + condições ✅.
  **Temperatura** (5ª e ÚLTIMA barra visível — teto do GDD respeitado): deriva para um alvo
  contextual (dia 70 / noite 45; chuva −28 ao relento; teto de prédio +12 e anula a chuva; fogo/
  tocha domina em 92, esquenta 2× mais rápido; nadar despenca para 12 e esfria rápido — a escama
  do Jacaré tem custo real, a balsa segue superior). Abaixo de 25 = **Congelando**: −5 vida/min.
  **Condições** (estados discretos com ÍCONES ao lado do painel, não uma 6ª barra): **Sangrando**
  (mordida de mob: 15% de chance, 30% para rato/barata; −10 vida/min por 90s; QUALQUER remédio
  estanca), **Enjoado** (carne estranha 35% / pizza velha 20%; energia e fome drenam mais por 120s;
  só a POMADA cura — papéis distintos pros dois remédios), **Congelando** (vem da temperatura).
  Desconforto (frio/sangramento) interrompe o sono. Tudo persiste no save; avisos pedagógicos ao
  ganhar cada condição. **Energia/Sono** *(2026-08-07,
  decisões travadas pelo usuário)*: 4ª barra; drena 12/min acordado + custo por golpe (0.5) e
  esquiva (1.5); comida devolve um pouco (20% da fome restaurada). Recupera DORMINDO (cama da toca
  de graça no spawn + **Cama de Panos** craftável: pano 4 + grama 4): o tempo corre **4× sem pular
  a noite** — dano, qualquer tecla ou barra cheia acordam (sombras/lua de sangue podem morder a
  soneca — emergente). Zerou = **exaustão**: −30% velocidade e golpes 35% mais lentos até dormir.
  Persiste no save. Temperatura e condições ficam para depois.
- **S6 — Progressão** ✅ COMPLETO *(2026-08-07)*: **Perks por marcos** (nunca grind de skill — lock
  do GDD): 7 perks por marcos variados (sobreviver d3/d7, 10 caças, 50 recursos, 20 saques, 3 sonos,
  1ª ilha) com efeitos passivos (−10% dano recebido, −25% sanidade no escuro, +10% dano, +20% em
  recursos, 25% de loot extra, −15% energia, +15% balsa); estrela "⭐ Perks: N/7" no HUD com tooltip
  (desbloqueadas + marcos pendentes); por-run (permadeath), persiste no save. **Reputação com a
  colônia**: 0–100 (começa 10); +15 por missão, +2 por troca, −10 por machucar guaxinim da colônia;
  níveis Estranho → Conhecido (25) → Amigo da Colônia (60) destravam 4 ofertas extras do corvo
  (mostradas trancadas com 🔒 — o jogador VÊ o que a confiança compra); exibida no menu de trocas;
  persiste no save. + ~~renomeação temática~~ ✅ *(renomeação feita 2026-08-06)*:
  título honesto **"Guaxinim — Noites de Muriqui"** (project.godot/menu/export/CI); TODOS os nomes de
  item em pt-BR (ids congelados p/ compatibilidade de save; load agora descarta ids órfãos); Ham Bat
  FORA → **Taco de Beisebol** (mesmo tier 59dmg/100dur, madeira 3 + corda 1, ícone novo); aranhas →
  **baratas gigantes** (BarataMob + sprites marrons novos; seda→Carapaça, glândula→Gosma de Barata,
  Armadura de Carapaça); tribo de coelhos → **colônia de guaxinins** (ColonyRaccoon com máscara/cauda
  anelada) com **corvo mercador** (CrowTrader; ele já trocava coisa brilhante); UI 100% pt-BR
  (Criação/Mochila/categorias/fases do dia traduzidas só na exibição — chaves internas intactas).
  Perks/reputação AINDA PENDENTES.
- **Pacote de UX** ✅ *(2026-08-06)*: pilha de notificações (até 4 simultâneas, dedupe — antes se
  sobrescreviam); sanidade legível (aviso pedagógico no 1º cruzamento do limiar, popup "+10 sanidade"
  ao golpear sombra via FloatText, aviso 1×/noite quando a drenagem no escuro começa); tooltips ricos
  em todo slot (nome + efeitos via ItemDatabase.tooltip + dica de ação esquerdo/direito); clique
  esquerdo em armadura na mochila agora VESTE (igual hotbar; antes ia pro hotbar); legenda no mapa
  (Você/Fogueira/Colônia/Ponto de interesse); slider "Brilho noturno extra" nas Configurações
  (0% = visual desenhado, 100% = −50% de escuridão; persiste em settings.cfg).
- **Pacote de perigo** ✅ *(2026-08-07)*: (1) **Caranguejos Gigantes** nas ilhas (5 na grande / 3 na
  pequena; territoriais presos ao território como os cães; o casco absorve 40% do dano; pinça de 24;
  dropam carne + carapaça — 2ª fonte de quitina; a aproximação da caverna do Jacaré fica limpa);
  (2) **preço do saque noturno** — vasculhar contêiner à noite drena 8 de sanidade (4 perto de luz),
  com aviso pedagógico: o próprio sistema de horror é o custo, sem mecânica nova; (3) **Vigilância
  (heat)** — ser AVISTADO por humano soma +15 numa barra global 0-100 que decai 12/min e persiste no
  save; ≥30 = "alertas", ≥60 = "CAÇADA" (humanos até +25% de visão e +20% de velocidade; o cone
  desenhado no chão cresce junto — a furtividade continua legível).
- **Depois**: pass de arte 2.5D (o tema já validado em placeholder), estilingue/armadilhas/bombas,
  âncoras restantes, fronteiras dinâmicas.

## Decisões travadas (herdadas + novas)
2.5D isométrico fixo, arte pintada (depois) · sem fim, placar em dias · sanidade fica · lua rege a
maré · interiores híbridos teto-que-some · chefes de lugar c/ drops únicos · missões pela colônia ·
**gradiente de presença humana** · bairros=faixas, lugarões=âncoras, esgoto=subsolo · stats em fases
c/ teto de 5 barras · perks em marcos (não classes, não grind-por-uso).

## Em aberto
Ritmo exato do ciclo lunar · densidade de quarteirões · qual ameaça mora nos interiores comuns ·
detalhes de detecção (furtividade) · lista final de drops únicos por chefe.
