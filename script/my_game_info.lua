-- # 各类定义表
-- # = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
-- # 主副手武器
local my_game_info = {
    one_weapon = {"Broadsword of the Resistance", "Guardian Warblade"},
    second_weapon = {
        "Forgotten Longbow", "Forgotten Staff", "Forgotten Sword",
        "Forgotten Crossbows", "Forgotten Daggers", "Forgotten Wand",
        "Sparring Longspear", "Sniper Longbow", "Arcane Staff",
        "Manasteel Sword", "Watchkeeper Crossbows", "Utility Daggers",
        "Inquisition Rod", "Combat Halberd"
    },

    -- # 角色匹配坐标
    role_matching = {
        ["女術者"] = {773, 675},
        ["戰士"] = {721, 675},
        ["遊俠"] = {670, 675},
        ["女巫"] = {825, 675},
        ["傭兵"] = {877, 675},
        ["僧侶"] = {928, 675},
        ["女獵人"] = {670, 730}
    },

    role_name_list = {
        ["女術者"] = "元素由我掌控。我知道閃電為何會擊中人；火焰為何會燃燒；寒冷為何會導致結冰。一切的元素現象皆隨我號令顯現。那些犯下過錯之人無論逃到天涯海角，都躲不過馬拉克斯的復仇。",
        ["戰士"] = "我的個人需求很低，有座鍛爐和一張床就足矣。然而，他們卻燒掉我的家園，奪走我的一切。給我一把精良的錘子，我就會讓他們知道，當熱愛和平之人被激起戰爭的欲望，會是一件多麼危險的事。",
        ["遊俠"] = "我只需一箭，便能百步穿楊。我身手矯健，還有雙如老鷹一般的銳眼。只要弓箭在手，試圖追擊我的人都只有死路一條。",
        ["女巫"] = "我無懼死亡，死亡甚至要臣服於我。黑暗與亡者將隨我征戰，成為我手下無堅不摧的利器。我的敵人將從身體內部開始潰爛，而我的亡靈大軍則會在他們的慘叫聲中，將其撕成碎片。",
        ["傭兵"] = "你天生擁有敏捷的身手和強健的體魄。你對老天給你的天賦做了什麼，決鬥者？你的自我沉淪，浪費了這些才能。",
        ["僧侶"] = "我這一生恪守紀律，所有的準備都是為了此刻。我為了仁慈的幻夢者而戰。解放我的雙手，那些追尋混沌之人將在我面前倒下！",
        ["女獵人"] = "我在神靈的旨意下走出森林，卻發現外頭充斥著暴力與死亡。拿長矛來！ˊ果他們渴望鮮血，我就讓他們見識見識，什麼叫為生存而戰。"
    },

    -- # 地区列表
    region_list = {
        "Texas (US)", "Washington, D.C. (US)", "California (US)",
        "Amsterdam (ES)", "London (EU)", "Frankfurt (EU)", "Milan (EU)",
        "Singapore", "Australia", "Sao Paulo (BR)", "Paris (EU)", "Moscow (RU)",
        "Auckland (NZ)", "Japan", "Canada (East)", "South Africa", "Hong Kong"
    },

    -- # 角色技能位置
    skill_pos = {
        ["Q"] = {1211.0, 866.28125},
        ["W"] = {1253.75, 866.28125},
        ["E"] = {1296.5, 866.28125},
        ["R"] = {1339.25, 866.28125},
        ["T"] = {1382.0, 866.28125},
        ["P"] = {1298, 813},
        ["M"] = {1382.0, 812},
        ["MIDDLE"] = {1338.0, 812}
    },

    skill_pos_litter = {
        ["q"] = {1211.0, 866.28125},
        ["w"] = {1253.75, 866.28125},
        ["e"] = {1296.5, 866.28125},
        ["r"] = {1339.25, 866.28125},
        ["t"] = {1382.0, 866.28125}
    },

    newbie_gear = {
        ["女巫"] = {
            ["skill"] = "屍術矢",
            ["gear"] = "雜響權杖",
            ["gearinfo"] = "WeaponGrantedChaosboltPlayer"
        },
        ["女術者"] = {["skill"] = "電球", ["gear"] = ""},
        ["戰士"] = {["skill"] = "翻騰重擊", ["gear"] = ""},
        ["遊俠"] = {["skill"] = "閃電箭矢", ["gear"] = "寬頭箭袋"},
        ["傭兵"] = {["skill"] = "分裂彈藥", ["gear"] = ""},
        ["僧侶"] = {["skill"] = "崩雷鳴", ["gear"] = ""},
        ["女獵人"] = {["skill"] = "迴旋斬", ["gear"] = ""}
    },

    -- # 角色技能列表名
    -- # 结构：角色名: {技能名：{"text":技能所在页面,"skill_name":技能列表名,"skill_pos":技能位置,"level_skillstone":技能石等级,"palyer_level":角色等级,"primary_or_secondary":主副技能}}
    skill_ui = {
        ["女巫"] = {
            ["Unearth"] = {
                ["text"] = "Occult",
                ["skill_name"] = "UnearthPlayer",
                ["skill_pos"] = "Q",
                ["level_skillstone"] = 1,
                ["palyer_level"] = 1,
                ["primary_or_secondary"] = true
            },
            ["Spark"] = {
                ["text"] = "Elemental",
                ["skill_name"] = "SparkPlayer",
                ["skill_pos"] = "W",
                ["level_skillstone"] = 1,
                ["palyer_level"] = 1,
                ["primary_or_secondary"] = true
            },
            ["Flame Wall"] = {
                ["text"] = "Elemental",
                ["skill_name"] = "FlameWallPlayer",
                ["skill_pos"] = "E",
                ["level_skillstone"] = 1,
                ["palyer_level"] = 1,
                ["primary_or_secondary"] = true
            },
            ["Skeletal Arsonist"] = {
                ["text"] = "Occult",
                ["skill_name"] = "SummonSkeletalArsonistsPlayer",
                ["skill_pos"] = "R",
                ["level_skillstone"] = 3,
                ["palyer_level"] = 6,
                ["primary_or_secondary"] = false
            }
        }
    },

    -- # 键盘按键表
    ascii_dict = {
        ["0"] = 48,
        ["1"] = 49,
        ["2"] = 50,
        ["3"] = 51,
        ["4"] = 52,
        ["5"] = 53,
        ["6"] = 54,
        ["7"] = 55,
        ["8"] = 56,
        ["9"] = 57,
        ["a"] = 65,
        ["b"] = 66,
        ["c"] = 67,
        ["d"] = 68,
        ["e"] = 69,
        ["f"] = 70,
        ["g"] = 71,
        ["h"] = 72,
        ["i"] = 73,
        ["j"] = 74,
        ["k"] = 75,
        ["l"] = 76,
        ["m"] = 77,
        ["n"] = 78,
        ["o"] = 79,
        ["p"] = 80,
        ["q"] = 81,
        ["r"] = 82,
        ["s"] = 83,
        ["t"] = 84,
        ["u"] = 85,
        ["v"] = 86,
        ["w"] = 87,
        ["x"] = 88,
        ["y"] = 89,
        ["z"] = 90,
        ["f10"] = 121,
        ["esc"] = 27,
        ["tab"] = 9,
        ["enter"] = 13,
        ["space"] = 32,
        ["backspace"] = 8,
        ["shift"] = 160,
        ["ctrl"] = 17,
        ["alt"] = 18,
        ["left"] = 37,
        ["up"] = 38,
        ["right"] = 39,
        ["down"] = 40,
        ["."] = 190,
        ["`"] = 192,
        ["["] = 219,
        ["]"] = 221,
        ["-"] = 189,
        ["="] = 187,
        ["/"] = 191,
        ["pageup"] = 33,
        ["f8"] = 119
    },

    city = {"皆伐營地", "阿杜拉車隊", "高地神塔營地","金司馬區","庇護所","卡里市集","林間空地"},
    city_map = {
        "皆伐營地", "阿杜拉車隊", "高地神塔營地",
        "城鎮傳送門","金司馬區","庇護所","卡里市集","林間空地"
    },
    hideout_CH = {
        "高地神塔庇護所", "藏身處：運河", "藏身處：神殿",
        "藏身處：石灰岩", "藏身處：殞落", "藏身處：無畏隊",
        "藏身處：扭曲", "藏身處：瓦斯提里競技場",
        "藏身處：救贖烽塔", "皆伐營地", "阿杜拉車隊",
        "高地神塔營地","城鎮傳送門","藏身處：海岸線"
    },
    hideout = {
        "G_Endgame_Town", "HideoutFelled", "HideoutShrine", "HideoutLimestone",
        "HideoutCanal", "HideoutDreadnought", "HideoutTwisted",
        "HideoutRacetrack", "HideoutBeaconOfSalvation", "G1_town", "G2_town",
        "G3_town", "G4_town", "P1_town", "P2_town","P3_town","HideoutShoreline"
    },

    boss_name = {
        "熾烈衛士．特茲卡特", "巨型守衛者．瓦斯威德",
        "真菌巨靈", "信仰之嘲．融蠟",
        "被遺忘的囚犯．帕拉薩", "巨蛇女王．瑪娜莎",
        "憎惡者．亞歐塔"
    },

    game_region = {
        "Rise of the Abyssal 聯盟",
        "Dawn of the Hunt 聯盟",
        "Standard 聯盟"
    },

    trash_map = {
        "MapLeaguePortal", -- # 界域之门
        "MapVoidReliquary", -- # 宝库
        "MapUberBoss_Monolith", "MapSwampTower", -- # 沉溺尖塔 有Boss
        "MapSwampTower_NoBoss", -- # 沉溺尖塔
        "MapUberBoss_CopperCitadel", -- # 青铜城寨
        "MapUberBoss_StoneCitadel", -- # 岩石城寨
        "MapUberBoss_IronCitadel", -- # 钢铁城寨
        "MapSunTemple_NoBoss", -- # 太阳神殿
        "MapSunTemple", -- # 太阳神殿 有Boss
        "MapBloomingField", -- # 盛放田野 有Boss
        "MapVaalFoundry", --# 瓦尔铸造厂 有Boss
        -- # "MapAugury", --# 预兆 有Boss
        -- # "MapAugury_NoBoss", --# 预兆
        "MapNecropolis", -- # 魔影墓场 有Boss
        "MapNecropolis_NoBoss", -- # 魔影墓场
        "MapForge", -- # 锻造 有Boss
        "MapAlpineRidge_NoBoss", "MapAlpineRidge",
        "MapSandspit",-- 新版砂土
        "MapVaalVault"
    },

    not_attact_mons_path_name = {
        "Metadata/Monsters/VaalSavage/bonewall/SavageBoneWall@66", -- #'骨牆'
        "Metadata/Monsters/LeagueRitual/Daemons/BloodWave@79", -- # 祭祀血浪
        "Metadata/Monsters/Clone/WarriorLightningClone@79", -- # 小電人
        "Metadata/Monsters/LeagueRitual/Daemons/RatTornado@70", -- # 祭祀龙卷风
        "Metadata/Monsters/Totems/ancestor_totem/AncestralWarriorSpirit@34", -- # '先祖戰士精魂'
        "Metadata/Monsters/Totems/ancestor_totem/AncestralWarriorSpirit@40",
        'Metadata/Monsters/VaalHumanoids/VaalHumanoidCannon/VaalHumanoidCannonLightningSkitterMine_@80' -- # 疾速地雷
    },

    not_attact_mons_CN_name = {
        "", "惡魔", "隱形", "視覺惡魔", "複製之躰", "複製體",
        "暴行雕像", "先祖戰士精魂", "骨牆", "潛伏之炎",
        "複製體", "複製之體", "果息", "疾速地雷", "核息", "鮮明水母","芙雷雅．哈特林"
        -- "動亂",
    },

    space_path_name_list_round = {
        "Metadata/Monsters/LeagueRitual/Daemons/RatTornado@65",
        "Metadata/Monsters/LeagueRitual/Daemons/RatTornado@79",
        #'Metadata/Effects/Spells/ground_effects/VisibleServerGroundEffect',
        #'Metadata/Projectiles/AfflictionMinionDeathSpike',
        "Metadata/Monsters/LeagueRitual/Daemons/PurplePustules",
        "Metadata/Monsters/InvisibleFire/MDPerennialKingTornado@79",
        "Metadata/Projectiles/CaveDwellerSuperProjectile",
        "Metadata/Monsters/MonsterMods/Flamewaller/Flamewall",
        #"Metadata/Monsters/Cenobite/CenobiteBloater/CenobiteBloater@74"
    },

    High_Damage_Skill = {
        -- 祭坛
        {
            1,
            "Metadata/Effects/Spells/monsters_effects/League_Ritual/chaos_ritual/bloom_pod.ao",
            10
        }, -- 祭祀爆炸球
        {
            1,
            "Metadata/Effects/Environment/Endgame/Rituals/Bloodwave/blood_wave.ao",
            15
        }, -- 祭祀血浪
        {1, "Metadata/Monsters/LeagueRitual/Daemons/RatTornado.ao", 20}, -- 祭祀龙卷风
        {
            1,
            "Metadata/Effects/Spells/monsters_effects/Act3_FOUR/TrenchHag/WaterOrb.ao",
            20
        }, -- 女巫水球
        {1, "Metadata/Monsters/LeagueRitual/Daemons/volatile.ao", 10}, -- 祭坛追踪紫色爆炸球
        {1, "Metadata/Monsters/MonsterMods/VolatilePlants/volatile.ao", 10} -- 追踪紫色爆炸球
    },

    MonitoringSkills_Circle = {
        -- 祭坛
        {
            1,
            "Metadata/Effects/Spells/monsters_effects/monster_mods/fire/explode_on_death/ao/fire_beacons.ao",
            20
        }, -- 爆炸火圈
        {1, "Metadata/Monsters/LeagueRitual/Daemons/volatile_explode.ao", 15},
        {
            1,
            "Metadata/Effects/Spells/monsters_effects/monster_mods/fire/flame_waller/ao/flame_wall.ao",
            5
        }, -- 火墙
        {
            1,
            "Metadata/Effects/Spells/monsters_effects/Act3_FOUR/IllFatedExplorer/ao/death_spores.ao",
            25
        }, {
            1,
            "Metadata/Effects/Spells/monsters_effects/monster_mods/ice/explode_on_death/ao/ice_beacons.ao",
            20
        }, -- 爆炸冰圈
        {
            1,
            "Metadata/Effects/Spells/monsters_effects/Act1_FOUR/CoffinWretch/ChildSpiritProjectile.ao",
            15
        }, -- {1,'Metadata/Effects/Spells/grd_Zones/grd_Chilled01.ao',15},
        {
            1,
            "Metadata/Effects/Spells/monsters_effects/monster_mods/ice/chilled_ground/ao/surge_pulse.ao",
            15
        }, {
            1,
            "Metadata/Effects/Spells/monsters_effects/monster_mods/exploding_orbs/exploding_orb.ao",
            15
        }, {
            1,
            "Metadata/Effects/Spells/monsters_effects/Act3_FOUR/CenobiteLeash/ao/Poison_MortarBurst_Grd.ao",
            15
        }, {
            1,
            "Metadata/Effects/Spells/monsters_effects/Act3_FOUR/CenobiteLeash/ao/Heal_MortarBurst.ao",
            15
        }, {
            1,
            "Metadata/Effects/Spells/monsters_effects/Act1_FOUR/CannibalPict/bow/ao/bloom_pod.ao",
            15
        }, -- 爆炸紫色球
        {
            1,
            "Metadata/Effects/Spells/monsters_effects/monster_mods/lightning/periodic_lightning_storm/ao/lightning_zap_marker.ao",
            15
        }, {
            1,
            "Metadata/Effects/Spells/monsters_effects/League_Azmeri/monsters/PictMaleAxeDagger/revive_AOE.ao",
            15
        }, {
            1,
            "Metadata/Effects/Spells/monsters_effects/monster_mods/lightning/shocked_ground/ao/shocked_ground.ao",
            15
        }, {
            1,
            "Metadata/Effects/Spells/monsters_effects/monster_mods/lightning/explode_on_death/ao/lightning_beacons.ao",
            15
        }, {
            1,
            "Metadata/Effects/Spells/monsters_effects/monster_mods/fire/burned_ground/ao/grd_Burning01.ao",
            15
        },
        {
            1,
            "Metadata/Effects/Spells/ground_effects_v2/smoke_blind/smoke_blind.ao",
            15
        }, {
            1,
            "Metadata/Effects/Spells/monsters_effects/Act3_FOUR/TrenchHag/WaterOrb.ao",
            15
        }, {
            1,
            "Metadata/Effects/Spells/monsters_effects/Act3_FOUR/TrenchHag/WaterVortex.ao",
            15
        }, {
            1,
            "Metadata/Effects/Spells/monsters_effects/Act3_FOUR/VaalSorcerer/ao/BallLightning/orb.ao",
            8
        }, -- 追踪电球
        {
            1,
            "Metadata/Effects/Spells/monsters_effects/monster_mods/lightning/periodic_lightning_storm/ao/lightning_zap.ao",
            15
        }, {
            1,
            "Metadata/Effects/Spells/monsters_effects/Gallows/Act1/FungalArtillery/fungalimpact.ao",
            10
        }, -- 毒爆
        {
            1,
            "Metadata/Effects/Spells/monsters_effects/Act1_FOUR/FungalArtillery/ao/fungal_ground.ao",
            10
        }, -- 毒爆地面
        {
            1,
            "Metadata/Effects/Spells/monsters_effects/Act2_FOUR/BoneCultistsZealots/fire_projectile.ao",
            2
        }, -- 小火球
        {
            1,
            "Metadata/Effects/Spells/fire_rolling_magma/magma_projectile_monster.ao",
            5
        }, -- 火弹球
        {
            1,
            "Metadata/Effects/Spells/monsters_effects/Act3_FOUR/VaalGuards/VaalGuard03/ao/mortar_explode.ao",
            15
        }, -- 小火弹球
        {
            1,
            "Metadata/Effects/Spells/monsters_effects/Act2_FOUR/MaraKethZombie/cloud_ground.ao",
            15
        }, -- 毒地面
        {
            1,
            "Metadata/Effects/Spells/monsters_effects/Act1_FOUR/Skeleton_Golemancer/skelenado.ao",
            5
        }, -- 绿色小龙卷风
        {
            1,
            "Metadata/Effects/Spells/monsters_effects/Act1_FOUR/Graveyard/skeleton_caster/ao/lightning_projectile.ao",
            5
        }, -- 小直线闪电
        {
            1,
            "Metadata/Effects/Spells/monsters_effects/Act1_FOUR/CannibalPict/bow/ao/bloom_lotus.ao",
            5
        }, -- 紫色减速花
        {
            1,
            "Metadata/Effects/Spells/monsters_effects/Act1_FOUR/Fungal_Cave/spore_bombs/Fungi_Bomb02.ao",
            5
        }, -- 小蘑菇
        {
            1,
            "Metadata/Effects/Spells/monsters_effects/Act1_FOUR/Graveyard/bearer_of_pen/penitence_slam.ao",
            15
        }, -- 怪物劈砍
        {1, "Metadata/Monsters/Clone/IntLightningClone.ao", 10}, -- 小电人1
        {1, "Metadata/Monsters/Clone/StrBLightningClone.ao", 10}, -- 小电人2
        {
            1,
            "Metadata/Effects/Spells/monsters_effects/Act3_FOUR/VaalZealotSpearBlood/degen_pool.ao",
            16
        }, -- 血地面
        {
            1,
            "Metadata/Effects/Spells/monsters_effects/Gallows/Act1/LivingBlood/LivingBlood.ao",
            16
        }, -- 血地面
        {
            1,
            "Metadata/Effects/Spells/monsters_effects/Act3_FOUR/BloodPriest/soulrend/rig.ao",
            5
        }, -- 血追踪球
        {
            1,
            "Metadata/Effects/Spells/monsters_effects/League_Azmeri/monsters/PictMaleAxeDagger/revive_AOE.ao",
            15
        }, -- 紫色大爆炸
        {
            1,
            "Metadata/Effects/Spells/monsters_effects/Act2_FOUR/DrudgeMiner/explosive_grenade_drudge.ao",
            10
        }, -- 怪物劈砍
        {
            1,
            "Metadata/Effects/Spells/monsters_effects/Act2_FOUR/SandGolemancer/sand_tornado.ao",
            25
        }, -- 沙龍捲2
        -- 主线
        {
            1,
            "Metadata/Effects/Spells/monsters_effects/Act1_FOUR/WifeMonster/delayed_blast_01_large.ao",
            20
        }, {
            1,
            "Metadata/Effects/Spells/monsters_effects/Act2_FOUR/PerennialKing/ao/sand_tornado.ao",
            25
        }, -- 沙龍捲1
        {
            1,
            "Metadata/Effects/Spells/monsters_effects/League_Azmeri/monster_fx/vodoo_king_boss/corrupting_blood.ao",
            25
        }, -- 祭祀邪魔地上血圈
        {
            1,
            "Metadata/Effects/Spells/monsters_effects/Act3_FOUR/ViperNapuatzi/ao/spear_aura/spear_aura.ao",
            20
        }, -- 邪魔毒蛇納普阿茲
        {2,"Metadata/Effects/Spells/monsters_effects/Act4_FOUR/GreatWhiteOne/ao/piranha_puddle_01.ao", 20}, --大白鲨boss

        {2,"Metadata/Effects/Spells/monsters_effects/Act4_FOUR/TwilightOrderGuardBoss/ao/SkyBeam.ao", 30}, --勇士-卜拉克斯


        

    },

    MonitoringSkills_Sector = {
        {"Metadata/Effects/Spells/monsters_effects/League_Abyss/FarudinCorpseStrider/spike_proj_impact.ao", 40, 60, 4}, --深渊精英怪地刺
    },

    MonitoringSkills_Rect = {
        {"Metadata/Effects/Spells/monsters_effects/Act1_FOUR/FungalArtillery/ao/abysslightning_projectile_impact.ao",20,5},
        {"TCSwollenMillerCharge",95,30},
        {"TCSwollenMillerChargeEnraged",95,30},
        {"SwollenMillerSlam",95,30}
    },

    -- # 商人npc
    merchant_npc = {"烏娜"},
    sell_list = {
        "One Hand Mace", "Two Hand Mace", "Warstaff", "Wand", "Staff",
        "Crossbow", "Sceptre", "Bow", "Body Armour", "Helmet", "Gloves",
        "Boots", "Shield", "Quiver", "Focus", "Amulet", "Belt", "Ring",
        "LifeFlask", "ManaFlask", "UtilityFlask", "Buckler", "Spear"
    },

    -- # 数据结构：
    -- # k: 地图名字 v0:对应的地图名字 v1:该地图的上一地图名字 v2: 是否有传送点 0：有 1: 无 v3:在地图页面的x轴 v4:在地图页面的y轴
    task_area_list = {
        G1_1 = { {"河岸", "河岸"}, "无" },
        G1_town = { {"皆伐營地", "皆伐營地"}, "有" },
        G1_2 = { {"皆伐", "皆伐"}, "有" },
        G1_3 = { {"泥沼陋居", "泥沼陋居"}, "无" },
        G1_4 = { {"葛瑞爾林", "葛瑞爾林"}, "有" },
        G1_5 = { {"赤谷", "赤谷"}, "有" },
        G1_6 = { {"纏縛陰林", "纏縛陰林"}, "有", "纏縛陰林" },
        G1_7 = { {"不朽帝國之墓", "不朽帝國之墓"}, "有" },
        G1_8 = { {"政務官陵墓", "政務官陵墓"}, "有", "政務官陵墓" },
        G1_9 = { {"配偶的墓室", "配偶的墓室"}, "有", "配偶的墓室" },
        G1_11 = { {"獵場", "獵場"}, "有" },
        G1_12 = { {"弗雷索恩", "弗雷索恩"}, "有" },
        G1_13_1 = { {"奧格姆農地", "奧格姆農地"}, "有" },
        G1_13_2 = { {"奧格姆村", "奧格姆村"}, "有" },
        G1_14 = { {"宅第壁壘", "宅第壁壘"}, "有" },
        G1_15 = { {"奧格姆宅第", "奧格姆宅第"}, "有", "奧格姆宅第" },
        G2_1 = { {"瓦斯提里郊區", "瓦斯提里郊區"}, "有" },
        G2_town = { {"阿杜拉車隊", "阿杜拉車隊"}, "有" },
        G2_2 = { {"叛徒之路", "叛徒之路"}, "有", "叛徒之路" },
        G2_3 = { {"哈拉妮關口", "哈拉妮關口"}, "有" },
        G2_3a = { {"哈拉妮關口", "哈拉妮關口"} },
        G2_4_1 = { {"凱斯城", "凱斯城"}, "有" },
        G2_4_2 = { {"失落之城", "失落之城"}, "有", "失落之城" },
        G2_4_3 = { {"掩埋神殿", "掩埋神殿"}, "有", "掩埋神殿" },
        G2_5_1 = { {"乳齒象惡地", "乳齒象惡地"}, "有" },
        G2_5_2 = { {"骨坑", "骨坑"}, "有" },
        G2_6 = { {"泰坦之谷", "泰坦之谷"}, "有" },
        G2_7 = { {"泰坦石窟", "泰坦石窟"}, "有", "泰坦石窟" },
        G2_8 = { {"戴斯哈", "戴斯哈"}, "有" },
        G2_9_1 = { {"悼念之路", "悼念之路"}, "有" },
        G2_9_2 = { {"戴斯哈尖塔", "戴斯哈尖塔"}, "有" },
        G2_10_1 = { {"莫頓挖石場", "莫頓挖石場"}, "有" },
        G2_10_2 = { {"莫頓礦坑", "莫頓礦坑"}, "有", "莫頓礦坑" },
        G2_12_1 = { {"無畏隊", "無畏隊"}, "有" },
        G2_12_2 = { {"無畏隊先鋒", "無畏隊先鋒"}, "有" },
        G2_13 = { {"絲克瑪試煉", "絲克瑪試煉"}, "有", "絲克瑪試煉" },
        G3_1 = { {"風沙沼澤", "風沙沼澤"}, "有" },
        G3_town = { {"高地神塔營地", "高地神塔營地"}, "有" },
        G3_2_1 = { {"感染荒地", "感染荒地"}, "有" },
        G3_2_2 = { {"瑪特蘭水道", "瑪特蘭水道"}, "无" },
        G3_3 = { {"叢林遺跡", "叢林遺跡"}, "有" },
        G3_4 = { {"劇毒墓穴", "劇毒墓穴"}, "无", "劇毒墓穴" },
        G3_5 = { {"龍蜥濕地", "龍蜥濕地"}, "有" },
        G3_6_1 = { {"吉卡尼的機械迷城", "吉卡尼的機械迷城"}, "有", "吉卡尼的機械迷城" },
        G3_6_2 = { {"吉卡尼的聖域", "吉卡尼的聖域"}, "有", "吉卡尼的聖域" },
        G3_7 = { {"阿札克泥沼", "阿札克泥沼"}, "有" },
        G3_8 = { {"淹沒之城", "淹沒之城"}, "有" },
        G3_9 = { {"熔岩寶庫", "熔岩寶庫"}, "有", "熔岩寶庫" },
        G3_10_Airlock = { {"混沌神殿", "混沌神殿"}, "有", "混沌神殿" },
        G3_11 = { {"污垢頂峰", "污垢頂峰"}, "有" },
        G3_12 = { {"科佩克神殿", "科佩克神殿"}, "无", "高地神塔" },
        G3_14 = { {"奧札爾", "奧札爾"}, "有" },
        G3_16 = { {"阿戈拉", "阿戈拉"}, "有" },
        G3_17 = { {"漆黑密室", "漆黑密室"}, "有", "漆黑密室" },
        G4_town = { {"金司馬區", "金司馬區"}, "有" },
        G4_1_1 = { {"金氏島", "金氏島"}, "有" },
        G4_1_2 = { {"火山迷窟", "火山迷窟"}, "有" },
        G4_2_1 = { {"凱吉灣", "凱吉灣"}, "有" },
        G4_2_2 = { {"旅程結束", "旅程結束"}, "有" },
        G4_3_1 = { {"瓦卡帕努島", "瓦卡帕努島"}, "有" },
        G4_3_2 = { {"吟謠洞窟", "吟謠洞窟"}, "有" },
        G4_4_1 = { {"悉妮蔻拉之眼", "悉妮蔻拉之眼"}, "有" },
        G4_4_2 = { {"亡者之殿", "亡者之殿"}, "有" },
        G4_4_3 = { {"祖靈的試煉", "祖靈的試煉"}, "有" },
        G4_5_1 = { {"廢棄監獄", "廢棄監獄"}, "有" },
        G4_5_2 = { {"單獨禁閉", "單獨禁閉"}, "有" },
        G4_7 = { {"伯勞鳥之島", "伯勞鳥之島"}, "有" },
        G4_8a = { {"阿拉塔斯", "阿拉塔斯"}, "有" },
        G4_8b = { {"阿拉塔斯", "阿拉塔斯"}, "有" },
        G4_10 = { {"挖掘", "挖掘"}, "有" },
        G4_11_1a = { {"尼加卡努", "尼加卡努"}, "有" },
        G4_11_1b = { {"尼加卡努", "尼加卡努"}, "有" },
        G4_11_2 = { {"部族之心", "部族之心"}, "有" },
        P1_Town = { {"庇護所", "庇護所"}, "有" },
        P1_1 = { {"火噬農地", "火噬農地"}, "有" },
        P1_2 = { {"瑟雷之石", "瑟雷之石"}, "有" },
        P1_3 = { {"黑木林", "黑木林"}, "有" },
        P1_4 = { {"霍爾登", "霍爾登"}, "有" },
        P1_5 = { {"狼之要塞", "狼之要塞"}, "有" },
        P1_6 = { {"霍爾登宅第", "霍爾登宅第"}, "有" },
        P2_Town = { {"卡里市集", "卡里市集"}, "有" },
        P2_1 = { {"卡里交匯道", "卡里交匯道"}, "无" },
        P2_2 = { {"卡塔爾之塘", "卡塔爾之塘"}, "有" },
        P2_3 = { {"塞爾卡里庇護所", "塞爾卡里庇護所"}, "有" },
        P2_5 = { {"賈萊關口", "賈萊關口"}, "有" },
        P2_6 = { {"奇瑪", "奇瑪"}, "有" },
        P2_7 = { {"奇瑪水源地", "奇瑪水源地"}, "有" },
        P3_Town = { {"林間空地", "林間空地"}, "有" },
        P3_1 = { {"灰燼森林", "灰燼森林"}, "无" },
        P3_2 = { {"庫萊亞村", "庫萊亞村"}, "有" },
        P3_3 = { {"冰川湖泊", "冰川湖泊"}, "有" },
        P3_4 = { {"狂嗥洞穴", "狂嗥洞穴"}, "有" },
        P3_5 = { {"庫萊亞山巔", "庫萊亞山巔"}, "有" },
        P3_6 = { {"蝕刻溪谷", "蝕刻溪谷"}, "有" },
        P3_7 = { {"庫阿西克寶庫", "庫阿西克寶庫"}, "有" }
    },

    task_maps = {
        {"G1_town", {"抵達皆伐", "黑暗中的秘密", "神祕的影魅","石頭上的悲傷", "奧格姆的狂狼"}}, 
        {"G1_12", {"不祥祭壇"}}, 
        {"G2_town", {"獲得通行許可", "腐化痕跡", "石皇冠","七大水域之都", "象牙盜匪"}}, 
        {"G3_town", {"瓦爾的傳承"}}, 
        {"G3_7", {"部落復仇"}},
        {"G4_1_1",{"金氏族地"}},
        {"G4_town",{"暗黑迷霧","大搜索"}},
        {"G4_4_1",{"祖靈的試煉"}},
        {"G4_7",{"伯勞鳥之島"}}
    },


    mian_task = {
        "抵達皆伐", "黑暗中的秘密", "石頭上的悲傷",
        "神祕的影魅", '傳統的代價', "腐化痕跡",
        "奧格姆的狂狼", '遺失的魯特琴', '尋找熔爐',
        "不祥祭壇", "獲得通行許可", "腐化痕跡",
        "七大水域之都", "象牙盜匪", "石皇冠", "瓦爾的傳承",
        "部落復仇","暗黑迷霧","金氏族地","塔赫亞的考驗","祖靈的試煉",
        "伯勞鳥之島","大搜索"
    },

    type_conversion = {
        ["單手錘"] = "One Hand Mace",
        ["雙手錘"] = "Two Hand Mace",
        ["細杖"] = "Warstaff",
        ["法杖"] = "Wand",
        ["長杖"] = "Staff",
        ["十字弓"] = "Crossbow",
        ["權杖"] = "Sceptre",
        ["弓"] = "Bow",
        ["胸甲"] = "Body Armour",
        ["頭盔"] = "Helmet",
        ["手套"] = "Gloves",
        ["鞋子"] = "Boots",
        ["盾牌"] = "Shield",
        ["箭袋"] = "Quiver",
        ["法器"] = "Focus",
        ["項鍊"] = "Amulet",
        ["腰帶"] = "Belt",
        ["戒指"] = "Ring",
        ["生命藥劑"] = "LifeFlask",
        ["魔力藥劑"] = "ManaFlask",
        ["護符"] = "UtilityFlask",
        ["通貨"] = "StackableCurrency",
        ["巨靈之幣"] = "ItemisedSanctum",
        ["技能寶石"] = "UncutSkillGemStackable",
        ["精魂寶石"] = "UncutReservationGemStackable",
        ["輔助寶石"] = "UncutSupportGemStackable",
        ["主動技能寶石"] = "Active Skill Gem",
        ["任務道具"] = "QuestItem",
        ["靈魂核心"] = "SoulCore",
        ["徵兆"] = "Omen",
        ["巔峰碎片"] = "PinnacleKey",
        ["祭祀碎片"] = "MapFragment",
        ["最後通牒雕刻"] = "UltimatumKey",
        ["地圖鑰匙"] = "Map",
        ["碑牌"] = "TowerAugmentation",
        ["聖物鑰匙"] = "VaultKey",
        ["珠寶"] = "Jewel",
        ["聖物"] = "Relic",
        ["長鋒"] = "Spear",
        ["輕盾"] = "Buckler",
        ["精煉"] = "StackableCurrency",
        ["催化劑"] = "StackableCurrency",
        ["精髓"] = "StackableCurrency",
        ["符文"] = "SoulCore",
        ["魔符"] = "SoulCore",
        ["裂痕石"] = "Breachstone",
        ["深淵骸骨"] = "StackableCurrency",
        ["族裔輔助寶石"] = "Support Skill Gem"
    },

    -- # 仓库类型
    -- """
    -- 下标0 为初始坐标
    -- 下标1 为格子大小
    -- 下标2 为格子数量
    -- """
    warehouse_type = {
        ["0"] = {{14, 99}, {43.81, 43.81}, {12, 12}},
        ["1"] = {{14, 99}, {43.81, 43.81}, {12, 12}},
        ["7"] = {{14, 99}, {22, 22}, {24, 24}}
    },

    -- # 通货页对应坐标
    currency_page = {
        ["蛻變石"] = {51,150},
        ["高階蛻變石"] = {102,150},
        ["完美蛻變石"] = {153,150},
        ["增幅石"] = {51,206},
        ["高階增幅石"] = {102,206},
        ["完美增幅石"] = {153,206},
        ["富豪石"] = {51,265},
        ["高階富豪石"] = {51,265},
        ["完美富豪石"] = {51,265},
        ["崇高石"] = {51,319},
        ["高階崇高石"] = {51,319},
        ["完美崇高石"] = {51,319},
        ["混沌石"] = {51,376},
        ["高階混沌石"] = {51,376},
        ["完美混沌石"] = {51,376},
        ["點金石"] = {220,150},
        ["瓦爾寶珠"] = {277,150},  
        ["無效石"] = {335,150},
        ["機會石"] = {220,206},
        ["破裂石"] = {277,206},
        ["神聖石"] = {335,206},
        ["卡蘭德的魔鏡"] = {249,262},
        ["悉妮蔻拉的髮絲"] = {305,262},
        ["蛻變石碎片"] = {192,482},
        ["富豪石碎片"] = {247,482},
        ["工匠碎片"] = {360,482},
        ["機率碎片"] = {304,482},
        ["低階工匠石"] = {400,150},
        ["高階工匠石"] = {451,150},
        ["完美工匠石"] = {502,150},
        ["巧匠石"] = {503,203},
        ["奧術蝕刻師"] = {389,281},
        ["護甲片"] = {445,281},
        ["磨刀石"] = {502,281},
        ["玻璃彈珠"] = {445,334},
        ["寶石匠的稜鏡"] = {502,334},
        ["知識卷軸"] = {502,410},
    },

    -- # 章节名:{地图名:[[UI名,参数值],有无传送点,[一层屏幕坐标,二层屏幕坐标],二层名]}
    the_story_map = {
        ["第 1 章"] = {
            ["河岸"] = {"G1_1"},
            ["皆伐營地"] = {"G1_town"},
            ["皆伐"] = {"G1_2"},
            ["泥沼陋居"] = {"G1_3"},
            ["葛瑞爾林"] = {"G1_4"},
            ["赤谷"] = {"G1_5"},
            ["纏縛陰林"] = {"G1_6", {"纏縛陰林", "G1_6_Underground"}},
            ["不朽帝國之墓"] = {"G1_7"},
            ["政務官陵墓"] = {"G1_8", {"政務官陵墓", "G1_8_Underground"}},
            ["配偶的墓室"] = {"G1_9", {"配偶的墓室", "G1_9_Underground"}},
            ["獵場"] = {"G1_11"},
            ["奧格姆農地"] = {"G1_13_1"},
            ["奧格姆村"] = {"G1_13_2"},
            ["宅第壁壘"] = {"G1_14"},
            ["奧格姆宅第"] = {"G1_15", {"奧格姆宅第", "G1_15_Underground"}}
        },
        ["第 2 章"] = {
            ["瓦斯提里郊區"] = {"G2_1"},
            ["阿杜拉車隊"] = {"G2_town"},
            ["叛徒之路"] = {"G2_2", {"叛徒之路", "G2_2_Underground"}},
            ["哈拉妮關口"] = {"G2_3"},
            ["凱斯城"] = {"G2_4_1"},
            ["凱斯地底城"] = {"G2_4_2", {"失落之城", "G2_4_2_Underground"}},
            ["掩埋神殿"] = {"G2_4_3", {"掩埋神殿", "G2_4_3_Underground"}},
            ["乳齒象惡地"] = {"G2_5_1"},
            ["骨坑"] = {"G2_5_2"},
            ["泰坦之谷"] = {"G2_6"},
            ["泰坦石窟"] = {"G2_7", {"泰坦石窟", "G2_7_Underground"}},
            ["戴斯哈"] = {"G2_8"},
            ["悼念之路"] = {"G2_9_1"},
            ["戴斯哈尖塔"] = {"G2_9_2"},
            ["莫頓挖石場"] = {"G2_10_1"},
            ["莫頓礦坑"] = {"G2_10_2", {"莫頓礦坑", "G2_10_2_Underground"}},
            ["無畏隊"] = {"G2_12_1"},
            ["無畏隊先鋒"] = {"G2_12_2"},
            ["絲克瑪試煉"] = {"G2_13", {"絲克瑪試煉", "G2_13_Underground"}}
        },
        ["第 3 章"] = {
            ["風沙沼澤"] = {"G3_1"},
            ["高地神塔營地"] = {"G3_town"},
            ["感染荒地"] = {"G3_2_1"},
            ["瑪特蘭水道"] = {"G3_2_2"},
            ["叢林遺跡"] = {"G3_3"},
            ["劇毒墓穴"] = {"G3_4", {"劇毒墓穴", "G3_4_Underground"}},
            ["龍蜥濕地"] = {"G3_5"},
            ["吉卡尼的機械迷城"] = {"G3_6_1", {"吉卡尼的機械迷城", "G3_6_1_Underground"}},
            ["吉卡尼的聖域"] = {"G3_6_2", {"吉卡尼的聖域", "G3_6_2_Underground"}},
            ["阿札克泥沼"] = {"G3_7"},
            ["淹沒之城"] = {"G3_8"},
            ["熔岩寶庫"] = {"G3_9", {"熔岩寶庫", "G3_9_Underground"}},
            ["混沌神殿"] = {"G3_10_Airlock", {"混沌神殿", "G3_10_Airlock_Underground"}},
            ["污垢頂峰"] = {"G3_11"},
            ["科佩克神殿"] = {"G3_12", {"科佩克神殿", "G3_12_Underground"}},
            ["奧札爾"] = {"G3_14"},
            ["阿戈拉"] = {"G3_16"},
            ["漆黑密室"] = {"G3_17", {"漆黑密室", "G3_17_Underground"}},
        },
        ["<red>{第一章}"] = {
            ["河岸"] = {"C_G1_1"},
            ["皆伐營地"] = {"C_G1_town"},
            ["皆伐"] = {"C_G1_2"},
            ["泥沼陋居"] = {"C_G1_3"},
            ["葛瑞爾林"] = {"C_G1_4"},
            ["赤谷"] = {"C_G1_5"},
            ["纏縛陰林"] = {"C_G1_6", {"纏縛陰林", "C_G1_6_Underground"}},
            ["不朽帝國之墓"] = {"C_G1_7"},
            ["政務官陵墓"] = {"C_G1_8", {"政務官陵墓", "C_G1_8_Underground"}},
            ["配偶的墓室"] = {"C_G1_9", {"配偶的墓室", "C_G1_9_Underground"}},
            ["獵場"] = {"C_G1_11"},
            ["奧格姆農地"] = {"C_G1_13_1"},
            ["奧格姆村"] = {"C_G1_13_2"},
            ["宅第壁壘"] = {"C_G1_14"},
            ["奧格姆宅第"] = {"C_G1_15", {"奧格姆宅第", "C_G1_15_Underground"}}
        },
        ["<red>{第二章}"] = {
            ["瓦斯提里郊區"] = {"C_G2_1"},
            ["阿杜拉車隊"] = {"C_G2_town"},
            ["叛徒之路"] = {"C_G2_2", {"叛徒之路", "C_G2_2_Underground"}},
            ["哈拉妮關口"] = {"C_G2_3"},
            ["凱斯城"] = {"C_G2_4_1"},
            ["凱斯地底城"] = {"C_G2_4_2", {"失落之城", "C_G2_4_2_Underground"}},
            ["掩埋神殿"] = {"C_G2_4_3", {"掩埋神殿", "C_G2_4_3_Underground"}},
            ["乳齒象惡地"] = {"C_G2_5_1"},
            ["骨坑"] = {"C_G2_5_2"},
            ["泰坦之谷"] = {"C_G2_6"},
            ["泰坦石窟"] = {"C_G2_7", {"泰坦石窟", "C_G2_7_Underground"}},
            ["戴斯哈"] = {"C_G2_8"},
            ["悼念之路"] = {"C_G2_9_1"},
            ["戴斯哈尖塔"] = {"C_G2_9_2"},
            ["莫頓挖石場"] = {"C_G2_10_1"},
            ["莫頓礦坑"] = {"C_G2_10_2", {"莫頓礦坑", "C_G2_10_2_Underground"}},
            ["無畏隊"] = {"C_G2_12_1"},
            ["無畏隊先鋒"] = {"C_G2_12_2"},
            ["絲克瑪試煉"] = {"C_G2_13", {"絲克瑪試煉", "C_G2_13_Underground"}}
        },
        ["<red>{第三章}"] = {
            ["風沙沼澤（現今）"] = {"G_Endgame_G3_1"},
            ["高地神塔營地（過去）"] = {"G_Endgame_G3_town"},
            ["感染荒地（現今）"] = {"G_Endgame_G3_2_1"},
            ["瑪特蘭水道（現今）"] = {"G_Endgame_G3_2_2"},
            ["叢林遺跡（現今）"] = {"G_Endgame_G3_3"},
            ["劇毒墓穴（現今）"] = {"G_Endgame_G3_4"},
            ["龍蜥濕地（現今）"] = {"G_Endgame_G3_5"},
            ["吉卡尼的機械迷城（現今）"] = {"G_Endgame_G3_6_1"},
            ["吉卡尼的聖域（現今）"] = {"G_Endgame_G3_6_2", {"吉卡尼的聖域（現今）", "G_Endgame_G3_6_2_Underground"}},
            ["阿札克泥沼（現今）"] = {"G_Endgame_G3_7"},
            ["淹沒之城（現今）"] = {"G_Endgame_G3_8"},
            ["熔岩寶庫（現今）"] = {"G_Endgame_G3_9", {"熔岩寶庫（現今）", "G_Endgame_G3_9_Underground"}},
            ["混沌神殿（現今）"] = {"G_Endgame_G3_10_Airlock", {"混沌神殿（現今）", "G_Endgame_G3_10_Airlock_Underground"}},
            ["污垢頂峰（現今）"] = {"G_Endgame_G3_11"},
            ["科佩克神殿（現今）"] = {"G_Endgame_G3_12", {"科佩克神殿（現今）", "G_Endgame_G3_12_Underground"}},
            ["奧札爾（過去）"] = {"G_Endgame_G3_14"},
            ["阿戈拉（過去）"] = {"G_Endgame_G3_16_"},
            ["漆黑密室（過去）"] = {"G_Endgame_G3_17", {"漆黑密室（過去）", "G_Endgame_G3_17_Underground"}},
            ["高地神塔庇護所（過去）"] = {"G_Endgame_Town"}
        }
    },

    the_story_map1 = {
        ["第 1 章"] = {
            ["河岸"] = {{"河岸", "G1_1"}, false, {{628, 301}}},
            ["皆伐營地"] = {{"皆伐營地", "G1_town"}, true, {{839, 316}}},
            ["皆伐"] = {{"皆伐", "G1_2"}, true, {{730, 232}}},
            ["泥沼陋居"] = {{"泥沼陋居", "G1_3"}, false, {{655, 230}}},
            ["葛瑞爾林"] = {{"葛瑞爾林", "G1_4"}, true, {{500, 128}}},
            ["赤谷"] = {{"赤谷", "G1_5"}, true, {{345, 227}}},
            ["纏縛陰林"] = {
                {"纏縛陰林", "G1_6"}, true, {{446, 398}, {429, 329}},
                "纏縛陰林"
            },
            ["不朽帝國之墓"] = {
                {"不朽帝國之墓", "G1_7"}, true, {{279, 503}}
            },
            ["政務官陵墓"] = {
                {"政務官陵墓", "G1_8"}, true, {{185, 440}, {302, 541}},
                "政務官陵墓"
            },
            ["配偶的墓室"] = {
                {"配偶的墓室", "G1_9"}, true, {{198, 524}, {420, 730}},
                "配偶的墓室"
            },
            ["獵場"] = {{"獵場", "G1_11"}, true, {{320, 680}}},
            ["奧格姆農地"] = {
                {"奧格姆農地", "G1_13_1"}, true, {{847, 666}}
            },
            ["奧格姆村"] = {
                {"奧格姆村", "G1_13_2"}, true, {{1010, 648}}
            },
            ["宅第壁壘"] = {{"宅第壁壘", "G1_14"}, true, {{1214, 552}}},
            ["奧格姆宅第"] = {{"奧格姆宅第", "G1_15"}, true, {{1156, 514}, {1204, 752}},"奧格姆宅第"}
        },

        ["第 2 章"] = {
            ["瓦斯提里郊區"] = {
                {"瓦斯提里郊區", "G2_1"}, true, {{1025, 636}}
            },
            ["阿杜拉車隊"] = {
                {"阿杜拉車隊", "G2_town"}, true, {{963, 629}}
            },
            ["叛徒之路"] = {
                {"叛徒之路", "G2_2"}, true, {{767, 345}, {535, 432}},
                "叛徒之路"
            },
            ["哈拉妮關口"] = {
                {"哈拉妮關口", "G2_3"}, true, {{668, 307}}
            },
            -- ["哈拉妮關口"] = {{"哈拉妮關口", "G2_3a"}},
            ["凱斯城"] = {{"凱斯城", "G2_4_1"}, true, {{819, 481}}},
            ["凱斯地底城"] = {
                {"失落之城", "G2_4_2"}, true, {{939, 428}, {872, 491}},
                "失落之城"
            },
            ["掩埋神殿"] = {
                {"掩埋神殿", "G2_4_3"}, true, {{890, 366}, {745, 429}},
                "掩埋神殿"
            },
            ["乳齒象惡地"] = {
                {"乳齒象惡地", "G2_5_1"}, true, {{914, 627}}
            },
            ["骨坑"] = {{"骨坑", "G2_5_2"}, true, {{953, 689}}},
            ["泰坦之谷"] = {{"泰坦之谷", "G2_6"}, true, {{1113, 376}}},
            ["泰坦石窟"] = {
                {"泰坦石窟", "G2_7"}, true, {{1165, 353}, {1050, 425}},
                "泰坦石窟"
            },
            ["戴斯哈"] = {{"戴斯哈", "G2_8"}, true, {{344, 380}}},
            ["悼念之路"] = {{"悼念之路", "G2_9_1"}, true, {{253, 334}}},
            ["戴斯哈尖塔"] = {
                {"戴斯哈尖塔", "G2_9_2"}, true, {{197, 399}}
            },
            ["法里登挖石場"] = {
                {"莫頓挖石場", "G2_10_1"}, true, {{1355, 311}}
            },
            ["法里登鑄造廠"] = {
                {"法里登鑄造廠", "G2_10_2"}, true,
                {{1455, 319}, {1276, 256}}, "莫頓礦坑"
            },
            ["無畏隊"] = {{"無畏隊", "G2_12_1"}, true, {{405, 284}}},
            ["無畏隊先鋒"] = {
                {"無畏隊先鋒", "G2_12_2"}, true, {{300, 241}}
            },
            ["絲克瑪試煉"] = {
                {"絲克瑪試煉", "G2_13"}, true, {{583, 689}, {1085, 250}},
                "絲克瑪試煉"
            }
        },

        ["第 3 章"] = {
            ["風沙沼澤"] = {{"風沙沼澤", "G3_1"}, true, {{375, 662}}},
            ["高地神塔營地"] = {
                {"高地神塔營地", "G3_town"}, true, {{780, 581}}
            },
            ["感染荒地"] = {{"感染荒地", "G3_2_1"}, true, {{495, 340}}},
            ["瑪特蘭水道"] = {
                {"瑪特蘭水道", "G3_2_2"}, false, {{843, 367}}
            },
            ["叢林遺跡"] = {{"叢林遺跡", "G3_3"}, true, {{545, 434}}},
            ["劇毒墓穴"] = {
                {"劇毒墓穴", "G3_4"}, false, {{474, 517}, {489, 456}},
                "劇毒墓穴"
            },
            ["龍蜥濕地"] = {{"龍蜥濕地", "G3_5"}, true, {{249, 343}}},
            ["吉卡尼的機械迷城"] = {
                {"吉卡尼的機械迷城", "G3_6_1"}, true,
                {{300, 256}, {257, 485}}, "吉卡尼的機械迷城"
            },
            ["吉卡尼的聖域"] = {
                {"吉卡尼的聖域", "G3_6_2"}, true,
                {{265, 237}, {111, 367}}, "吉卡尼的聖域"
            },
            ["阿札克泥沼"] = {
                {"阿札克泥沼", "G3_7"}, true, {{754, 235}}
            },
            ["淹沒之城"] = {{"淹沒之城", "G3_8"}, true, {{915, 615}}},
            ["熔岩寶庫"] = {
                {"熔岩寶庫", "G3_9"}, true, {{920, 536}, {970, 528}},
                "熔岩寶庫"
            },
            ["混沌神殿"] = {
                {"混沌神殿", "G3_10_Airlock"}, true,
                {{153, 293}, {285, 73}}, "混沌神殿"
            },
            ["污垢頂峰"] = {{"污垢頂峰", "G3_11"}, true, {{1096, 524}}},
            ["科佩克神殿"] = {
                {"科佩克神殿", "G3_12"}, false, {{784, 698}, {830, 686}},
                "高地神塔"
            },
            ["奧札爾"] = {{"奧札爾", "G3_14"}, true, {{915, 615}}},
            ["阿戈拉"] = {{"阿戈拉", "G3_16"}, true, {{1097, 524}}},
            ["漆黑密室"] = {
                {"漆黑密室", "G3_17"}, true, {{1140, 610}, {1132, 651}},
                "漆黑密室"
            }
        },

        ["<red>{第一章}"] = {
            ["河岸"] = {{"河岸", "C_G1_1"}, false, {{628, 302}}},
            ["皆伐營地"] = {
                {"皆伐營地", "C_G1_town"}, true, {{839, 316}}
            },
            ["皆伐"] = {{"皆伐", "C_G1_2"}, true, {{853, 217}}},
            ["泥沼陋居"] = {{"泥沼陋居", "C_G1_3"}, false, {{840, 169}}},
            ["葛瑞爾林"] = {{"葛瑞爾林", "C_G1_4"}, true, {{500, 129}}},
            ["赤谷"] = {{"赤谷", "C_G1_5"}, true, {{344, 227}}},
            ["纏縛陰林"] = {
                {"纏縛陰林", "C_G1_6"}, true, {{281, 319}, {429, 329}},
                "纏縛陰林"
            },
            ["不朽帝國之墓"] = {
                {"不朽帝國之墓", "C_G1_7"}, true, {{279, 503}}
            },
            ["政務官陵墓"] = {
                {"政務官陵墓", "C_G1_8"}, true, {{185, 446}, {302, 541}},
                "政務官陵墓"
            },
            ["配偶的墓室"] = {
                {"配偶的墓室", "C_G1_9"}, true, {{162, 500}, {420, 729}},
                "配偶的墓室"
            },
            ["獵場"] = {{"獵場", "C_G1_11"}, true, {{357, 663}}},
            ["奧格姆農地"] = {
                {"奧格姆農地", "C_G1_13_1"}, true, {{848, 666}}
            },
            ["奧格姆村"] = {
                {"奧格姆村", "C_G1_13_2"}, true, {{1051, 547}}
            },
            ["宅第壁壘"] = {
                {"宅第壁壘", "C_G1_14"}, true, {{1215, 552}}
            },
            ["奧格姆宅第"] = {
                {"奧格姆宅第", "C_G1_15"}, true,
                {{1157, 515}, {1204, 752}}, "奧格姆宅第"
            }
        },

        ["<red>{第二章}"] = {
            ["瓦斯提里郊區"] = {
                {"瓦斯提里郊區", "C_G2_1"}, true, {{1111, 699}}
            },
            ["阿杜拉車隊"] = {
                {"阿杜拉車隊", "C_G2_town"}, true, {{1047, 693}}
            },
            ["叛徒之路"] = {
                {"叛徒之路", "C_G2_2"}, true, {{569, 484}, {535, 432}},
                "叛徒之路"
            },
            ["哈拉妮關口"] = {
                {"哈拉妮關口", "C_G2_3"}, true, {{531, 414}}
            },
            ["凱斯城"] = {{"凱斯城", "C_G2_4_1"}, true, {{915, 489}}},
            ["失落之城"] = {
                {"失落之城", "C_G2_4_2"}, true, {{829, 439}, {872, 491}},
                "失落之城"
            },
            ["掩埋神殿"] = {
                {"掩埋神殿", "C_G2_4_3"}, true, {{918, 362}, {744, 429}},
                "掩埋神殿"
            },
            ["乳齒象惡地"] = {
                {"乳齒象惡地", "C_G2_5_1"}, true, {{870, 635}}
            },
            ["骨坑"] = {{"骨坑", "C_G2_5_2"}, true, {{777, 729}}},
            ["泰坦之谷"] = {{"泰坦之谷", "C_G2_6"}, true, {{1112, 375}}},
            ["泰坦石窟"] = {
                {"泰坦石窟", "C_G2_7"}, true, {{1168, 353}, {1051, 425}},
                "泰坦石窟"
            },
            ["戴斯哈"] = {{"戴斯哈", "C_G2_8"}, true, {{348, 462}}},
            ["悼念之路"] = {
                {"悼念之路", "C_G2_9_1"}, true, {{225, 383}}
            },
            ["戴斯哈尖塔"] = {
                {"戴斯哈尖塔", "C_G2_9_2_"}, true, {{324, 364}}
            },
            ["莫頓挖石場"] = {
                {"莫頓挖石場", "C_G2_10_1"}, true, {{1355, 311}}
            },
            ["法里登鑄造廠"] = {
                {"法里登鑄造廠", "C_G2_10_2"}, true,
                {{1456, 318}, {1276, 256}}, "莫頓礦坑"
            },
            ["無畏隊"] = {{"無畏隊", "C_G2_12_1"}, true, {{405, 284}}},
            ["無畏隊先鋒"] = {
                {"無畏隊先鋒", "C_G2_12_2"}, true, {{300, 241}}
            },
            ["絲克瑪試煉"] = {
                {"絲克瑪試煉", "C_G2_13"}, true, {{583, 689}, {483, 631}},
                "絲克瑪試煉"
            }
        },

        ["<red>{第三章}"] = {
            ["風沙沼澤"] = {
                {"風沙沼澤（現今）", "C_G3_1"}, true, {{375, 633}}
            },
            ["高地神塔營地"] = {
                {"高地神塔營地（過去）", "C_G3_town"}, true,
                {{780, 580}}
            },
            ["感染荒地"] = {
                {"感染荒地（現今）", "C_G3_2_1"}, true, {{492, 305}}
            },
            ["瑪特蘭水道"] = {
                {"瑪特蘭水道（現今）", "C_G3_2_2"}, false, {{843, 336}}
            },
            ["叢林遺跡"] = {
                {"叢林遺跡（現今）", "C_G3_3"}, true, {{466, 468}}
            },
            ["劇毒墓穴"] = {
                {"劇毒墓穴（現今）", "C_G3_4"}, false,
                {{404, 409}, {488, 423}}, "劇毒墓穴（現今）"
            },
            ["龍蜥濕地"] = {
                {"龍蜥濕地（現今）", "C_G3_5"}, true, {{356, 306}}
            },
            ["吉卡尼的機械迷城"] = {
                {"吉卡尼的機械迷城（現今）", "C_G3_6_1"}, true,
                {{300, 225}}
            },
            ["吉卡尼的聖域"] = {
                {"吉卡尼的聖域（現今）", "C_G3_6_2"}, true,
                {{384, 194}, {111, 338}}, "吉卡尼的聖域（現今）"
            },
            ["阿札克泥沼"] = {
                {"阿札克泥沼（現今）", "C_G3_7"}, true, {{754, 205}}
            },
            ["淹沒之城"] = {
                {"淹沒之城（現今）", "C_G3_8"}, true, {{993, 668}}
            },
            ["熔岩寶庫"] = {
                {"熔岩寶庫（現今）", "C_G3_9"}, true,
                {{920, 509}, {970, 499}}, "熔岩寶庫（現今）"
            },
            ["混沌神殿"] = {
                {"混沌神殿（現今）", "C_G3_10_Airlock"}, true,
                {{152, 264}, {285, 45}}, "混沌神殿（現今）"
            },
            ["污垢頂峰"] = {
                {"污垢頂峰（現今）", "C_G3_11"}, true, {{1097, 494}}
            },
            ["科佩克神殿"] = {
                {"科佩克神殿（現今）", "C_G3_12"}, false,
                {{783, 664}, {830, 657}}, "科佩克神殿（現今）"
            },
            ["奧札爾"] = {
                {"奧札爾（過去）", "C_G3_14"}, true, {{992, 728}}
            },
            ["阿戈拉"] = {
                {"阿戈拉（過去）", "C_G3_16_"}, true, {{1097, 554}}
            },
            ["漆黑密室"] = {
                {"漆黑密室（過去）", "C_G3_17"}, true,
                {{1140, 639}, {1132, 681}}, "漆黑密室（過去）"
            },
            ["高地神塔庇護所"] = {
                {"高地神塔庇護所（過去）", "G_Endgame_Town"}, true,
                {{782, 725}}
            }
        }
    },

    not_need_identify = {
        "StackableCurrency", "ItemisedSanctum", "UncutSkillGemStackable",
        "UncutReservationGemStackable", "UncutSupportGemStackable", "Active Skill Gem",
        "Support Skill Gem", "QuestItem", "SoulCore", "Omen", "PinnacleKey",
        "MapFragment", "UltimatumKey"
    },

    map_type = {
        ["地圖頭目"] = "總督的先行者碑牌",
        ["裂痕"] = "裂痕碑牌",
        ["譫妄"] = "譫妄碑牌",
        ["照耀"] = "先行者碑牌",
        ["祭祀"] = "祭祀碑牌"
    },

    equip_type = {
        "One Hand Mace", "Two Hand Mace", "Warstaff", "Wand", "Staff",
        "Crossbow", "Sceptre", "Bow", "Body Armour", "Helmet", "Gloves",
        "Boots", "Shield", "Quiver", "Focus", "Amulet", "Belt", "Ring", "Jewel",
        "LifeFlask", "ManaFlask", "Spear", "Buckler","UtilityFlask","TowerAugmentation"
    },

    item_type_china = {
        "單手錘", "雙手錘", "細杖", "法杖", "長杖", "十字弓",
        "權杖", "弓", "胸甲", "頭盔", "手套", "鞋子", "盾牌",
        "箭袋", "法器", "項鍊", "腰帶", "戒指", "生命藥劑",
        "魔力藥劑", "珠寶", "長鋒", "輕盾","護符","碑牌"
    },

    item_size = {
        ["One Hand Mace"] = {2, 3},
        ["Two Hand Mace"] = {2, 4},
        ["Warstaff"] = {2, 4},
        ["Wand"] = {1, 3},
        ["Staff"] = {1, 4},
        ["Crossbow"] = {2, 4},
        ["Sceptre"] = {2, 3},
        ["Bow"] = {2, 4},
        ["Body Armour"] = {2, 3},
        ["Helmet"] = {2, 2},
        ["Gloves"] = {2, 2},
        ["Boots"] = {2, 2},
        ["Shield"] = {2, 4},
        ["Quiver"] = {2, 3},
        ["Focus"] = {2, 3},
        ["Amulet"] = {1, 1},
        ["Belt"] = {2, 1},
        ["Ring"] = {1, 1},
        ["LifeFlask"] = {1, 2},
        ["ManaFlask"] = {1, 2},
        ["UtilityFlask"] = {1, 1},
        ["StackableCurrency"] = {1, 1},
        ["ItemisedSanctum"] = {1, 1},
        ["UncutSkillGemStackable"] = {1, 1},
        ["UncutReservationGemStackable"] = {1, 1},
        ["UncutSupportGemStackable"] = {1, 1},
        ["Active Skill Gem"] = {1, 1},
        ["QuestItem"] = {2, 4},
        ["SoulCore"] = {1, 1},
        ["Omen"] = {1, 1},
        ["PinnacleKey"] = {1, 1},
        ["MapFragment"] = {1, 1},
        ["UltimatumKey"] = {1, 1},
        ["Map"] = {1, 1},
        ["TowerAugmentation"] = {1, 1},
        ["Jewel"] = {1, 1},
        ["Relic"] = {1, 1},
        ["Spear"] = {1, 4},
        ["Buckler"] = {2, 2},
        ["VaultKey"] = {1, 1},
        ["Support Skill Gem"] = {1, 1}
    },

    Treasure_Chest = {
        "金盒", "箱子", "生鏽箱子", "保險箱", "貨箱", "籃子",
        "雕像", "樵夫的儲物櫃", "膿包", "罐子", "寶庫",
        "被埋葬的祕寶", "裂痕君王的抑制之手", "抑制之手",
        "木桶"
    },

    first_magicProperties = {
        "復甦手下", "強化復甦手下",
        "吸取魔力和造成閃電傷害", "近接感觸", "迷霧之體"
    },


    -- # 通貨
    StackableCurrency_CN = {
        "知識卷軸","鑑定通貨","寶石匠的稜鏡","玻璃彈珠","奧術蝕刻師",
        "磨刀石","護甲片","機率碎片","工匠碎片","富豪石碎片",
        "蛻變石碎片","通貨碎片","完美工匠石","高階工匠石","低階工匠石",
        "卡蘭德的魔鏡","悉妮蔻拉的髮絲","破裂石","巧匠石","無效石",
        "機會石","神聖石","點金石","瓦爾寶珠","完美混沌石","高階混沌石",
        "混沌石","完美崇高石","高階崇高石","崇高石","完美富豪石","高階富豪石",
        "富豪石","完美蛻變石","高階蛻變石","蛻變石","完美增幅石","高階增幅石","增幅石"

    },

    -- # 鑒定通貨
    Identify_Currency_CN = {
        "知識卷軸"
    },

    -- # 譫妄異域
    Delirium_in_foreign_lands_CN = {
        "濃縮液態孤立","濃縮液態苦難","濃縮液態恐懼",
        "液態絕望","液態厭惡","液態忌妒","液態偏執",
        "稀釋的液態貪婪","稀釋的液態罪惡","稀釋的液態憤怒",
        '幻像斷片'
    },

    -- # 裂痕聯盟
    Crack_Alliance_CN = {
        "飛掠的催化劑", "混沌催化劑", "嘶鳴的催化劑",
        "掠奪的催化劑", "物理催化劑", "閃電催化劑",
        "冰冷催化劑", "火焰催化劑", "適性的催化劑",
        "甲殼的催化劑", "魔力催化劑", "生命催化劑", "裂痕石",
        "裂痕裂片"
    },

    -- # 碎片
    Fragment_CN = {
        "澤洛克的寶庫鑰匙：時空之物","澤洛克的寶庫鑰匙：絲克瑪的決意",
        "澤洛克的寶庫鑰匙：祝福之絆","澤洛克的寶庫鑰匙：沙瀑面紗",
        "澤洛克的寶庫鑰匙：力抗黑暗","仲裁者的寶庫鑰匙","奧爾羅斯的寶庫鑰匙",
        "湯馬祖的寶庫鑰匙","儀式寶庫鑰匙","試煉大師的寶庫鑰匙","烈許的寶庫鑰匙",
        "黎明寶庫鑰匙","汙染危機碎片","褻瀆危機碎片","汙穢危機碎片",
        "風化危機碎片","褪色危機碎片","遠古危機碎片","勝利之運","致命之運","怯懦之運"
    },

    -- # 死境探險
    Dead_realm_exploration_CN = {
        "異域幣鑄", "豔陽文物", "秩序文物", "黑暗血鐮文物",
        "破碎之環文物","符文斷片"
    },

    --深淵
    Abyss_CN = {
        "骷髏馬克的誘惑","右旋死靈術之兆","左旋死靈術之兆",
        "光明之兆","腐敗之兆","黑血者之兆","諸侯之兆","領主之兆",
        "深淵迴響之兆","保存良好的脊椎","保存良好的顱骨","古老的鎖骨",
        "保存良好的鎖骨","破碎的鎖骨","古老的肋骨","保存良好的肋骨",
        "破碎的肋骨","古老的顎骨","保存良好的顎骨","破碎的顎骨"
    },

    -- # 精髓
    Essence_CN = {
        "深淵精髓","錯亂精髓","極恐精髓","譫妄精髓","浮誇精髓",
        "完美豐裕精髓","完美探尋精髓","完美無限精髓","完美輕快精髓",
        "完美迅捷精髓","完美巫術精髓","完美戰鬥精髓","完美命令精髓",
        "完美毀滅精髓","完美接地精髓","完美電能精髓","完美解凍精髓",
        "完美寒冰精髓","完美隔絕精髓","完美烈焰精髓","完美磨礪精髓",
        "完美強化精髓","完美心智精髓","完美肉體精髓",
        "高階豐裕精髓","高階探尋精髓","高階輕快精髓","高階迅捷精髓",
        "高階命令精髓","高階毀滅精髓","高階巫術精髓","高階戰鬥精髓",
        "高階磨礪精髓","高階接地精髓","高階電能精髓","高階解凍精髓",
        "高階寒冰精髓","高階隔絕精髓","高階烈焰精髓","高階無限精髓",
        "高階強化精髓","高階心智精髓","高階肉體精髓",
        "豐裕精髓","探尋精髓","無限精髓","輕快精髓","迅捷精髓","巫術精髓",
        "戰鬥精髓","命令精髓","毀滅精髓","接地精髓","電能精髓","解凍精髓",
        "寒冰精髓","隔絕精髓","烈焰精髓","磨礪精髓","強化精髓","心智精髓",
        "肉體精髓","低階豐裕精髓","低階探尋精髓","低階無限精髓","低階輕快精髓",
        "低階迅捷精髓","低階巫術精髓","低階戰鬥精髓","低階命令精髓","低階毀滅精髓",
        "低階接地精髓","低階電能精髓","低階解凍精髓","低階寒冰精髓","低階隔絕精髓",
        "低階烈焰精髓","低階磨礪精髓","低階強化精髓","低階心智精髓","低階肉體精髓"
    },

    -- # 高階精髓
    High_Essence_CN = {
        "高階豐裕精髓","高階探尋精髓","高階輕快精髓",
        "高階迅捷精髓","高階命令精髓","高階毀滅精髓",
        "高階巫術精髓","高階戰鬥精髓","高階磨礪精髓",
        "高階接地精髓","高階電能精髓","高階解凍精髓",
        "高階寒冰精髓","高階隔絕精髓","高階烈焰精髓",
        "高階無限精髓","高階強化精髓","高階心智精髓","高階肉體精髓",
    },

    -- # 完美精髓
    Perfect_Essence_CN = {
        "完美豐裕精髓","完美探尋精髓","完美無限精髓",
        "完美輕快精髓","完美迅捷精髓","完美巫術精髓",
        "完美戰鬥精髓","完美命令精髓","完美毀滅精髓",
        "完美接地精髓","完美電能精髓","完美解凍精髓",
        "完美寒冰精髓","完美隔絕精髓","完美烈焰精髓",
        "完美磨礪精髓","完美強化精髓","完美心智精髓","完美肉體精髓",
    },

    -- # 已汙染的精髓
    Contaminated_Essence_CN = {
        "深淵精髓","錯亂精髓","極恐精髓","譫妄精髓","浮誇精髓",
    },

    -- # 符文
    Rune_CN = {
        "費爾羅的追擊符文",
        "費爾羅的優雅符文",
        "費努姆斯的流失符文",
        "費努姆斯的轉動符文",
        "爵士格蘭內爾的專精符文",
        "花魁蔓南的殘酷符文",
        "巨狼之爪符文",
        "薩卡瓦爾的記憶符文",
        "薩卡瓦爾的侵蝕符文",
        "伯爵夫人瑟絲可的箭術符文",
        "庫雷席安的守護符文",
        "庫雷席安的恢復符文",
        "巨狼意志符文",
        "薩卡瓦爾的天空符文",
        "流浪女巫艾珊德菈的智慧符文",
        "爵士格特的野性符文",
        "費努姆斯的苦痛符文",
        "爵士勒爾德的暖春符文",
        "赫絲緹菈的寒冬符文",
        "爵士邁爾克的盛夏符文",
        "費爾羅的狩獵符文",
        "高階崇高符文", "高階迅捷符文", "高階奉獻符文",
        "高階領導符文", "高階決心符文", "決心符文",
        "低階決心符文", "高階嫻熟符文", "嫻熟符文",
        "低階嫻熟符文", "高階堅實符文", "堅實符文",
        "低階堅實符文", "高階岩石符文", "岩石符文",
        "低階岩石符文", "高階啟發符文", "啟發符文",
        "低階啟發符文", "高階重生符文", "重生符文",
        "低階重生符文", "高階遠見符文", "遠見符文",
        "低階遠見符文", "高階心靈符文", "心靈符文",
        "低階心靈符文", "高階肉體符文", "肉體符文",
        "低階肉體符文", "高階鍛鐵符文", "鍛鐵符文",
        "低階鍛鐵符文", "高階暴風符文", "暴風符文",
        "低階暴風符文", "高階冰川符文", "冰川符文",
        "低階冰川符文", "高階沙漠符文", "沙漠符文",
        "低階沙漠符文"
    },

    -- # 補充
    -- #高階符文
    High_Rune_CN = {
        "費爾羅的追擊符文",
        "費爾羅的優雅符文",
        "費努姆斯的流失符文",
        "費努姆斯的轉動符文",
        "爵士格蘭內爾的專精符文",
        "花魁蔓南的殘酷符文",
        "巨狼之爪符文",
        "薩卡瓦爾的記憶符文",
        "薩卡瓦爾的侵蝕符文",
        "伯爵夫人瑟絲可的箭術符文",
        "庫雷席安的守護符文",
        "庫雷席安的恢復符文",
        "巨狼意志符文",
        "薩卡瓦爾的天空符文",
        "流浪女巫艾珊德菈的智慧符文",
        "爵士格特的野性符文",
        "費努姆斯的苦痛符文",
        "爵士勒爾德的暖春符文",
        "赫絲緹菈的寒冬符文",
        "爵士邁爾克的盛夏符文",
        "費爾羅的狩獵符文",
        "高階崇高符文", "高階迅捷符文", "高階奉獻符文",
        "高階領導符文", "高階決心符文"
    },

    -- # 徵兆
    Sign_CN = {
        "密室之兆","增援之兆","狩獵之兆","回應祈禱之兆","重組之兆",
        "還價之兆","博弈之兆","聖化之兆","祝福之兆","大幅提升之兆",
        "左旋結晶之兆","右旋結晶之兆","遠古之兆","機會之兆","右旋廢止之兆",
        "左旋廢止之兆","混沌數量之兆","混沌怪物之兆","混沌稀有度之兆",
        "右旋抺除之兆","左旋抺除之兆","削切之兆","催化喜悅之兆","均勻喜悅之兆",
        "右旋提升之兆","左旋提升之兆","改善之兆","腐化之兆","復興之兆",
        "刷新之兆","均勻加冕之兆","願力斷片"
    },

    -- # 靈魂核心
    SoulCore_CN = {
        "亞斯塔祖提的康復靈魂核心",
        "烏洛莫提的消減靈魂核心",
        "查莫托的狂暴靈魂核心",
        "克特帕托的流動靈魂核心",
        "提卡蒂的苦痛靈魂核心",
        "裘洛托的戰爭靈魂核心",
        "希特克拉多的腐壞靈魂核心",
        "席波卡多的支配靈魂核心",
        "柔派克的力量靈魂核心",
        "瓜特利斯的的耐久靈魂核心",
        "奧皮洛提的攻擊靈魂核心",
        "托波譚提的阻挫靈魂核心",
        "札拉提的絕緣靈魂核心",
        "哈尤席的隔熱靈魂核心",
        "艾特莫華的撤退靈魂核心",
        "艾斯卡巴靈魂核心", "智慧靈魂核心", "敏捷靈魂核心",
        "力量靈魂核心", "堤卡巴靈魂核心",
        "克特帕托靈魂核心", "柔派克靈魂核心",
        "薩摩特靈魂核心", "普希瓦爾靈魂核心",
        "希特克拉多靈魂核心", "札拉提靈魂核心",
        "吉卡尼靈魂核心", "歐派理堤靈魂核心",
        "特卡蒂靈魂核心", "塔普塔特靈魂核心"
    },

    -- # 魔符
    Sigil_CN = {
        "格羅德護符",
        "席里斯護符",
        "萊拉克許護符",
        "埃格林護符","義許塔護符","馬薩里斯護符",
        "特盧達納護符",
        "狡兔魔符", "狐狸魔符", "公牛魔符",
        "夜梟魔符", "靈貓魔符", "野狼魔符", "蝮蛇魔符",
        "野豬魔符", "雄鹿魔符", "靈長魔符", "巨熊魔符"
    },

    -- # 未切割的寶石
    UncutGemstone_CN = {
        "未切割的技能寶石（等級 20）","未切割的技能寶石（等級 19）","未切割的技能寶石（等級 18）",
        "未切割的技能寶石（等級 17）","未切割的技能寶石（等級 16）","未切割的技能寶石（等級 15）",
        "未切割的技能寶石（等級 14）","未切割的技能寶石（等級 13）","未切割的技能寶石（等級 12）",
        "未切割的技能寶石（等級 11）","未切割的技能寶石（等級 10）","未切割的技能寶石（等級 9）",
        "未切割的技能寶石（等級 8）","未切割的技能寶石（等級 7）","未切割的技能寶石（等級 6）",
        "未切割的技能寶石（等級 5）","未切割的技能寶石（等級 4）","未切割的技能寶石（等級 3）",
        "未切割的技能寶石（等級 2）","未切割的技能寶石（等級 1）",

        "未切割的精魂寶石（等級 20）","未切割的精魂寶石（等級 19）","未切割的精魂寶石（等級 18）",
        "未切割的精魂寶石（等級 17）","未切割的精魂寶石（等級 16）","未切割的精魂寶石（等級 15）",
        "未切割的精魂寶石（等級 14）","未切割的精魂寶石（等級 13）","未切割的精魂寶石（等級 12）",
        "未切割的精魂寶石（等級 11）","未切割的精魂寶石（等級 10）","未切割的精魂寶石（等級 9）",
        "未切割的精魂寶石（等級 8）","未切割的精魂寶石（等級 7）","未切割的精魂寶石（等級 6）",
        "未切割的精魂寶石（等級 5）","未切割的精魂寶石（等級 4）",

        "未切割的輔助寶石（等級 5）","未切割的輔助寶石（等級 4）",
        "未切割的輔助寶石（等級 3）","未切割的輔助寶石（等級 2）",
        "未切割的輔助寶石（等級 1）",
    },

    -- # 未切割的技能寶石
    UncutGemstoneSkill_CN = {
        "未切割的技能寶石（等級 20）","未切割的技能寶石（等級 19）","未切割的技能寶石（等級 18）",
        "未切割的技能寶石（等級 17）","未切割的技能寶石（等級 16）","未切割的技能寶石（等級 15）",
        "未切割的技能寶石（等級 14）","未切割的技能寶石（等級 13）","未切割的技能寶石（等級 12）",
        "未切割的技能寶石（等級 11）","未切割的技能寶石（等級 10）","未切割的技能寶石（等級 9）",
        "未切割的技能寶石（等級 8）","未切割的技能寶石（等級 7）","未切割的技能寶石（等級 6）",
        "未切割的技能寶石（等級 5）","未切割的技能寶石（等級 4）","未切割的技能寶石（等級 3）",
        "未切割的技能寶石（等級 2）","未切割的技能寶石（等級 1）",
    },

    -- # 未切割的保留寶石
    UncutGemstoneReserved_CN = {
        "未切割的精魂寶石（等級 20）","未切割的精魂寶石（等級 19）","未切割的精魂寶石（等級 18）",
        "未切割的精魂寶石（等級 17）","未切割的精魂寶石（等級 16）","未切割的精魂寶石（等級 15）",
        "未切割的精魂寶石（等級 14）","未切割的精魂寶石（等級 13）","未切割的精魂寶石（等級 12）",
        "未切割的精魂寶石（等級 11）","未切割的精魂寶石（等級 10）","未切割的精魂寶石（等級 9）",
        "未切割的精魂寶石（等級 8）","未切割的精魂寶石（等級 7）","未切割的精魂寶石（等級 6）",
        "未切割的精魂寶石（等級 5）","未切割的精魂寶石（等級 4）",
    },

    -- # 未切割的輔助寶石
    UncutGemstoneSupport_CN = {
        "未切割的輔助寶石（等級 5）","未切割的輔助寶石（等級 4）",
        "未切割的輔助寶石（等級 3）","未切割的輔助寶石（等級 2）",
        "未切割的輔助寶石（等級 1）",
    },

    -- # 寶石
    Gemstone_CN = {
        "艾爾卡莉之慾","仲裁者的燃灼","瓦拉什塔的祝福","柯戈的繩索",
        "澤洛克的克制","阿茲里的魅惑","Ahn's Citadel","Daresso's Passion",
        "Uhtred's Augury","Uhtred's Omen","Uhtred's Exodus","瑞佛的狂暴",
        "Tacati's Ire","卡洛翰的決心","萊基亞塔的流動","烏爾尼多的擁抱",
        "托沃的崩裂","艾許的光芒","索伏的燃焰","骷髏馬克的支配",
        "Kalisa's Crescendo","達拉的渴望","派蒂的慈悲","塔赫亞的照顧",
        "Romira's Requital","薩雷許的折磨","西奧妮的鍛鍊","Kaom's Madness",
        "亞瓊的獎章","菈妲的強襲","Doedre's Undoing","特克羅德的復仇",
        "艾里絲的管鐘","范尼達的奮進","帕科特的協議","厄羅克的鍛鍊",
        "布魯特斯的腦","Einhar's Beastrite","阿特路伊的出血",
    },

    ui_level_map = {
        ["65"] = 1,
        ["66"] = 2,
        ["67"] = 3,
        ["68"] = 4,
        ["69"] = 5,
        ["70"] = 6,
        ["71"] = 7,
        ["72"] = 8,
        ["73"] = 9,
        ["74"] = 10,
        ["75"] = 11,
        ["76"] = 12,
        ["77"] = 13,
        ["78"] = 14,
        ["79"] = 15,
        ["80"] = 16,
        ["81"] = 17,
        ["82"] = 18,
        ["83"] = 19,
        ["84"] = 20
    },

    PRIORITY_MAPS = {
        'MapBluff', 'MapAlpineRidge', 'MapMesa', 'MapSwampTower',
        'MapLostTowers', 'MapBluff_NoBoss', 'MapAlpineRidge_NoBoss',
        'MapMesa_NoBoss', 'MapSwampTower_NoBoss', 'MapLostTowers_NoBoss'
    },

    type_3_boss = {
        "白之亞瑪"
    }
}

return my_game_info
