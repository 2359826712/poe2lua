local main_task= {
    tasks_data = {
        ["<N>{<normal>{滑鼠左鍵}} 來移動。"] = {
            interaction_object = {"受傷的男人"},
            index = 1
        },
        ["與受傷的居民交談"] = {
            interaction_object = {"受傷的男人"},
            index = 2
        },
        ["找到皆伐"] = {
            map_name = "G1_1",
            index = 3
        },
        ["尋找米勒，並在皆伐尋求庇護"] = {
            map_name = "G1_1",
            Boss = {"浮腫米勒"},
            interaction_object_map_name = {"MillerActive","G1_town"},
            index = 4
        },
        ['擊殺浮腫米勒並終止他的怒火'] = {
            map_name = "G1_1",
            Boss = {"浮腫米勒"},
            interaction_object_map_name = {"MillerActive"},
            index = 5
        },
        ["進入伐木營地"] = {
            map_name = "G1_1",
            interaction_object = {"皆伐營地"},
            interaction_object_map_name = {"G1_town"},
            index = 6
        },
        ["與鐵匠交談"] = {
            map_name = "G1_town",
            interaction_object = {"倫利"},
            grid_x = 386,
            grid_y = 397,
            index = 7
        },
        ["領取倫利的獎勵"] = {
            map_name = 'G1_town',
            interaction_object = {"倫利", "米勒的憐憫獎勵"},
            grid_x = 396,
            grid_y = 360,
            index = 8
        },
        ["穿過皆伐營地前往葛瑞爾林"] = {
            map_name = 'G1_2',
            interaction_object = {'葛瑞爾林','凜冬狼的頭顱'},
            Boss = {'腐敗獸群．貝伊拉'},
            interaction_object_map_name = {'G1_4','CroneActive'},
            index = 9
        },
        ["在葛瑞爾林尋找伯爵行動的證據"] = {
            map_name = 'G1_4',
            interaction_object = {'召喚烏娜'},
            index = 10
        },
        ["召喚烏娜並詢問她關於樹上的古老存在的事情"] = {
            map_name = 'G1_4',
            interaction_object = {'召喚烏娜','烏娜'},
            interaction_object_map_name = {'Waypoint'},
            index = 11
        },
        ["在原始密林尋找赤谷入口"] = {
            map_name = 'G1_5',
            interaction_object = {'赤谷'},
            index = 12
        },
        ["在葛瑞爾林尋找赤谷入口在赤谷尋找含有力量魔符的鐵鏽方尖碑"] = {
            map_name = 'G1_5',
            interaction_object = {'赤谷'},
            index = 13
        },
        ["將鍛造好的魔符尖矢交給原始密林中的黑衣幽魂"] = {
            map_name = 'G1_town',
            interaction_object = {'倫利','拿取魔符尖刺'},
            grid_x = 394,
            grid_y = 363,
            index = 14
        },
        ["跟倫利領取鍛造好的魔符尖矢"] = {
            map_name = 'G1_town',
            interaction_object = {'倫利','取得魔符尖刺'},
            grid_x = 394,
            grid_y = 363,
            index = 15
        },
        ["赤谷"] = {
            map_name = 'G1_5',
            interaction_object = {'赤谷'},
            index = 16
        },
        ["調查鐵鏽方尖碑收集力量魔符"] = {
            map_name = 'G1_5',
            interaction_object = {'鐵鏽方尖碑'},
            interaction_object_map_name = {'RustObeliskActive'},
            index = 17
        },
        ["尋找3個力量魔符"] = {
            map_name = 'G1_5',
            interaction_object = {'鐵鏽方尖碑'},
            interaction_object_map_name = {'RustObeliskActive'},
            index = 18
        },
        ["收集全部3個力量魔符"] = {
            map_name = 'G1_5',
            interaction_object = {'鐵鏽方尖碑'},
            interaction_object_map_name = {'RustObeliskActive'},
            index = 19
        },
        ["擊敗鐵鏽之王取得最後一個力量魔符。"] = {
            map_name = 'G1_5',
            interaction_object = {'鐵鏽方尖碑'},
            interaction_object_map_name = {'RustObeliskActive'},
            index = 20
        },
        ["收集剩餘的2個力量魔符"] = {
            map_name = 'G1_5',
            Boss = {'鐵鏽之王'},
            interaction_object = {'鐵鏽方尖碑'},
            interaction_object_map_name = {'RustObeliskActive'},
            index = 21
        },
        ["擊敗守護力量魔符的怪物。"] = {
            map_name = 'G1_5',
            interaction_object = {'鐵鏽方尖碑'},
            interaction_object_map_name = {'RustObeliskActive'},
            index = 22
        },
        ["收集最後一個力量魔符"] = {
            map_name = 'G1_5',
            interaction_object = {'鐵鏽方尖碑'},
            interaction_object_map_name = {'RustObeliskActive'},
            index = 23
        },
        ["將魔符交給倫利鍛造"] = {
            map_name = 'G1_5',
            Boss = {'鐵鏽之王'},
            interaction_object = {'鐵鏽方尖碑'},
            interaction_object_map_name = {'RustObeliskActive'},
            index = 24
        },
        ["皆伐營地"] = {
            map_name = 'G1_town',
            index = 25
        },
        ["返回皆伐營地並與烏娜交談"] = {
            map_name = 'G1_town',
            interaction_object = {'烏娜'},
            grid_x = 327,
            grid_y = 324,
            index = 26
        },
        ["返回皆伐營地與烏娜交談"] = {
            map_name = 'G1_town',
            interaction_object = {'烏娜'},
            grid_x = 327,
            grid_y = 324,
            index = 27
        },
        ["葛瑞爾林"] = {
            map_name = 'G1_4',
            index = 28
        },
        ['將魔符尖矢戳進攝魂之樹'] = {
            map_name = 'G1_4',
            interaction_object = {'符文之印'},
            index = 29
        },
        ['將剩餘2根魔符尖矢戳進攝魂之樹'] = {
            map_name = 'G1_4',
            interaction_object = {'符文之印'},
            interaction_object_map_name = {'Checkpoint'}, 
            index = 30
        },
        ['將最後一根魔符尖矢戳進攝魂之樹'] = {
            map_name = 'G1_4',
            interaction_object = {'符文之印'},
            interaction_object_map_name = {'Checkpoint'},
            index = 31
        },
        ['尋找葛瑞爾林中的纏縛陰林入口'] = {
            map_name = 'G1_6',
            index = 32
        },
        ['返回葛瑞爾林中的纏縛陰林入口'] = {
            map_name = 'G1_6',
            interaction_object = {'纏縛陰林'},
            index = 33
        },
        ['繼續穿過纏縛陰林'] = {
            map_name = 'G1_6',
            Boss = {'腐敗的德魯伊'},
            interaction_object = {'不朽帝國之墓'},
            interaction_object_map_name = {'G1_7'},
            index = 34
        },
        ['纏縛陰林'] = {
            map_name = 'G1_6',
            index = 35
        },
        ['穿過纏縛陰林'] = {
            map_name = 'G1_6',
            index = 36
        },
        ['召喚烏娜，請她協助清除根鬚'] = {
            map_name = 'G1_6',
            interaction_object = {'召喚烏娜'},
            index = 37
        },
        ['與烏娜談論根鬚'] = {
            map_name = 'G1_6',
            interaction_object = {'烏娜'},
            index = 38
        },
        ['在不朽帝國之墓尋找配偶的墓室和陵墓'] = {
            map_name = 'G1_9',
            index = 39
        },
        ['探索配偶的墓室，尋找德雷文和他的配偶'] = {
            map_name = 'G1_9',
            Boss = {'政務官配偶．阿席妮雅'},
            interaction_object = {'政務官配偶．阿席妮雅'},
            interaction_object_map_name = {'WifeActive', 'WifeInactive'},
            index = 40
        },
        ['調查陵墓，尋找拉克朗的家人'] = {
            map_name = 'G1_9',
            Boss = {'政務官配偶．阿席妮雅'},
            interaction_object = {'政務官配偶．阿席妮雅'},
            interaction_object_map_name = {'WifeActive', 'WifeInactive'},
            index = 41
        },
        ['消滅阿席妮雅'] = {
            map_name = 'G1_9',
            Boss = {'政務官配偶．阿席妮雅'},
            interaction_object = {'政務官配偶．阿席妮雅'},
            interaction_object_map_name = {'WifeActive', 'WifeInactive'},
            index = 42
        },
        ['拾起阿席妮雅的紀念鑰匙碎片'] = {
            map_name = 'G1_9',
            Boss = {'政務官配偶．阿席妮雅'},
            interaction_object_map_name = {'WifeActive', 'WifeInactive'},
            interaction_object = {'阿席妮雅的回憶之鑰碎片'},
            index = 43
        },
        ['政務官陵墓'] = {
            map_name = 'G1_8',
            index = 44
        },
        ['配偶的墓室'] = {
            map_name = 'G1_9',
            index = 45
        },
        ['返回不朽帝國之墓並尋找德雷文'] = {
            map_name = 'G1_8',
            index = 46
        },
        ['在靜縊陵墓中尋找德雷文政務官。'] = {
            map_name = 'G1_8',
            Boss = {'永恆政務官．德雷文'},
            interaction_object = {'德雷文的回憶之鑰碎片'},
            interaction_object_map_name = {'HusbandActive', 'HusbandInactive'},
            index = 47
        },
        ['在靜縊陵墓中尋找政務官德雷文'] = {
            map_name = 'G1_8',
            Boss = {'永恆政務官．德雷文'},
            interaction_object = {'德雷文的回憶之鑰碎片'},
            interaction_object_map_name = {'HusbandActive', 'HusbandInactive'},
            index = 48
        },
        ['在陵墓尋找拉克朗的妻子'] = {
            map_name = 'G1_8',
            Boss = {'永恆政務官．德雷文'},
            interaction_object = {'德雷文的回憶之鑰碎片'},
            interaction_object_map_name = {'HusbandActive', 'HusbandInactive'},
            index = 49
        },
        ['消滅永恆政務官．德雷文'] = {
            map_name = 'G1_8',
            Boss = {'永恆政務官．德雷文'},
            interaction_object_map_name = {'HusbandActive', 'HusbandInactive'},
            interaction_object = {'德雷文的回憶之鑰碎片'},
            index = 50
        },
        ['消滅德雷文政務官'] = {
            map_name = 'G1_8',
            Boss = {'永恆政務官．德雷文'},
            interaction_object_map_name = {'HusbandActive', 'HusbandInactive'},
            interaction_object = {'德雷文的回憶之鑰碎片'}, 
            index = 51
        },
        ['拾起德雷文的紀念鑰匙碎片'] = {
            map_name = 'G1_8',
            Boss = {'永恆政務官．德雷文'},
            interaction_object_map_name = {'HusbandActive', 'HusbandInactive'},
            interaction_object = {'德雷文的回憶之鑰碎片'},
            index = 52
        },
        ['在配偶的墓室中尋找阿席妮雅'] = {
            map_name = 'G1_9',
            Boss = {'政務官配偶．阿席妮雅'},
            interaction_object = {'WifeActive', 'WifeInactive'},
            interaction_object_map_name = {'WifeActive', 'WifeInactive'},
            index = 53
        },
        ['消滅政務官配偶．阿席妮雅'] = {
            map_name = 'G1_9',
            Boss = {'政務官配偶．阿席妮雅'},
            interaction_object_map_name = {'WifeActive', 'WifeInactive'},
            interaction_object = {'阿席妮雅的回憶之鑰碎片'},
            index = 54
        },
        ['不朽帝國之墓'] = {
            map_name = 'G1_7',
            index = 55
        },
        ['返回不朽帝國之墓並打開紀念之門'] = {
            map_name = 'G1_7',
            interaction_object = {'紀念之門'},
            index = 56
        },
        ['返回墓地與拉克朗交談'] = {
            map_name = 'G1_7',
            Boss = {'無盡悲歌的拉克朗'},
            interaction_object = {'迷克朗'},
            interaction_object_map_name = {'GraveyardBossActive', 'GraveyardBossInactive'},
            index = 57
        },
        ['跟隨拉克朗'] = {
            map_name = 'G1_7',
            Boss = {'無盡悲歌的拉克朗'},
            interaction_object = {'拉克朗伯爵的戒指'},
            interaction_object_map_name = {'GraveyardBossActive', 'GraveyardBossInactive','拉克朗'},
            index = 58
        },
        ['讓拉克朗安息'] = {
            map_name = 'G1_7',
            Boss = {'無盡悲歌的拉克朗'},
            interaction_object = {'拉克朗伯爵的戒指'},
            interaction_object_map_name = {'GraveyardBossActive', 'GraveyardBossInactive','拉克朗'},
            index = 59
        },
        ['穿過紀念之門後，搜尋伯爵之墓'] = {
            map_name = 'G1_7',
            interaction_object = {'迷失者．拉克朗'},
            Boss = {'無盡悲歌的拉克朗'},
            interaction_object_map_name = {'GraveyardBossActive', 'GraveyardBossInactive'},
            index = 60
        },
        ['將拉克朗伯爵的戒指交給烏娜'] = {
            map_name = 'G1_town',
            grid_x = 312,
            grid_y = 327,
            interaction_object = {'烏娜'},
            index = 61
        },
        ['見證黑衣幽魂的復活'] = {
            map_name = 'G1_town',
            grid_x = 312,
            grid_y = 327,
            interaction_object = {'烏娜', '黑衣幽魂'},
            index = 62
        },
        ['進入獵場'] = {
            map_name = 'G1_13_1',
            index = 63
        },
        ['獵場'] = {
            map_name = 'G1_13_1',
            index = 64
        },
        ['奧格姆農地'] = {
            map_name = 'G1_13_1',
            interaction_object = {'奧格姆村'},
            interaction_object_map_name = {'G1_13_2'},
            index = 65
        },
        ['與烏娜交談以獲得獎勵'] = {
            map_name = 'G1_town',
            grid_x = 336,
            grid_y = 306,
            interaction_object = {'烏娜','遺失的魯特琴獎勵'},
            index = 66
        },
        ['在奧格姆農地尋找烏娜的魯特琴'] = {
            map_name = 'G1_13_1',
            interaction_object = {'烏娜的魯特琴盒','烏娜的魯特琴'},
            interaction_object_map_name = {'FarmlandsUnasHutLandmarkActive'},
            index = 67
        },
        ['找到村莊入口'] = {
            map_name = 'G1_13_1',
            interaction_object = {'奧格姆村','烏娜的魯特琴盒','烏娜的魯特琴'},
            interaction_object_map_name = {'G1_13_2','FarmlandsUnasHutLandmarkActive'},
            index = 68
        },
        ['在皆伐與蕾堤絲交談'] = {
            map_name = 'G1_town',
            interaction_object = {'蕾堤絲'},
            grid_x = 368,
            grid_y = 306,
            index = 69
        },
        
        ['搜尋腐化種子'] = {
            map_name = 'G1_13_2',
            interaction_object = {'ExecutionerActive'},
            interaction_object_map_name = {'ExecutionerActive', 'ExecutionerInactive'},
            index = 70
        },
        ['殺死劊子手'] = {
            map_name = 'G1_13_2',
            Boss = {'劊子手'},
            interaction_object = {'ExecutionerActive'},
            interaction_object_map_name = {'ExecutionerActive', 'ExecutionerInactive'},
            index = 71
        },
        ['釋放囚犯'] = {
            map_name = 'G1_13_2',
            interaction_object = {'把手','蕾堤絲'},
            Boss = {'劊子手'},
            interaction_object_map_name = {'G1_14'},
            index = 72
        },
        ['與蕾堤絲交談'] = {
            map_name = 'G1_13_2',
            interaction_object = {'蕾堤絲'},
            interaction_object_map_name = {'G1_14'},
            index = 73
        },
        ['將工具帶回給倫利'] = {
            map_name = 'G1_town',
            interaction_object = {'倫利'},
            grid_x = 386,
            grid_y = 397,
            index = 74
        },
        ['找到倫利的工具'] = {
            map_name = 'G1_13_2',
            interaction_object = {'鍛造工具'},
            index = 75
        },
        ['奧格姆村'] = {
            map_name = 'G1_13_2',
            index = 76
        },
        ['奧格姆宅第'] = {
            map_name = 'G1_15',
            index = 78
        },
        ['返回皆伐營地並與黑衣幽魂交談'] = {
            map_name = 'G1_town',
            grid_x = 359,
            grid_y = 288,
            interaction_object = {'黑衣幽魂'},
            index = 77
        },
        ['潛入村外的宅第奧格姆伯爵'] = {
            map_name = 'G1_15', 
            interaction_object = {'奧格姆宅第'},
            index = 79
        },
        ['在宅第中尋找奧格姆伯爵'] = {
            map_name = 'G1_15',
            interaction_object = {'瘋狂讚美詩','燭光精髓'},
            Boss = {'吉恩諾伯爵', '腐敗巨狼．吉恩諾','存活儀式．燭光'},
            interaction_object_map_name = {'GargoyleActive'},
            index = 80
        },
        ['擊殺奧格姆伯爵'] = {
            map_name = 'G1_15',
            Boss = {'吉恩諾伯爵', '腐敗巨狼．吉恩諾'},
            index = 81
        },
        
        ['前往東邊'] = {
            map_name = 'G1_town',
            interaction_object = {'黑衣幽魂', '追尋巨獸的蹤跡'},
            grid_x = 383,
            grid_y = 274,
            index = 82
        },
        ['尋找祭祀神壇並淨化它們'] = {
            map_name = 'G1_12',
            Boss={'迷霧之王'},
            interaction_object = {' 祭祀神壇'},
            index = 83
        },
        ['擊敗迷霧之王'] = {
            map_name = 'G1_12',
            Boss={'迷霧之王'},
            interaction_object = {' 祭祀神壇','寶石花顱骨'},
            index = 84
        },
        ['與費恩交談以獲取獎勵'] = {
            map_name = 'G1_town',
            grid_x = 312,
            grid_y = 327,
            interaction_object = {'費恩','不祥祭壇獎勵','寶石花顱骨'},
            index = 85
        },
        ['向阿薩拉詢問關於巨獸的消息'] = {
            map_name = 'G2_town',
            interaction_object = {'絲克瑪．阿薩拉'},
            grid_x = 573,
            grid_y = 272,
            index = 86
        },
        ["瓦斯提里郊區"] = {
            map_name = 'G2_1',
            index = 87
        },
        ['與黑衣幽魂對話'] = {
            map_name = 'G2_1',
            index = 87
        },
        ['與車隊負責人交談'] = {
            map_name = 'G2_1',
            interaction_object = {'RathbreakerActive'},
            interaction_object_map_name = {'RathbreakerActive'},
            index = 88
        },
        ['找出鬣狗劫匪並消滅他們'] = {
            map_name = 'G2_1',
            Boss = {'撕裂者'},
            interaction_object = {'RathbreakerActive'},
            interaction_object_map_name = {'RathbreakerActive', 'RathbreakerInactive'},
            index = 89
        },
        ['找到鬣狗劫匪並消滅他們'] = {
            map_name = 'G2_1',
            Boss = {'撕裂者'},
            interaction_object = {'RathbreakerActive'},
            interaction_object_map_name = {'RathbreakerActive', 'RathbreakerInactive'},
            index = 90
        },
        ['擊敗撕裂者'] = {
            map_name = 'G2_1',
            Boss = {'撕裂者'},
            interaction_object = {'RathbreakerActive'},
            interaction_object_map_name = {'RathbreakerActive', 'RathbreakerInactive'},
            index = 91
        },
        ['和札卡交談'] = {
            map_name = 'G2_1',
            interaction_object = {'札卡'},
            interaction_object_map_name = {'札卡'},
            index = 92
        },
        ['登上車隊，與你救出的馬拉克斯血脈見面'] = {
            map_name = 'G2_1',
            interaction_object = {'札卡', '阿杜拉車隊'},
            interaction_object_map_name = {'StashPlayer'},
            index = 93
        },
        ['進入阿杜拉車隊'] = {
            map_name = 'G2_1',
            interaction_object = {'阿杜拉車隊'},
            interaction_object_map_name = {'G2_town'},
            index = 94
        },
        ['與阿杜拉車隊一同前往報告中的腐化之地'] = {
            map_name = 'G2_10_1',
            index = 95
        },
        ['使用貧脊之地的地圖前往莫頓挖石場所在之處'] = {
            map_name = 'G2_10_1',
            index = 96
        },
        ['探索莫頓挖石場'] = {
            map_name = 'G2_10_1',
            interaction_object = {'莫頓礦坑'},
            interaction_object_map_name = {'G2_10_2'},
            index = 97
        },
        ['莫頓挖石場'] = {
            map_name = 'G2_10_1',
            index = 98
        },
        ['進入法里登鑄造廠'] = {
            map_name = 'G2_10_2',
            index = 99
        },
        ['莫頓礦坑'] = {
            map_name = 'G2_10_2',
            index = 100
        },
        ['調查法里登鑄造廠'] = {
            map_name = 'G2_10_2',
            interaction_object = {'Rudjaive'},
            interaction_object_map_name = {'RudjaActive'},
            index = 101
        },
        ['擊敗恐懼工程師．魯賈'] = {
            map_name = 'G2_10_2',
            Boss = {'恐懼工程師．魯賈'},
            interaction_object = {'Rudjaive'}, 
            interaction_object_map_name = {'RudjaActive'},
            index = 102
        },
        ['探索廢棄挖石場'] = {
            map_name = 'G2_10_2',
            interaction_object_map_name = {'法里登叛變者．芮蘇', 'RudjaInactive'},
            interaction_object = {'法里登叛變者．芮蘇'},
            index = 103
        },
        ['使用貧脊之地的地圖前往哈拉妮關口所在之處'] = {
            map_name = 'G2_town',
            special_map_point = {587,733},
            grid_x = 586,
            grid_y = 723,
            interaction_object = {'哈拉妮關口', '絲克瑪．阿薩拉'},
            index = 104
        },
        ['審問法里登的叛變者'] = {
            map_name = 'G2_town',
            interaction_object = {'芮蘇'},
            grid_x = 573,
            grid_y = 272,
            index = 105
        },
        ['調查鍊金房'] = {
            map_name = 'G2_town',
            interaction_object = {'芮蘇'},
            grid_x = 573,
            grid_y = 272,
            index = 106
        },
        ['返回車隊的領路車處，詢問在那裡的叛變者'] = {
            map_name = 'G2_town',
            grid_x = 573,
            grid_y = 272,
            interaction_object = {'芮蘇'},
            index = 107
        },
        ['返回車隊，與芮蘇討論古老關口'] = {
            map_name = 'G2_town',
            grid_x = 573,
            grid_y = 272,
            interaction_object = {'芮蘇'},
            index = 108
        },
        ['和阿薩拉談談關於芮蘇的情報'] = {
            map_name = 'G2_town',
            grid_x = 573,
            grid_y = 272,
            interaction_object = {'絲克瑪．阿薩拉'},
            index = 109
        },
        ['使用貧脊之地的地圖前往叛徒之路'] = {
            map_name = 'G2_2',
            index = 110
        },
        ['叛徒之路'] = {
            map_name = 'G2_2',
            index = 111
        },
        ['返回車隊，與芮蘇討論封閉的古老關口'] = {
            map_name = 'G2_2',
            interaction_object = {'哈拉妮關口','古代封印','符文之印'},
            Boss = {'叛徒芭芭拉'},
            interaction_object_map_name = {'G2_3'},
            index = 112
        },
        ['前往古老關口'] = {
            map_name = 'G2_2',
            index = 113
        },
        ['返回阿杜拉車隊，並與札卡交談'] = {
            map_name = 'G2_town',
            grid_x = 384,
            grid_y = 247,
            interaction_object = {'札卡', '驅散沙戮風暴'},
            index = 114
        },
        ['哈拉妮關口'] = {
            map_name = 'G2_3',
            index = 115
        },
        ['沿著叛徒之路向上，抵達古老關口頂端'] = {
            map_name = 'G2_3',
            Boss = {'崛起之王．賈嫚拉'},
            interaction_object = {'召喚阿薩拉'},
            interaction_object_map_name = {
                'PerennialHumanActive',
                'PerennialHumanInactive',
            },
            index = 116
        },
        ['想辦法和阿薩拉一起開啟古老關口'] = {
            map_name = 'G2_3',
            Boss = {'崛起之王．賈嫚拉'},
            interaction_object = {'Per'},
            interaction_object_map_name = {
                'PerennialHumanActive',
                'PerennialHumanInactive',
            },
            index = 117
        },
        ['一路殺向第二道關口並開啟它'] = {
            map_name = 'G2_3',
            Boss = {'崛起之王．賈嫚拉'},
            interaction_object = {'Per'},
            interaction_object_map_name = {
                'PerennialHumanActive',
                'PerennialHumanInactive',
            },
            index = 118
        },
        ['一路殺向第三道關口並開啟它'] = {
            map_name = 'G2_3',
            Boss = {'崛起之王．賈嫚拉'},
            interaction_object = {'Per'},  
            interaction_object_map_name = {
                'PerennialHumanActive',
                'PerennialHumanInactive',
            },
            index = 119
        },
        ['殺出一條向前的路'] = {
            map_name = 'G2_3',
            Boss = {'崛起之王．賈嫚拉'},
            interaction_object = {'Per'},  
            interaction_object_map_name = {
                'PerennialHumanActive',
                'PerennialHumanInactive',
            },
            index = 120
        },
        ['幫助阿薩拉擊殺法里登的腐化首領'] = {
            map_name = 'G2_3',
            Boss = {'崛起之王．賈嫚拉'},
            interaction_object = {'Per'},  
            interaction_object_map_name = {
                'PerennialHumanActive',
                'PerennialHumanInactive',
            },
            index = 121
        },
        ['協助阿薩拉殺死法里登的腐化首領'] = {
            map_name = 'G2_town',
            grid_x = 573,
            grid_y = 272,
            interaction_object = {'絲克瑪．阿薩拉'},
            index = 122
        },
        ['返回車隊，與札卡交談'] = {
            map_name = 'G2_town',
            grid_x = 573,
            grid_y = 272,
            interaction_object = {'絲克瑪．阿薩拉'},
            index = 123
        },
        ['使用貧脊之地的地圖前往凱斯城所在之處'] = {
            map_name = 'G2_4_1',
            index = 124
        },
        ['前往失落的凱斯城'] = {
            map_name = 'G2_4_1',
            interaction_object = {'失落之城'},
            Boss = {'異界．干擾女王．卡巴拉'},
            interaction_object_map_name = {'G2_4_2','KabalaActive'},
            index = 125
        },
        ['凱斯城'] = {
            map_name = 'G2_4_1',
            interaction_object = { "卡巴拉部落聖物" },
            index = 126
        },
        ['在沙堆中找到失落的凱斯城的入口'] = {
            map_name = 'G2_4_1',
            Boss = {'異界．干擾女王．卡巴拉'},
            interaction_object = {'失落之城'},
            interaction_object_map_name = {'G2_4_2','KabalaActive'},
            index = 127
        },
        ['失落之城'] = {
            map_name = 'G2_4_2',
            index = 128
        },
        ['找出埋在黃沙之下的凱斯城入口'] = {
            map_name = 'G2_4_2',
            interaction_object = {'掩埋神殿', '門'},
            interaction_object_map_name = {'G2_4_3'},
            index = 129
        },
        ['掩埋神殿'] = {
            map_name = 'G2_4_3',
            index = 130
        },
        ['在凱斯城中心尋找聖域'] = {
            map_name = 'G2_4_3', 
            interaction_object = {'凱斯之心', '哈拉妮神殿','門'},
            Boss = {'遺忘之子．阿齊瑞爾'},
            interaction_object_map_name = {'大廳'},
            index = 131
        },
        ['擊敗遺忘之子．阿薩里恩以獲得水之精髓'] = {
            map_name = 'G2_4_3',
            Boss = {'遺忘之子．阿齊瑞爾'},
            interaction_object = {'凱斯之心', '哈拉妮神殿','門','水之女神','水之女神．哈拉妮','無盡熾炎', '點燃女神'},
            interaction_object_map_name = {'大廳'},
            index = 132
        },
        ['消滅遺忘之子，取得水之精髓'] = {
            map_name = 'G2_4_3',
            Boss = {'遺忘之子．阿齊瑞爾'},
            interaction_object = {'凱斯之心', '哈拉妮神殿','門','水之女神','水之女神．哈拉妮','無盡熾炎', '點燃女神'},
            index = 133
        },
        ['與水之女神交談，看看能否幫上祂的忙'] = {
            map_name = 'G2_4_3',
            Boss = {'遺忘之子．阿齊瑞爾'},
            interaction_object = {'凱斯之心', '哈拉妮神殿','門','水之女神','水之女神．哈拉妮','無盡熾炎', '點燃女神'},
            index = 134
        },
        ['見證水之女神的安息'] = {
            map_name = 'G2_4_3',
            Boss = {'遺忘之子．阿齊瑞爾'},
            interaction_object = {'凱斯之心', '哈拉妮神殿','門','水之女神','水之女神．哈拉妮','無盡熾炎', '點燃女神'},
            index = 135
        },
        ['使用永燃燼火讓水之女神安息'] = {
            map_name = 'G2_4_3',
            interaction_object = {'凱斯之心', '哈拉妮神殿','門','水之女神','水之女神．哈拉妮','無盡熾炎', '點燃女神'},
            index = 136
        },
        ['拾取水之精髓'] = {
            map_name = 'G2_4_3',
            Boss = {'遺忘之子．阿齊瑞爾'},
            interaction_object = {'凱斯之心', '哈拉妮神殿','門','水之女神','水之女神．哈拉妮','無盡熾炎', '點燃女神'},
            index = 137
        },
        ['前往乳齒象惡地'] = {
            map_name = 'G2_5_1',
            index = 138
        },
        ['乳齒象惡地'] = {
            map_name = 'G2_5_1',
            index = 139
        },
        ['在乳齒象惡地尋找骨坑入口'] = {
            map_name = 'G2_5_1',
            interaction_object = {'骨坑'},
            interaction_object_map_name = {'G2_5_2'},
            index = 140
        },
        ['在骨坑尋找乳齒象象牙'] = {
            map_name = 'G2_5_2',
            interaction_object = {'MastodonActive'},
            interaction_object_map_name = {'MastodonActive', 'MastodonInactive'},
            index = 141
        },
        ['骨坑'] = {
            map_name = 'G2_5_2',
            interaction_object = {'太陽部落聖物'},
            index = 142
        },
        ['擊敗遠古之蹄．埃克巴勃和死亡領主．伊克塔，然後取回象牙'] = {
            map_name = 'G2_5_2',
            Boss = {'遠古之蹄．埃克巴勃','死亡領主．伊克塔'},
            interaction_object = {'MastodonActive'},
            interaction_object_map_name = {'MastodonActive', 'MastodonInactive'},
            index = 143
        },
        ['取回象牙'] = {
            map_name = 'G2_5_2',
            interaction_object = {'乳齒象象牙'},
            interaction_object_map_name = {'MastodonActive', 'MastodonInactive'},
            index = 144
        },
        ['返回阿杜拉車隊並與札卡交談']= {
            map_name= 'G2_town',
            grid_x= 384,
            grid_y= 247,
            interaction_object= {'札卡', '七大水域之都獎勵'},
            index = 145
        },
        ['收下交還水之精髓的獎勵。']= {
            map_name= 'G2_town',
            grid_x= 384,
            grid_y= 247,
            interaction_object= {'札卡', '七大水域之都獎勵'},
            index = 146
        },
        ['跟札卡拿取乳齒象象牙的獎勵']= {
            map_name= 'G2_town',
            grid_x= 381,
            grid_y= 238,
            interaction_object= {'札卡', '象牙盜匪獎勵'},
            index = 147
        },
        ['使用貧脊之地的地圖前往泰坦之谷所在之處']= {
            map_name= 'G2_6',
            index = 148
        },
        ['泰坦之谷']= {
            map_name= 'G2_6',
            index = 149
        },
        ['在泰坦之谷底下找出進入泰坦石窟的通道']= {
            map_name= 'G2_6',
            interaction_object= {'古代封印'},
            interaction_object_map_name= {'TitanRuneActive'},
            index = 150
        },
        ['找到並啟動更多遠古封印']= {
            map_name= 'G2_6',
            interaction_object= {'古代封印'},
            interaction_object_map_name= {'TitanRuneActive'},
            index = 151
        },
        ['想辦法進入位於泰坦之谷下方的泰坦石窟']= {
            map_name= 'G2_6',
            interaction_object= {'古代封印'},
            interaction_object_map_name= {'TitanRuneActive'},
            index = 152
        },
        ['將火焰紅寶石交給札卡']= {
            map_name= 'G2_town',
            grid_x= 381,
            grid_y= 238,
            interaction_object= {'札卡'},
            index = 153
        },
        ['札卡為你提供了擊敗巨像．札爾瑪拉斯的獎勵']= {
            map_name= 'G2_town',
            grid_x= 381,
            grid_y= 238,
            interaction_object= {'札卡', '泰坦獎勵'},
            index = 154
        },
        ['進入抑制入口處的泰坦石窟']= {
            map_name= 'G2_7',
            index = 155
        },
        ['泰坦石窟']= {
            map_name= 'G2_7',
            index = 156
        },
        ['進入泰坦石窟']= {
            map_name= 'G2_7',
            interaction_object= {'TitanActive'},
            interaction_object_map_name= {'TitanActive', 'TitanInactive'},
            index = 157
        },
        ['在泰坦石窟找到烈焰儀式的祭壇']= {
            map_name= 'G2_7',
            Boss= {'巨像．札爾瑪拉斯'},
            interaction_object= {'TitanActive'},
            interaction_object_map_name= {'TitanActive', 'TitanInactive'},
            index = 158
        },
        ['擊敗巨像．札爾瑪拉斯並取回火焰紅寶石']= {
            map_name= 'G2_7',
            Boss= {'巨像．札爾瑪拉斯'},
            interaction_object= {'火焰紅寶石'},
            interaction_object_map_name= {'TitanActive', 'TitanInactive'},
            index = 159
        },
        ['拾起火焰紅寶石']= {
            map_name= 'G2_7',
            Boss= {'巨像．札爾瑪拉斯'},
            interaction_object= {'火焰紅寶石'},
            interaction_object_map_name= {'TitanActive', 'TitanInactive'},
            index = 160
        },
        ['與黑衣幽魂交談']= {
            map_name= 'G2_town',
            interaction_object= {'黑衣幽魂'},
            grid_x= 264,
            grid_y= 261,
            index = 161
        },
        ['與阿杜拉的絲克瑪交談']= {
            map_name= 'G2_town',
            interaction_object= {'絲克瑪．阿薩拉'},
            grid_x= 488,
            grid_y= 252,
            index = 162
        },
        ['回去找札卡取得瓦斯提里的戰角'] = {
            map_name= 'G2_town',
            grid_x= 381,
            grid_y= 238,
            interaction_object= {'札卡', '瓦斯提里的戰角'},
            index = 163
        },
        ['使用貧脊之地的地圖返回哈拉妮關口的沙戮風暴吹揚之處']= {
            map_name= 'G2_town',
            special_map_point= {662,415},
            interaction_object= {'吹響戰角'},
            index = 164
        },
        ['使用瓦斯提里的戰角驅散沙戮風暴']= {
            map_name= 'G2_town',
            grid_x= 674,
            grid_y= 254,
            interaction_object= {'吹響戰角'},
            index = 165
        },
        ['與阿薩拉對話']= {
            map_name= 'G2_town',
            grid_x= 573,
            grid_y= 272,
            interaction_object= {'絲克瑪．阿薩拉'},
            index = 166
        },
        ['使用貧脊之地的地圖前往戴斯哈所在之處']= {
            map_name= 'G2_8',
            index = 167
        },
        ['在戴斯哈的某處尋找萊露瑪的遺體']= {
            map_name= 'G2_8',
            interaction_object= {'戰死的部下'},
            index = 168
        },
        ['將書信還給位在阿杜拉車隊的某個人']= {
            map_name= 'G2_town',
            grid_x= 376,
            grid_y= 273,
            interaction_object= {'夏布林','傳統的代價獎勵','將最終信件交給夏布林'},
            index = 169
        },
        ['將遺書交還給夏布林']= {
            map_name= 'G2_town',
            grid_x= 376,
            grid_y= 273,
            interaction_object= {'夏布林','傳統的代價獎勵','將最終信件交給夏布林'},
            index = 169
        },
        ['登上戴斯哈']= {
            map_name= 'G2_9_1',
            interaction_object= {'悼念之路', '門','戰死的部下'},
            interaction_object_map_name= {'G2_9_1'},
            index = 170
        },
        ['悼念之路']= {
            map_name= 'G2_9_1',
            interaction_object= {'戴斯哈尖塔', '門'},
            interaction_object_map_name= {'G2_9_2'},
            index = 171
        },
        ['穿過悼念之路']= {
            map_name= 'G2_9_2',
            interaction_object= {'戴斯哈尖塔', '門'},
            interaction_object_map_name= {'G2_9_2'},
            index = 172
        },
        -- ['擊敗憎惡者．賈嫚拉']= {
        --     map_name= 'G2_9_2',
        --     interaction_object= {'ToGuive'},
        --     interaction_object_map_name= {'TorGulActive'},
        --     index = 173
        -- },
        ['戴斯哈尖塔']= {
            map_name= 'G2_9_2',
            Boss= {'玷汙者托爾．谷爾'},
            interaction_object = {"ToGuive","卡洛翰的姐妹"},
            interaction_object_map_name = {"TorGulActive"},
            index = 173
        },
        ['擊敗玷汙者托爾．谷爾']= {
            map_name= 'G2_9_2',
            interaction_object= {'TorGve'},
            interaction_object_map_name= {'TorGulActive'},
            Boss= {'玷汙者托爾．谷爾'},
            index = 174
        },
        ['與夏布林交談']= {
            map_name= 'G2_town',
            grid_x= 376,
            grid_y= 273,
            interaction_object= {'夏布林','傳統的代價獎勵'},
            index = 175
        },
        ['使用貧脊之地的地圖前往無畏隊所在之處']= {
            map_name= 'G2_12_1',
            index = 176
        },
        ["toLevel_33"] = {
            map_name= 'G2_12_1',
            index = 177
        },
        ['無畏隊']= {
            map_name= 'G2_12_1',
            index = 177
        },
        ['在法里登人中殺出一條血路']= {
            map_name= 'G2_12_1',
            interaction_object= {'無畏隊先鋒'},
            interaction_object_map_name= {'G2_12_2'},
            index = 178
        },
        ['無畏隊先鋒']= {
            map_name= 'G2_12_2',
            index = 179
        },
        ['一路殺到憎惡者．賈嫚拉的王座']= {
            map_name= 'G2_12_2',
            interaction_object= {'絲克薩拉'},
            Boss= {'憎惡者．賈嫚拉'},
            interaction_object_map_name= {'PerennialCorruptedActive'},
            index = 180
        },
        ['擊敗憎惡者．賈嫚拉']= {
            map_name= 'G2_12_2',
            interaction_object_map_name= {'PerennialCorruptedActive'},
            Boss= {'憎惡者．賈嫚拉'},
            interaction_object= {'絲克瑪．阿薩拉'},
            index = 181
        },
        ['與車隊西北方的神殿裡的黑衣幽魂對話']= {
            map_name= 'G2_town',
            grid_x= 403,
            grid_y= 830,
            interaction_object= {'黑衣幽魂'},
            index = 182
        },
        ['使用車隊中點西北方的一處坡道，尋找黑衣幽魂']= {
            map_name= 'G2_town',
            grid_x= 403,
            grid_y= 830,
            interaction_object= {'黑衣幽魂'},
            index = 183
        },
        ['與阿薩拉交談以南行前往沙掠濕地']= {
            map_name= 'G2_town',
            grid_x= 574,
            grid_y= 272,
            interaction_object= {'絲克瑪．阿薩拉', '前往風沙沼澤'},
            index = 184
        },
        ['戴斯哈']= {
            map_name= 'G2_8',
            interaction_object= {'門', '悼念之路'},
            interaction_object_map_name= {'G2_9_1'},
            index = 185
        },
        ['前往戴斯哈']= {
            map_name= 'G2_8',
            interaction_object= {'門', '悼念之路'},
            interaction_object_map_name= {'G2_9_1'},
            index = 186
        },
        ['與那些寶藏獵人會面']= {
            map_name= 'G3_town',
            grid_x= 354,
            grid_y= 800,
            interaction_object= {'奧斯瓦德', '艾瓦'},
            index = 187
        },
        ['詢問黑衣幽魂降低水位的方法']= {
            map_name= 'G3_town',
            grid_x= 460,
            grid_y= 756,
            interaction_object= {'黑衣幽魂'},
            index = 188
        },
        ['進入叢林遺跡以尋找瑪特蘭水道']= {
            map_name= 'G3_3',
            Boss={'神威銀拳'},
            interaction_object= {'感染荒地'},
            interaction_object_map_name= {'G3_2_1','SilverbackBlackfistBossActive'},
            index = 189
        },
        ['與黑衣幽魂對話，了解下一步該做什麼']= {
            map_name= 'G3_1',
            interaction_object= {'黑衣幽魂'},
            index = 190
        },
        ['與黑衣幽魂交談，了解下一步該做什麼']= {
            map_name= 'G3_1',
            index = 191,
            interaction_object= {'高地神塔營地'},
            interaction_object_map_name= {'G3_town'}
        },
        ['穿越沙掠濕地，尋找高地神塔']= {
            map_name= 'G3_1',
            index = 192,
            interaction_object= {'高地神塔營地'},
            interaction_object_map_name= {'G3_town'}
        },
        ['風沙沼澤']= {
            map_name= 'G3_town',
            interaction_object= {'黑衣幽魂'},
            index = 192
        },
        ['叢林遺跡']= {
            map_name= 'G3_3',
            index = 193
        },
        ['探索叢林遺跡以尋找瑪特蘭水道']= {
            map_name= 'G3_3',
            Boss={'神威銀拳'},
            interaction_object= {'感染荒地'},
            interaction_object_map_name= {'G3_2_1'},
            index = 194
        },
        ['感染荒地']= {
            map_name= 'G3_2_1',
            index = 195
        },
        ['跟著運河尋找瑪特蘭水道']= {
            map_name= 'G3_2_1',
            interaction_object= {'龍蜥濕地'},
            interaction_object_map_name= {'G3_5'},
            index = 196
        },
        ['召喚艾瓦詢問她的建議']= {
            map_name= 'G3_2_1',
            interaction_object= {'龍蜥濕地'},
            interaction_object_map_name= {'G3_5'},
            index = 196
        },
        ['沿著運河尋找水道']= {
            map_name= 'G3_2_1',
            interaction_object= {'龍蜥濕地'},
            interaction_object_map_name= {'G3_5'},
            index = 197
        },
        ['龍蜥濕地']= {
            map_name= 'G3_5',
            index = 198
        },
        ['探索龍蜥濕地，尋找古老的機械迷城']= {
            map_name= 'G3_5',
            interaction_object= {'吉卡尼的機械迷城'},
            interaction_object_map_name= {'G3_6_1'},
            index = 199
        },
        ['擊敗龍蜥．欽路錫安']= {
            map_name= 'G3_5',
            Boss= {'龍蜥．欽路錫安','劇毒之花'},
            interaction_object= {'吉迷城'},
            interaction_object_map_name= {'XyclucianBossActive'},
            index = 200
        },
        ['前往混沌神殿']= {
            map_name= 'G3_5',
            Boss= {'龍蜥．欽路錫安','劇毒之花'},
            interaction_object= {'混沌神殿'},
            interaction_object_map_name= {'G3_10_Airlock'},
            index = 201
        },
        ['吉卡尼的機械迷城']= {
            map_name= 'G3_6_1',
            index = 202
        },
        ['進入吉卡尼的機械迷城']= {
            map_name= 'G3_5',
            Boss= {'龍蜥．欽路錫安','劇毒之花'},
            interaction_object= {'吉卡尼的機械迷城'},
            interaction_object_map_name= {'XyclucianBossActive', 'G3_6_1'},
            index = 203
        },
        ['進入機械迷城上層']= {
            map_name= 'G3_6_1',
            Boss={'遺忘的黑顎'},
            interaction_object= {'召喚艾瓦', '艾瓦', '門'},
            interaction_object_map_name= {'艾瓦'},
            index = 204
        },
        ['在機械迷城中尋找一個大型靈魂核心']= {
            map_name= 'G3_6_1',
            Boss={'遺忘的黑顎'},
            interaction_object= {'召喚艾瓦', '艾瓦', '門'},
            interaction_object_map_name= {'艾瓦'},
            index = 205
        },
        ['召喚艾瓦，尋求她的意見']= {
            map_name= 'G3_6_1',
            Boss={'遺忘的黑顎'},
            interaction_object= {'召喚艾瓦', '艾瓦','門', '小型靈魂核心'},
            interaction_object_map_name= {'艾瓦'},
            index = 206
        },
        ['向艾瓦詢問建議']= {
            map_name= 'G3_6_1', 
            Boss={'遺忘的黑顎'},
            interaction_object= {'召喚艾瓦', '艾瓦','門', '小型靈魂核心'},
            interaction_object_map_name= {'艾瓦'},
            index = 207
        },
        ['在吉卡尼的機械迷城尋找小型靈魂核心以開啟大門']= {
            map_name= 'G3_6_1',
            Boss={'遺忘的黑顎'},
            interaction_object= {'門', '小型靈魂核心', '石陣祭壇'},
            index = 208
        },
        ['將小型靈魂核心放進石陣祭壇中']= {
            map_name= 'G3_6_1',
            Boss={'遺忘的黑顎'},
            interaction_object= {'門', '小型靈魂核心', '石陣祭壇', '吉卡尼的聖域'},
            interaction_object_map_name= {'G3_6_2'},
            index = 209
        },
        ['繼續深入機械迷城']= {
            map_name= 'G3_6_1',
            Boss={'遺忘的黑顎'},
            interaction_object= {'門', '小型靈魂核心', '石陣祭壇', '吉卡尼的聖域'},
            interaction_object_map_name= {'G3_6_2'},
            index = 210
        },
        ['吉卡尼的聖域']= {
            map_name= 'G3_6_2',
            index = 211
        },
        ['探索吉卡尼的聖域']= {
            map_name= 'G3_6_2',
            interaction_object= {'召喚艾瓦','艾瓦'},
            interaction_object_map_name= {'ZicoatlBossActive'},
            index = 212
        },
        ['深入機械迷城']= {
            map_name= 'G3_6_2',
            interaction_object= {'召喚艾瓦','艾瓦'},
            interaction_object_map_name= {'ZicoatlBossActive'},
            index = 213
        },
        ['召喚艾瓦並與之交談']= {
            map_name= 'G3_6_2',
            interaction_object= {'艾瓦'},
            interaction_object_map_name= {'ZicoatlBossActive'},
            index = 214
        },
        ['召喚艾瓦並與她交談']= {
            map_name= 'G3_6_2',
            interaction_object= {'召喚艾瓦','艾瓦'},
            interaction_object_map_name= {'ZicoatlBossActive'},
            index = 214
        },
        -- ['召喚艾瓦，尋求她的意見']= {
        --     map_name= 'C_G3_6_2',
        --     interaction_object= {'中型靈魂核心',' <questitem>{發電機}','門'},
        -- },
        ['在吉卡尼的聖域尋找兩個中型靈魂核心，並用它們啟動兩台發電機']= {
            map_name= 'G3_6_2',
            interaction_object= {'中型靈魂核心','<questitem>{發電機}','門','<questitem>{大型靈魂核心}'},
            index = 215
        },
        ['在機械迷城下層尋找兩個中型靈魂核心，並用它們啟動兩台發電機']= {
            map_name= 'G3_6_2',
            interaction_object= {'<questitem>{大型靈魂核心}','艾瓦','門'},
            interaction_object_map_name= {'艾瓦'},
            index = 216
        },
        ['取回艾瓦附近的大型靈魂核心']= {
            map_name= 'G3_6_2',
            interaction_object= {'中型靈魂核心', '<questitem>{發電機}','<questitem>{大型靈魂核心}','門'},
            index = 217
        },
        ['擊敗核心守衛．茲科亞特']= {
            map_name= 'G3_6_2',
            Boss= {'核心守衛．茲科亞特'},
            interaction_object= {'ZicBActive'},
            interaction_object_map_name= {'ZicoatlBossActive'},
            index = 218
        },
        ['撿起大型靈魂核心']= {
            map_name= 'G3_6_2',
            Boss= {'核心守衛．茲科亞特'},
            interaction_object= {'中型靈魂核心', '<questitem>{發電機}','門','<questitem>{大型靈魂核心}'},
            interaction_object_map_name= {'ZicoatlBossActive','ZicoatlBossInactive'},
            index = 219
        },
        ['返回感染荒地並啟動石陣祭壇']= {
            map_name= 'G3_2_1',
            interaction_object= {'石陣祭壇'},
            index = 220
        },
        ['瑪特蘭水道']= {
            map_name= 'G3_2_1',
            interaction_object= {'瑪特蘭水道'},
            interaction_object_map_name= {'G3_2_2'},
            index = 221
        },
        ['進入瑪特蘭水道並找出控制機關']= {
            map_name= 'G3_2_1',
            interaction_object= {'瑪特蘭水道'},
            interaction_object_map_name= {'G3_2_2'},
            index = 222
        },
        ['找出控制機關並啟用瑪特蘭水道，抽乾該區的水']= {
            map_name= 'G3_2_2',
            interaction_object= {'壓桿'},
            index = 223
        },
        ['返回營地，在高地神塔下方找到艾瓦']= {
            map_name= 'G3_town',
            grid_x= 419,
            grid_y= 330,
            interaction_object= {'艾瓦'},
            index = 224
        },
        ['進入淹沒之城並尋找阿戈拉']= {
            map_name= 'G3_8',
            index = 225
        },
        ['探索淹沒之城並尋找阿戈拉']= {
            map_name= 'G3_11',
            index = 226
        },
        ['淹沒之城']= {
            map_name= 'G3_8',
            index = 227
        },
        ['污垢頂峰']= {
            map_name= 'G3_11',
            Boss= {'污垢女王'},
            index = 229
        },
        ['探索污垢頂峰並尋找鑰匙']= {
            map_name= 'G3_11',
            interaction_object= {'污垢'},
            Boss= {'污垢女王'},
            interaction_object_map_name= {'QueenOfFilthBossActive'},
            index = 230
        },
        ['擊敗污垢女王']= {
            map_name= 'G3_11',
            Boss= {'污垢女王'},
            interaction_object= {'污垢'},
            interaction_object_map_name= {'QueenOfFilthBossActive'},
            index = 231
        },
        ['撿起神殿大門神像']= {
            map_name= 'G3_11',
            interaction_object_map_name= {'QueenOfFilthBossInactive'},
            interaction_object= {'神殿大門神像'},
            index = 232
        },
        ['帶著神殿大門神像回去找艾瓦']= {
            map_name= 'G3_town',
            grid_x= 458,
            grid_y= 324,
            interaction_object= {'艾瓦','科佩克'},
            index = 233
        },
        ['開啟前往科佩克神殿的大門']= {
            map_name= 'G3_town',
            grid_x= 458,
            grid_y= 324,
            interaction_object= {'門','科佩克'},
            interaction_object_map_name= {'G3_12'},
            index = 234
        },
        ['從寶藏獵人營地下方進入科佩克神殿']= {
            map_name= 'G3_12',
            grid_x= 458,
            grid_y= 324,
            interaction_object= {'科佩克'},
            interaction_object_map_name= {'G3_12'},
            index = 235
        },
        ['科佩克神殿']= {
            map_name= 'G3_12',
            grid_x= 458,
            grid_y= 324,
            interaction_object= {'科佩克'},
            interaction_object_map_name= {'G3_12'},
            index = 236
        },
        ['探索科佩克神殿並尋找瓦爾的知識展覽室']= {
            map_name= 'G3_12',
            Boss= {'豔陽神聖主教．凱亞祖利'},
            interaction_object= {'召瓦尔','科佩克'},
            interaction_object_map_name= {'KaazuliBossActive'},
            index = 237
        },
        ['擊敗豔陽神聖主教．凱亞祖利']= {
            map_name= 'G3_12',
            Boss= {'豔陽神聖主教．凱亞祖利'},
            interaction_object= {'艾瓦','召瓦尔','科佩克','召喚艾瓦', '調查平台'},
            interaction_object_map_name= {'KaazuliBossActive','艾瓦'},
            index = 238
        },
        ['搭乘電梯']= {
            map_name= 'G3_12',
            Boss= {'豔陽神聖主教．凱亞祖利'},
            interaction_object= {'艾瓦','召喚艾瓦', '調查平台','高地神塔營地','科佩克'},
            interaction_object_map_name= {'KaazuliBossActive','KaazuliBossInactive'},
            index = 239
        },
        ['召喚艾瓦並告訴她發生什麼事']= {
            map_name= 'G3_12',
            interaction_object= {'召喚艾瓦','科佩克'},
            Boss= {'豔陽神聖主教．凱亞祖利'},
            interaction_object_map_name= {'KaazuliBossInactive'},
            index = 240
        },
        ['與艾瓦對話']= {
            map_name= 'G3_12',
            interaction_object= {'艾瓦', '調查平台','科佩克'},
            Boss= {'豔陽神聖主教．凱亞祖利'},
            interaction_object_map_name= {'艾瓦', 'KaazuliBossInactive'},
            index = 241
        },
        ['進入崎點']= {
            map_name= 'G3_town',
            grid_x= 423,
            grid_y= 835,
            interaction_object= {'崎點'},
            index = 242
        },
        ['高地神塔營地']= {
            map_name= 'G3_town',
            interaction_object= {'召瓦尔'},
            index = 243
        },
        ['回到過去，進入奧札爾']= {
            map_name= 'G3_14',
            interaction_object= {'奧札爾'},
            Boss= {'豔陽神聖主教．凱亞祖利'},
            interaction_object_map_name= {'G3_14'},
            index = 244
        },
        ['在奧札爾尋找有關巨獸的情報']= {
            map_name= 'G3_14',
            Boss= {'邪魔毒蛇納普阿茲'},
            interaction_object= {'奧爾'},
            interaction_object_map_name= {'ViperNapuatziBossActive'},
            index = 245
        },
        ['擊敗邪魔毒蛇納普阿茲']= {
            map_name= 'G3_14',
            Boss= {'邪魔毒蛇納普阿茲'},
            interaction_object= {'奧爾'},
            interaction_object_map_name= {'ViperNapuatziBossActive'},
            index = 246
        },
        ['從多里亞尼手中拯救艾瓦']= {
            map_name= 'G3_14',
            Boss= {'邪魔毒蛇納普阿茲'},
            interaction_object= {'阿戈拉'},
            interaction_object_map_name= {'G3_16'},
            index = 247
        },
        ['奧札爾']= {
            map_name= 'G3_14',
            interaction_object = { "犧牲之心" },
            index = 248
        },
        ['進入阿戈拉並尋找漆黑密室']= {
            map_name= 'G3_14',
            interaction_object= {'阿戈拉'},
            interaction_object_map_name= {'G3_16'},
            index = 249
        },
        ['阿戈拉']= {
            map_name= 'G3_16',
            index = 250
        },
        ['從阿戈拉殺出血路，並找到漆黑密室']= {
            map_name= 'G3_16',
            interaction_object= {'漆黑密室'},
            interaction_object_map_name= {'G3_17'},
            index = 251
        },
        ['漆黑密室']= {
            map_name= 'G3_17',
            index = 252
        },
        ['在漆黑密室裡找到多里亞尼']= {
            map_name= 'G3_17',
            interaction_object= {'艾瓦'},
            Boss= { '多里亞尼','多里亞尼的凱旋'},
            interaction_object_map_name= {'DoryaniBossActive'},
            index = 253
        },
        ['抓捕多里亞尼以獲得他對巨獸的知識']= {
            map_name= 'G3_17',
            Boss= { '多里亞尼','多里亞尼的凱旋'},
            interaction_object= {'艾瓦'},
            interaction_object_map_name= {'DoryaniBossActive'},
            index = 254
        },
        ['在高地神塔營地與多里亞尼對話']= {
            map_name= 'G3_town',
            interaction_object= {'多里亞尼'},
            index = 255
        },
        
        ['阿札克泥沼']= {
            map_name= 'G3_7',
            interaction_object = { "傑洛特顱骨" },
            index = 257
        },
        ['召喚瑟維打聽卡佛的消息']= {
            map_name= 'G3_7',
            interaction_object= {'召喚瑟維'},
            index = 258
        },
        ['與瑟維交談，打聽卡佛的消息']= {
            map_name= 'G3_7',
            interaction_object= {'瑟維'},
            index = 259
        },
        ['在阿札克村莊中找到尹娜杜克並殺掉她']= {
            map_name= 'G3_7',
            Boss={'沼澤女巫．尹娜杜克'},
            index = 260
        },
        ['殺死沼澤女巫']= {
            map_name= 'G3_7',
            Boss={'沼澤女巫．尹娜杜克'},
            interaction_object_map_name= {'IgnagdukBossActive'},
            index = 261
        },
        ['拾取尹娜杜克的長鋒']= {
            map_name= 'G3_7',
            Boss={'沼澤女巫．尹娜杜克'},
            interaction_object= {'尹娜杜克的幽暗長鋒','傑洛特顱骨'},
            interaction_object_map_name= {'IgnagdukBossInactive'},
            index = 262
        },
        ['拾取尹娜杜克的長矛']= {
            map_name= 'G3_7',
            Boss={'沼澤女巫．尹娜杜克'},
            interaction_object= {'尹娜杜克的幽暗長鋒','傑洛特顱骨'},
            interaction_object_map_name= {'IgnagdukBossInactive'},
            index = 262
        },
        ['返回城鎮並與瑟維交談']= {
            map_name= 'G3_town',
            grid_x= 516,
            grid_y= 855,
            interaction_object= {'瑟維'},
            index = 263
        },
        ['跟瑟維領取獎勵']= {
            map_name= 'G3_town',
            grid_x= 516,
            grid_y= 855,
            interaction_object= {'瑟維','部落復仇獎勵'},
            index = 264
        },
        ['和艾瓦對話以前往金司馬區']= {
            map_name= 'G3_town',
            interaction_object= {'艾瓦',"前往金司馬區"},
            index = 265
        },
        ["金司馬區"] = {
            map_name= 'G4_town',
            interaction_object= {'黑衣幽魂'},
            grid_x = 1023,
            grid_y = 1635,
            interaction_object_map_name= {'黑衣幽魂'},
            index = 308
        },
        ['與瑪寇魯交談，討論雇用船隻的事宜']= {
            map_name= 'G4_town',
            grid_y = 1410,
            grid_x = 1032,
            interaction_object= {'瑪寇魯'},
            index = 267
        },
        ['與瑪寇魯對話，來前往凱吉灣']= {
            map_name= 'G4_2_2',
            index = 268
        },
        ['探索凱吉灣']= {
            map_name= 'G4_2_2',
            interaction_object= {'旅程結束'},
            interaction_object_map_name= {'G4_2_2'},
            index = 269
        },
        ['進入末途島']= {
            map_name= 'G4_2_2',
            interaction_object= {'旅程結束'},
            interaction_object_map_name= {'G4_2_2'},
            index = 269
        },
        ['凱吉灣']= {
            map_name= 'G4_2_1',
            index = 270
        },
        ['旅程結束']= {
            map_name= 'G4_2_2',
            index = 271
        },
        ['探索末途島']= {
            map_name= 'G4_2_2',
            Boss={'哈特林統帥'},
            interaction_object_map_name= {'G4_2_2_BossActive'},
            index = 272
        },
        ['召喚圖貞']= {
            map_name= 'G4_2_2',
            Boss={'哈特林統帥'},
            interaction_object_map_name= {'G4_2_2_BossActive'},
            index = 272
        },
        ['殺死哈特林船長']= {
            map_name= 'G4_2_2',
            Boss={'哈特林統帥'},
            interaction_object_map_name= {'G4_2_2_BossActive'},
            index = 273
        },
        ['拾取維里西姆']= {
            map_name= 'G4_2_2',
            interaction_object= {'維里西姆'},
            index = 274
        },
        ["將維里西姆交給丹尼格"]= {
            map_name= 'G4_town',
            grid_x = 1133,
            grid_y = 1681,
            interaction_object= {'丹尼格'},
            index = 275
        },
        ["跟丹尼格領取維里西姆尖矢"]= {
            map_name= 'G4_town',
            grid_x = 1133,
            grid_y = 1681,
            interaction_object= {'丹尼格','維里西姆尖矢'},
            index = 275
        },
        ["返回芙雷雅．哈特林身邊"]= {
            map_name= 'G4_2_2',
            interaction_object= {"圖貞",'召喚圖貞',"卡魯圖騰","芙雷雅．哈特林"},
            interaction_object_map_name= {'芙雷雅．哈特林'},
            index = 276
        },
        ["自瘋狂中存活"]= {
            map_name= 'G4_2_2',
            Boss= {"恐懼造物．歐姆弗畢亞"},
            interaction_object_map_name= {'StoryGlyph'},
            index = 276
        },
        ["在金司馬區與圖貞對話"]= {
            map_name= 'G4_town',
            grid_x = 1133,
            grid_y = 1681,
            interaction_object= {'圖貞'},
            index = 277
        },
        ["向圖貞領取獎勵"]= {
            map_name= 'G4_town',
            grid_x = 947,
            grid_y = 1608,
            interaction_object= {'圖貞',"暗黑迷霧獎勵"},
            index = 277
        },
        ['金氏島']= {
            map_name= 'G4_1_1',
            index = 278
        },
        ['探索金氏島']= {
            map_name= 'G4_1_1',
            interaction_object= {'火山迷窟'},
            Boss = {"眼盲巨獸"},
            interaction_object_map_name= {'G4_1_2'},
            index = 279
        },
        ['進入火山迷窟']= {
            map_name= 'G4_1_1',
            interaction_object= {'火山迷窟'},
            interaction_object_map_name= {'G4_1_2'},
            index = 280
        },
        ['火山迷窟']= {
            map_name= 'G4_1_2',
            index = 280
        },
        ['探索火山迷窟']= {
            map_name= 'G4_1_2',
            Boss = {"金氏領主．克魯托克"},
            interaction_object_map_name= {"VolcanicWarrensBossActive"},
            index = 281
        },
        ['擊殺克魯托克']= {
            map_name= 'G4_1_2',
            Boss = {"金氏領主．克魯托克"},
            interaction_object_map_name= {"VolcanicWarrensBossActive"},
            index = 282
        },
        ['與馬提奇對話']= {
            map_name= 'G4_1_2',
            Boss = {"金氏領主．克魯托克"},
            interaction_object= {"馬提奇"},
            interaction_object_map_name= {"VolcanicWarrensBossInactive"},
            index = 283
        },
        ['悉妮蔻拉之眼']= {
            map_name= 'G4_4_1',
            index = 284
        },
        ['與馬提奇會面']= {
            map_name= 'G4_4_1',
            interaction_object= {"馬提奇"},
            index = 285
        },
        ['與馬提基對話']= {
            map_name= 'G4_4_1',
            interaction_object= {"馬提奇"},
            index = 286
        },
        ['窺探傳承之井']= {
            map_name= 'G4_4_1',
            interaction_object= {"傳承之井"},
            index = 287
        },
        ['完成岡姆的精神試煉完成瑪塔的精神試煉完成萊基亞塔的精神試煉']= {
            map_name= 'G4_4_1',
            index = 288
        },
        ['完成瑪塔的精神試煉完成萊基亞塔的精神試煉']= {
            map_name= 'G4_4_1',
            index = 289
        },
        ['完成萊基亞塔的精神試煉']= {
            map_name= 'G4_4_1',
            index = 290
        },
        ['找出亡者之殿']= {
            map_name= 'G4_4_1',
            interaction_object={"亡者之殿"},
            interaction_object_map_name= {"G4_4_2"},
            index = 291
        },
        ['亡者之殿']= {
            map_name= 'G4_4_2',
            index = 292
        },
        ['完成塔赫亞的試煉']= {
            map_name= 'G4_4_2',
            interaction_object_map_name= {"G4_4_2_Encounter_ValakoTribeActive"},
            index = 293
        },
        ['拾起塔赫亞的空白紋身']= {
            map_name= 'G4_4_2',
            interaction_object_map_name= {"G4_4_2_Encounter_ValakoTribeInactive"},
            index = 294
        },
        ['將塔赫亞的空白紋身交給悉妮蔻拉圖騰']= {
            map_name= 'G4_4_2',
            interaction_object={"悉妮蔻拉圖騰"},
            interaction_object_map_name= {"G4_4_2_Encounter_ValakoTribeInactive"},
            index = 295
        },
        ['向悉妮蔻拉圖騰領取獎勵']= {
            map_name= 'G4_4_2',
            interaction_object={"悉妮蔻拉圖騰","塔赫亞的考驗獎勵","努葛瑪呼的考驗獎勵","拿馬乎的考驗獎勵","塔薩里奧的考驗獎勵"},
            index = 296
        },
        ['完成拿馬乎的試煉']= {
            map_name= 'G4_4_2',
            interaction_object_map_name= {"G4_4_2_Encounter_NgamahuTribeActive"},
            index = 297
        },
        ['拾起拿馬乎的空白紋身']= {
            map_name= 'G4_4_2',
            interaction_object_map_name= {"G4_4_2_Encounter_NgamahuTribeInactive"},
            index = 298
        },
        ['將拿馬乎的空白紋身交給悉妮蔻拉圖騰']= {
            map_name= 'G4_4_2',
            interaction_object={"悉妮蔻拉圖騰"},
            interaction_object_map_name= {"G4_4_2_Encounter_NgamahuTribeInactive"},
            index = 299
        },
        ['完成塔薩里的試煉']= {
            map_name= 'G4_4_2',
            interaction_object_map_name= {"G4_4_2_Encounter_TasalioTribeActive"},
            index = 300
        },
        ['拾起塔薩里的空白紋身']= {
            map_name= 'G4_4_2',
            interaction_object_map_name= {"G4_4_2_Encounter_TasalioTribeInactive"},
            index = 301
        },
        ['將塔薩里的空白紋身交給悉妮蔻拉圖騰']= {
            map_name= 'G4_4_2',
            interaction_object={"悉妮蔻拉圖騰"},
            interaction_object_map_name= {"G4_4_2_Encounter_TasalioTribeInactive"},
            index = 302
        },
        ['探索亡者之殿']= {
            map_name= 'G4_4_2',
            interaction_object={"祖靈"},
            index = 303
        },
        ['擊敗白之亞瑪']= {
            map_name= 'G4_4_2',
            interaction_object={"白之亞瑪"},
            Boss = {"白之亞瑪"},
            interaction_object_map_name= {"G4_4_2_YamaActive"},
            index = 303
        },
        ["拾起銀幣"] ={
            map_name= 'G4_4_2',
            interaction_object={"白之亞瑪","銀幣"},
            interaction_object_map_name= {"G4_4_2_YamaInactive"},
            index = 304
        },
        ['進一步探索亡者之殿']= {
            map_name= 'G4_4_3',
            index = 305
        },
        ['進入傳送門並和死亡之母會面']= {
            map_name= 'G4_4_3',
            index = 305
        },
        ['祖靈的試煉']= {
            map_name= 'G4_4_3',
            index = 306
        },
        ["與娜瓦莉交談"] = {
            map_name= 'G4_4_3',
            interaction_object={"娜瓦莉"},
            interaction_object_map_name= {"娜瓦莉"},
            index = 307
        },
        ["向娜瓦莉取得獎勵"] = {
            map_name= 'G4_4_3',
            interaction_object={"娜瓦莉","祖靈的試煉獎勵"},
            interaction_object_map_name= {"娜瓦莉"},
            index = 307
        },
        ["瓦卡帕努島"] = {
            map_name= 'G4_3_1',
            index = 308
        },
        ["探索瓦卡帕努島"] = {
            map_name= 'G4_3_1',
            interaction_object= {'吟謠洞窟'},
            Boss = {"大白鯊"},
            interaction_object_map_name= {'G4_3_2'},
            index = 309
        },
        ["擊敗大白鯊"] = {
            map_name= 'G4_3_1',
            interaction_object= {'鯊魚鰭'},
            Boss = {"大白鯊"},
            interaction_object_map_name= {'G4_3_1_BossActive'},
            index = 310
        },
        ["進入吟謠洞窟"] = {
            map_name= 'G4_3_2',
            index = 311
        },
        ["吟謠洞窟"] = {
            map_name= 'G4_3_2',
            index = 311
        },
        ["探索吟謠洞窟"] = {
            map_name= 'G4_3_2',
            interaction_object_map_name= {'G4_3_2_BossActive'},
            index = 312
        },
        ["擊殺死亡之謠，黛莫拉"] = {
            map_name= 'G4_3_2',
            Boss = {"擊殺死亡之謠．黛莫拉"},
            interaction_object_map_name= {'G4_3_2_BossActive'},
            index = 313
        },
        ["廢棄監獄"] = {
            map_name= 'G4_5_1',
            index = 314
        },
        ["探索監獄"] = {
            map_name= 'G4_5_2',
            index = 315
        },
        ["進入單獨禁閉室"] = {
            map_name= 'G4_5_2',
            index = 315
        },
        ["單獨禁閉"] = {
            map_name= 'G4_5_2',
            index = 316
        },
        ["探索單獨禁閉室"] = {
            map_name= 'G4_5_2',
            interaction_object= {'門',"把手"},
            Boss = {"囚犯"},
            index = 317
        },
        ["打開加固的門"] = {
            map_name= 'G4_5_2',
            interaction_object= {'門',"把手"},
            Boss = {"囚犯"},
            index = 318
        },
        ["殺死囚犯"] = {
            map_name= 'G4_5_2',
            interaction_object= {'門',"把手"},
            Boss = {"囚犯"},
            index = 319
        },
        ["伯勞鳥之島"] = {
            map_name= 'G4_7',
            index = 320
        },
        ["探索伯勞鳥之島"] = {
            map_name= 'G4_7',
            index = 321
        },
        ["擊殺天之禍殃"] = {
            map_name= 'G4_7',
            Boss = {"天之禍殃"},
            interaction_object_map_name= {'G4_7_BossActive'},
            index = 321
        },
        ["在金司馬區與黑衣幽魂對話"] = {
            map_name= 'G4_town',
            interaction_object= {'黑衣幽魂'},
            grid_x = 1023,
            grid_y = 1635,
            index = 322
        },
        ["與瑪寇魯對話"] = {
            map_name= 'G4_town',
            interaction_object= {'瑪寇魯'},
            grid_x = 1025,
            grid_y = 1407,
            index = 323
        },
        ["前往阿拉塔斯"] = {
            map_name= 'G4_town',
            interaction_object= {"阿拉塔斯",'瑪寇魯',"啟航"},
            special_map_point = {587,733},
            grid_x = 1025,
            grid_y = 1407,
            index = 324
        },
        ["詢問某人關於武器的事"] = {
            map_name= 'G4_8b',
            interaction_object= {'傳道士羅蘭迪斯',"介紹"},
            interaction_object_map_name= {'傳道士羅蘭迪斯'},
            index = 325
        },
        ["阿拉塔斯"] = {
            map_name= 'G4_8b',
            index = 326
        },
        ["調查教堂外的騷動"] = {
            map_name= 'G4_8b',
            interaction_object= {'門'},
            index = 327
        },
        ["攻擊並破壞力場"] = {
            map_name= 'G4_8b',
            index = 328
        },
        ["在伏擊中活下來"] = {
            map_name= 'G4_8b',
            index = 328
        },
        ["尋找重鑄武器的方法"] = {
            map_name= 'G4_10',
            interaction_object= {'挖掘',"晚鐘"},
            interaction_object_map_name= {'G4_10',"ExaltedBellActive"},
            index = 330
        },
        ["擊敗救贖者之手．托維安"] = {
            map_name= 'G4_8b',
            Boss={"救贖者之手．托維安"},
            interaction_object_map_name= {'G4_8b_BossActive'},
            index = 331
        },
        ["進入挖掘場"] = {
            map_name= 'G4_10',
            index = 332
        },
        ["挖掘"] = {
            map_name= 'G4_10',
            index = 333
        },
        ["面對卡努與第一使者"] = {
            map_name= 'G4_10',
            Boss={"烏托邦的第一使者．本篤特斯"},
            interaction_object_map_name= {'G4_10_BossActive'},
            index = 334
        },
        ["擊敗烏托邦的第一使者．本篤特斯"] = {
            map_name= 'G4_10',
            Boss={"烏托邦的第一使者．本篤特斯"},
            interaction_object_map_name= {'G4_10_BossActive',"G4_10_BossInactive"},
            index = 335
        },
        ["進入挖掘場遺址"] = {
            map_name= 'G4_10',
            interaction_object= {'黑衣幽魂'},
            Boss={"烏托邦的第一使者．本篤特斯"},
            interaction_object_map_name= {'G4_10_BossActive','黑衣幽魂'},
            index = 336
        },
        ["目睹黑衣幽魂重鑄出武器"] = {
            map_name= 'G4_10',
            interaction_object= {'黑衣幽魂'},
            Boss={"烏托邦的第一使者．本篤特斯"},
            interaction_object_map_name= {'G4_10_BossActive','黑衣幽魂'},
            index = 337
        },
        ["與拉卓里對話"] = {
            map_name= 'G4_town',
            interaction_object= {'拉卓里'},
            grid_x = 1025,
            grid_y = 1407,
            index = 338
        },
        ["與拉卓里對話以前往尼加卡努"] = {
            map_name= 'G4_11_1b',
            index = 339
        },
        ["尼加卡努"] = {
            map_name= 'G4_11_1b',
            index = 339
        },
        ["toLevel_52"] = {
            map_name= 'G4_11_1b',
            index = 339
        },
        ["找到部族之心"] = {
            map_name= 'G4_11_1b',
            interaction_object= {'部族之心'},
            interaction_object_map_name= {'G4_11_2'},
            index = 340
        },
        ["部族之心"] = {
            map_name= 'G4_11_2',
            index = 341
        },
        ["找到塔瓦凱"] = {
            map_name= 'G4_11_2',
            Boss = {"酋長．塔瓦凱"},
            interaction_object_map_name= {'G4_11_2_BossActive'},
            index = 342
        },
        ["跟隨塔瓦凱"] = {
            map_name= 'G4_11_2',
            Boss = {"墮落者．塔瓦凱"},
            interaction_object_map_name= {'瑪寇魯'},
            index = 343
        },
        ["擊敗塔瓦凱"] = {
            map_name= 'G4_11_2',
            Boss = {"酋長．塔瓦凱","墮落者．塔瓦凱","被吞噬者．塔瓦凱"},
            index = 344
        },
        ["目睹黑衣幽魂治療塔瓦凱和瑪寇魯"] = {
            map_name= 'G4_11_2',
            interaction_object_map_name= {'瑪寇魯'},
            index = 345
        },
        ["回到金司馬區"] = {
            map_name= 'G4_town',
            interaction_object= {'黑衣幽魂'},
            index = 346
        },
        ["與黑衣幽魂對話來前往奧格姆"] = {
            map_name= 'G4_town',
            interaction_object= {'黑衣幽魂',"前往奧格姆"},
            grid_x = 1023,
            grid_y = 1635,
            index = 347
        },
        ['庇護所'] = {
            map_name= 'P1_Town',
            index = 347
        },
        ['與倫利對話'] = {
            map_name= 'P1_Town',
            interaction_object= {'倫利'},
            index = 348
        },
        ['前往火噬農地'] = {
            map_name= 'P1_2',
            interaction_object= {'倫利'},
            index = 349
        },
        ['火噬農地'] = {
            map_name= 'P1_1',
            index = 350
        },
        ['探索火噬農地'] = {
            map_name= 'P1_2',
            interaction_object= {'瑟雷之石'},
            interaction_object_map_name= {'P1_2'},
            index = 351
        },
        ['接近黑暗'] = {
            map_name= 'P1_2',
            interaction_object= {'瑟雷之石'},
            interaction_object_map_name= {'P1_2'},
            index = 351
        },
        ['瑟雷之石'] = {
            map_name= 'P1_2',
            index = 352
        },
        ['尋求亡靈們的協助'] = {
            map_name= 'P1_2',
            index = 353
        },
        ['啟動符文石陣'] = {
            map_name= 'P1_2',
            interaction_object= {'符文巨石'},
            interaction_object_map_name= {'RuneMarkersInactive'},
            index = 354
        },
        ['啟動剩餘的石陣'] = {
            map_name= 'P1_2',
            interaction_object= {'符文巨石'},
            interaction_object_map_name= {'RuneMarkersInactive'},
            index = 355
        },
        ['找出石陣提供力量的對象'] = {
            map_name= 'P1_2',
            interaction_object_map_name= {'BossSummoningLocationInactive'},
            index = 356
        },
        ['擊敗迷霧之刃．希奧拉'] = {
            map_name= 'P1_2',
            Boss = {"迷霧之刃．希奧拉"},
            interaction_object_map_name= {'BossSummoningLocationInactive'},
            index = 357
        },
        ['等待烏娜的到來'] = {
            map_name= 'P1_2',
            interaction_object_map_name= {'BossSummoningLocationInactive'},
            index = 357
        },
        ['與烏娜對話'] = {
            map_name= 'P1_2',
            interaction_object= {'烏娜',"亡靈"},
            interaction_object_map_name= {'BossSummoningLocationInactive'},
            index = 358
        },
        ['返回火噬農地的黑暗之中'] = {
            map_name= 'P1_1',
            interaction_object_map_name= {'P1_3'},
            index = 359
        },
        ['進入黑木林'] = {
            map_name= 'P1_1',
            interaction_object= {'黑木林'},
            interaction_object_map_name= {'P1_3'},
            index = 360
        },
        ['黑木林'] = {
            map_name= 'P1_3',
            index = 361
        },
        ['在黑木林中殺出一條血路'] = {
            map_name= 'P1_4',
            index = 362
        },
        ['霍爾登'] = {
            map_name= 'P1_4',
            index = 363
        },
        ['探索霍爾登'] = {
            map_name= 'P1_6',
            interaction_object= {'霍爾登宅第'},
            interaction_object_map_name= {'P1_6'},
            index = 364
        },
        ['霍爾登宅第'] = {
            map_name= 'P1_6',
            index = 365
        },
        ['找出領主和夫人'] = {
            map_name= 'P1_6',
            interaction_object= {'門'},
            interaction_object_map_name= {'P1_6'},
            index = 366
        },
        ['擊敗領主和夫人'] = {
            map_name= 'P1_6',
            interaction_object= {'門'},
            Boss = {"艾兒薇絲女士","沃夫里克領主"},
            index = 367
        },
        ["回到奧格姆和倫利見面"] = {
            map_name= 'P1_Town',
            interaction_object= {'倫利'},
            index = 368
        },
        ["狼之要塞"] = {
            map_name= 'P1_5',
            index = 368
        },
        ["與黑衣幽魂對話來前往市集"] = {
            map_name= 'P1_Town',
            interaction_object= {'黑衣幽魂','前往瓦斯提里'},
            grid_x = 414,
            grid_y = 465,
            index = 369
        },
        ["卡里市集"] = {
            map_name= 'P2_Town',
            index = 370
        },
        ["卡里交匯道"] = {
            map_name= 'P2_1',
            index = 371
        },
        ["前往卡里交匯道"] = {
            map_name= 'P2_1',
            index = 372
        },
        ["尋找毒蠍與沙蟲"] = {
            map_name= 'P2_1',
            Boss = {"最終之刺．艾克提","沙蟲．艾能德"},
            index = 373
        },
        ["擊敗艾克提與艾能德"] = {
            map_name= 'P2_1',
            Boss = {"最終之刺．艾克提","沙蟲．艾能德"},
            index = 374
        },
        ["回去卡里市集找芮蘇"] = {
            map_name= 'P2_Town',
            interaction_object= {'卡里交匯道'},
            index = 375
        },
        ["跟芮蘇領取專精之書"] = {
            map_name= 'P2_Town',
            grid_x = 284,
            grid_y = 448,
            interaction_object= {'芮蘇','開闢道路獎勵'},
            index = 375
        },
        ["骨顎階梯"] = {
            map_name= 'P2_1',
            interaction_object= {'骨顎階梯'},
            index = 376
        },
        ["找到塞爾卡里庇護所"] = {
            map_name= 'P2_3',
            index = 377
        },
        ["卡塔爾之塘"] = {
            map_name= 'P2_2',
            index = 378
        },
        ["探索卡塔爾之塘"] = {
            map_name= 'P2_3',
            index = 379
        },
        ["塞爾卡里庇護所"] = {
            map_name= 'P2_3',
            index = 379
        },
        ["尋找水衛使者和雄偉巨靈之幣"] = {
            map_name= 'P2_3',
            interaction_object= {'賈多'},
            interaction_object_map_name= {'賈多'},
            index = 380
        },
        ['擊敗眼鏡蛇領主．艾爾札拉'] = {
            map_name= 'P2_3',
            Boss = {"眼鏡蛇領主．艾爾札拉"},
            interaction_object_map_name= {'賈多'},
            index = 381
        },
        ["在卡里交匯道尋找賈萊關口"] = {
            map_name= 'P2_5',
            index = 376
        },
        ["進入賈萊關口"] = {
            map_name= 'P2_Town',
            interaction_object_map_name= {'P2_5'},
            index = 376
        },
        ["賈萊關口"] = {
            map_name= 'P2_5',
            interaction_object= {'奇瑪'},
            interaction_object_map_name= {'P2_6'},
            index = 377
        },
        ["穿越賈萊關口"] = {
            map_name= 'P2_5',
            interaction_object= {'奇瑪'},
            interaction_object_map_name= {'P2_6'},
            index = 378
        },
        ["擊敗墮炎．沃納斯"] = {
            map_name= 'P2_5',
            Boss = {"墮炎．沃納斯"},
            interaction_object_map_name= {'P2_6'},
            index = 379
        },
        ["進入奇瑪"] = {
            map_name= 'P2_5',
            interaction_object= {'奇瑪'},
            interaction_object_map_name= {'P2_6'},
            index = 380
        },
        ["奇瑪"] = {
            map_name= 'P2_6',
            index = 381
        },
        ["探索奇瑪並尋找儀式場所"] = {
            map_name= 'P2_6',
            interaction_object= {'奇瑪水源地'},
            interaction_object_map_name= {'P2_7'},
            index = 382
        },
        ["召喚賈多"] = {
            map_name= 'P2_6',
            interaction_object= {'召喚賈多'},
            interaction_object_map_name= {'P2_7'},
            index = 383
        },
        ["和賈多對話"] = {
            map_name= 'P2_6',
            interaction_object= {'賈多'},
            interaction_object_map_name= {'賈多'},
            index = 384
        },
        ["進入奇瑪水源地"] = {
            map_name= 'P2_6',
            interaction_object= {'奇瑪水源地'},
            interaction_object_map_name= {'P2_7'},
            index = 385
        },
        ["奇瑪水源地"] = {
            map_name= 'P2_7',
            index = 386
        },
        ["探索奇瑪水源地"] = {
            map_name= 'P2_7',
            index = 387
        },
        ["擊敗法里登王子．亞茲馬迪"] = {
            map_name= 'P2_7',
            Boss = {"法里登王子．亞茲馬迪"},
            index = 388
        },
        ["與雄偉巨靈之幣互動"] = {
            map_name= 'P2_7',
            interaction_object = {"宏偉巨靈之幣"},
            index = 389
        },
        ["與賈多對話"] = {
            map_name= 'P2_7',
            interaction_object= {'賈多'},
            interaction_object_map_name= {'賈多'},
            index = 390
        },
        ["與黑衣幽魂對話來前往庫萊亞山。"] = {
            map_name= 'P2_Town',
            interaction_object= {'黑衣幽魂','前往庫萊亞山'},
            grid_x = 307,
            grid_y = 313,
            index = 391
        },
        ["林間空地"] = {
            map_name= 'P3_Town',
            index = 392
        },
        ["與多里亞尼對話"] = {
            map_name= 'P3_Town',
            interaction_object= {'多里亞尼'},
            index = 392
        },
        ["進入灰燼森林"] = {
            map_name= 'P3_2',
            index = 393
        },
        ["灰燼森林"] = {
            map_name= 'P3_2',
            index = 394
        },
        ["探索灰燼森林"] = {
            map_name= 'P3_2',
            interaction_object= {'庫萊亞村'},
            interaction_object_map_name= {'P3_2'},
            index = 395
        },
        ["進入庫萊亞村"] = {
            map_name= 'P3_2',
            interaction_object= {'庫萊亞村'},
            interaction_object_map_name= {'P3_2'},
            index = 396
        },
        ["庫萊亞村"] = {
            map_name= 'P3_2',
            index = 397
        },
        ["探索庫萊亞村"] = {
            map_name= 'P3_2',
            interaction_object= {'冰川湖泊'},
            interaction_object_map_name= {'P3_3'},
            index = 398
        },
        ["擊敗瘋狂的阿茲莫里人"] = {
            map_name = 'P3_2',
            Boss = {"迷失長矛．萊塔拉"},
            interaction_object_map_name = {'P3_3'},
            index = 399
        },
        ["進入冰川湖泊"] = {
            map_name= 'P3_2',
            interaction_object= {'冰川湖泊','寶石殼顱骨'},
            interaction_object_map_name= {'P3_3'},
            index = 401
        },
        ["冰川湖泊"] = {
            map_name= 'P3_3',
            index = 402
        },
        ["探索冰川湖泊"] = {
            map_name= 'P3_3',
            interaction_object= {'庫萊亞山巔'},
            interaction_object_map_name= {'P3_5'},
            index = 403
        },
        ["擊敗凍結之爪．拉卡爾"] = {
            map_name = 'P3_3',
            Boss = {"凍結之爪．拉卡爾"},
            interaction_object_map_name = {'P3_5'},
            index = 404
        },
        ["進入庫萊亞山巔"] = {
            map_name= 'P3_6',
            index = 405
        },
        ["庫萊亞山巔"] = {
            map_name= 'P3_6',
            index = 406
        },
        ["探索庫萊亞山巔"] = {
            map_name= 'P3_6',
            index = 407
        },
        ["進入蝕刻溪谷"] = {
            map_name= 'P3_6',
            index = 408
        },
        ["蝕刻溪谷"] = {
            map_name= 'P3_6',
            index = 409
        },
        ["探索蝕刻溪谷"] = {
            map_name= 'P3_6',
            interaction_object= {'庫阿西克寶庫'},
            interaction_object_map_name= {'P3_7'},
            index = 410
        },
        ["擊敗風暴血獸"] = {
            map_name = 'P3_6',
            Boss = {"守護者．風暴血獸"},
            interaction_object_map_name = {'P3_7'},
            index = 411
        },
        ["進入庫阿西克寶庫"] = {
            map_name= 'P3_7',
            index = 412
        },
        ["庫阿西克寶庫"] = {
            map_name= 'P3_7',
            index = 413
        },
        ["探索庫阿西克寶庫"] = {
            map_name= 'P3_7',
            interaction_object= {'門'},
            index = 414
        },
        ["擊敗佐林和澤莉娜"] = {
            map_name= 'P3_7',
            Boss={"鮮血女祭司．澤莉娜","鮮血祭司．佐林"},
            interaction_object= {'門'},
            index = 415
        },
        ["召喚多里亞尼"] = {
            map_name= 'P3_7',
            interaction_object= {"召喚多里亞尼"},
            index = 416
        },
        ["找到狂嗥洞穴"] = {
            map_name= 'P3_4',
            index = 417
        },
        ["狂嗥洞穴"] = {
            map_name= 'P3_4',
            index = 418
        },
        ["找到雪獸"] = {
            map_name= 'P3_4',
            index = 419
        },
        ["擊敗雪獸"] = {
            map_name= 'P3_4',
            Boss = {"怪異雪獸"},
            index = 420
        },
        ["拾起寒冰獠牙"] = {
            map_name= 'P3_4',
            interaction_object= {"寒冰獠牙"},
            index = 421
        },
        ["將寒冰獠牙交給希爾妲"] = {
            map_name= 'P3_Town',
            interaction_object= {"希爾妲"},
            index = 422
        },
        ["向希爾妲領取獎勵"] = {
            map_name= 'P3_Town',
            interaction_object= {"希爾妲","狂嗥之風獎勵"},
            grid_x = 534,
            grid_y = 393,
            index = 423
        },
        ["跟黑衣幽魂領取獎勵"] = {
            map_name= 'G4_town',
            interaction_object= {'黑衣幽魂'},
            grid_x = 1023,
            grid_y = 1635,
            index = 424
        },
        ["與黑衣幽魂對話來前往奧瑞亞。"] = {
            map_name= 'G4_town',
            interaction_object= {'黑衣幽魂',"前往奧瑞亞"},
            grid_x = 1023,
            grid_y = 1635,
            index = 424
        },
        ["靈魂深井"] = {
            map_name= 'G2_Abyss_Hub',
            index = 425
        },
    }
}
return main_task