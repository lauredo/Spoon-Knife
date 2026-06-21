# Survival Craft — Contexto do Projeto (handoff entre sessões)

Top-down survival game (estilo Don't Starve) em **Godot 4.7**, GDScript. Projeto em
`godot_game/`. Este doc resume o estado atual, como rodar/validar, a arquitetura e o
pipeline de arte, pra continuar em outra sessão.

## Engine & validação
- **Godot 4.7 NÃO está no PATH.** Binário (note o .exe dentro de pasta `...exe`):
  - Editor: `C:\Users\lexxo\Desktop\click\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe`
  - Console (use pra checagem headless, escreve no stdout): `...\Godot_v4.7-stable_win64_console.exe`
- **Rodar/validar headless** (PowerShell), a partir de `godot_game/`:
  - Importar assets novos: `& "<console exe>" --headless --path godot_game --import`
  - Smoke test (carrega Main.tscn, roda N frames): `& "<console exe>" --headless --path godot_game --quit-after 200` → exit 0 e sem `SCRIPT ERROR`/`ERROR` = ok.
- **Gotchas de validação headless:**
  - Scripts `class_name` só são type-checked por completo quando instanciados — um smoke test de startup pode NÃO pegar erro em `DropItem`/`Campfire` (só instanciam em runtime). Para compilar tudo, use um script `extends SceneTree` que dá `load()` em cada `res://scripts/*.gd`.
  - `--check-only --script X` compila isolado SEM autoloads → falso "Identifier not found: ItemDatabase/GameManager/Assets". Não confie nisso; use `load()` num SceneTree rodando, ou o smoke test.
  - **Checagem VISUAL** (cor/composição/Y-sort): headless não renderiza, mas dá pra capturar o
    jogo de verdade rodando **com janela** (GPU). Ferramenta: `tools/screen_cap.gd` — registra
    como autoload temporário (`ScreenCap="*res://tools/screen_cap.gd"` em `[autoload]`), roda o
    **gui exe** (sem `--headless`): `& "<gui exe>" --path godot_game --quit-after 600`. Ele espera
    ~1.2s, salva `user://terrain_shot.png` (printa o caminho absoluto: `app_userdata/<nome>/...`)
    e dá quit. Ler o PNG. **Remover o autoload depois** (senão o jogo fecha sozinho a cada run).

## Gotchas de GDScript no 4.7 (já corrigidos, evitar reintroduzir)
- `INFERENCE_ON_VARIANT` é **erro**: `var x := <Variant>` (ex.: `:=` de `clamp()`/`min()`/`Dictionary.get()`/`.global_position` em var tipada `Node`) não compila. Use tipo explícito (`var x: float = clamp(...)`) ou variante tipada (`clampf`).
- Métodos de instância não podem ser chamados estaticamente: `Color.lerp(a,b,t)` → `a.lerp(b,t)`.
- 4.7 adicionou built-ins (ex.: `CanvasItem.draw_ellipse_arc`) que colidem com métodos custom de mesmo nome → renomear o custom.
- Indentação: tudo com **tabs** (1 por nível).
- **Pixel art borrado**: `texture_filter = NEAREST` no nó (ex.: `AnimatedSprite2D` do player) **não
  fez efeito** — caía no default do projeto (Linear) e o guaxinim renderizava borrado. Corrigido
  globalmente: `project.godot [rendering] textures/canvas_textures/default_texture_filter=0` (Nearest).

## Arquitetura
- **Autoloads** (`project.godot [autoload]`, em ordem): `Assets`, `ItemDatabase`, `CraftingSystem`, `GameManager`.
- **Cena principal** `scenes/Main.tscn` (`Main.gd`): `Background` (z -10), `World` (Node2D, **y_sort**), com filhos `Resources/Mobs/Structures/DroppedItems` (todos **y_sort**), `DarknessOverlay` (z 50), `HUDLayer`, `CraftingMenu` (CanvasLayers). O **Player é criado por código** em `Main._spawn_player()` e adicionado ao `World` (sem z_index, pra ser Y-sorted). Não aparece no editor parado — só em Play.
- **Entidades** (`scripts/`): `Player`, `MobBase`+`BoarMob`+`SpiderMob`, `ResourceNode` (TREE/ROCK/BUSH/GRASS_TUFT), `Campfire`, `DropItem`, `HUD`, `CraftingMenu`, `WorldGenerator`. Cenas (`scenes/`) são só root+script; filhos (colisão, áreas, sprites) são criados em `_ready()`.
- **Camadas de física 2D** (`project.godot [layer_names]`): 1=World, 2=Player, 3=Mobs, 4=Resources, 5=DroppedItems, 6=Structures. (bitmask: World=1, Player=2, Mobs=4, Resources=8, Drops=16, Structures=32).
  - Player `collision_mask = 1|4|32`; Mobs `1|2|4|32`.
  - **ResourceNode**: layer 8 (interação). Árvore/pedra TAMBÉM na layer 1 (`8|1=9`) → bloqueiam player/mobs. Arbusto/grama só layer 8 → atravessáveis. Hitbox da árvore = **cápsula vertical do tronco** (base na base do tronco); pedra = círculo.

## Pipeline de arte (como atualizar sprites) — ver também `godot_game/` abaixo
Visuais são **sprites carregados de arquivos**, com **fallback procedural** automático (se faltar arquivo, cai no `_draw()` antigo, sem crash).
- **Fonte**: SVGs editáveis em `assets/_svg_src/<categoria>/...` (pasta tem `.gdignore`). UI em `assets/ui/*.svg` (Godot importa SVG como textura direto).
- **Build (SVG→PNG)**: `& "<console exe>" --headless --path godot_game -s res://tools/build_assets.gd` → rasteriza todo `_svg_src/**.svg` para `assets/sprites/**.png` a 4×.
- **Ícones de item**: `tools/gen_item_icons.gd` gera 1 SVG por item (a partir das cores do `ItemDatabase`); pula os que já existem (não sobrescreve edições).
- **Loader**: autoload `Assets` (`scripts/autoload/Assets.gd`): `item_icon(id)`, `sprite(cat,name)`, `sprite_frames(name, specs)`. Retorna null se faltar (→ fallback). Cache interno.
- **Animados** (player, boar, spider, chama da fogueira): `SpriteFrames` montado em runtime a partir de PNGs `assets/sprites/<name>/<anim>_<i>.png` (sem `.tres`). `flip_h` por direção; flash de dano via `modulate`. Barras de vida/arco de ataque/luz continuam procedurais por cima.
- **Atualizar arte**: edita o SVG (ou troca o PNG direto) e roda `build_assets.gd`. Sem código.
- `*.import` é **gitignored** (Godot reimporta ao abrir); os `.png`/`.svg` são versionados.

### Terreno = sheet de terra isométrica tileada
- Fonte: `assets/external-sprites/ground.png` (1408×768, `.gdignore` — é um *concept sheet*
  com banner/legendas/guaxinim embutidos, **não** dá pra tilear inteiro).
- Gerador re-rodável: `tools/slice_terrain.gd` produz um tile **grande, orgânico e seamless**
  `976×360` → `assets/sprites/terrain/ground.png`. O sheet é um TILESET de losangos isométricos
  (vira uma grade óbvia se tileado cru), então transformamos em terra mosqueada. Pipeline
  (consts tunáveis no topo): (1) crop em períodos casados por borda (`BASE_W=976`, `BASE_H=360`);
  (1b) **achata o gradiente vertical** de brilho (topo é mais escuro); (2) *texture bombing* —
  ~8 patches de outras regiões (mesma fase ~140×90px) p/ variar pedras/tom; (2b) **domain warp**
  (`FastNoiseLite`) desloca os pixels → as emendas retas dos losangos viram linhas orgânicas
  irregulares (mata a grade); (2c) levanta as emendas escuras restantes pro tom local; (2d) **tone**
  — levanta o preto, clareia e esquenta (`TONE_*`) pra virar terra seca, não lama/pântano (a saída
  do warp vinha escura/fria); + **de-blue** (`DEBLUE`) converte as pedras azuis frias do sheet em
  marrom (não faziam sentido como terra); (3) seamless cruzando as bordas opostas. Rodar: `& "<console exe>"
  --headless --path godot_game -s res://tools/slice_terrain.gd` (depois `--import`).
  **Validado por screenshot real** (ver `screen_cap.gd` acima), não só por simulação de tiling.
- `Main._setup_background()` carrega `Assets.sprite("terrain","ground")` e desenha um
  `Sprite2D` tileado (`texture_repeat=ENABLED`, `region_rect` cobrindo o mundo, NEAREST,
  z -9) sobre um `ColorRect` de base marrom. Se faltar a textura → fallback verde+patches.
  Tunáveis: `TERRAIN_SCALE` (0.85, tamanho do losango vs. player) e as consts em `slice_terrain.gd`
  (`PATCH_ALPHA`/`PATCHES` p/ variação, `SEAM_BLEND` p/ a costura, `BASE_*` p/ o crop).

### Player = sprite sheet de guaxinim (pixel art)
- Fonte: `assets/external-sprites/racoon.png` (1408×768, `.gdignore` — fonte bruta).
- Fatiador re-rodável: `tools/slice_raccoon.gd` → 30 frames em `assets/sprites/player/`
  (`idle/walk` SE/SW/NE + `attack` SE/SW; idle SW/NE reusa walk[0]). Remove fundo azul, separa frames pelo corpo (ignora a garra amarela), canvas fixo 124×110 (center-x, base nos pés).
  Rodar: `& "<console exe>" --headless --path godot_game -s res://tools/slice_raccoon.gd`
- `Player.gd` (`_setup_sprite`/`_update_sprite`): AnimatedSprite2D **front (SE) / back (NE) +
  flip horizontal**. Esquerda/direita/baixo = arte de frente (`se`), espelhada p/ esquerda
  (`flip_h = facing.x < 0`); **costas (`ne`) só quando subir é a direção dominante** (`facing.y < 0
  and |y| > |x|`). Walk vs idle vem do flag `is_moving` (do INPUT, não de `velocity.length()` — a
  velocidade pós-`move_and_slide` oscilava e fazia o idle piscar no meio da caminhada). `attack_se`
  é front-only. Filtro de pixel art é global (ver gotcha de `default_texture_filter`). A arte
  `sw`/`nw` fatiada ficou sem uso (a esquerda é só flip).

### Árvore = pixel art (sheet `trees.png`) + efeito de hit
- Fonte: `assets/external-sprites/trees.png` (1991×528, `.gdignore` — concept sheet com HEALTHY
  trees, sequência "RTE" de corte e HIT EFFECTS). Fatiador `tools/slice_trees.gd` (rects por célula,
  keia o fundo navy + bordas/labels cinza, tight-crop) → `assets/sprites/resources/tree.png` +
  `assets/sprites/effects/wood_chips.png` + `leaf_0..5.png` (a célula de folhas é dividida em
  componentes conexos = folhas individuais). **Gotcha**: o key de navy tinha que ser estrito
  (`b > r+14 e b > g+14`) senão comia a sombra verde-escura da folhagem e abria BURACOS na copa.
  Rodar: `-s res://tools/slice_trees.gd`.
- Hit da árvore (`ResourceNode`, só p/ TREE): **(1) sway** — `_process` rotaciona o sprite em torno
  da base do tronco (`_sway_pivot`), oscilação amortecida (amplitude segue `shake_amount`) → a copa
  vibra e a base fica plantada (NÃO move a árvore inteira). **(2) folhas caindo** — `_spawn_hit_effect`
  solta 2–4 `leaf_*` da copa que caem com drift+rotação+fade (tween). Pedra/arbusto = jitter de posição.
- **Câmera**: `Main._setup_camera` agora seta `process_callback = PHYSICS` — a câmera é filha do player
  (que move em `_physics_process`); com o callback idle padrão o smoothing dessincronizava e a tela
  toda tremia ao andar. Validar andando in-game (não dá pra ver tremor em screenshot estático).
- Nota: o "machado flutuando" perto do player é o ÍCONE do item equipado desenhado em `Player._draw`
  (pré-existente, não é da árvore).

## Trabalho recente (log)
1. Compatibilidade Godot 4.7 (type-inference, `Color.lerp`, `draw_ellipse_arc`, indentação) — commitado.
2. Pipeline de assets + arte vetorial flat pra mobs/recursos/estruturas/itens/UI — commitado.
3. Hitbox de árvore(tronco)/pedra + atravessar arbusto/grama + **Y-sort** (profundidade) — commit `ed9a64d`.
4. Player substituído pelo **guaxinim** (sheet fatiado, 4 direções) — commit `2980d43`.
5. Terreno: fundo verde flat → **textura de terra isométrica tileada** (`slice_terrain.gd` +
   `Main._setup_background`). Não commitado ainda.

## Ajustes pendentes / tunáveis (rápidos)
- **Tamanho do player**: `Player._setup_sprite` usa altura-alvo 60px (escala ~0.55). Ajustar o `60.0`.
- **Tamanho de recursos/mobs**: `ResourceNode._sprite_target_height()`; mobs usam `body_radius*3` em `MobBase._setup_sprite`.
- **Y-sort**: player/mobs ordenam pela origem (centro), recursos pela base. Se a troca frente/trás parecer adiantada, dá pra somar um offset de ordenação (~+24px) pros "pés".
- **Arco de ataque amarelo** desenhado por código no `Player._draw` agora sobrepõe a garra do guaxinim (redundante) — pode remover.
- **Contraste de estilo**: player é pixel art; resto é vetor/flat. Considerar pixelizar o resto OU refazer o player em vetor, se quiser uniformizar.
- Estado "esgotado" dos recursos (toco/entulho) ainda é procedural (sem sprite dedicado).

## Git / repo
- Remote: https://github.com/lauredo/Spoon-Knife.git , branch `main` (commits direto na main).
- CI: `.github/workflows/build.yml` instala Godot 4.7 e exporta Web + Android.
- Mensagens de commit terminam com `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
