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
  - Para checar visual/composição (tamanho, Y-sort) NÃO dá headless — tem que abrir o editor e dar Play.

## Gotchas de GDScript no 4.7 (já corrigidos, evitar reintroduzir)
- `INFERENCE_ON_VARIANT` é **erro**: `var x := <Variant>` (ex.: `:=` de `clamp()`/`min()`/`Dictionary.get()`/`.global_position` em var tipada `Node`) não compila. Use tipo explícito (`var x: float = clamp(...)`) ou variante tipada (`clampf`).
- Métodos de instância não podem ser chamados estaticamente: `Color.lerp(a,b,t)` → `a.lerp(b,t)`.
- 4.7 adicionou built-ins (ex.: `CanvasItem.draw_ellipse_arc`) que colidem com métodos custom de mesmo nome → renomear o custom.
- Indentação: tudo com **tabs** (1 por nível).

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

### Player = sprite sheet de guaxinim (pixel art)
- Fonte: `assets/external-sprites/racoon.png` (1408×768, `.gdignore` — fonte bruta).
- Fatiador re-rodável: `tools/slice_raccoon.gd` → 30 frames em `assets/sprites/player/`
  (`idle/walk` SE/SW/NE + `attack` SE/SW; idle SW/NE reusa walk[0]). Remove fundo azul, separa frames pelo corpo (ignora a garra amarela), canvas fixo 124×110 (center-x, base nos pés).
  Rodar: `& "<console exe>" --headless --path godot_game -s res://tools/slice_raccoon.gd`
- `Player.gd` usa AnimatedSprite2D em **4 direções isométricas** (NW = NE espelhado), filtro NEAREST (pixel art), pés ancorados (`_setup_sprite`/`_update_sprite`/`_iso_dir`).

## Trabalho recente (log)
1. Compatibilidade Godot 4.7 (type-inference, `Color.lerp`, `draw_ellipse_arc`, indentação) — commitado.
2. Pipeline de assets + arte vetorial flat pra mobs/recursos/estruturas/itens/UI — commitado.
3. Hitbox de árvore(tronco)/pedra + atravessar arbusto/grama + **Y-sort** (profundidade) — commit `ed9a64d`.
4. Player substituído pelo **guaxinim** (sheet fatiado, 4 direções) — commit `2980d43`.

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
