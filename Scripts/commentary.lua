local commentary = {}

local banks = {
    instant = {
        "Boss刚亮血条就开始写遗书了。",
        "这不是战斗，这是血条的闪退现场。",
        "开场动画还没播完，Boss已经在结算页面等大家。",
        "一眨眼就结束，Boss甚至没来得及认全人。",
        "这波属于进门、爆炸、收工，一气呵成。",
        "Boss：我准备好了。糖罐：不，你没有。",
    },
    million = {
        "百万伤害到账，血条看完选择了沉默。",
        "伤害突破一百万，计算器已经申请工伤。",
        "七位数输出！Boss的血条正在连夜搬家。",
        "一百万不是终点，是糖罐热身结束的提示音。",
        "这串数字有点长，Boss看一半就倒了。",
        "百万大关被踩过去了，输出仪表盘开始冒烟。",
    },
    nuclear = {
        "瞬间爆炸！这十秒像往血条里塞了一颗太阳。",
        "本轮火力过于灿烂，Boss的护甲正在重新理解物理。",
        "输出峰值拉满，空气里全是暴击数字。",
        "这一轮不是爆发，是伤害数字集体越狱。",
        "十秒核爆窗口完成，Boss血条当场失去表情。",
        "火力密度严重超标，建议给Boss发一副护目镜。",
    },
    hot = {
        "手感正热，伤害数字排队冲进Boss血条。",
        "这一轮输出很有精神，血条掉得相当配合。",
        "节奏拉起来了，下一轮可以更不讲道理。",
        "火力已经接管现场，Boss开始认真考虑撤退。",
        "输出曲线抬头了，糖罐正在加热。",
        "这十秒很扎实，Boss的血条明显有意见。",
    },
    domination = {
        "有人承包了大半片血条，其他人负责见证历史。",
        "头名火力过于醒目，Boss可能以为今天是单挑。",
        "输出集中度拉满，第一名正在独自装修结算榜。",
        "一位选手拿走了大部分伤害，血条快记住名字了。",
        "主力输出正在一骑绝尘，后排请抓紧上车。",
    },
    acceleration = {
        "火力突然翻倍，看来刚才确实只是在热身。",
        "输出档位往上推了，Boss的好日子到头了。",
        "第二轮明显认真了，伤害曲线开始起飞。",
        "加速完成，这十秒比上一轮凶多了。",
        "糖罐踩下油门，血条开始倒着长。",
    },
    captured = {
        "打赢还不够，顺手把Boss装进球里带走了。",
        "Boss从对手变成同事，入职流程相当暴力。",
        "血条没能保住自由，但成功保住了性命。",
        "最终结论：打不过就加入，Boss执行得很彻底。",
        "这场战斗的战利品会自己走路，性价比很高。",
        "Boss已被打包带走，糖罐今天拒绝空手回家。",
    },
    failed = {
        "这次Boss守住了血条，糖罐先去补给，账下次再算。",
        "战斗暂时中断，Boss获得了一张限时免死券。",
        "输出没有消失，只是去准备下一次更响的爆炸。",
        "Boss今天侥幸下班，糖罐的复仇清单已经更新。",
        "这局先记在小本本上，下次连本带利拿回来。",
        "撤退不是失败，是把下一次秒杀提前存档。",
        "血条这次没清空，但经验条已经偷偷涨了。",
    },
    close = {
        "输出咬得很紧，MVP差点需要猜拳决定。",
        "榜首竞争相当激烈，结算板差点冒出火星。",
        "大家输出都很能打，这份榜单含金量很足。",
        "这是一场真正的团队围殴，Boss输得很有集体感。",
        "伤害分布很漂亮，每个人都在血条上留了签名。",
    },
    finish = {
        "血条归零，数据入账，今天又是糖罐营业成功的一天。",
        "Boss负责倒下，大家负责把结算榜变得好看。",
        "战斗结束，伤害数字排好队来领取掌声。",
        "结算完成：配合在线，输出在线，Boss不在线。",
        "这一场打得有条有理，除了Boss的血条比较凌乱。",
        "任务完成，接下来进入快乐看榜环节。",
        "数据不会说谎，但这份伤害确实有点嚣张。",
        "Boss已经下班，MVP还在结算板上加班。",
    },
}

local function choose(list, seed)
    local text = tostring(seed or "")
    local hash = 0
    for index = 1, #text do
        hash = (hash * 33 + string.byte(text, index)) % 2147483647
    end
    return list[(hash % #list) + 1]
end

function commentary.progress(stats)
    local seed = table.concat({ stats.key or "", stats.total or 0, stats.window_index or 0 }, ":")
    if stats.current_dps >= 1000000 or stats.window_damage >= 3000000 then
        return choose(banks.nuclear, seed)
    end
    if stats.total >= 1000000 and stats.previous_total < 1000000 then
        return choose(banks.million, seed)
    end
    if stats.current_dps >= 100000 then
        return choose(banks.hot, seed)
    end
    if stats.previous_dps > 0 and stats.current_dps >= stats.previous_dps * 2
        and stats.current_dps >= 10000 then
        return choose(banks.acceleration, seed)
    end
    if stats.top_share >= 80 and stats.total >= 10000 then
        return choose(banks.domination, seed)
    end
    return nil
end

function commentary.final(stats)
    local seed = table.concat({ stats.key or "", stats.total or 0, stats.duration or 0, stats.reason or "" }, ":")
    if stats.reason == "timeout" then
        return choose(banks.failed, seed)
    end
    if stats.reason == "captured" then
        return choose(banks.captured, seed)
    end
    if stats.duration <= 3 then
        return choose(banks.instant, seed)
    end
    if stats.total >= 1000000 then
        return choose(banks.million, seed)
    end
    if stats.team_dps >= 100000 then
        return choose(banks.nuclear, seed)
    end
    if stats.second_share > 0 and stats.top_share - stats.second_share <= 5 then
        return choose(banks.close, seed)
    end
    if stats.top_share >= 80 and stats.total >= 10000 then
        return choose(banks.domination, seed)
    end
    return choose(banks.finish, seed)
end

return commentary
