# MUNDO — visão do redesenho (cidade + mar + 2.5D)

> ⚠️ **Superado como fonte de verdade:** o documento-mestre agora é o **[GDD.md](GDD.md)**
> (2026-06-25, brief completo do jogador + gradiente de presença humana). Este arquivo permanece
> como registro das decisões do pivô de mundo; onde conflitar, **vale o GDD** — em particular, o
> "apagão global permanente" foi substituído pelo **gradiente** (zonas mortas são o apagão espacial;
> apagões locais viram eventos).

> Documento-irmão do [MVP.md](MVP.md). O MVP definiu o **loop** (e ele está fechado e validado).
> Este define o **mundo** onde esse loop vai viver de verdade — a identidade que nasce junto com a
> migração 2.5D, em vez de re-vestir a floresta placeholder depois.

## Premissa

> Um **guaxinim** sobrevive numa **cidade costeira tomada pelo mato**. Ele faz o que guaxinim faz:
> **saqueia** casas e restaurantes, arrasta o que acha pra uma **base na borda da floresta**, e
> aguenta a noite — quando **as luzes da cidade se apagam** e o lugar deixa de ser cidade.

Por que isso e não a floresta genérica:
- **O guaxinim vira essencial.** Na mata, o protagonista podia ser qualquer bicho. Na cidade, ele
  *é* a fantasia — o bicho que vira lata, invade cozinha, rouba comida de gente. O tema finalmente
  casa com a premissa original ("guaxinim fazendo coisas humanas").
- **A cidade já é feita de lugares.** Restaurante, casa, posto, escola — cada prédio é um ponto de
  interesse com loot próprio, sem precisar inventar justificativa.
- **Luz vira geografia**, não efeito (ver abaixo).

## Pilares (inalterados)
- **Sobreviver** · **Construir** · **Explorar**
- Terror dirigido por **fome/sanidade** — fofo virando assustador.
- **Vida** e **fome** seguem idênticas. **Sanidade fica** (ver "Decisões").

## Formato do mundo

Nada de fatias radiais (isso era placeholder). O mundo é uma **faixa costeira**: mata numa ponta,
mar na outra, cidade no meio, com **malha de ruas e quarteirões**.

| Distrito | O que tem | Papel |
|---|---|---|
| **Borda Verde** (parque/mata) | árvores, verde, calmo | onde você faz **base**. Spawn. |
| **Residencial** | casas, quintais, latas | loot básico: comida simples, utensílios |
| **Centro Comercial** | restaurantes, mercados | **a melhor comida** — e o maior perigo |
| **Industrial / Ferro-velho** | sucata, metal, vidro | materiais de **construção e armadura** |
| **Orla Alagada** | quarteirões inundados, prédios-ilha | loot raro — **balsa ou maré baixa** |

### Escala — **18.000px**, faixas de ~4.500 *(fechado 2026-06-25)*
Derivada dos números, não escolhida no chute. Player **220 px/s**, dia claro **195s**. Distância vira
tempo, e tempo vira **preparo**:

| Distrito | Dist. da base | Ida a pé | Exige |
|---|---|---|---|
| Residencial | ~4.500px | ~20s | nada — é o quintal, dia 1 |
| Comercial | ~9.000px | ~41s | run de verdade, comida na mochila |
| Industrial | ~13.500px | ~61s | preparo — tocha, armadura |
| **Orla** | ~18.000px | ~82s | **inviável a pé num dia** → balsa e/ou base avançada |

Ida+volta na Orla = 164s dos 195s de luz → **não sobra tempo pra saquear**. Isso não é problema, **é a
mecânica**. Quarteirão ~800–1.200px (prédio andável ~200–400px).

> **Consequência que emerge sozinha:** base-building ganha propósito **logístico** — plantar um
> fogo-no-tambor no Comercial vira **posto avançado**, não decoração.

### A progressão geográfica (a espinha do design)
Loot **não regenera**: casa saqueada fica saqueada. Isso empurra você da Borda Verde pra dentro da
cidade, distrito a distrito, e termina na **Orla**. Ou seja:

> **A balsa é o portão do late-game** — e também **upgrade de velocidade**: a Orla distante vira
> viável exatamente quando você a desbloqueia. Esgotar o perto é o que te obriga a navegar.

## Mecânicas novas / mudadas

**Apagão progressivo (a ideia-âncora) — a QUEDA da cidade, não um clímax.** A cidade começa com
postes acesos = corredores seguros. A rede morre noite a noite, e isso **encaixa nas noites temáticas
que já existem**:
- Noite 1 — a maior parte acesa; ilhas de luz.
- Noite 2 — metade do bairro cai *(hoje: Lua de Sangue)*.
- Noite 3 — **blackout total**.
- **Noite 4+ — permanente.** Não há volta: você vive no cadáver da cidade.

Como o jogo é **sem fim**, o apagão não é um chefe a derrotar — é um **limiar que se cruza e nunca se
desfaz**. As 3 primeiras noites são o **ato de abertura** (a queda); depois o jogo é mais difícil
**pra sempre**, e sobrevivível só porque você se preparou (base, tambores, tocha, armadura). É a
curva de dificuldade que um jogo sem fim precisa — reusando a escalada já construída.

Você **aprende quais ruas ainda têm energia** — o mapa vira conhecimento útil, não enfeite. Usa o
sistema de luz que já existe (CanvasModulate + PointLight2D): poste aceso = PointLight2D que apaga.

**Saque com esgotamento.** Contêiner (lata, geladeira, vitrine) esvazia e fica vazio → pressão de
exploração automática, sem timer artificial.

**Sombras.** Passam a surgir **quando as luzes apagam** — o gatilho vira diegético em vez de abstrato.

**Maré pela LUA — o segundo relógio.** A água sobe e desce e muda o que é andável. Quem manda é a
**fase da lua** — ciclo próprio (gera janelas raras) mas **legível**, porque a lua te conta.
- **Duas altas e duas baixas por dia** (como no mundo real).
- **A fase da lua define a AMPLITUDE:**
  - **Cheia / nova → maré de sizígia:** baixas extremas (a Orla **abre a pé**) e altas extremas.
  - **Quartos → maré de quadratura:** oscilação fraca, Orla só de balsa.
- **Maré baixa:** quarteirão alagado fica a pé — acesso **grátis**, mas é **armadilha** (a maré sobe
  com você lá dentro). **Maré alta:** só de balsa. Logo a balsa não é só acesso, é **acesso em
  qualquer maré** — a diferença entre correr risco e ter controle.
- Você **olha pra lua e planeja** ("cheia em dois dias → dá pra invadir a Orla a pé"). A lua vira
  **atmosfera e interface ao mesmo tempo** — e já tem casa: o relógio circular do HUD.
- Num jogo **sem fim**, o ciclo lunar dá o **ritmo de longo prazo** que os dias sozinhos não dão. E a
  janela de terror nasce sozinha: **maré baixa à noite, depois do blackout** — acesso livre, escuro total.

**Missões — o motor de propósito.** Num jogo **sem fim** não existe "vencer", então as missões são o
que **substitui a condição de vitória**: são elas que apontam pra onde ir. Quem dá é a **colônia de
guaxinins** (reusa o `CrowTrader`, o corvo — ele já é o ponto de contato com a colônia).
- Missões nascem das necessidades reais: *"traga 6 sucatas"*, *"a despensa acabou — ache comida"*,
  *"tem algo no mercado, dá um jeito"*.
- Elas **apontam pra um lugar** → o lugar guarda um **chefe** → o chefe larga um **drop único**.
  Essa é a cadeia que faz o jogo sem fim ter direção:

> **missão → lugar → chefe → drop único → nova missão mais longe.**

E ela casa com a progressão geográfica: conforme o loot perto esgota, as missões te mandam mais
fundo — até a Orla.

**Chefes de lugar + drops únicos.** Não há chefe de calendário. Cada **lugar** importante guarda algo
(o alfa da matilha no ferro-velho, algo no escuro do mercado, o que mora na torre alagada). Derrotar
larga um **item único e útil** — a recompensa que paga a viagem e o único jeito de conseguir aquilo.
Isso transforma exploração em progressão real, sem precisar de árvore de tech.

**Interiores — só nos lugares que importam.** Nem toda casa é entrável. A maioria é cenário com
contêiner na fachada (lata, geladeira numa parede quebrada, vitrine). **Os prédios exploráveis são os
landmarks** → reusa o sistema de POI que já existe e está validado (descoberta + marcador no mapa +
recompensa). Isso entrega a fantasia sem a conta infinita de conteúdo.

- **Como funciona: teto que some.** O interior é parte do **mesmo mundo** — paredes com colisão (o
  `Wall.gd` já prova o padrão), porta, e um telhado que faz fade quando o player entra (Area2D no
  perímetro). **Sem troca de cena, sem teleporte**: inventário, stats, dia/noite, clima e mobs nem
  sabem que você "entrou". *(A alternativa — uma cena por prédio — brigaria com a arquitetura de
  mundo persistente. Descartada.)*
- **Ganho de graça:** a escuridão é um `CanvasModulate` global → **interiores ficam pretos à noite
  sozinhos**. A tocha passa a importar dentro de casa, e a lâmpada do teto é um `PointLight2D` que
  **morre junto com o apagão**. Saquear a casa na noite 1 (luz acesa) ≠ voltar nela na noite 3
  (blackout). De dia entra sol pelo telhado furado — a ruína tomada pelo mato justifica sozinha.
- **Refúgio com preço:** os mobs andam em **linha reta** (sem pathfinding — foi o que travava o
  chefe). A matilha **não acha a porta** e fica rosnando lá fora. Isso é design, não bug: o prédio é
  refúgio — mas lá dentro está escuro, você está sozinho, e a sanidade cai. Interiores precisam de
  **ameaça própria** (ratos, algo no escuro) pra não virar esconderijo grátis.
- **Consequência de escala:** interior andável = **menos prédios e maiores** — um quarteirão tem 4-6
  exploráveis, não 40 casinhas-ícone. Aceito conscientemente.

## De → Para (o motor sobrevive; muda a pele)

| Hoje | Cidade |
|---|---|
| Fogueira | **fogo no tambor** |
| Baú | geladeira / armário |
| Madeira · pedra · flint | árvores no asfalto · **sucata · vidro · concreto** |
| Bagas · carne · cenoura | **pizza velha · rosquinha · enlatado** |
| Cozinhar na fogueira | esquentar (micro-ondas / tambor) |
| Muralha de pedra | tapume · grade · carrinho de compras |
| Lobos | **matilha de cães de rua** |
| Aranhas | ratos / baratas |
| Tribo dos coelhos | **colônia de guaxinins sob o viaduto** |
| Comerciante | **um corvo que troca coisas brilhantes** |
| Biomas | **distritos** |
| Landmarks | os prédios já são |
| Chefe da 3ª noite | *em aberto* — alfa da matilha? controle de zoonoses? algo do escuro |

## O que atravessa vs o que é descartado

**Atravessa (a maquinaria — construída e validada):** stats · dia/noite · **clima** · **noites
temáticas** · iluminação · inventário/hotbar/mochila · craft · IA de mobs (MobBase) · armadura ·
**grade de construção + fantasma** · **mapa com névoa + marcadores** · trocas · descoberta de POIs ·
áudio · menus.

**Descartado:** a geração **radial em setores** (fatias de pizza) e os rótulos/ids temáticos.
Cidade tem quarteirões e ruas — é outro gerador.

> Honestidade de custo: o momento é **o mais barato possível** — ~30 itens, arte 100% placeholder
> procedural, migração ainda não começou. Renomear 30 itens é trivial; renomear 150 com a arte
> pintada pronta, não. Por isso este documento existe **antes** da Fase 4.

## Decisões

**Travadas:**
- Tema: **guaxinim em cidade costeira tomada pelo mato**.
- **Sanidade fica.** Raiva *não* substitui: sanidade é algo que você **protege** (pressão
  defensiva), raiva é algo que você **acumula** (recurso ofensivo) — trocar inverte o pilar. Raiva
  pode entrar **depois, como mecânica adicional** (fúria de guaxinim encurralado).
- Vida e fome inalteradas.
- O **mar é parte do formato do mundo**, não um recurso avulso — nasce com o redesenho.
- Estilo/câmera: mantém o de [MVP.md](MVP.md) — 2.5D, billboards pintados por IA, ortográfica isométrica fixa.
- **Interiores: sim, mas HÍBRIDO** *(fechado 2026-06-25)* — **nem toda casa é entrável**. Fachada pra
  maioria; interior de verdade só nos lugares que importam, e **esses são os landmarks**. Técnica:
  **teto que some** no mesmo mundo (nunca cena separada). Ver "Mecânicas → Interiores".

- **Maré é DINÂMICA e regida pela LUA** *(fechado 2026-06-25)* — ver "Mecânicas → Maré pela Lua".
- **SEM FIM — não há vitória** *(fechado 2026-06-25)*. Placar = **dias sobrevividos**. O apagão da
  noite 3 não é clímax, é **limiar permanente** (ver "Mecânicas → Apagão"). Isso alinha com a visão
  longa do [MVP.md](MVP.md) ("sobrevivência sem fim").
  *Consequência de código:* `GameManager.trigger_victory` / `game_won` / `HUD.show_victory` viram
  código morto → remover na 4b. A tela de morte passa a mostrar os dias sobrevividos.
- **Chefe agendado: ABANDONADO** *(2026-06-25)* — "boss da 3ª noite" sai de cena. **Confirmado no
  lugar dele:** chefes moram **nos lugares** e largam **drops únicos** (ver "Mecânicas → Chefes de
  lugar"). Pagamento/risco da exploração, não evento de calendário.
- **MISSÕES existem** *(fechado 2026-06-25)* — dadas pela colônia; são elas que substituem a condição
  de vitória num jogo sem fim (ver "Mecânicas → Missões"). Cadeia:
  **missão → lugar → chefe → drop único → nova missão mais longe.**
- **Escala: 18.000px**, faixas de ~4.500 *(fechado — ver "Formato do mundo → Escala")*.

**Em aberto (a decidir antes de codar):**
- *(nada bloqueante — as decisões estruturais estão fechadas.)* Afinações que se resolvem testando na
  4b: período do ciclo lunar, densidade de quarteirões, e qual ameaça mora nos interiores.

## Ordem de migração

Substitui a Fase 4 do [MVP.md](MVP.md), que dizia "migrar 2.5D + assets pintados". Agora ela carrega
o tema junto:

- **4a — Fechar este documento** (resolver os itens "em aberto").
- **4b — Re-tematizar no engine atual** (barato, valida o conceito antes da arte):
  renomear itens/ids, trocar `WorldGenerator` radial por **malha de quarteirões + distritos**,
  contêineres saqueáveis, postes de luz com apagão progressivo, e os **primeiros prédios com interior
  (teto-que-some) nos landmarks**. Ainda em placeholder procedural.
- **4c — Playtest do tema** — a cidade é mais divertida que a mata? *(portão: não gerar arte antes disso)*
- **4d — Spike 2.5D** + portar a lógica (que é engine-agnóstica).
- **4e — Assets pintados de IA** com a identidade já definida aqui.
- **4f — Balsa + Orla** (o late-game geográfico).

> A ordem existe pra proteger o investimento: **o tema é validado em placeholder** (barato) antes de
> qualquer arte pintada (caro). Mesma lógica que usamos pro loop no MVP.

## Fora de escopo (por enquanto)
Interior em **todo** prédio · **pathfinding de mobs** (`NavigationAgent2D` — sem ele, prédio/quintal
é refúgio *by design*) · múltiplas cidades · veículos além da balsa · **árvore de diálogo** (missões
são um painel, não conversa) · facções · mecânica de raiva.
