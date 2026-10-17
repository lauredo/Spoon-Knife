# Guaxinim — Noites de Muriqui

Sobrevivência sem fim como um **guaxinim** em Vila Muriqui, uma cidade litorânea onde as luzes
estão se apagando. Saqueie casas, evite os humanos de dia, aguente as noites (e a lua de sangue),
negocie com o corvo da colônia, construa uma balsa e chegue às ilhas. Criado em **Godot 4**.

> Documentos de design: `GDD.md` (mestre) e `MUNDO.md` (visão do mundo). Este README cobre o
> básico de como rodar e os controles; alguns detalhes de sistemas abaixo podem estar defasados.

## Como Jogar

### Requisitos
- **Godot Engine 4.2+** — [Download em godotengine.org](https://godotengine.org)

### Executar o Jogo
1. Abra o Godot Engine
2. Clique em **Import** e selecione o arquivo `godot_game/project.godot`
3. Pressione **F5** ou clique em **Play** para iniciar

---

## Controles

| Tecla | Ação |
|-------|------|
| `WASD` | Mover o personagem |
| `Click Esquerdo` | Atacar / Coletar recurso |
| `E` | Interagir com objetos próximos |
| `Space` | Rolar / Dodge (invencível durante o dodge) |
| `T` | Abrir/fechar menu de Criação |
| `I` | Abrir/fechar a mochila |
| `M` | Abrir/fechar o mapa |
| `F` | Ciclar item equipado na hotbar |
| `1-6` | Selecionar slot da hotbar |
| `F1` | Menu de debug |
| `R` | Reiniciar (após morrer) |
| `Esc` | Sair |

---

## Sistemas do Jogo

### Sobrevivência
- **Vida** (vermelho): Perde ao ser atacado. Recupera comendo.
- **Fome** (amarelo): Drena constantemente. Chegando a 0, começa a perder vida.
- **Sanidade** (azul): Cai durante a noite e em lugares escuros. Cai muito baixo = efeitos visuais de loucura.

### Ciclo Dia/Noite
- Dia dura ~5 minutos, noite ~1 min e meio.
- À noite a escuridão aumenta e as baratas ficam mais agressivas.
- Construa uma fogueira para afastar a escuridão e manter a sanidade.

### Recursos
| Recurso | Ferramenta | Drops |
|---------|-----------|-------|
| Árvore | Machado | Madeira, Galho, Sementes |
| Rocha | Picareta | Pedra, Sílex |
| Arbusto | Mãos | Frutinhas, Galho |
| Grama | Mãos | Grama, Sementes |

### Crafting (tecla T)
| Item | Ingredientes |
|------|-------------|
| Machado | 2 Galho + 1 Sílex |
| Picareta | 2 Galho + 2 Sílex |
| Tocha | 2 Galho + 2 Grama |
| Corda | 3 Grama |
| Lança | 2 Galho + 1 Sílex + 1 Corda |
| Fogueira | 2 Madeira + 2 Grama + 2 Galho |
| Baú | 6 Madeira + 2 Corda |
| Taco de Beisebol | 3 Madeira + 2 Pano + 1 Corda |

### Mobs
- **Barata Gigante**: Agressiva de longe. À noite fica mais rápida e agressiva. Dropa carapaça, gosma e carne estranha.
- **Javali**: Passivo até ser atacado. Muito resistente e forte. Dropa carne e sementes.
- E mais: ratos, cães de rua, veados, humanos (furtividade), sombras, chefes Alfa e Jacaré.

### Combate
- Ataque com **clique esquerdo** — hit em arco na direção do personagem.
- Ferramentas e armas têm **durabilidade** — consomem com o uso.
- **Dodge** com Space: invencibilidade temporária, cooldown de 1.2s.
- Mobs têm barra de vida visível acima deles.

### Fogueira
- Craft com 2 Madeira + 2 Grama + 2 Galho, ela se coloca automaticamente no mundo.
- Dura 5 minutos de combustível. Pressione **E** perto dela com madeira no inventário para reabastecer.
- Ilumina uma grande área, protegendo a sanidade do jogador à noite.

---

## Arquitetura do Código

```
godot_game/
├── project.godot              # Configuração do projeto Godot
├── scenes/
│   ├── Main.tscn              # Cena principal
│   ├── mobs/
│   │   ├── Barata.tscn
│   │   └── Boar.tscn
│   ├── resources/
│   │   ├── Tree.tscn
│   │   ├── Rock.tscn
│   │   └── Bush.tscn
│   ├── items/
│   │   └── DropItem.tscn
│   └── structures/
│       └── Campfire.tscn
└── scripts/
    ├── autoload/
    │   ├── ItemDatabase.gd    # Banco de dados de itens
    │   ├── CraftingSystem.gd  # Sistema de crafting e receitas
    │   └── GameManager.gd     # Estado global do jogo
    ├── Main.gd                # Scene principal
    ├── Player.gd              # Controle do jogador
    ├── PlayerStats.gd         # Vida, fome, sanidade
    ├── Inventory.gd           # Inventário e hotbar
    ├── MobBase.gd             # Classe base dos inimigos (máquina de estados)
    ├── BarataMob.gd           # Barata gigante (agressiva)
    ├── BoarMob.gd             # Javali (passivo/territorial)
    ├── ResourceNode.gd        # Árvores, rochas, arbustos
    ├── DropItem.gd            # Item dropado no chão
    ├── Campfire.gd            # Fogueira (estrutura)
    ├── WorldGenerator.gd      # Geração procedural do mundo
    ├── DayNightCycle.gd       # Ciclo dia/noite
    ├── HUD.gd                 # Interface do jogador
    └── CraftingMenu.gd        # Menu de crafting
```
