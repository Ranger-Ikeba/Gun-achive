ВАЖНО: этот скрипт НЕ трогает project.godot (чтобы не сломать твой проект).
Сделай вручную 3 вещи в Godot:

1. Project -> Project Settings -> Application -> Run -> Main Scene
   поставь: res://scenes/main.tscn
   (если не хочешь терять текущую главную сцену — просто открывай
    scenes/main.tscn и жми F6 для запуска этой сцены)

2. Project -> Project Settings -> Input Map
   добавь действия (Add New Action) и привяжи клавиши:
     move_forward  -> W
     move_back     -> S
     move_left     -> A
     move_right    -> D
     jump          -> Space
     shoot         -> ЛКМ (Mouse Button 1)
   (ui_cancel и ui_accept уже есть в Godot по умолчанию: Esc и Enter/Space)

3. Project -> Project Settings -> Layer Names -> 3D Physics
   layer_1 = world
   layer_2 = player
   layer_3 = hitbox

Готово. Открой scenes/main.tscn и жми F6.
