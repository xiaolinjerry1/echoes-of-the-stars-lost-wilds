# 导出资产实测清单

由 `python dev/audit_art_assets.py` 生成。UV 数量表示带 TEXCOORD_0 的 primitive / 总 primitive；不代表 UV 已精修。三角面数按导出索引统计，不是 Blender 原始顶点数。

| GLB | 三角面 | UV | 图片数 | 图片贴图槽（材质合计） | skin / 权重片段 / 动画 |
|---|---:|---:|---:|---|---|
| art/models/boss/boss_sprout.glb | 4020 | 1/1 | 4 | emissiveTexture, normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 1 / 1 / 8 |
| art/models/boss/moss_crown_beast.glb | 5818 | 1/1 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 1 / 1 / 16 |
| art/models/enemy/dread_wyvern.glb | 9224 | 1/1 | 4 | emissiveTexture, normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 1 / 1 / 11 |
| art/models/enemy/forest_mage.glb | 4096 | 1/1 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 1 / 1 / 10 |
| art/models/enemy/forest_shaman.glb | 5464 | 1/1 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 1 / 1 / 11 |
| art/models/enemy/moss_boar.glb | 3794 | 1/1 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 1 / 1 / 10 |
| art/models/enemy/timber_wolf.glb | 3910 | 1/1 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 1 / 1 / 8 |
| art/models/player/frost_edge.glb | 1630 | 1/1 | 4 | emissiveTexture, normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 0 |
| art/models/player/iron_sword.glb | 574 | 4/4 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 0 |
| art/models/player/npc_elin.glb | 4204 | 1/1 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 1 / 1 / 10 |
| art/models/player/npc_glen.glb | 4136 | 1/1 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 1 / 1 / 10 |
| art/models/player/npc_mara.glb | 4204 | 1/1 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 1 / 1 / 10 |
| art/models/player/npc_tom.glb | 4068 | 1/1 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 1 / 1 / 10 |
| art/models/player/npc_wounded_ranger.glb | 3980 | 1/1 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 1 / 1 / 10 |
| art/models/player/warrior_arms.glb | 2712 | 1/1 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 1 / 1 / 13 |
| art/models/prop/camp_forge.glb | 2586 | 1/1 | 4 | emissiveTexture, normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 0 |
| art/models/prop/chest.glb | 2836 | 2/2 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 0 |
| art/models/prop/heal_totem.glb | 888 | 1/1 | 4 | emissiveTexture, normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 0 |
| art/models/prop/herb.glb | 2696 | 1/1 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 0 |
| art/models/prop/storage_crate.glb | 3712 | 1/1 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 0 |
| art/models/prop/wyvern_fireball.glb | 320 | 1/1 | 4 | emissiveTexture, normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 0 |
| art/models/scenery/campfire.glb | 3346 | 4/4 | 5 | emissiveTexture, normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 1 |
| art/models/scenery/creek_bank.glb | 2 | 1/1 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 0 |
| art/models/scenery/creek_water.glb | 2 | 1/1 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 0 |
| art/models/scenery/dungeon_gate.glb | 2156 | 1/1 | 4 | emissiveTexture, normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 0 |
| art/models/scenery/dungeon_pillar.glb | 3368 | 1/1 | 4 | emissiveTexture, normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 0 |
| art/models/scenery/echo_stone.glb | 1180 | 1/1 | 4 | emissiveTexture, normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 0 |
| art/models/scenery/forest_dirt.glb | 2 | 1/1 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 0 |
| art/models/scenery/forest_grass.glb | 2 | 1/1 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 0 |
| art/models/scenery/grass_tuft.glb | 144 | 1/1 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 0 |
| art/models/scenery/hunter_broken_wall.glb | 440 | 1/1 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 0 |
| art/models/scenery/hunter_cabin.glb | 3158 | 1/1 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 0 |
| art/models/scenery/hunter_fence.glb | 440 | 1/1 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 0 |
| art/models/scenery/hut.glb | 4832 | 1/1 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 0 |
| art/models/scenery/observatory_altar.glb | 216 | 1/1 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 0 |
| art/models/scenery/observatory_pillar_broken.glb | 116 | 1/1 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 0 |
| art/models/scenery/observatory_pillar_fallen.glb | 176 | 1/1 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 0 |
| art/models/scenery/observatory_wall.glb | 792 | 1/1 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 0 |
| art/models/scenery/river_pebbles.glb | 320 | 1/1 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 0 |
| art/models/scenery/rock.glb | 806 | 1/1 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 0 |
| art/models/scenery/stone_pillar.glb | 476 | 1/1 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 0 |
| art/models/scenery/tent.glb | 1876 | 1/1 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 0 |
| art/models/scenery/tree_a.glb | 1652 | 1/1 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 0 |
| art/models/scenery/tree_b.glb | 1924 | 1/1 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 0 |
| art/models/scenery/waterfall_cliff.glb | 1422 | 1/1 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 0 |
| art/models/scenery/waterfall_curtain.glb | 1152 | 1/1 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 0 |
| art/models/scenery/waterfall_pond.glb | 96 | 1/1 | 3 | normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 0 |
| art/models/scenery/windmill.glb | 4772 | 1/1 | 4 | emissiveTexture, normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 0 |
| art/models/scenery/windmill_blades.glb | 1916 | 1/1 | 4 | emissiveTexture, normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 0 / 0 / 0 |
| art/models/spirit/flame_crystal.glb | 420 | 1/1 | 4 | emissiveTexture, normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 1 / 1 / 8 |
| art/models/spirit/glow_wisp.glb | 1684 | 1/1 | 4 | emissiveTexture, normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 1 / 1 / 8 |
| art/models/spirit/stone_guardian.glb | 3144 | 1/1 | 4 | emissiveTexture, normalTexture, occlusionTexture, pbrMetallicRoughness.baseColorTexture, pbrMetallicRoughness.metallicRoughnessTexture | 1 / 1 / 8 |

## 源码引用但文件缺失


## 程序化视觉候选（含已被 GLB 替换的回退与调试图形，不能直接全部算成缺失）

- `scenes/actors/base_enemy.gd:62`：`var _flash_material: StandardMaterial3D = null`
- `scenes/actors/base_enemy.gd:514`：`var mesh := CapsuleMesh.new()`
- `scenes/actors/base_enemy.gd:517`：`var material := StandardMaterial3D.new()`
- `scenes/actors/base_enemy.gd:554`：`_flash_material = StandardMaterial3D.new()`
- `scenes/actors/dread_wyvern.gd:210`：`var ring := TorusMesh.new()`
- `scenes/actors/dread_wyvern.gd:215`：`var mat := StandardMaterial3D.new()`
- `scenes/actors/npc.gd:92`：`var mesh := body.mesh as CapsuleMesh`
- `scenes/actors/npc.gd:95`：`var material := mesh.material as StandardMaterial3D`
- `scenes/actors/npc.gd:98`：`material = material.duplicate() as StandardMaterial3D`
- `scenes/actors/npc.tscn:10`：`[sub_resource type="StandardMaterial3D" id="Mat_body"]`
- `scenes/actors/npc.tscn:14`：`[sub_resource type="CapsuleMesh" id="Mesh_body"]`
- `scenes/actors/npc.tscn:19`：`[sub_resource type="SphereMesh" id="Mesh_head"]`
- `scenes/combat/enemy_bolt.gd:45`：`var mesh := SphereMesh.new()`
- `scenes/combat/enemy_bolt.gd:48`：`var material := StandardMaterial3D.new()`
- `scenes/combat/fireball.gd:53`：`var mesh := SphereMesh.new()`
- `scenes/combat/fireball.gd:58`：`var material := StandardMaterial3D.new()`
- `scenes/combat/frost_bolt.gd:41`：`var mesh := SphereMesh.new()`
- `scenes/combat/frost_bolt.gd:46`：`var material := StandardMaterial3D.new()`
- `scenes/combat/hit_effect.gd:39`：`var mesh := SphereMesh.new()`
- `scenes/combat/hit_effect.gd:42`：`var material := StandardMaterial3D.new()`
- `scenes/combat/loot_drop.gd:120`：`var mesh := SphereMesh.new()`
- `scenes/combat/loot_drop.gd:125`：`var material := StandardMaterial3D.new()`
- `scenes/combat/ring_effect.gd:14`：`var mesh := TorusMesh.new()`
- `scenes/combat/ring_effect.gd:17`：`var material := StandardMaterial3D.new()`
- `scenes/combat/spirit_fireball.gd:42`：`var mesh := SphereMesh.new()`
- `scenes/combat/spirit_fireball.gd:45`：`var material := StandardMaterial3D.new()`
- `scenes/dungeons/boss_moss_crown_beast.gd:94`：`var line_mesh := BoxMesh.new()`
- `scenes/dungeons/boss_moss_crown_beast.gd:96`：`var line_mat := StandardMaterial3D.new()`
- `scenes/dungeons/boss_moss_crown_beast.gd:111`：`var wedge_mat := StandardMaterial3D.new()`
- `scenes/dungeons/boss_moss_crown_beast.gd:511`：`var ring := TorusMesh.new()`
- `scenes/dungeons/boss_sprout.gd:40`：`var mesh := CylinderMesh.new()`
- `scenes/dungeons/boss_sprout.gd:45`：`var material := StandardMaterial3D.new()`
- `scenes/dungeons/dungeon_entrance.gd:26`：`fallback.add_child(PropFactory.box(Vector3(1.1, 4.0, 1.1), Color(0.44, 0.44, 0.46), Vector3(side * 2.0, 2.0, 0)))`
- `scenes/dungeons/dungeon_entrance.gd:27`：`fallback.add_child(PropFactory.box(Vector3(5.4, 0.9, 1.2), Color(0.40, 0.40, 0.42), Vector3(0, 4.2, 0)))`
- `scenes/dungeons/dungeon_entrance.gd:28`：`var dark := PropFactory.box(Vector3(3.2, 3.6, 0.4), Color(0.04, 0.05, 0.06), Vector3(0, 1.8, 0.2))`
- `scenes/dungeons/dungeon_entrance.gd:29`：`var dark_mat := dark.material_override as StandardMaterial3D`
- `scenes/dungeons/dungeon_entrance.gd:34`：`var glow := PropFactory.sphere(0.14, Color(0.5, 0.9, 0.6), Vector3(side * 1.3, 3.1, -0.4))`
- `scenes/dungeons/dungeon_entrance.gd:35`：`var glow_mat := glow.material_override as StandardMaterial3D`
- `scenes/dungeons/dungeon_pillar.gd:25`：`fallback.add_child(PropFactory.cylinder(0.85, 0.6, Color(0.48, 0.47, 0.44), Vector3(0, 0.3, 0), 1.0, 10))`
- `scenes/dungeons/dungeon_pillar.gd:26`：`fallback.add_child(PropFactory.cylinder(0.55, 4.0, Color(0.55, 0.54, 0.5), Vector3(0, 2.6, 0), 0.6, 10))`
- `scenes/dungeons/dungeon_pillar.gd:27`：`fallback.add_child(PropFactory.box(Vector3(1.5, 0.5, 1.5), Color(0.44, 0.43, 0.4), Vector3(0, 4.85, 0)))`
- `scenes/dungeons/dungeon_pillar.gd:70`：`var chunk := PropFactory.box(`
- `scenes/dungeons/forest_grove_dungeon.gd:119`：`var ground_visual := PropFactory.box(Vector3(60.0, 1.0, 60.0), Color(0.34, 0.5, 0.26), Vector3(0, -0.5, 0))`
- `scenes/dungeons/forest_grove_dungeon.gd:191`：`var result: StandardMaterial3D`
- `scenes/dungeons/forest_grove_dungeon.gd:193`：`result = meshes[0].get_active_material(0).duplicate() as StandardMaterial3D`
- `scenes/player/fp_arms.gd:12`：`var _arm_materials: Array[StandardMaterial3D] = []`
- `scenes/player/fp_arms.gd:16`：`var _weapon_glow_material: StandardMaterial3D`
- `scenes/player/fp_arms.gd:64`：`var source := mesh_instance.mesh.surface_get_material(surface) as StandardMaterial3D`
- `scenes/player/fp_arms.gd:66`：`var material := source.duplicate() as StandardMaterial3D`
- `scenes/player/fp_arms.gd:113`：`_weapon_glow_material = StandardMaterial3D.new()`
- `scenes/player/spirit_entity.gd:49`：`var sphere := _placeholder.mesh as SphereMesh`
- `scenes/player/spirit_entity.gd:51`：`var material := sphere.material as StandardMaterial3D`
- `scenes/player/spirit_entity.gd:53`：`material = material.duplicate() as StandardMaterial3D`
- `scenes/player/spirit_entity.tscn:5`：`[sub_resource type="StandardMaterial3D" id="Mat_placeholder"]`
- `scenes/player/spirit_entity.tscn:11`：`[sub_resource type="SphereMesh" id="Mesh_placeholder"]`
- `scenes/world/camp.gd:75`：`fallback.add_child(PropFactory.cylinder(2.3, 8.6, Color(0.74, 0.70, 0.62), Vector3(0, 4.3, 0), 1.9, 12))`
- `scenes/world/camp.gd:76`：`fallback.add_child(PropFactory.cylinder(2.1, 1.7, Color(0.42, 0.30, 0.20), Vector3(0, 9.4, 0), 0.5, 12))`
- `scenes/world/camp.gd:77`：`fallback.add_child(PropFactory.box(Vector3(0.6, 1.0, 0.05), Color(0.35, 0.25, 0.16), Vector3(0, 0.5, 2.3)))`
- `scenes/world/camp.gd:86`：`var blade := PropFactory.box(Vector3(0.22, 4.6, 0.08), Color(0.60, 0.48, 0.32))`
- `scenes/world/camp.gd:92`：`blade_fallback.add_child(PropFactory.sphere(0.35, Color(0.35, 0.26, 0.18)))`
- `scenes/world/camp.gd:108`：`fallback.add_child(PropFactory.sphere(0.26, Color(0.42, 0.40, 0.38), Vector3(cos(angle) * 0.95, 0.12, sin(angle) * 0.95)))`
- `scenes/world/camp.gd:110`：`var log_mesh := PropFactory.cylinder(0.12, 1.4, Color(0.30, 0.20, 0.12), Vector3(0, 0.18, 0))`
- `scenes/world/camp.gd:165`：`var quad := QuadMesh.new()`
- `scenes/world/camp.gd:167`：`var flame_mat := StandardMaterial3D.new()`
- `scenes/world/camp.gd:187`：`fallback.add_child(PropFactory.cylinder(1.7, 1.9, Color(0.58, 0.50, 0.36), Vector3(0, 0.95, 0), 0.0, 3))`
- `scenes/world/camp.gd:188`：`fallback.add_child(PropFactory.box(Vector3(0.05, 0.9, 1.0), Color(0.28, 0.22, 0.15), Vector3(0, 0.4, 0.75)))`
- `scenes/world/camp.gd:201`：`fallback.add_child(PropFactory.box(Vector3(4.4, 2.6, 3.4), Color(0.50, 0.38, 0.26), Vector3(0, 1.3, 0)))`
- `scenes/world/camp.gd:202`：`fallback.add_child(PropFactory.cylinder(2.6, 1.2, Color(0.36, 0.26, 0.16), Vector3(0, 3.1, 0), 0.0, 4))`
- `scenes/world/camp.gd:203`：`fallback.add_child(PropFactory.box(Vector3(0.9, 1.8, 0.1), Color(0.30, 0.22, 0.14), Vector3(0, 0.9, 1.75)))`
- `scenes/world/camp.gd:222`：`fallback.add_child(PropFactory.cylinder(0.4, 0.55, Color(0.35, 0.28, 0.20), Vector3(0, 0.27, 0), -1.0, 8))`
- `scenes/world/camp.gd:223`：`fallback.add_child(PropFactory.box(Vector3(0.55, 0.18, 0.28), Color(0.28, 0.30, 0.33), Vector3(0, 0.78, 0)))`
- `scenes/world/camp.gd:224`：`fallback.add_child(PropFactory.box(Vector3(1.5, 1.1, 1.2), Color(0.40, 0.36, 0.34), Vector3(1.6, 0.55, 0)))`
- `scenes/world/camp.gd:260`：`fallback.add_child(PropFactory.box(Vector3(1.0, 0.8, 0.9), Color(0.46, 0.34, 0.22), Vector3(0, 0.4, 0)))`
- `scenes/world/camp.gd:261`：`fallback.add_child(PropFactory.box(Vector3(1.04, 0.12, 0.94), Color(0.36, 0.26, 0.16), Vector3(0, 0.86, 0)))`
- `scenes/world/camp.gd:281`：`board.add_child(PropFactory.cylinder(0.08, 1.8, Color(0.40, 0.30, 0.20), Vector3(-0.6, 0.9, 0), -1.0, 6))`
- `scenes/world/camp.gd:282`：`board.add_child(PropFactory.cylinder(0.08, 1.8, Color(0.40, 0.30, 0.20), Vector3(0.6, 0.9, 0), -1.0, 6))`
- `scenes/world/camp.gd:283`：`board.add_child(PropFactory.box(Vector3(1.7, 1.0, 0.08), Color(0.55, 0.42, 0.28), Vector3(0, 1.5, 0)))`
- `scenes/world/camp.gd:294`：`point.add_child(PropFactory.cylinder(1.2, 0.25, Color(0.52, 0.52, 0.55), Vector3(0, 0.12, 0), 1.0, 8))`
- `scenes/world/camp.gd:295`：`point.add_child(PropFactory.cylinder(0.18, 1.6, Color(0.60, 0.62, 0.68), Vector3(0, 0.9, 0), 0.12, 8))`
- `scenes/world/camp.gd:296`：`var crystal := PropFactory.cylinder(0.22, 0.5, Color(0.55, 0.85, 1.0), Vector3(0, 1.9, 0), 0.0, 6)`
- `scenes/world/camp.gd:297`：`var crystal_mat := crystal.material_override as StandardMaterial3D`
- `scenes/world/chest.gd:52`：`fallback.add_child(PropFactory.box(Vector3(0.95, 0.45, 0.6), Color(0.44, 0.31, 0.19), Vector3(0, 0.225, 0)))`
- `scenes/world/chest.gd:56`：`lid_pivot.add_child(PropFactory.box(Vector3(0.99, 0.2, 0.64), Color(0.50, 0.36, 0.22), Vector3(0, 0.1, 0.3)))`
- `scenes/world/chest.gd:63`：`var trim := PropFactory.box(Vector3(1.0, 0.08, 0.64), trim_color, Vector3(0, 0.44, 0))`
- `scenes/world/chest.gd:64`：`var trim_mat := trim.material_override as StandardMaterial3D`
- `scenes/world/chest.gd:70`：`fallback.add_child(PropFactory.box(Vector3(0.1, 0.42, 0.62), trim_color, Vector3(0, 0.22, 0)))`
- `scenes/world/echo_stone.gd:20`：`var _glow_materials: Array[StandardMaterial3D] = []`
- `scenes/world/echo_stone.gd:69`：`var source := instance.mesh.surface_get_material(i) as StandardMaterial3D`
- `scenes/world/echo_stone.gd:71`：`var material := source.duplicate() as StandardMaterial3D`
- `scenes/world/echo_stone.gd:112`：`var mesh := rune_ring.mesh.duplicate() as TorusMesh`
- `scenes/world/echo_stone.gd:116`：`var material := mesh.material as StandardMaterial3D`
- `scenes/world/echo_stone.gd:119`：`material = material.duplicate() as StandardMaterial3D`
- `scenes/world/echo_stone.gd:125`：`func _find_glow_material() -> StandardMaterial3D:`
- `scenes/world/echo_stone.tscn:10`：`[sub_resource type="StandardMaterial3D" id="Mat_stone"]`
- `scenes/world/echo_stone.tscn:14`：`[sub_resource type="CylinderMesh" id="Mesh_stone"]`
- `scenes/world/echo_stone.tscn:20`：`[sub_resource type="StandardMaterial3D" id="Mat_rune"]`
- `scenes/world/echo_stone.tscn:26`：`[sub_resource type="TorusMesh" id="Mesh_rune"]`
- `scenes/world/gather_node.tscn:10`：`[sub_resource type="StandardMaterial3D" id="Mat_stem"]`
- `scenes/world/gather_node.tscn:14`：`[sub_resource type="StandardMaterial3D" id="Mat_leaf"]`
- `scenes/world/gather_node.tscn:20`：`[sub_resource type="CylinderMesh" id="Mesh_stem"]`
- `scenes/world/gather_node.tscn:26`：`[sub_resource type="SphereMesh" id="Mesh_leaf"]`
- `scenes/world/poi_waterfall.gd:5`：`var _flow_materials: Array[StandardMaterial3D] = []`
- `scenes/world/poi_waterfall.gd:52`：`var mat := mesh.mesh.surface_get_material(surface).duplicate() as StandardMaterial3D`
- `scenes/world/prop_factory.gd:7`：`static func material(color: Color, roughness := 0.85, metallic := 0.0, emission := Color.BLACK, emission_energy := 1.0) -> StandardMaterial3D:`
- `scenes/world/prop_factory.gd:8`：`var mat := StandardMaterial3D.new()`
- `scenes/world/prop_factory.gd:20`：`var mesh := BoxMesh.new()`
- `scenes/world/prop_factory.gd:30`：`var mesh := CylinderMesh.new()`
- `scenes/world/prop_factory.gd:43`：`var mesh := SphereMesh.new()`
- `scenes/world/quest_pickup.tscn:9`：`[sub_resource type="BoxMesh" id="Mesh_book"]`
- `scenes/world/quest_pickup.tscn:12`：`[sub_resource type="StandardMaterial3D" id="Mat_book"]`
- `scenes/world/terrain_builder.gd:21`：`var _creek_material: StandardMaterial3D`
- `scenes/world/terrain_builder.gd:153`：`var material := StandardMaterial3D.new()`
- `scenes/world/terrain_builder.gd:226`：`var material := StandardMaterial3D.new()`
- `scenes/world/terrain_builder.gd:292`：`var fallback := StandardMaterial3D.new()`
- `scenes/world/terrain_builder.gd:295`：`_creek_material = _ground_material("res://art/models/scenery/creek_water.glb", fallback).duplicate() as StandardMaterial3D`
- `scenes/world/terrain_builder.gd:547`：`func _veg_material() -> StandardMaterial3D:`
- `scenes/world/terrain_builder.gd:548`：`var material := StandardMaterial3D.new()`
- `scenes/world/terrain_builder.gd:558`：`var trunk := CylinderMesh.new()`
- `scenes/world/terrain_builder.gd:570`：`var cone := CylinderMesh.new()`
- `scenes/world/terrain_builder.gd:581`：`var sphere := SphereMesh.new()`
- `scenes/world/terrain_builder.gd:598`：`var sphere := SphereMesh.new()`
- `scenes/world/weather_system.gd:132`：`var drop := BoxMesh.new()`
- `scenes/world/weather_system.gd:134`：`var drop_mat := StandardMaterial3D.new()`
- `dev/art_work/boss_before_upgrade.gd:80`：`var line_mesh := BoxMesh.new()`
- `dev/art_work/boss_before_upgrade.gd:82`：`var line_mat := StandardMaterial3D.new()`
- `dev/art_work/boss_before_upgrade.gd:97`：`var wedge_mat := StandardMaterial3D.new()`
- `dev/capture_wolf_motion.gd:71`：`func _checker_material() -> StandardMaterial3D:`
- `dev/capture_wolf_motion.gd:77`：`var material := StandardMaterial3D.new()`
- `dev/test_combat.tscn:21`：`[sub_resource type="StandardMaterial3D" id="Mat_ground"]`
- `dev/test_combat.tscn:27`：`[sub_resource type="BoxMesh" id="Mesh_ground"]`
- `dev/test_combat.tscn:30`：`[sub_resource type="StandardMaterial3D" id="Mat_dummy"]`
- `dev/test_combat.tscn:38`：`[sub_resource type="CapsuleMesh" id="Mesh_dummy"]`
- `dev/test_enemies.tscn:22`：`[sub_resource type="StandardMaterial3D" id="Mat_ground"]`
- `dev/test_enemies.tscn:28`：`[sub_resource type="BoxMesh" id="Mesh_ground"]`
- `dev/test_enemies.tscn:31`：`[sub_resource type="StandardMaterial3D" id="Mat_obstacle"]`
- `dev/test_enemies.tscn:38`：`[sub_resource type="BoxMesh" id="Mesh_pillar"]`
- `dev/test_enemies.tscn:45`：`[sub_resource type="BoxMesh" id="Mesh_rock_a"]`
- `dev/test_enemies.tscn:52`：`[sub_resource type="BoxMesh" id="Mesh_rock_b"]`
- `dev/test_enemies.tscn:59`：`[sub_resource type="BoxMesh" id="Mesh_wall"]`
- `dev/test_movement.tscn:21`：`[sub_resource type="BoxMesh" id="Mesh_ground"]`
- `dev/test_movement.tscn:24`：`[sub_resource type="StandardMaterial3D" id="Mat_ground"]`
- `dev/test_movement.tscn:30`：`[sub_resource type="BoxMesh" id="Mesh_box_a"]`
- `dev/test_movement.tscn:36`：`[sub_resource type="BoxMesh" id="Mesh_box_b"]`
- `dev/test_movement.tscn:42`：`[sub_resource type="BoxMesh" id="Mesh_box_c"]`
- `dev/test_movement.tscn:48`：`[sub_resource type="BoxMesh" id="Mesh_ramp"]`
- `dev/test_movement.tscn:54`：`[sub_resource type="BoxMesh" id="Mesh_platform"]`
- `dev/test_movement.tscn:61`：`[sub_resource type="CylinderMesh" id="Mesh_stele"]`
- `dev/test_movement.tscn:72`：`[sub_resource type="BoxMesh" id="Mesh_pool"]`
- `dev/test_movement.tscn:75`：`[sub_resource type="StandardMaterial3D" id="Mat_pool"]`
- `dev/test_quests.tscn:27`：`[sub_resource type="StandardMaterial3D" id="Mat_ground"]`
- `dev/test_quests.tscn:33`：`[sub_resource type="BoxMesh" id="Mesh_ground"]`
- `dev/test_quests.tscn:36`：`[sub_resource type="StandardMaterial3D" id="Mat_obstacle"]`
- `dev/test_quests.tscn:43`：`[sub_resource type="BoxMesh" id="Mesh_rock"]`
- `dev/verify_camp_forge.gd:25`：`var mat := mesh.mesh.surface_get_material(0) as StandardMaterial3D`
- `dev/verify_camp_hut.gd:23`：`var mat := mesh.mesh.surface_get_material(0) as StandardMaterial3D`
- `dev/verify_chest_art.gd:28`：`var mat := node.get_active_material(0) as StandardMaterial3D`
- `dev/verify_creek.gd:34`：`var mat: StandardMaterial3D`
- `dev/verify_creek.gd:51`：`var water_mat := terrain.get_node("CreekWater").material_override as StandardMaterial3D`
- `dev/verify_echo_stone.gd:28`：`var mat := instance.get_active_material(0) as StandardMaterial3D`
- `dev/verify_echo_stone.gd:34`：`var other: StandardMaterial3D=second._find_glow_material()`
- `dev/verify_echo_stone.gd:35`：`var source := instance.mesh.surface_get_material(0) as StandardMaterial3D`
- `dev/verify_forest_rock.gd:36`：`var mat := mesh.surface_get_material(0) as StandardMaterial3D`
- `dev/verify_forest_shaman.gd:38`：`var mat := node.get_active_material(0) as StandardMaterial3D`
- `dev/verify_forest_shaman.gd:111`：`var mat := material as StandardMaterial3D`
- `dev/verify_forest_surface.gd:12`：`func check_material(mat: StandardMaterial3D, label: String) -> void:`
- `dev/verify_forest_surface.gd:38`：`check_material(visual.material_override as StandardMaterial3D,name)`
- `dev/verify_forest_surface.gd:43`：`print("SURFACE_DIAG ",name," normal=",arrays[Mesh.ARRAY_NORMAL][0]," alpha_mode=",(visual.material_override as StandardMaterial3D).transparency)`
- `dev/verify_forest_surface.gd:49`：`var mat := visual.material_override as StandardMaterial3D`
- `dev/verify_forest_surface.gd:68`：`check_material(mesh.surface_get_material(0) as StandardMaterial3D,name)`
- `dev/verify_herb.gd:32`：`var mat := node.get_active_material(0) as StandardMaterial3D`
- `dev/verify_humanoid_cast.gd:42`：`var material := node.get_active_material(0) as StandardMaterial3D`
- `dev/verify_hunter_cabin.gd:33`：`var mat := node.get_active_material(0) as StandardMaterial3D`
- `dev/verify_iron_sword.gd:17`：`var material := mesh.surface_get_material(surface) as StandardMaterial3D`
- `dev/verify_moss_boar.gd:36`：`var material := mesh.mesh.surface_get_material(0) as StandardMaterial3D`
- `dev/verify_observatory.gd:33`：`var mat := node.get_active_material(0) as StandardMaterial3D`
- `dev/verify_remaining_assets.gd:33`：`var material := node.get_active_material(surface) as StandardMaterial3D`
- `dev/verify_storage_crate.gd:25`：`var mat := mesh.mesh.surface_get_material(0) as StandardMaterial3D`
- `dev/verify_tent.gd:31`：`var mat := node.get_active_material(0) as StandardMaterial3D`
- `dev/verify_timber_wolf.gd:37`：`var material := mesh_instance.mesh.surface_get_material(surface) as StandardMaterial3D`
- `dev/verify_waterfall.gd:43`：`var mat := node.get_active_material(0) as StandardMaterial3D`
- `dev/verify_waterfall.gd:49`：`var flow: StandardMaterial3D = waterfall._flow_materials[0]`
