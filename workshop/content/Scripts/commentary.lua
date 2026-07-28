local commentary = {}

local banks = {
    instant = {
        "{guild}这波属于击杀基础，{player}的DPS不基础。",
        "{player}千百次练习只为这一刻，{boss}千百点血量只撑这一刻。",
        "{boss}刚亮血条，{guild}已经把结算页面预加载好了。",
        "我要验牌——验完发现{player}拿的是伤害王炸。",
        "{guild}从从容容进场，{boss}连滚带爬退场。",
        "{guild}没有预制伤害，全是{player}现炒的爆发。",
        "{player}给足了情绪价值：满血进场，空血离场。",
        "{boss}：我准备好了。{guild}：如何呢，又能怎？",
    },
    million = {
        "{guild}赛博对账完成：{boss}欠的百万血条，今天一次结清。",
        "百万伤害基础，{player}这份输出一点也不基础。",
        "{player}敬自己一杯，七位数伤害已经替你买单。",
        "不是助我破鼎，是{player}助{boss}破防。",
        "{guild}喊一声来财，伤害和掉落一起到账。",
        "{player}把输出打出了活人感，{boss}只剩阵亡感。",
        "七位数一出来，{guild}的计算器先空降疲惫了。",
        "{player}主理百万伤害，{boss}主理安静躺下。",
    },
    nuclear = {
        "{guild}这一轮不是爆发，是往{boss}血条里塞了一颗太阳。",
        "{player}把火力密度拉满，{boss}申请现场验牌。",
        "核爆基础，{player}这一轮的数字完全不基础。",
        "{boss}突然空降疲惫，病因是{player}刚按完技能。",
        "{guild}十秒赛博对账，{boss}的血条当场余额不足。",
        "{player}主理瞬间爆炸，护甲主理重新理解物理。",
        "{guild}的火力从从容容，{boss}的血条连滚带爬。",
        "这不是预制核爆，是{player}端上来的现炒伤害。",
    },
    hot = {
        "{guild}手感正热，伤害数字排队冲进{boss}的血条。",
        "{player}这十秒情绪价值拉满，{boss}的情绪暂不考虑。",
        "输出基础，{player}越打越热这件事不基础。",
        "{guild}开始主理战场，{boss}开始主理撤退路线。",
        "{player}把节奏推上来了，下一轮准备继续破鼎。",
        "{boss}想问如何呢又能怎，{guild}回答继续打。",
        "{player}的输出很有活人感，血条掉得也很有实感。",
        "{guild}拒绝预制手感，这十秒全部现打现结。",
    },
    domination = {
        "{player}承包了大半片血条，{guild}负责见证主理人营业。",
        "{player}火力过于醒目，{boss}可能以为今天是单挑。",
        "我要验牌——{player}这张牌上写着全场主C。",
        "{guild}赛博对账发现，大部分伤害都签着{player}的名字。",
        "伤害占比基础，{player}这个占比完全不基础。",
        "{player}一骑绝尘，{boss}的血条已经记住这个名字。",
        "{player}把活人感留在榜首，把空血感留给了{boss}。",
        "{guild}本场情绪价值由{player}独家赞助。",
    },
    acceleration = {
        "{guild}突然踩下油门，{boss}的好日子到头了。",
        "{player}上一轮叫预热，这一轮才叫主理输出。",
        "翻倍基础，{player}越打越凶一点也不基础。",
        "{player}千百次练习只为这一刻，伤害曲线正式起飞。",
        "{guild}加速完成，{boss}当场空降疲惫。",
        "赛博对账发现：{player}这一轮比上一轮更不讲道理。",
        "{player}从从容容升档，{boss}连滚带爬掉血。",
        "不是技能突然变强，是{guild}刚才只在热身。",
    },
    captured = {
        "{guild}不只要伤害，还要把{boss}打包带走。",
        "{boss}从对手变成同事，{guild}的入职流程很有实战感。",
        "赛博对账完成：{boss}用自由换回了剩余血条。",
        "打不过就加入，{boss}把这句话执行得相当彻底。",
        "{guild}喊一声来财，战利品真的自己走过来了。",
        "捕捉基础，{guild}把Boss变队友的操作不基础。",
        "{player}负责伤害，{guild}负责把{boss}写进员工名单。",
        "{boss}获得了新的主理岗位：替{guild}继续打工。",
    },
    failed = {
        "这次{boss}守住了血条，{guild}先敬老己一杯再回来。",
        "战斗暂时中断，{boss}获得一张由{guild}签发的限时免死券。",
        "{player}的输出没有消失，只是在准备下一次破鼎。",
        "{boss}今天侥幸下班，{guild}的赛博账本已经记上了。",
        "{guild}这局先存档，下次让{boss}连本带利结算。",
        "撤退基础，{guild}把下一次秒杀提前存档不基础。",
        "血条没清空，但{player}的经验条已经偷偷上涨。",
        "{guild}从从容容回城，等下次让{boss}连滚带爬。",
    },
    close = {
        "{player}和{runnerup}把榜首打成了赛博验牌现场。",
        "{guild}的MVP竞争很有活人感，结算板差点冒出火星。",
        "第一基础，第二也不基础，{guild}这份榜单含金量拉满。",
        "{player}与{runnerup}咬得太紧，MVP差点要猜拳决定。",
        "{guild}本场不是单核，是两位输出主理人共同营业。",
        "{boss}输得很有团队感，{guild}每个人都在血条上签了名。",
        "我要验牌——{player}和{runnerup}只差一张暴击牌。",
        "{guild}给足彼此情绪价值，顺便把{boss}送进结算。",
    },
    finish = {
        "血条归零，数据入账，今天又是{guild}营业成功的一天。",
        "{boss}负责倒下，{player}负责把结算榜变得好看。",
        "{guild}赛博对账完成：输出在线，{boss}不在线。",
        "击杀基础，{guild}这份配合一点也不基础。",
        "{player}主理本场MVP，{boss}主理安静下班。",
        "{guild}千百次练习只为这一刻，接下来进入快乐看榜。",
        "{player}给足伤害，{guild}给足情绪价值。",
        "{boss}已经空降疲惫，{guild}仍然从从容容。",
        "不是预制胜利，是{guild}一刀一技能现打出来的。",
        "{player}敬自己一杯，这份伤害确实值得。",
    },
}

local function render(template, stats)
    local values = {
        guild = tostring(stats.guild or "全队"),
        player = tostring(stats.player or "本场选手"),
        runnerup = tostring(stats.runnerup or "另一位高手"),
        pal = tostring(stats.pal or "帕鲁伙伴"),
        boss = tostring(stats.boss or "Boss"),
    }
    return (string.gsub(template, "{([%a_]+)}", function(key)
        return values[key] or ""
    end))
end

local function stable_hash(seed)
    local text = tostring(seed or "")
    local hash = 0
    for index = 1, #text do
        hash = (hash * 33 + string.byte(text, index)) % 2147483647
    end
    return hash
end

local function choose(list, seed, stats)
    local hash = stable_hash(seed)
    return render(list[(hash % #list) + 1], stats)
end

function commentary.progress(stats)
    local seed = table.concat({ stats.key or "", stats.total or 0, stats.window_index or 0 }, ":")
    if stats.current_dps >= 1000000 or stats.window_damage >= 3000000 then
        return choose(banks.nuclear, seed, stats)
    end
    if stats.total >= 1000000 and stats.previous_total < 1000000 then
        return choose(banks.million, seed, stats)
    end
    if stats.current_dps >= 100000 then
        return choose(banks.hot, seed, stats)
    end
    if stats.previous_dps > 0 and stats.current_dps >= stats.previous_dps * 2
        and stats.current_dps >= 10000 then
        return choose(banks.acceleration, seed, stats)
    end
    if stats.top_share >= 80 and stats.total >= 10000 then
        return choose(banks.domination, seed, stats)
    end
    return nil
end

function commentary.final(stats)
    local seed = table.concat({ stats.key or "", stats.total or 0, stats.duration or 0, stats.reason or "" }, ":")
    if stats.reason == "timeout" then
        return choose(banks.failed, seed, stats)
    end
    if stats.reason == "captured" then
        return choose(banks.captured, seed, stats)
    end
    if stats.duration <= 3 then
        return choose(banks.instant, seed, stats)
    end
    if stats.total >= 1000000 then
        return choose(banks.million, seed, stats)
    end
    if stats.team_dps >= 100000 then
        return choose(banks.nuclear, seed, stats)
    end
    if stats.second_share > 0 and stats.top_share - stats.second_share <= 5 then
        return choose(banks.close, seed, stats)
    end
    if stats.top_share >= 80 and stats.total >= 10000 then
        return choose(banks.domination, seed, stats)
    end
    return choose(banks.finish, seed, stats)
end

return commentary
