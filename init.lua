--------------------------------------------------
--Vup杀
--------------------------------------------------

--狂野模式开关
--记得把zzsystem.lua里的也设置为true
wild_mode = false	--狂野模式！！（仅限服务器用，解放偷梁换柱、猴子）

--------------------------------------------------
--描述里的加号都给老子别用全角！！！——Notify
--（旧Vup杀）转换技描述里带半角加号会转不动。
--------------------------------------------------

local extension = Package("vupslash")
extension.metadata = require "packages.vupslash.metadata"
-- 加载本包的翻译包(load translations of this package)，这一步在本文档的最后进行。

--------------------------------------------------
--计划
--房间部分：
-- 增加读条秒数及无懈可击秒数
-- 增加手气卡
-- 增加密码
-- 增加安全直播模式
--游戏部分：
-- 增加音量调节功能
-- 增加超过最大体力值和滋养
-- 增加交互方式
-- 思考图片的处理方式
--底层部分
-- 增加属性伤害（涉及：冰沙···）
-- 在卡牌上做标记（涉及：秋乌炽翎）
-- 增加轮次时点（涉及：萨比萌视幻）
-- 新增技能种类：转换技
-- 玩家是否可以使用特定牌
-- 胜率！（根据单游戏包/多游戏包，不同模式分类（可以把这些也做进筛选项））
-- 录像！！！！
-- AI！！！！！
--UI部分
-- 推进UI扩展包
--------------------------------------------------

--------------------------------------------------
--通用马克
--4/3血量的前端怎么处理需要后续看看QML能不能直接通过导入最大血量及现有血量逃课（N说是涉及底层汇编级别的问题，我想应该以后会有别的办法）

--skillinvoke强行发动一次的问题后续可以通过调整on_cost处理。【初步解决，后续检查并实装on_cost，等0.0.7skillinvoke更新后改回来。】
-- 涉及范围：视幻（等回头搞好时机再说） 蟹袭（未测试） 忆狩（掉血部分优化暂无法完成） 娇惰
--缺少技能无效时的应对（慵懒，芳仙，视幻等，后续更新）【疑似在skill里有可用函数】
-- 在上面的情况下，以下技能存在跳过阶段无法作为on_cost一部分的方式，后续处理（芳仙、娇惰）
--通用计算回合内伤害/弃牌量的东西暂时耦合在其他技能里（扬歌，抹挑）
--回合后一键删除标记集成（龙息，抹挑，连奏，袭穴，芳仙，视幻，忆狩，娇惰）

--有个player:canEffect(对方角色,技能名)以及SkillCanTarget(对方角色, player, 技能名)的看不出来是什么，疑似与词条“发动此技能”有关，但和技能无效一样是通用内容）

--bug:
--铁索连环的联动容易出问题，据说第一张用铁索的卡诺娅会直接触发技能。
--------------------------------------------------

--------------------------------------------------
-- gamerule开发计划
-- 1. （room）标记清理
-- 可以集中清理角色身上标记，需要涉及的时间点：
-- 回合结束、出牌阶段结束、摸牌阶段结束、弃牌阶段结束
-- 可以支持清除指定前缀/后缀的标记。
-- 扩展：可以清除手牌上的标记，时机：离开手牌区（仅持有者变化不影响标记），进入弃牌堆，拥有者变化

-- 2. （room/player）统计一名角色本回合造成/受到的伤害

-- 3. （room/player）统计一名角色是否在本回合内使用牌指定过其他角色

-- 4. （room/player）统计一名角色弃牌阶段因为弃置而失去的牌数

-- 5. （player）使用的下一张牌可以额外增加/取消N个目标，是否受距离限制

-- 6. 重铸牌，返回牌堆
--------------------------------------------------

--------------------------------------------------
--检查是否存在对应阶段（以后可以考虑搬走）
--------------------------------------------------

local function exist_or_not(player, Phase)
  local exist_truth = true
  if player.skipped_phases ~= {} then
    for k in ipairs(player.skipped_phases) do
      if k == Phase then
        exist_truth = false
      end
    end
  end
  return exist_truth
end

--------------------------------------------------
--花色相对
--------------------------------------------------

local function suit_close(suit)
  if suit == Card.Spade then
    return Card.Club
  elseif suit == Card.Club then
    return Card.Spade
  elseif suit == Card.Heart then
    return Card.Diamond
  elseif suit == Card.Diamond then
    return Card.Heart
  end
end

--------------------------------------------------
--返回phase对应的字符串
--请注意8 notactive、9 phasenone暂无官方叫法，暂未写入
--------------------------------------------------

local function phase_string(phase_int)
  if phase_int == 1 then
    return "回合开始"
  elseif phase_int == 2 then
    return "准备"
  elseif phase_int == 3 then
    return "判定"
  elseif phase_int == 4 then
    return "摸牌"
  elseif phase_int == 5 then
    return "出牌"
  elseif phase_int == 6 then
    return "弃牌"
  elseif phase_int == 7 then
    return "结束"
  else
    return "我也不知道"
  end
end


--------------------------------------------------
--交互方式逃课方案1
--------------------------------------------------

local function yes_or_no(player, skill_name, prompt)
  local room = player.room
  local choiceList = {}
  table.insert(choiceList, "confirm")
  table.insert(choiceList, "cancel")
  local choice = room:askForChoice(player, choiceList, skill_name, prompt)
  if choice == "confirm" then
    return true
  elseif choice == "cancel" then
    return false
  end
end

--------------------------------------------------
--标记清理者（回合结束版）
--TODO:清理需要规避的东西还没完善;global与否以及怎么放进系统待定
--TODO2:目前已做完的需要纳管的技能（龙息，抹挑，连奏，袭穴，芳仙，视幻，忆狩，娇惰）
--TODO3:失去技能后对标记的处理可以在一键删除姬里面处理（龙息，视幻（待定），袭穴）。
--TODO4:各类基础信息统计
--------------------------------------------------

local turn_end_clear_mark = {}	--回合结束清除的标记
local mark_cleaner = fk.CreateTriggerSkill{
name = "mark_cleaner",
refresh_events = {fk.EventPhaseChanging},
can_refresh = function(self, event, target, player, data)
  return data.from ~= Player.NotActive and data.to == Player.NotActive
end,
on_refresh = function(self, event, target, player, data)
  local room = player.room
  for _, p in ipairs(turn_end_clear_mark) do
    room:setPlayerMark(player, p, 0)
  end
end,
}

--Fk:addSkill(mark_cleaner)

--------------------------------------------------
--额外体力标记
--bug：技能未触发
--技能马克：未完成滋养前置的体力增加导致额外体力标记数量增加。
--------------------------------------------------

local extra_hp = fk.CreateTriggerSkill{
name = "#extra_hp",
refresh_events = {fk.GameStart, fk.Damaged, fk.HpChanged},
can_refresh = function(self, event, target, player, data)
  if event == fk.GameStart then
    return true
  elseif event == fk.Damaged then
    local damage = data
    return target == player and damage.damage > 0
  elseif event == fk.HpChanged then
    local damage = data
    return target == player and damage.damage < 0
  end
end,
on_refresh = function(self, event, target, player, data)
  local room = player.room
  if event == fk.GameStart then
    -- 检索所有在场角色，赋予额外体力标记。
    print(1)
    local all = room:getAllPlayers()
    for _,p in ipairs(all) do
      if p.hp > p.maxhp then
        local x = p.hp - p.maxHp
        room:setPlayerMark(p, "@extra_hp", x)
      end
    end
  elseif event == fk.Damaged then
    --减少对应的标记，如小于最大体力，归零
    if player.maxhp >= player.hp then
      room:setPlayerMark(player, "@extra_hp", 0)
    else
      local x = player.hp - player.maxHp
      room:setPlayerMark(player, "@extra_hp", x)
    end
  elseif event == fk.HpChanged then
    --增加对应的标记，需要注意此处的damage可能要改成-1之类的，配合以后的伪滋养处理吧。
    local damage = data
    print(data)
  end
end,
}

Fk:addSkill(extra_hp)

--------------------------------------------------
--本回合造成多少伤害
--------------------------------------------------

local damage_checker = fk.CreateTriggerSkill{
name = "#damage_checker",
refresh_events = {fk.Damage},
can_refresh = function(self, event, target, player, data)
  return target == player
end,
on_refresh = function(self, event, target, player, data)
  local room = player.room
  local damage = data
  print(damage.damage)
  room:addPlayerMark(player, "#turn_damage", damage.damage)
end,
}
table.insert(turn_end_clear_mark, "#turn_damage")

--Fk:addSkill(damage_checker)

--------------------------------------------------
--测试技能：超级英姿
--------------------------------------------------
local super_yingzi = fk.CreateTriggerSkill{
  name = "superyingzi",
  anim_type = "drawcard",
  events = {fk.DrawNCards},
  on_use = function(self, event, target, player, data)
    data.n = data.n + 20
  end,
}

--------------------------------------------------
--嗜甜
--------------------------------------------------

local v_shitian = fk.CreateTriggerSkill{
  name = "v_shitian",
  --默认播放配音，可以通过Mute=false关闭技能配音。
  --mute = true,
  --赋予支援型技能定义
  anim_type = "support", 
  --时机：阶段开始时
  events = {fk.EventPhaseStart}, 
  --触发条件：触发时机的角色为遍历到的角色、遍历到的角色具有本技能、遍历到的角色处于准备阶段。
  can_trigger = function(self, event, target, player, data) 
    return target == player and player:hasSkill(self.name) and
      player.phase == Player.Start
  end,
  -- on_trigger = function(self, event, target, player, data)
  --   --if self:isEffectable(player) then
  --   self:doCost(event, target, player, data)
  --   --end
  -- end,
  -- on_cost = function(self, event, target, player, data)
  --   --if self:isEffectable(player) then
  --   return true
  --   --end
  -- end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    --播放技能语音
    room:broadcastSkillInvoke(self.name)
    local judge = {} ---@type JudgeStruct
    judge.who = player
    --这一条的意思是，出现以下两种花色条件后显示判定成功的特效
    judge.pattern = ".|.|heart,diamond"
    judge.reason = self.name
    room:judge(judge)

    if judge.card.color == Card.Red then
      player:drawCards(1, self.name)
      --考虑到本作存在治疗过量概念，不需要角色受伤也可触发回复效果。
      --if player:isWounded() then 
      room:recover{
        who = player,
        num = 1,
        recoverBy = player,
        skillName = self.name,
      }
      --彩蛋标签准备
      room:setPlayerMark(player, "v_shitian_failed", 0)
      room:delay(500)
    else	--触发彩蛋
      if player:getMark("v_shitian_failed") >= 1 then
        room:setEmotion(player, "./packages/vupslash/image/anim/v_shitian_failed")

      else
        room:addPlayerMark(player, "v_shitian_failed", 1)
      end
    end
  end,
}

--------------------------------------------------
--藏聪
--------------------------------------------------

local v_cangcong = fk.CreateTriggerSkill{
  name = "v_cangcong",
  --赋予防御型技能定义
  anim_type = "defensive",
  --时机：目标确定后
  events = {fk.TargetConfirmed},
  --触发条件：触发时机的角色为遍历到的角色、遍历到的角色具有本技能、牌的种类为杀/锦囊牌、牌的目标>1。
  can_trigger = function(self, event, target, player, data)
    --print(#AimGroup:getAllTargets(data.tos))
    return target == player and player:hasSkill(self.name) and
      (data.card.name == "slash" or (data.card.type == Card.TypeTrick and
      data.card.sub_type ~= Card.SubtypeDelayedTrick)) and
      #AimGroup:getAllTargets(data.tos) > 1
  end,
  -- on_trigger = function(self, event, target, player, data)
  --   --if self:isEffectable(player) then
  --   self:doCost(event, target, player, data)
  --   --end
  -- end,
  -- on_cost = function(self, event, target, player, data)
  --   --if self:isEffectable(player) then
  --   return true
  --   --end
  -- end,
  on_use = function(self, event, target, player, data)
    table.insert(data.nullifiedTargets, player.id)
  end,
}

--------------------------------------------------
--绫奈奈奈
--------------------------------------------------

local lingnainainai_fentujk = General(extension, "lingnainainai_fentujk", "psp", 3, 3, General.Female)
lingnainainai_fentujk:addSkill(v_shitian)
lingnainainai_fentujk:addSkill(v_cangcong)

--------------------------------------------------
--抽卡
--技能马克：花色多次判定显示英文；解锁隐藏巫女豹与戦的代码；
--------------------------------------------------

local v_chouka = fk.CreateTriggerSkill{
  name = "v_chouka",
  --赋予摸牌型技能定义
  anim_type = "drawcard",
  --时机：阶段开始时
  events = {fk.EventPhaseStart},
  --触发条件：触发时机的角色为遍历到的角色、遍历到的角色具有本技能、遍历到的角色处于摸牌阶段。
  can_trigger = function(self, event, target, player, data)
    return (target == player and player:hasSkill(self.name) and player.phase == Player.Draw)
  end,
  -- on_trigger = function(self, event, target, player, data)
  --   --if self:isEffectable(player) then
  --   self:doCost(event, target, player, data)
  --   --end
  -- end,
  -- on_cost = function(self, event, target, player, data)
  --   --if self:isEffectable(player) then
  --   return true
  --   --end
  -- end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    --记录已判定的花色
    local used_suit = {}
    local dummy = Fk:cloneCard('slash', Card.NoSuit, 0)
    while true do
      local all_suit = {"spade", "heart", "club", "diamond"}
      for _, s in ipairs(used_suit) do table.removeOne(all_suit, s) end
      local pattern = ".|.|" .. (#all_suit == 0 and "none" or table.concat(all_suit, ","))
      local judge = {
        who = player,
        reason = self.name,
        pattern = pattern,
      }
      room:judge(judge)
      local suit = judge.card:getSuitString()
      if table.contains(used_suit, suit) then
        return true
      else
        table.insert(used_suit, suit)
        dummy:addSubcard(judge.card)
      end
      local prompt_suit = table.concat(used_suit, "+")
      local prompt = "v_chouka_choice_log:::"..prompt_suit
      local choices = {"v_chouka_repeat", "v_chouka_stop"}
      local choice = room:askForChoice(player, choices, self.name, prompt)
      --点击取消，退出判定。
      if choice == "v_chouka_stop" then
        room:obtainCard(player.id, dummy, true)
        if #(dummy.subcards) >= 3 then
          room:setEmotion(player, "./packages/vupslash/image/anim/haibao")
          --getThread暂无此代码，因此先注释掉。
          room:delay(360)
          room:setEmotion(player, "./packages/vupslash/image/anim/haibao")
          if #(dummy.subcards) >= 4 then
            --为玩家记录可解锁角色，由于暂无本功能，先注释掉
            --RecordUnlockGenerals(player, "baishenyao_weiwunv")
            room:delay(360)
            room:setEmotion(player, "./packages/vupslash/image/anim/haibao")
            room:delay(360)
            room:setEmotion(player, "./packages/vupslash/image/anim/haibao")
          end
        end
        room:delay(500)
        break
      end
    end
  end,
}

--------------------------------------------------
--慵懒
--技能马克：后续需要关注丈八等转化牌的效果（目前丈八是相加的暂时解决不了）
--------------------------------------------------

local v_yonglanHelper = fk.CreateTriggerSkill{
  name = "#v_yonglanHelper",
  refresh_events = {fk.TargetConfirming},
  can_refresh = function(self, event, target, player, data)
    --print(data.card.number)
    return (target == player and player:hasSkill(self.name))
  end,
  on_refresh = function(self, event, target, player, data)
    local card = data.card
    local room = player.room
    if card.trueName == "slash" and card.number > 0 then
      --print(card.number)
      room:setPlayerMark(player, "v_yonglan_currentSlash", card.number)
    else
      room:setPlayerMark(player, "v_yonglan_currentSlash", 999)
    end
  end
}
local v_yonglan = fk.CreateViewAsSkill{
  name = "v_yonglan",
  anim_type = "defensive",
  pattern = "jink",
  card_filter = function(self, to_select, selected)
    if #selected == 1 then return false end
    return Fk:getCardById(to_select).number > Self:getMark("v_yonglan_currentSlash")
      and Fk:currentRoom():getCardArea(to_select) ~= Player.Equip
  end,
  view_as = function(self, cards)
    if #cards ~= 1 then
      return nil
    end
    local c = Fk:cloneCard("jink")
    c:addSubcard(cards[1])
    return c
  end,
  enabled_at_response = function(self, player)
    return player:usedSkillTimes(self.name, Player.HistoryTurn) < 1
  end,
}
v_yonglan:addRelatedSkill(v_yonglanHelper)

--------------------------------------------------
--白神遥
--角色马克：抽卡，慵懒
--------------------------------------------------

local baishenyao_zhaijiahaibao = General(extension, "baishenyao_zhaijiahaibao", "psp", 3, 3, General.Female)
baishenyao_zhaijiahaibao:addSkill(v_chouka)
baishenyao_zhaijiahaibao:addSkill(v_yonglan)

--------------------------------------------------
--咏星
--------------------------------------------------

local v_yongxing = fk.CreateTriggerSkill{
  --（刚需）技能认证名
  name = "v_yongxing",
  --(非必要）赋予摸牌型技能定义
  anim_type = "drawcard",
  --技能为锁定技，满足条件后强制发动
  frequency = Skill.Compulsory,
  --时机：造成伤害后
  events = {fk.Damage},
  --触发条件：
  --存在触发时机的角色、触发时机的角色为遍历到的角色、遍历到的角色具有本技能、造成伤害的角色为遍历到的角色。
  can_trigger = function(self, event, target, player, data)
    local damage = data
    return target and target == player and player:hasSkill(self.name) and
      damage.from == player
  end,
  on_trigger = function(self, event, target, player, data)
    for i = 1, data.damage do
      self:doCost(event, target, player, data)
    end
  end,
  -- on_cost = function(self, event, target, player, data)
  --   for i = 1, data.damage do
  --     return true
  --   end
  -- end,
  on_use = function(self, event, target, player, data)
    player:drawCards(1, self.name)
  end,
}

--------------------------------------------------
--扬歌
--技能马克1：（后续跟全局合并）检测出牌阶段是否造成伤害暂时如果临时获得可能之前造成伤害不会算入
--技能马克2：如果存在角色存在不被特定牌指定的能力，此处暂时没写应对。
--------------------------------------------------

local v_yangge_damage_checker = fk.CreateTriggerSkill{
  name = "#v_yangge_damage_checker",
  refresh_events = {fk.Damage, fk.EventPhaseChanging},
  can_refresh = function(self, event, target, player, data)
    if event == fk.Damage then
      return target == player and player:hasSkill(self.name)
    elseif event == fk.EventPhaseChanging then
      return target == player and player:hasSkill(self.name) and data.from ~= Player.NotActive and data.to == Player.NotActive
    end
  end,
  on_refresh = function(self, event, target, player, data)
    if event == fk.Damage then
      local room = player.room
      local damage = data
      --print(damage.damage)
      room:addPlayerMark(player, "#play_damage", damage.damage)
    elseif event == fk.EventPhaseChanging then
      local room = player.room
      room:setPlayerMark(player, "#play_damage", 0)
    end
    
  end,
}
local v_yangge = fk.CreateTriggerSkill{
  name = "v_yangge",
  --赋予支援型技能定义
  anim_type = "support",
  --时机：阶段开始时
  events = {fk.EventPhaseStart},
  --触发条件：触发时机的角色为遍历到的角色、遍历到的角色具有本技能，遍历到的角色处于结束阶段，出牌阶段未被跳过，本回合未造成伤害、技能未失效（见on_trigger）。
  can_trigger = function(self, event, target, player, data)
    --阶段变化时，实现“是否跳出牌”的效果。
    --exist_or_not：用来确认是否跳过对应阶段，类似于以前的Player:isSkipped()
    return target == player and player:hasSkill(self.name) 
    and player.phase == Player.Finish and exist_or_not(player, Player.Play) and player:getMark("#play_damage") == 0
  end,
  -- on_trigger = function(self, event, target, player, data)
  --   --if self:isEffectable(player) then
  --   self:doCost(event, target, player, data)
  --   --end
  -- end,
  -- on_cost = function(self, event, target, player, data)
  --   --if self:isEffectable(player) then
  --   return true
  --   --end
  -- end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local peach_or_not = room:askForCard(player, 1, 1, false, self.name, true)[1]
    --print(peach_or_not)
    local alives = room:getAlivePlayers()
    local targets = {}
    for _,p in ipairs(alives) do
      table.insert(targets, p.id)
    end
    if peach_or_not then
      room:throwCard(peach_or_not, self.name, player)
      local god_salvation = Fk:cloneCard("god_salvation")
      local new_use = {} ---@type CardUseStruct
      new_use.from = player.id
      new_use.tos = {}
      for _, target in ipairs(targets) do
        table.insert(new_use.tos, { target })
      end
      new_use.card = god_salvation
      new_use.skillName = self.name
      room:useCard(new_use)
    else
      player:turnOver()
      local savage_assault = Fk:cloneCard("savage_assault")
      local new_use = {} ---@type CardUseStruct
      new_use.from = player.id
      new_use.tos = {}
      for _, target in ipairs(targets) do
        if target ~= player.id then
          table.insert(new_use.tos, { target })
        end
      end
      new_use.card = savage_assault
      new_use.skillName = self.name
      room:useCard(new_use)
    end
  end,
}
v_yangge:addRelatedSkill(v_yangge_damage_checker)

--------------------------------------------------
--东爱璃
--角色马克：
--------------------------------------------------

local dongaili_xingtu = General(extension, "dongaili_xingtu", "psp", 3, 3, General.Female)
dongaili_xingtu:addSkill(v_yongxing)
dongaili_xingtu:addSkill(v_yangge)

--------------------------------------------------
--袭穴
--技能马克：失去技能后对标记的处理可以在一键删除姬里面处理。
--------------------------------------------------
local v_xixue = fk.CreateTriggerSkill{
  name = "v_xixue",
  --赋予摸牌型技能定义
  anim_type = "drawcard",
  events = {fk.CardUseFinished},
  --触发条件：触发时机的角色为遍历到的角色、遍历到的角色具有本技能、遍历到的角色处于出牌阶段、满足技能条件
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and
      player.phase == Player.Play and self.can_xixue
  end,
  on_use = function(self, event, target, player, data)
    player:drawCards(1, self.name)
  end,

  refresh_events = {fk.CardUseFinished, fk.EventPhaseStart},
  can_refresh = function(self, event, target, player, data)
    if event == fk.EventPhaseStart then
      return target == player and player:hasSkill(self.name) and player.phase ~= Player.Play
    elseif event == fk.CardUseFinished then
      return target == player and player:hasSkill(self.name) and player.phase == Player.Play -- FIXME: this is a bug of FK 0.0.2!!
    end
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    if event == fk.EventPhaseStart then
      room:setPlayerMark(player, "#v_xixue_mark", 0)
      room:setPlayerMark(player, "@v_xixue_mark", 0)
    elseif event == fk.CardUseFinished then
      self.can_xixue = suit_close(data.card.suit) == player:getMark("#v_xixue_mark")
      room:setPlayerMark(player, "#v_xixue_mark", data.card.suit)
      room:setPlayerMark(player, "@v_xixue_mark", data.card:getSuitString())
    end
  end,
}

--------------------------------------------------
--小千村鼬鼬
--角色马克：袭穴
--------------------------------------------------

local xiaoqiancunyouyou_yaolingbaiyou = General(extension,"xiaoqiancunyouyou_yaolingbaiyou", "novus", 3, 3, General.Female)
xiaoqiancunyouyou_yaolingbaiyou:addSkill(v_xixue)

--------------------------------------------------
--链心
--技能马克：非锁定技，为防止星汐搬运出现问题后续需要重构；技能二次发动的提示需要优化。
--------------------------------------------------
local v_lianxin = fk.CreateTriggerSkill{
  --（刚需）技能认证名
  name = "v_lianxin",
  --(非必要）赋予特殊型技能定义
  anim_type = "special",
  --时机：受到伤害时，造成伤害时
  events = {fk.DamageInflicted},
  --触发条件：
  --触发时机的角色为遍历到的角色、遍历到的角色具有本技能、场上存在未被横置的角色、造成的伤害大于0。
  can_trigger = function(self, event, target, player, data)
    --遍历全场所有存活角色，挑出其中未被横置的角色。
    local room = player.room
    local alives = room:getAlivePlayers()
    local targets = {}
    local damage = data
    for _,p in ipairs(alives) do
      if not p.chained then
        table.insert(targets, p.id)
      end
    end
    return target == player and player:hasSkill(self.name) and
        #targets > 0 and damage.damage > 0
  end,
  on_use = function(self, event, target, player, data)
    --遍历全场所有存活角色，挑出其中未被横置的角色。
    local room = player.room
    local alives = room:getAlivePlayers()
    local targets = {}
    local prompt = "#v_lianxin_target"
    for _,p in ipairs(alives) do
      --chained使用true/false还是用chained/not-chained等会再看看源码
      if not p.chained then
        table.insert(targets, p.id)
      end
    end
    --选择是否发动技能，如果打算发动技能，则从先前的未被横置角色中选择一名发动此技能横置之。
    local to = room:askForChoosePlayers(player, targets, 1, 1, prompt, self.name)
    local trueto = room:getPlayerById(to[1])
    if #to > 0 then
      if not trueto.chained then
        trueto:setChainState(true)
      end
    else
      --后续优化为锁定技，靠这里的取消与否决定是否发动技能，否则就跳过
      return true
    end
    --TODO:发动技能后可以再发动一次技能，让这个角色回复一点体力
    if room:askForSkillInvoke(player,self.name,data) then
      room:recover{
        who = trueto,
        num = 1,
        recoverBy = player,
        skillName = self.name
      }
    end
  end,
}

--------------------------------------------------
--惑炎
--技能马克：需要等火攻再落实，先视为火杀
--TODO:技能翻译失效，技能视为火杀效果有但火杀没打到了虚空。
--------------------------------------------------

local v_huoyan = fk.CreateTriggerSkill{
  name = "v_huoyan",
  --赋予输出型技能定义
  anim_type = "offensive",
  --时机：阶段变化时
  events = {fk.EventPhaseChanging},
  --触发条件：触发时机的角色为遍历到的角色、遍历到的角色具有本技能，下一阶段为出牌阶段，出牌阶段未被跳过。
  can_trigger = function(self, event, target, player, data)
    local change = data
    --阶段变化时，实现“是否跳出牌”的效果。
    --exist_or_not：用来确认是否跳过对应阶段，类似于以前的Player:isSkipped()
    return target == player and player:hasSkill(self.name) 
    and change.to == Player.Play and exist_or_not(player, Player.Play)
  end,
  -- on_trigger = function(self, event, target, player, data)
  --   --if self:isEffectable(player) then
  --   self:doCost(event, target, player, data)
  --   --end
  -- end,
  -- on_cost = function(self, event, target, player, data)
  --   --if self:isEffectable(player) then
  --   return true
  --   --end
  -- end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    --阶段变化时，实现“是否跳出牌”的效果。
    local change = data
    if change.to == Player.Play then

        
      --暂定逻辑：技能改为锁定技，通过askforchooseplayer（可能会因为没有cancelable干扰）选择是否发动技能，如发动，生成火攻，然后让对方寄，顺带跳回合；否则啥都不发生。
      
      --TODO:技能被无效化的效果还没做，以及类似的火攻护身符一类的标记都后续可以再选择角色范围里补上。
      --if not SkillNullify(player, self.name) then
      local prompt = "#v_huoyan"
      local alives = room:getAlivePlayers()
      local targets = {}
      for _,p in ipairs(alives) do
        table.insert(targets, p.id)
      end


      local to = room:askForChoosePlayers(player, targets, 1, 1, prompt, self.name)

      if #to > 0 then

        local fire__slash = Fk:cloneCard("fire__slash")
        local new_use = {} ---@type CardUseStruct
        new_use.from = player.id
        --技能马克：可能会存在类似于知更酱多目标BUG的问题
        new_use.tos = { to[1] }
        new_use.card = fire__slash
        new_use.skillName = self.name

        --测试skillName是否有效
        --print(new_use.skillName)

        room:useCard(new_use)

        --此处不使用player:skip()而使用return true原因如下：
        --N神原话：触发技被触发的源头为Gamelogic::trigger（这个可以参考文档）
        --根据源码serverplay.lua中play函数的表示（其用于每个阶段的衍生），每个阶段开始时会先检索一次跳过阶段
        --由于其相关概念影响到触发时机，因此影响到了on_use中skip函数的使用
        --新版本说法：时机为change阶段时，跳阶段的检测已经完成，此时把下一个阶段塞进跳阶段列表里无效。
        return true
      end
    end
  end,
}


--------------------------------------------------
--尤特
--角色马克：链心
--------------------------------------------------

--local youte_lianxinmonv = General(extension, "youte_lianxinmonv", "facemoe", 4, 4, General.Female)
--youte_lianxinmonv:addSkill(v_lianxin)
--youte_lianxinmonv:addSkill(v_huoyan)

--------------------------------------------------
--龙息
--------------------------------------------------

local v_longxi = fk.CreateTriggerSkill{
  name = "v_longxi",
  --赋予输出型技能定义,
  anim_type = "offensive",
  --技能为锁定技，满足条件后强制发动
  frequency = Skill.Compulsory,
  events = {fk.TargetSpecified},
  --触发条件：触发时机的角色为遍历到的角色，触发者拥有此技能，触发者本回合已使用过一张牌，触发者处于出牌阶段。
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and player.phase == Player.Play and player:getMark("#v_longxi_mark") == 2
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local targets = data
    local longxi_tar = AimGroup:getAllTargets(targets.tos)
    --选择这张牌指定的所有目标，执行拆一张牌的指令
    for _, p in ipairs(longxi_tar) do
      --print(p)
      local pls = room:getPlayerById(p)
      --如果被选定的目标两个区域都没牌则不执行下一步。
      if (not pls:isNude()) then
        --由遍历到的角色对目标选择手牌区/装备区的一张牌
        local cid = room:askForCardChosen(
          player,
          pls,
          "he",
          self.name
        )
        --将这张牌丢弃牌区
        room:throwCard(cid, self.name, pls, player)
      end
    end
  end,
  --目前萌以前写的标记一键删除姬还没做出来，因此还是用比较原始的refresh处理。
  refresh_events = {fk.TargetSpecified, fk.EventPhaseStart},
  can_refresh = function(self, event, target, player, data)
    if not (target == player and player:hasSkill(self.name)) then
      return false
    end
    if event == fk.TargetSpecified then
      return player.phase == Player.Play
    elseif event == fk.EventPhaseStart then
      return player.phase == Player.NotActive
    end
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    if event == fk.TargetSpecified then
      room:addPlayerMark(player,"#v_longxi_mark",1)
    elseif event == fk.EventPhaseStart then
      room:setPlayerMark(player, "#v_longxi_mark", 0)
    end
  end
}

table.insert(turn_end_clear_mark, "#v_longxi_mark")

--------------------------------------------------
--卡诺娅
--角色马克：
--------------------------------------------------

local kanuoya_akanluerbanlong = General(extension, "kanuoya_akanluerbanlong", "xuyanshe", 4, 4, General.Female)
kanuoya_akanluerbanlong:addSkill(v_longxi)

--------------------------------------------------
--狐尾扇
--技能马克：后续可以给展示用的牌做cardflag
--------------------------------------------------

local v_huweishan = fk.CreateTriggerSkill{
  name = "v_huweishan",
  --赋予输出型技能定义
  anim_type = "offensive",
  --时机：手牌结算后
  events = {fk.CardUseFinished},
  --（阶段变化时）触发时机的角色为遍历到的角色；遍历到的角色具有本技能；存在实体卡（后续需要测试，如不成功可以通过ID>0处理）。
  --             使用的牌为杀；本回合只使用过一次技能。
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and data.card
    and data.card.trueName == "slash" and player:usedSkillTimes(self.name, Player.HistoryTurn) == 0
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local card_id = room:drawCards(player, 1, self.name, top)[1]
    local card = Fk:getCardById(card_id)
    room:obtainCard(player, card_id, true, fk.ReasonDraw)
    room:delay(250)
    if room:getCardOwner(card_id) == player then
      player:showCards(card)
      if card.type == Card.TypeBasic then
        local prompt = "v_huweishan_throw_choice"
        if yes_or_no(player, self.name, prompt) then
          room:setEmotion(player, "./packages/vupslash/image/anim/xingmengzhenxue")
          room:throwCard(card_id, self.name, player, player)
          player:addCardUseHistory(data.card.trueName, -1)
          room:sendLog{
            type = "#v_huweishan_success",
            from = player.id,
            arg = self.name,
            card = { card_id },
          }
        end
      end
    end
  end,
}

--------------------------------------------------
--星梦真雪
--角色马克：性别中性未实装
--------------------------------------------------

local xingmengzhenxue_rongyixiaohu = General(extension,"xingmengzhenxue_rongyixiaohu", "individual", 4, 4, General.Female)
xingmengzhenxue_rongyixiaohu:addSkill(v_huweishan)

--------------------------------------------------
--抹挑
--技能马克：
--（后续跟全局合并）检测出牌阶段造成伤害的数量
-- “本回合可以造成的伤害最高为1”后续可以补动画。
--注释：本技能将导致造成一点伤害后，伤害传导也无效。
--------------------------------------------------

local v_motiao_damage_checker = fk.CreateTriggerSkill{
  name = "#v_motiao_damage_checker",
  refresh_events = {fk.Damage, fk.EventPhaseChanging},
  can_refresh = function(self, event, target, player, data)
    if event == fk.Damage then
      return target == player and player:hasSkill(self.name)
    elseif event == fk.EventPhaseChanging then
      return target == player and player:hasSkill(self.name) and data.from ~= Player.NotActive and data.to == Player.NotActive
    end
  end,
  on_refresh = function(self, event, target, player, data)
    if event == fk.Damage then
      local room = player.room
      local damage = data
      --print(damage.damage)
      room:addPlayerMark(player, "#play_damage", damage.damage)
    elseif event == fk.EventPhaseChanging then
      local room = player.room
      room:setPlayerMark(player, "#play_damage", 0)
    end
  end,
}
local v_motiao = fk.CreateTriggerSkill{
  name = "v_motiao",
  --赋予摸牌型技能定义
  anim_type = "drawcard",
  --时机：阶段开始时，目标指定后, 造成伤害后
  events = {fk.EventPhaseStart, fk.TargetSpecified},
  --触发条件：
  --（阶段开始时）触发时机的角色为遍历到的角色；遍历到的角色具有本技能；
  --              被遍历到的角色处于回合开始阶段。
  --（目标指定时）触发时机的角色为遍历到的角色；遍历到的角色具有本技能；
  --             存在回合开始阶段时使用此技能的标签；
  --             被指定的角色中存在遍历到的角色。
  --             本次流程中第一次触发这个时机
  can_trigger = function(self, event, target, player, data)
    if event == fk.EventPhaseStart then
      return target == player and player:hasSkill(self.name)
      and player.phase == Player.Start
    elseif event == fk.TargetSpecified then
      local room = player.room
      --遍历所有被指定到的角色，确认是否存在遍历到的角色
      local motiao_useornot = false
      local targets = data
      local motiao_tar = AimGroup:getAllTargets(targets.tos)
      for _, p in ipairs(motiao_tar) do
        print(p)
        local pls = room:getPlayerById(p)
        if pls == player then
          motiao_useornot = true
        end
      end
      return target == player and player:hasSkill(self.name)
      and player:getMark("v_motiao_using") > 0
      and motiao_useornot
      and targets.firstTarget
    end
  end,
  on_cost = function(self, event, target, player, data)
    --确认是否发动技能。
    if event == fk.EventPhaseStart then
      local prompt = "v_motiao_choice"
      if yes_or_no(player, self.name, prompt) then
        return true
      end
    --满足技能发动要求后，锁定发动。
    elseif event == fk.TargetSpecified and player:getMark("v_motiao_using") > 0 then
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    --以on_cost中做出选择为代价，本回合内你只能造成1点伤害，你使用牌指定自己为目标之一后，摸一张牌。
    if event == fk.EventPhaseStart then
      room:setPlayerMark(player, "v_motiao_using", 1)
    --摸一张牌
    elseif event == fk.TargetSpecified then
      player:drawCards(1, self.name)
    end
  end,

  --手牌结算后清除“本次指定中已经摸过牌”标签；以及伤害在这里刷新。
  --目前萌以前写的标记一键删除姬还没做出来，因此还是用比较原始的refresh处理。
  refresh_events = {fk.EventPhaseStart, fk.DamageCaused},
  -- 刷新时机：（阶段开始时不赘述）
  --（造成伤害后）触发时机的角色为遍历到的角色；遍历到的角色具有本技能；
  --             存在回合开始阶段时使用此技能的标签；
  --             造成的伤害大于0；
  --             非光属性伤害（暂未实装）。
  can_refresh = function(self, event, target, player, data)
    if not (target == player and player:hasSkill(self.name)) then
      return false
    end
    if event == fk.EventPhaseStart then
      return player.phase == Player.NotActive
    elseif event == fk.DamageCaused then
      return player:getMark("v_motiao_using") > 0
      and data.damage > 0
    end
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    if event == fk.EventPhaseStart then
      room:setPlayerMark(player, "v_motiao_using", 0)
      --将本回合造成的伤害锁定为1（未测试，今晚摸了）
    elseif event == fk.DamageCaused then
      local x = math.min(data.damage, 1 - player:getMark("#play_damage"))
      if x < data.damage then
        if x > 0 then
          data.damage = 1
          --return false
        else
          --动画可以放这里放。
          room:sendLog{
            type = "#defense_damage",
            from = player.id,
            --log.to是数组
            to = {data.to.id},
            arg = self.name,
            arg2 = data.damage,
          }
          data.damage = 0
        end
      end
    end
  end
}
v_motiao:addRelatedSkill(v_motiao_damage_checker)

table.insert(turn_end_clear_mark, "v_motiao_using")

--------------------------------------------------
--连奏
--技能马克：打出的牌可能会无法返回number；丈八在下版本前可能还是算点数的。
--------------------------------------------------

local v_lianzou = fk.CreateTriggerSkill{
  name = "v_lianzou",
  --赋予摸牌型技能定义
  anim_type = "drawcard",
   --技能为限定技
  frequency = Skill.Limited,
  --时机：阶段结束时
  events = {fk.EventPhaseEnd},
  --触发条件：
  --（阶段结束时）触发时机的角色为遍历到的角色；遍历到的角色具有本技能；
  --              被遍历到的角色处于出牌阶段。
  --              被遍历到的角色本场游戏使用此技能的次数为0
  --              被遍历到的角色本轮使用/打出牌的点数之和>=50（打出是否算入在内待定）

  can_trigger = function(self, event, target, player, data)
    --if event == fk.EventPhaseEnd then
    return target == player and player:hasSkill(self.name)
    and player.phase == Player.Play
    and player:usedSkillTimes(self.name, Player.HistoryGame) == 0
    and player:getMark("@v_lianzou_count") >= 50
    --end
  end,
  on_cost = function(self, event, target, player, data)
    --确认是否发动技能。
    --if event == fk.EventPhaseEnd then
    local room = player.room
    if room:askForSkillInvoke(player,self.name,data) then
      return true
    end
    --end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    --判定直到点数大于等于50
    if event == fk.EventPhaseEnd then
      --这里可以后续放限定动画并给大概2500ms的延时+音效。
      local count = 0
      local dummy = Fk:cloneCard("slash")
      while count < 50 do
        local judge = {
          who = player,
          reason = self.name,
          pattern = ".|1~"..(50-count).."|.",
        }
        room:judge(judge)
        local result = judge.card
        count = count + result.number
        if count < 50 then
          dummy:addSubcard(result)
        end
      end
      room:obtainCard(player.id, dummy, true)
    end
  end,

  --目前萌以前写的标记一键删除姬还没做出来，因此还是用比较原始的refresh处理。

  --刷新时机：阶段开始时，手牌结算后，手牌打出结算后（这个说实话，待定）
  refresh_events = {fk.EventPhaseStart, fk.CardUseFinished, fk.CardRespondFinished},
  --刷新条件（不包括阶段开始时）
  --（手牌结算后，手牌打出结算后（这个待定））
  --             触发时机的角色为遍历到的角色；遍历到的角色具有本技能；
  --              被遍历到的角色处于出牌阶段。
  can_refresh = function(self, event, target, player, data)
    if not (target == player and player:hasSkill(self.name)) then
      return false
    end
    if event == fk.EventPhaseStart then
      return player.phase == Player.NotActive
    elseif event == fk.CardUseFinished or event == fk.CardRespondFinished then
      return target == player and player:hasSkill(self.name)
      and player.phase == Player.Play
    end
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    if event == fk.EventPhaseStart then
      room:setPlayerMark(player, "@v_lianzou_count", 0)
    --在满足以下条件的前提下，将牌的点数加入某个mark里。
    -- 卡牌存在，为实体牌, 卡牌点数小于等于13大于0。
    elseif event == fk.CardUseFinished or event == fk.CardRespondFinished then
      local card = data
      if card.card and card.card.id > 0 and card.card.number <= 13 and card.card.number > 0 then
        room:addPlayerMark(player, "@v_lianzou_count", card.card.number)
      end
    end
  end
}

table.insert(turn_end_clear_mark, "@v_lianzou_count")

--------------------------------------------------
--弦羽
--角色马克：抹挑
--------------------------------------------------

local xianyu_xiangluancuxian = General(extension,"xianyu_xiangluancuxian", "chaociyuan", 3, 3, General.Female)
xianyu_xiangluancuxian:addSkill(v_motiao)
xianyu_xiangluancuxian:addSkill(v_lianzou)

--------------------------------------------------
--幽蓝
--技能马克：缺少七海表情包
--------------------------------------------------
local v_youlan = fk.CreateTriggerSkill{
  --（刚需）技能认证名
  name = "v_youlan",
  --(非必要）赋予特殊型技能定义
  anim_type = "special",
  --技能为锁定技，满足条件后强制发动
  frequency = Skill.Compulsory,
  --时机：受到伤害时，造成伤害时
  events = {fk.DamageInflicted,fk.DamageCaused},
  --触发条件：
  --（受到伤害时）触发时机的角色为遍历到的角色、遍历到的角色具有本技能、牌为实体牌、牌的种类为锦囊牌、造成的伤害大于0。
  --（造成伤害时）造成伤害的来源为遍历到的角色、遍历到的角色具有本技能、牌为实体牌、牌的种类为锦囊牌、造成的伤害大于0。
  can_trigger = function(self, event, target, player, data)
    local damage = data
    if event == fk.DamageInflicted then
      return target == player and player:hasSkill(self.name) and
        (data.card and data.card.type == Card.TypeTrick) and damage.damage > 0
    elseif event == fk.DamageCaused then
      return target == player and player:hasSkill(self.name) and
        (data.card and data.card.type == Card.TypeTrick)  and damage.damage > 0
    end
  end,
  on_use = function(self, event, target, player, data)
    local damage = data
    local room = player.room
    if event == fk.DamageInflicted then
      damage.damage = damage.damage - 1
      if damage.damage <= 0 then
        room:setEmotion(player, "./packages/vupslash/image/anim/skill_nullify")
      end
    elseif event == fk.DamageCaused then
      damage.damage = damage.damage + 1
    end
  end,
}

--------------------------------------------------
--七海幽娴
--角色马克：幽蓝，性别无性未实装，特性·箭雨未实装
--------------------------------------------------

local qihaiyouxian_zhuangzhilingyun = General(extension, "qihaiyouxian_zhuangzhilingyun", "individual", 4, 3, General.Female)
qihaiyouxian_zhuangzhilingyun:addSkill(v_youlan)

--------------------------------------------------
--蓁惹
--技能马克：作为目标疑似会导致雌雄双股剑无效。
--------------------------------------------------

local v_zhenre = fk.CreateTriggerSkill{
  name = "v_zhenre",
  --赋予防御型技能定义
  anim_type = "defensive",
  --技能为锁定技，满足条件后强制发动
  frequency = Skill.Compulsory,
  --时机：目标确定后
  events = {fk.TargetConfirmed},
  --触发条件：目标为玩家、玩家具有本技能、牌的种类为杀、牌的花色为红桃或黑桃。
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and
      (data.card.trueName == "slash" and (data.card.suit == Card.Heart or data.card.suit == Card.Spade))
  end,
  on_use = function(self, event, target, player, data)
    table.insert(data.nullifiedTargets, player.id)
  end,
}

--------------------------------------------------
--芳仙
--技能马克：优化芳仙本体技能发动时的描述（可以考虑第一阶段的choice也做成锁定技，然后用askchooseplayer一类的方法插入tips）。
--------------------------------------------------

local v_fangxian_choice = fk.CreateTriggerSkill{
  name = "#v_fangxian_choice",
  --赋予支援型技能定义
  anim_type = "support",
  --时机：阶段变化时
  events = {fk.EventPhaseChanging},
  --触发条件：触发时机的角色为遍历到的角色、遍历到的角色具有本技能，下一阶段为摸牌阶段，摸牌阶段未被跳过。
  can_trigger = function(self, event, target, player, data)
    local change = data
    --阶段变化时，实现“是否跳摸牌”的效果。 
    --exist_or_not：用来确认是否跳过对应阶段，类似于以前的Player:isSkipped()
    return target == player and player:hasSkill(self.name) 
    and change.to == Player.Draw and exist_or_not(player, Player.Draw)
  end,
  -- on_trigger = function(self, event, target, player, data)
  --   --if self:isEffectable(player) then
  --   self:doCost(event, target, player, data)
  --   --end
  -- end,
  -- on_cost = function(self, event, target, player, data)
  --   --if self:isEffectable(player) then
  --   return true
  --   --end
  -- end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    --阶段变化时，实现“是否跳摸牌”的效果。
    local change = data
    if change.to == Player.Draw then
        --技能被无效化的效果试作
        if self:isEffectable(player) then
          room:setPlayerMark(player, "@@v_fangxian", 1)
        end
        --此处不使用player:skip()而使用return true原因如下：
        --N神原话：触发技被触发的源头为Gamelogic::trigger（这个可以参考文档）
        --根据源码serverplay.lua中play函数的表示（其用于每个阶段的衍生），每个阶段开始时会先检索一次跳过阶段
        --由于其相关概念影响到触发时机，因此影响到了on_use中skip函数的使用
        --新版本说法：时机为change阶段时，跳阶段的检测已经完成，此时把下一个阶段塞进跳阶段列表里无效。
        return true
        --end
      --end
    end
  end,
}
local v_fangxian = fk.CreateTriggerSkill{
  name = "v_fangxian",
  --赋予支援型技能定义
  anim_type = "support",
  --时机：阶段开始时
  events = {fk.EventPhaseStart},
  --触发条件：遍历到的角色处于结束阶段，通过芳仙跳过摸牌阶段。
  can_trigger = function(self, event, target, player, data)
    local room = player.room
    if player.phase == Player.Finish and player:getMark("@@v_fangxian") > 0 then
      --在场且存活
      --for _, p in ipairs(room:getAlivePlayers()) do
      return true
      --end
    end
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    --阶段变化时，实现“是否跳摸牌”的效果。
    if player.phase == Player.Finish and player:getMark("@@v_fangxian") > 0 then
      --制作一个囊括所有存活角色的table-targets
      local alives = room:getAlivePlayers()
      local prompt = "#v_fangxian-target"
      local targets = {}
      for _, p in ipairs(alives) do
        table.insert(targets, p.id)
      end
      --to：从targets中选择1个目标，是个值为number的table。
      local to = room:askForChoosePlayers(player, targets, 1, 1, prompt, self.name)
      --这里后续可以增加“技能发动者是否可以对对应角色使用技能”的判定，类似于caneffect函数。
      if #to > 0 then
        --通过ID找到对应的ServerPlayer
        local player_to = room:getPlayerById(to[1])
				--指向类特效用函数doIndicate，但执行后由于不明原因在367行报了function的错，不理解。
        --room:doAnimate(1, player:objectName(), to:objectName())	--doAnimate 1:产生一条从前者到后者的指示线
        if player_to ~= player then
          --doindicate的两个参数均为integer类型，一般为角色id
          room:doIndicate(player.id,to)
        end
        room:recover{
          who = player_to,
          num = 1,
          recoverBy = player,
          skillName = self.name
        }
			else
				player:drawCards(2, self.name)
			end
		end
  end,

  --目前萌以前写的标记一键删除姬还没做出来，因此还是用比较原始的refresh处理。
  refresh_events = {fk.EventPhaseStart},
  can_refresh = function(self, event, target, player, data)
    if not (target == player and player:hasSkill(self.name)) then
      return false
    end
    if event == fk.EventPhaseStart then
      return player.phase == Player.NotActive
    end
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, "@@v_fangxian", 0)
  end
}

table.insert(turn_end_clear_mark, "@@v_fangxian")

v_fangxian:addRelatedSkill(v_fangxian_choice)

--------------------------------------------------
--桃水纪
--角色马克：蓁惹，芳仙
--------------------------------------------------

local taoshuiji_fenhuafutao = General(extension, "taoshuiji_fenhuafutao", "individual", 4, 4, General.Female)
taoshuiji_fenhuafutao:addSkill(v_zhenre)
taoshuiji_fenhuafutao:addSkill(v_fangxian)

--------------------------------------------------
--视幻
--技能马克：等待轮次时点；需要重写on_cost；视幻发动时的提示暂时无法插入。
--------------------------------------------------

--TODO:修改角色手牌上限
--local v_shihuan_buff = fk.CreateMaxCardsSkill{
--  name = "#v_shihuan_buff"
  
--}
local v_shihuan = fk.CreateTriggerSkill{
  name = "v_shihuan",
  --赋予控场型技能定义
  anim_type = "control",
  --时机：阶段开始时
  events = {fk.EventPhaseStart},
  --触发条件：遍历到的角色处于准备阶段；遍历全场所有角色，存在角色持有该技能。
  can_trigger = function(self, event, target, player, data)
    --遍历全场所有角色，检查是否有存在此技能的角色（从阮卿言的经验来看要出多个角色发动技能的事儿）
    local room = player.room
    local alives = room:getAlivePlayers()
    local targets = {}
    for _,p in ipairs(alives) do
      if p:hasSkill(self.name) then
        table.insert(targets, p.id)
      end
    end
    return #targets > 0 and player.phase == Player.Start
  end,
  -- on_trigger = function(self, event, target, player, data)
  --   --if self:isEffectable(player) then
  --   self:doCost(event, target, player, data)
  --   --end
  -- end,
  -- on_cost = function(self, event, target, player, data)
  --   --if self:isEffectable(player) then
  --   return true
  --   --end
  -- end,
  on_use = function(self, event, target, player, data)
    --遍历全场所有角色，对持有此技能的角色检查是否本轮次使用过技能，若无，则询问其是否发动技能。
    local room = player.room
    local alives = room:getAlivePlayers()
    local targets = {}
    for _,p in ipairs(alives) do
      if p:hasSkill(self.name) then
        table.insert(targets, p.id)
      end
    end
    for _,myself in targets do
      local player_to = room:getPlayerById(myself[1])
      if player_to:usedSkillTime(self.name, Player.HistoryRound) < 1 then
        --先用askforskillinvoke试试，如果存在多次发动嵌套则可能使用askforchooseplayer（此状态下无法放提示）
        if room:askForSkillInvoke(player_to,self.name,data) then
          if player_to ~= player then
            --doindicate的两个参数均为integer类型，一般为角色id
            room:doIndicate(player_to.id,myself)
          end
          -- TODO:后续这里做log在提示信息中说明角色手牌上限调整。
          -- room:sendLog{
          --   type = "#v_shihuan_log",
          --   from = player.id,
          --   arg = self.name,
          --   arg2 = math.max(1, player:getHandcardNum(),
          -- }
          -- body
          room:setPlayerMark(player,"@v_shihuan!",math.max(1, player:getHandcardNum()))
        end
      end
    end
  end,
  --TODO:轮次结束清理标记，由于轮次开始/结束时时机预计将于0.0.6版本实装，因此暂不更新。
}

table.insert(turn_end_clear_mark, "@v_shihuan!")

--v_shihuan:addRelatedSkill(v_shihuan_buff)

--------------------------------------------------
--可餐
--技能马克：锦囊牌显示好结果暂时无法出现，有概率要把所有牌的名字写上去。
--------------------------------------------------

local v_kecan = fk.CreateTriggerSkill{
  name = "v_kecan",
  --赋予负面场型技能定义
  anim_type = "negative",
  --时机：受到伤害后
  events = {fk.Damaged},
  --触发条件：触发时机的角色为遍历到的角色、遍历到的角色具有本技能，伤害大于0，存在伤害来源，伤害来源存活。
  can_trigger = function(self, event, target, player, data)
    local damage = data
    return target == player and player:hasSkill(self.name) 
    and damage.damage > 0 and damage.from and damage.from:isAlive()
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    --执行判定，判定如为锦囊牌，则触发效果。
    local room = player.room
    local damage = data
    local judge = {
      who = damage.from,
      reason = self.name,
      --TODO:把所有锦囊牌的名字写上去？
      pattern = "TypeTrick|.|.",
    }
    room:judge(judge)
    if judge.card.type == Card.TypeTrick then
      room:recover{
        who = damage.from,
        num = 1,
        recoverBy = player,
        skillName = self.name,
      }
      room:changeMaxHp(player, -1)
    end
  end,
  --TODO:回合结束清理标记，但没有看到标记，原因不明。
}

--------------------------------------------------
--萨比萌
--角色马克：视幻
--------------------------------------------------

--local sabimeng_bimengjushou = General(extension,"sabimeng_bimengjushou", "individual", 6, 6, General.Female)
--sabimeng_bimengjushou:addSkill(v_shihuan)
--sabimeng_bimengjushou:addSkill(v_kecan)

--------------------------------------------------
--蟹袭
--技能马克：指向线出现自己指向自己这种怎么处理还没规避好。
--------------------------------------------------

local v_xiexi = fk.CreateTriggerSkill{
  name = "v_xiexi",
  --赋予特殊型技能定义
  anim_type = "special",
  --时机：手牌结算后
  events = {fk.CardUseFinished},
  --触发条件：结算的牌为红桃牌；遍历的角色存在此技能；当前回合角色及遍历的角色存活；遍历全场所有角色，存在角色持有该技能（据说这条不必要）。
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(self.name) and target:isAlive() and data.card.suit == Card.Heart
  end,
  -- on_trigger = function(self, event, target, player, data)
  --   --if self:isEffectable(player) then
  --   self:doCost(event, target, player, data)
  --   --end
  -- end,
  on_cost = function(self, event, target, player, data)
    if not target.chained then
      local prompt = "v_xiexi_chain:"..target.id
      if yes_or_no(player, self.name, prompt) then
        return true
      end
    elseif target.chained then
      local prompt = "v_xiexi_damage:"..target.id
      if yes_or_no(player, self.name, prompt) then
        return true
      end
    end
  end,
  on_use = function(self, event, target, player, data)
    --遍历全场所有角色，对持有此技能的角色询问其是否发动技能。
    local room = player.room
    --if target ~= player then
      --doindicate的两个参数均为integer类型，一般为角色id
      --这个容易出问题之后先试试把它干了
      --room:doIndicate(player.id,target.id)
    --end
    if not target.chained then
      target:setChainState(true)
    elseif target.chained then
      room:damage{
        from = player,
        to = target,
        damage = 1,
        damageType = fk.FireDamage,
        skillName = self.name,
      }
    end
  end,
}

--------------------------------------------------
--归影
--技能马克：描述为对应角色摸了X张牌，最好是获得两张牌。
--------------------------------------------------

local v_guiying = fk.CreateTriggerSkill{
  name = "v_guiying",
  --赋予控场型技能定义
  anim_type = "control",
  --时机：角色离场时
  events = {fk.Death},
  --触发条件：触发时机的角色存在、触发时机的角色为遍历到的角色、触发时机的角色具有本技能。
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name,false,true)
  end,
  -- on_trigger = function(self, event, target, player, data)
  --   --if self:isEffectable(player) then
  --   self:doCost(event, target, player, data)
  --   --end
  -- end,
  on_cost = function(self, event, target, player, data)
    --if self:isEffectable(player) then
    --制作一个囊括所有存活角色的table-targets，可以增加“技能发动者是否可以对对应角色使用技能”的判定，类似于caneffect函数。
    local room = player.room
    local alives = room:getAlivePlayers()
    local prompt = "#v_guiying_invoke"
    local targets = {}
    for _, p in ipairs(alives) do
      table.insert(targets, p.id)
    end
    --to：从targets中选择1个目标，是个值为number的table。
    local to = room:askForChoosePlayers(player, targets, 1, 1, prompt, self.name)
    if #to > 0 then
      self.cost_data = to[1]
      return true
    end
    --end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    --通过ID找到对应的ServerPlayer
    local player_to = room:getPlayerById(self.cost_data)
    player_to:turnOver()
    local dummy = Fk:cloneCard("slash")
    dummy:addSubcards(player:getCardIds(Player.Hand))
    dummy:addSubcards(player:getCardIds(Player.Equip))
    dummy:addSubcards(player:getCardIds(Player.Judge))
    room:obtainCard(player_to.id, dummy, false,fk.ReasonPrey)
  end,
}

--------------------------------------------------
--阮卿言
--角色马克：蟹袭，归影
--------------------------------------------------

local ruanqingyan_hushanguiying = General(extension,"ruanqingyan_hushanguiying", "individual", 3, 3, General.Female)
ruanqingyan_hushanguiying:addSkill(v_xiexi)
ruanqingyan_hushanguiying:addSkill(v_guiying)

--------------------------------------------------
--奇虑
--------------------------------------------------

local v_qilvbuff = fk.CreateTargetModSkill{
  name = "#v_qilvbuff",
  residue_func = function(self, player, skill, scope)
    if player:hasSkill(self.name) and skill.trueName == "slash_skill" 
      and scope == Player.HistoryPhase then
      return -1
    end
  end,
}
local v_qilv = fk.CreateTriggerSkill{
  name = "v_qilv",
  --赋予输出型技能定义
  anim_type = "offensive",
  --时机：阶段变化时
  events = {fk.CardUseFinished},
  --触发条件：触发时机的角色为遍历到的角色、遍历到的角色具有本技能，使用的牌为锦囊牌。
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) 
    and data.card.type == Card.TypeTrick
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    -- local targets = table.filter(room:getOtherPlayers(player), function(p)
    --   return p
    -- end)
    local targets = {}
    local other = room:getOtherPlayers(player)
    for _, p in ipairs(other) do
      -- TODO: 判断这个目标可不可以被玩家使用【杀】,且距离是否满足（这条已满足，后续可能被前一条覆盖）
      if player:inMyAttackRange(p) then
        table.insert(targets, p.id)
      end
    end
    local p = room:askForChoosePlayers(player, targets, 1, 1, "#v_qilv_askforslash", self.name)
    if #p > 0 then
      self.cost_data = p[1]
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local tar = room:getPlayerById(self.cost_data)
    --阶段变化时，实现“是否跳出牌”的效果。
    local slash = Fk:cloneCard("slash")
    local new_use = {} ---@type CardUseStruct
    new_use.from = player.id
    --技能马克：可能会存在类似于知更酱多目标BUG的问题
    new_use.tos = { { tar.id } }
    new_use.card = slash
    new_use.skillName = self.name
    --测试skillName是否有效
    --print(new_use.skillName)
    room:useCard(new_use)
  end,
}
v_qilv:addRelatedSkill(v_qilvbuff)

--------------------------------------------------
--无前Namae
--------------------------------------------------

local wuqian_daweiba = General(extension,"wuqian_daweiba", "individual", 4, 4, General.Male)
wuqian_daweiba:addSkill(v_qilv)

--------------------------------------------------
--自愈
--------------------------------------------------

local v_ziyu = fk.CreateTriggerSkill{
  name = "v_ziyu",
  --赋予支援型技能定义
  anim_type = "support",
  --时机：阶段开始时，受到伤害后
  events = {fk.EventPhaseStart, fk.Damaged},
  --触发条件：
  --（阶段开始时）触发时机的角色为遍历到的角色、遍历到的角色具有本技能、本阶段为结束阶段、遍历角色体力值不为全场唯一最高。
  --（受到伤害后）触发时机的角色为遍历到的角色、遍历到的角色具有本技能、受到伤害的角色为遍历到的角色、遍历角色体力值不为全场唯一最高。
  can_trigger = function(self, event, target, player, data)
    local room = player.room
    local damage = data
    --获取当前游戏除遍历到的角色外其他角色体力最大值。
    local other = room:getOtherPlayers(player)
    local other_max_hp = -999
    for _, p in ipairs(other) do
      if p.hp > other_max_hp then
        other_max_hp = p.hp
      end
    end
    if event == fk.EventPhaseStart then
      return target == player and player:hasSkill(self.name) 
      and player.phase == Player.Finish and player.hp <= other_max_hp
    elseif event == fk.Damaged then
      return target == player and player:hasSkill(self.name) and  damage.to == player and player.hp <= other_max_hp
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local judge = {} ---@type JudgeStruct
    judge.who = player
    --这一条的意思是，出现黑桃花色条件后显示判定成功的特效
    judge.pattern = ".|.|spade"
    judge.reason = self.name
    room:judge(judge)
    if judge.card.suit == Card.Spade then
      --考虑到本作存在治疗过量概念，不需要角色受伤也可触发回复效果。
      --if player:isWounded() then 
      room:recover{
        who = player,
        num = 1,
        recoverBy = player,
        skillName = self.name,
      }
    end
  end,
}

--------------------------------------------------
--嗜血
--------------------------------------------------

local v_shixue = fk.CreateTriggerSkill{
  --（刚需）技能认证名
  name = "v_shixue",
  --(非必要）赋予支援型技能定义
  anim_type = "support",
  --时机：造成伤害后
  events = {fk.Damage},
  --触发条件：
  --存在触发时机的角色、触发时机的角色为遍历到的角色、遍历到的角色具有本技能、造成伤害的角色为遍历到的角色、造成伤害的卡牌颜色为黑色。
  can_trigger = function(self, event, target, player, data)
    local damage = data
    return target and target == player and player:hasSkill(self.name) and
        damage.from == player and damage.card.color == Card.Black
  end,
  -- on_trigger = function(self, event, target, player, data)
  --   --if self:isEffectable(player) then
  --   self:doCost(event, target, player, data)
  --   --end
  -- end,
  on_cost = function(self, event, target, player, data)
    --if self:isEffectable(player) then
    local room = player.room
    for i = 1, data.damage do
      local choiceList = {}
      table.insert(choiceList, "recover_1")
      table.insert(choiceList, "draw_1")
      table.insert(choiceList, "cancel")
      local choice = room:askForChoice(player, choiceList, self.name)
      if choice == "cancel" then
        break
      elseif choice == "recover_1" then
        self.cost_data = 1
      elseif choice == "draw_1" then
        self.cost_data = 2
      end
      return true
    end
    --end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    if self.cost_data == 1 then
      room:recover{
        who = player,
        num = 1,
        recoverBy = player,
        skillName = self.name,
      }
    elseif self.cost_data == 2 then
      player:drawCards(1, self.name)
    end
  end,
}

--------------------------------------------------
--月下暗影
--角色马克：性别中性未实装
--------------------------------------------------

local yuexiaanying_juexingxuezu = General(extension,"yuexiaanying_juexingxuezu", "individual", 3, 5, General.Female)
yuexiaanying_juexingxuezu:addSkill(v_ziyu)
yuexiaanying_juexingxuezu:addSkill(v_shixue)

--------------------------------------------------
--忆狩
--技能马克：死了之后疑似还能发动忆狩。
--------------------------------------------------

local v_yishou_slash = fk.CreateTargetModSkill{
  name = "#v_yishou_slash",
  residue_func = function(self, player, skill, scope)
    if player:hasSkill(self.name) and skill.trueName == "slash_skill"
      and scope == Player.HistoryPhase and player:getMark("v_yishou_active") > 0 then
      return player:getMark("v_yishou_active")
    end
  end,
}
local v_yishou_mark = fk.CreateTriggerSkill{
  name = "#v_yishou_mark",
  --赋予卖血型技能定义
  anim_type = "masochism",
  --时机：阶段开始时，受到伤害后，摸牌时
  events = {fk.EventPhaseStart, fk.Damaged},
  --触发条件：
  --（阶段开始时）触发时机的角色为遍历到的角色、遍历到的角色具有本技能、本阶段为结束阶段、遍历到的角色存在且存活且体力>=1。
  --（受到伤害后）触发时机的角色为遍历到的角色、遍历到的角色具有本技能、受到伤害的角色为遍历到的角色、遍历到的角色存在且存活。
  can_trigger = function(self, event, target, player, data)
    local room = player.room
    local damage = data
    if event == fk.EventPhaseStart then
      return target == player and player:hasSkill(self.name) 
      and player.phase == Player.Finish and player.hp >= 1
    elseif event == fk.Damaged then
      return target == player and player:hasSkill(self.name) and damage.to == player
      and damage.damage >= 1
    end
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    --如果扳机为受到伤害后，根据体力值触发技能；否则正常触发。
    if event == fk.Damaged then
      for i = 1, data.damage do
        local room = player.room
        if (not player:isNude()) then
          local ret = room:askForDiscard(player, 1, 1, true, self.name, true)
          --需要的话在这里增加技能检测失效
          if #ret > 0 then
          --if room:askForDiscard(player, 1, 1, true, self.name, true) then
            return true
          end
        end
      end
    elseif event == fk.EventPhaseStart then
      --需要的话在这里增加技能检测失效;非锁定技想强制发动这里用个true就好啦
      local prompt = "v_yishou_end"
      if yes_or_no(player, self.name, prompt) then
        --尝试了一下，这里不能跳阶段，失败的话只能耦合到on_use了。
        room:loseHp(player, 1, self.name)
        return true
      end
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    if event == fk.EventPhaseStart then
      room:addPlayerMark(player, "@v_yishou_count", 1)
    elseif event == fk.Damaged then
      room:addPlayerMark(player, "@v_yishou_count", 1)
    end
  end,
}
local v_yishou = fk.CreateTriggerSkill{
  name = "v_yishou",
  --赋予卖血型技能定义
  anim_type = "masochism",
  --时机：摸牌时
  events = {fk.DrawNCards},
  --触发条件：
  --（摸牌）触发时机的角色为遍历到的角色、遍历到的角色具有本技能、某个标记大于等于1、存在摸牌阶段。
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and player:getMark("v_yishou_active") > 0
  end,
  on_cost = function(self, event, target, player, data)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local y = 2*player:getMark("v_yishou_active")
    data.n = data.n + y
  end,
  refresh_events = {fk.EventPhaseChanging},
  can_refresh = function(self, event, target, player, data)
    return ((data.from == Player.NotActive and data.to ~= Player.NotActive and target == player) 
    or (data.from ~= Player.NotActive and data.to == Player.NotActive))
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    local x = player:getMark("@v_yishou_count")
    if (data.from == Player.NotActive and data.to ~= Player.NotActive) then
      if x > 0 then
        room:sendLog{
          type = "#v_yishou_log",
          from = player.id,
          arg = 2*x,
          arg2 = x,
        }
        room:setPlayerMark(player, "v_yishou_active", x)
        room:setPlayerMark(player, "@v_yishou_count", 0)
      end
    --等一键删除姬出了之后就删了这玩意。
    elseif (data.from ~= Player.NotActive and data.to == Player.NotActive) then
      room:setPlayerMark(player, "v_yishou_active", 0)
    end
  end,
}

table.insert(turn_end_clear_mark, "v_yishou_active")

v_yishou:addRelatedSkill(v_yishou_mark)
v_yishou:addRelatedSkill(v_yishou_slash)

--------------------------------------------------
--祭血
--技能马克：
--------------------------------------------------

local v_jixue = fk.CreateActiveSkill{
  name = "v_jixue",
  anim_type = "support",
  frequency = Skill.Limited,
  can_use = function(self, player)
    return player:usedSkillTimes(self.name, Player.HistoryGame) == 0
  end,
  --target_num = 0,
  --card_num = 0,
  card_filter = function(self, to_select, selected, selected_targets)
    return false
  end,
  on_use = function(self, room, effect)
    --local players = room.players
    local from = room:getPlayerById(effect.from)
    --从两个区域换红色牌
    --local dummy = Fk:cloneCard("slash")
    local cards = {}
    local cards_throw = {}
    local hand = from:getCardIds(Player.Hand)
    local equip = from:getCardIds(Player.Equip)
    --print(hand)
    --print(equip)
    for _,p in ipairs(hand) do
      table.insert(cards, p)
    end
    for _,p in ipairs(equip) do
      table.insert(cards, p)
    end
    for _,p in ipairs(cards) do
      local card_now = Fk:getCardById(p)
      --这里后续可以追加玩家不可以弃置这张牌的判定，类似于鸡肋
      if card_now.color == Card.Red then
        --dummy:addSubcard(card_now)
        table.insert(cards_throw, p)
      end
    end
    --local x = #(dummy.subcards)
    local x = #(cards_throw)
    --print(x)
    if x > 0 then
      room:throwCard(cards_throw, self.name, from, from)
    end
    for i = 1, x do
      local choiceList = {}
      table.insert(choiceList, "recover_1")
      table.insert(choiceList, "draw_1")
      local choice = room:askForChoice(from, choiceList, self.name)
      if choice == "recover_1" then
        room:recover{
          who = from,
          num = 1,
          recoverBy = from,
          skillName = self.name,
        }
      elseif choice == "draw_1" then
        from:drawCards(1, self.name)
      end
    end
  end,
}

--------------------------------------------------
--辻蓝佳音瑠
--角色马克：动画未实装
--------------------------------------------------

local laila_xuelie = General(extension,"laila_xuelie", "individual", 3, 3, General.Female)
laila_xuelie:addSkill(v_yishou)
laila_xuelie:addSkill(v_jixue)

--------------------------------------------------
--娇惰
--技能马克：
-- Q1: 这个技能是什么意思？可以简单概括一下吗？
-- A1: 一般来说是以下效果：
-- ①你可以跳过判定阶段，摸牌阶段结束后弃置两张牌
-- ②你可以跳过摸牌阶段，出牌阶段结束后将手牌数补充至与跳过摸牌阶段时相同
-- ③你可以跳过出牌阶段，弃牌阶段结束后将手牌数补充至与跳过出牌阶段时相同

-- Q2: 至多摸至X张，这个上限会让我弃牌吗？
-- A2: 不会。如至多摸至5张，将手牌从6张调整至10张，则不会摸牌或弃牌。

-- Q3: 【乐不思蜀】对风野慵生效后，跳过摸牌阶段是什么效果？
-- A3: 跳过摸牌阶段与出牌阶段，弃牌阶段结束后将手牌数调整至与摸牌阶段相同。

-- Q4: 濑川绪良发动“奇遇”令风野慵于回合外执行一个出牌阶段，此时用“娇惰”跳过，会发生什么？
-- A4: 于风野慵的下个回合的准备阶段执行后，将手牌数调整至与跳过这个额外出牌阶段时相同。
--------------------------------------------------

local v_jiaoduo = fk.CreateTriggerSkill{
  name = "v_jiaoduo",
  --赋予特殊型技能定义
  anim_type = "special",
  --时机：阶段变化时，阶段结束时
  events = {fk.EventPhaseChanging, fk.EventPhaseEnd},
  --触发条件：
  --（阶段变化时）触发时机的角色为遍历到的角色；遍历到的角色具有本技能；
  --             本回合只使用过一次技能；
  --             被遍历到的角色处于判定/摸牌/出牌阶段；
  --             被遍历到的角色存在对应阶段。
  --（阶段结束时）触发时机的角色为遍历到的角色；遍历到的角色具有本技能；
  --              在上个阶段使用了此技能（通过标记完成）。
  can_trigger = function(self, event, target, player, data)
    if event == fk.EventPhaseChanging then
      local change = data
      --判定区如无牌，则不做判定区处理。
      local cards = {}
      local hand = player:getCardIds(Player.Judge)
      for _,p in ipairs(hand) do
        table.insert(cards, p)
      end
      local x = #(cards)
      return target == player and player:hasSkill(self.name)
      and player:usedSkillTimes(self.name, Player.HistoryTurn) == 0
      and ((change.to == Player.Judge and x > 0) or change.to == Player.Draw or change.to == Player.Play)
      and exist_or_not(player, change.to)
    elseif event == fk.EventPhaseEnd then
      return target == player and player:hasSkill(self.name)
      and player:getMark("v_jiaoduo_using") > 0
    end
  end,
  on_cost = function(self, event, target, player, data)
    --获取本阶段手牌数，确认是否跳过本阶段。
    if event == fk.EventPhaseChanging then
      local change = data
      --print("EventPhaseChanging")
      local prompt = "#v_jiaoduo_choice:::"..phase_string(change.to)..":"..0
      --print(prompt)
      local cards = {}
      local hand = player:getCardIds(Player.Hand)
      for _,p in ipairs(hand) do
        table.insert(cards, p)
      end
      local x = #(cards)
      if x > 0 then
        if x > player.maxHp then
          x = player.maxHp
        end
        prompt = "#v_jiaoduo_choice:::"..phase_string(change.to)..":"..x
      end
      if yes_or_no(player, self.name, prompt) then
        --尝试了一下，这里不能跳阶段，失败的话只能耦合到on_use了。
        --player:skip(change.to)
        return true
      end
    --满足技能发动要求后，锁定发动。
    elseif event == fk.EventPhaseEnd and (player:getMark("@v_jiaoduo_card") > 0 or player:getMark("@@v_jiaoduo_nocard") > 0) then
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    --以on_cost中跳过阶段为代价，为风野提供标签以触发后续技能。
    --一种标签为无手牌，另一种标签为手牌数，这种区分方式是因为需要将手牌数标签为0的情况视作未触发而非手牌为0.
    if event == fk.EventPhaseChanging then
      local cards = {}
      local hand = player:getCardIds(Player.Hand)
      for _,p in ipairs(hand) do
        table.insert(cards, p)
      end
      local x = #(cards)
      room:setPlayerMark(player, "v_jiaoduo_using", 1)
      if x > 0 then
        room:setPlayerMark(player, "@v_jiaoduo_card", x)
      else
        room:setPlayerMark(player, "@@v_jiaoduo_nocard", 1)
      end
      return true
    elseif event == fk.EventPhaseEnd then
      --清空使用状态，将之前记下来的手牌数转录到local变量z中
      room:setPlayerMark(player, "v_jiaoduo_using", 0)
      local z = 0
      if player:getMark("@@v_jiaoduo_nocard") > 0 then
        room:setPlayerMark(player, "@@v_jiaoduo_nocard", 0)
      elseif player:getMark("@v_jiaoduo_card") > 0 then
        z = player:getMark("@v_jiaoduo_card")
        room:setPlayerMark(player, "@v_jiaoduo_card", 0)
      end
      --现有手牌小于/大于之前记录值之后的处理。
      if player:getHandcardNum() < math.min(player.maxHp, z) then
        local a = math.min(player.maxHp, z) - player:getHandcardNum()
        player:drawCards(a, self.name)
      elseif player:getHandcardNum() > z then
        local a = player:getHandcardNum() - z
        room:askForDiscard(player, a, a, false, self.name, false)
      end
    end
  end,

  --目前萌以前写的标记一键删除姬还没做出来，因此还是用比较原始的refresh处理。
  refresh_events = {fk.EventPhaseStart},
  can_refresh = function(self, event, target, player, data)
    if not (target == player and player:hasSkill(self.name)) then
      return false
    end
    if event == fk.EventPhaseStart then
      return player.phase == Player.NotActive
    end
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, "v_jiaoduo_using", 0)
    room:setPlayerMark(player, "@v_jiaoduo_card", 0)
    room:setPlayerMark(player, "@@v_jiaoduo_nocard", 0)
  end
}

table.insert(turn_end_clear_mark, "v_jiaoduo_using")
table.insert(turn_end_clear_mark, "@v_jiaoduo_card")
table.insert(turn_end_clear_mark, "@@v_jiaoduo_nocard")

--------------------------------------------------
--风野慵
--角色马克：
--------------------------------------------------

local fengyeyong_youhemingling = General(extension,"fengyeyong_youhemingling", "individual", 4, 4, General.Female)
fengyeyong_youhemingling:addSkill(v_jiaoduo)

--------------------------------------------------
--炽翎
--技能马克：现在做不了，在没有cardflag的前提下，火攻如果需要特定，需要改军争的牌或在这里做一张clone火攻
--------------------------------------------------

local v_chiling = fk.CreateViewAsSkill{
  name = "v_chiling",
  --赋予输出型技能定义
  anim_type = "offensive",
  pattern = "fire_attack",
  card_filter = function(self, to_select, selected)
    if #selected == 1 then return false end
    return Fk:getCardById(to_select).color == Card.Red
  end,
  view_as = function(self, cards)
    if #cards ~= 1 then
      return nil
    end
    local c = Fk:cloneCard("fire_attack")
    c:addSubcard(cards[1])
    return c
  end,
  enabled_at_play = function(self, player)
    return player:usedSkillTimes(self.name, Player.HistoryTurn) < 1
  end,
  enabled_at_response = function(self, player)
    return false
  end,
}

--------------------------------------------------
--辨识
--技能马克：
--------------------------------------------------

local v_bianshi = fk.CreateActiveSkill{
  name = "v_bianshi",
  --赋予摸牌型技能定义
  anim_type = "drawcard",
  --可用条件：
  --出牌阶段限一次
  --角色手牌数<4+角色装备数
  can_use = function(self, player)
    local hands = {}
    local equips = {}
    local hand = player:getCardIds(Player.Hand)
    local equip = player:getCardIds(Player.Equip)
    for _,p in ipairs(hand) do
      table.insert(hands, p)
    end
    for _,p in ipairs(equip) do
      table.insert(equips, p)
    end
    return player:usedSkillTimes(self.name, Player.HistoryTurn) == 0
    and #(hands) < 4 + #(equips)
  end,
  card_filter = function(self, to_select, selected, selected_targets)
    return false
  end,
  on_use = function(self, room, effect)
    local players = room.players
    --记录手牌区及装备区的牌。
    local hands = {}
    local equips = {}
    local pp = nil
    --通过是否处于出牌阶段确认是否是该玩家。
    for _,p in ipairs(players) do
      if p.phase == Player.Play then
        pp = p
      end
    end
    local hand = pp:getCardIds(Player.Hand)
    local equip = pp:getCardIds(Player.Equip)
    for _,p in ipairs(hand) do
      table.insert(hands, p)
    end
    for _,p in ipairs(equip) do
      table.insert(equips, p)
    end

    local x = 4 + #(equips)
    local draw_num = x - #(hands)
    if draw_num > 0 then
      room:sendLog{
        type = "#v_bianshi",
        from = pp.id,
        arg = self.name,
        arg2 = x
      }
      room:drawCards(pp, draw_num, self.name, top)
      room:askForDiscard(pp, draw_num, draw_num, true, self.name, false)
    end
  end,
}

--------------------------------------------------
--成长
--技能马克：技能效果没写
--------------------------------------------------

local v_chengzhang = fk.CreateTriggerSkill{
  name = "v_chengzhang",
  --赋予支援型技能定义
  anim_type = "support",
  --时机：体力回复后
  events = {fk.HpRecover},
  --触发条件：
  --（摸牌）造成回复的角色为遍历到的角色、遍历到的角色具有本技能、触发时机的角色体力==1。
  can_trigger = function(self, event, target, player, data)
    print(player)
    print(data.recoverBy)
    local room = player.room
    local saver = room:getPlayerById(data.recoverBy)
    return saver == player and player:hasSkill(self.name) 
    and target.hp == 1
  end,
  -- on_cost = function(self, event, target, player, data)
  --   return true
  -- end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    --记录牌堆及弃牌堆的装备牌。
    local equips = {}
    --这里没摸到牌堆/弃牌堆的牌
    local draw = room.draw_pile
    local discard = room.discard_pile
    for _,p in ipairs(draw) do
      local card = Fk:getCardById(p)
      --（后续可以补充isavailable判定确保这个装备是可以被玩家装备的，如果出现玩家因为装备区封印穿不上去的情况可以噶了。)
      if card.type == Card.TypeEquip then
        table.insert(equips, p)
      end
    end
    for _,p in ipairs(discard) do
      local card = Fk:getCardById(p)
      --（后续可以补充isavailable判定确保这个装备是可以被玩家装备的，如果出现玩家因为装备区封印穿不上去的情况可以噶了。)
      if card.type == Card.TypeEquip then
        table.insert(equips, p)
      end
    end
    if #(equips) > 0 then
      print(#(equips))
      local x = #(equips)
      local c = math.random(0, x - 1)
      print(c)
      --说是这里返回了一个虚空值，搞不懂了（呆滞）
      local card = equips:at(c)
      local new_use = {} ---@type CardUseStruct
      new_use.from = player.id
      --技能马克：可能会存在类似于知更酱多目标BUG的问题
      new_use.tos = { { player.id } }
      new_use.card = Fk:getCardById(card)
      new_use.skillName = self.name
      room:useCard(new_use)
    end
  end,
}

--------------------------------------------------
--小毛
--角色马克：
--------------------------------------------------

local xiaomao_lairikeqi = General(extension,"xiaomao_lairikeqi", "individual", 1, 4, General.Female)
xiaomao_lairikeqi:addSkill(v_bianshi)
xiaomao_lairikeqi:addSkill(v_chengzhang)

--------------------------------------------------
--模式：斗地主
--------------------------------------------------

-- Because packages are loaded before gamelogic.lua loaded
-- so we can not directly create subclass of gamelogic in the top of lua
local m_1v2_getLogic = function()
  local m_1v2_logic = GameLogic:subclass("m_1v2_logic")

  function m_1v2_logic:initialize(room)
    GameLogic.initialize(self, room)
    self.role_table = {nil, nil, {"lord", "rebel", "rebel"}}
  end

  function m_1v2_logic:chooseGenerals()
    local room = self.room
    local function setPlayerGeneral(player, general)
      if Fk.generals[general] == nil then return end
      player.general = general
      player.gender = Fk.generals[general].gender
      self.room:broadcastProperty(player, "general")
      self.room:broadcastProperty(player, "gender")
    end

    local lord = room:getLord()
    room.current = lord
    local nonlord = room.players
    local generals = Fk:getGeneralsRandomly(#nonlord * 3)
    table.shuffle(generals)
    for _, p in ipairs(nonlord) do
      local arg = {
        (table.remove(generals, 1)).name,
        (table.remove(generals, 1)).name,
        (table.remove(generals, 1)).name,
      }
      p.request_data = json.encode(arg)
      p.default_reply = arg[1]
    end

    room:doBroadcastRequest("AskForGeneral", nonlord)
    for _, p in ipairs(nonlord) do
      if p.general == "" and p.reply_ready then
        local general = json.decode(p.client_reply)[1]
        setPlayerGeneral(p, general)
      else
        setPlayerGeneral(p, p.default_reply)
      end
      p.default_reply = ""
    end
  end

  return m_1v2_logic
end

local m_feiyang = fk.CreateTriggerSkill{
  name = "m_feiyang",
  anim_type = "control",
  events = {fk.EventPhaseStart},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and
      player.phase == Player.Judge and
      #player:getCardIds(Player.Hand) >= 2 and
      #player:getCardIds(Player.Judge) > 0
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:askForDiscard(player, 2, 2, false, self.name, false)
    local card = room:askForCardChosen(player, player, "j", self.name)
    room:throwCard(card, self.name, player, player)
  end
}
Fk:addSkill(m_feiyang)

local m_bahubuff = fk.CreateTargetModSkill{
  name = "#m_bahubuff",
  residue_func = function(self, player, skill, scope)
    if player:hasSkill(self.name) and skill.trueName == "slash_skill"
      and scope == Player.HistoryPhase then
      return 1
    end
  end,
}
local m_bahu = fk.CreateTriggerSkill{
  name = "m_bahu",
  anim_type = "drawcard",
  frequency = Skill.Compulsory,
  events = {fk.EventPhaseStart},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and
      player.phase == Player.Start
  end,
  on_use = function(self, event, target, player, data)
    player:drawCards(1)
  end,
}
m_bahu:addRelatedSkill(m_bahubuff)

Fk:addSkill(m_bahu)

local m_1v2_rule = fk.CreateTriggerSkill{
  name = "#m_1v2_rule",
  priority = 0.001,
  refresh_events = {fk.GameStart, fk.BuryVictim},
  can_refresh = function(self, event, target, player, data)
    if event == fk.GameStart then return player.role == "lord" end
    return target == player
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    if event == fk.GameStart then
      room:handleAddLoseSkills(player, "m_feiyang|m_bahu", nil, false)
      player.maxHp = player.maxHp + 1
      player.hp = player.hp + 1
      room:broadcastProperty(player, "maxHp")
      room:broadcastProperty(player, "hp")
      room:setTag("SkipNormalDeathProcess", true)
    else
      for _, p in ipairs(room.alive_players) do
        if p.role == "rebel" then
          local choices = {"m_1v2_draw2", "Cancel"}
          if p:isWounded() then
            table.insert(choices, 2, "m_1v2_heal")
          end
          local choice = room:askForChoice(p, choices, self.name)
          if choice == "m_1v2_draw2" then p:drawCards(2)
          else room:recover{ who = p, num = 1, skillName = self.name } end
        end
      end
    end
  end,
}
Fk:addSkill(m_1v2_rule)

local m_1v2_mode = fk.CreateGameMode{
  name = "m_1v2_mode",
  minPlayer = 3,
  maxPlayer = 3,
  rule = m_1v2_rule,
  logic = m_1v2_getLogic,
}

extension:addGameMode(m_1v2_mode)

-- 加载本包的翻译包(load translations of this package)，这一步在本文档的最后进行。
dofile "packages/vupslash/i18n/init.lua"

return { extension } 