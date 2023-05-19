local mod = RegisterMod('Fruity Plum Challenge', 1)
local game = Game()

mod.babyPlumBossId = 84
mod.rngShiftIdx = 35
mod.playerHash = nil

function mod:onGameStart(isContinue)
  if not mod:isChallenge() then
    return
  end
  
  if not isContinue then
    local seeds = game:GetSeeds()
    seeds:AddSeedEffect(SeedEffect.SEED_INFINITE_BASEMENT)
    
    local itemPool = game:GetItemPool()
    -- remove items that could change our loadout
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_BROKEN_MODEM)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_CLICKER)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_D4)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_D100)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_D_INFINITY)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_ESAU_JR)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_FRUITY_PLUM)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_GENESIS)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_LEMEGETON)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_METRONOME)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_MISSING_NO)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_SACRIFICIAL_ALTAR)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_TMTRAINER)
    itemPool:RemoveTrinket(TrinketType.TRINKET_ERROR)
    itemPool:RemoveTrinket(TrinketType.TRINKET_EXPANSION_PACK)
    itemPool:RemoveTrinket(TrinketType.TRINKET_M)
  end
end

function mod:onGameExit()
  mod.playerHash = nil
end

function mod:onNewLevel()
  if not mod:isChallenge() then
    return
  end
  
  -- force baby plum by XX
  -- check past this number just in case something like book of rev was used
  -- if we need to go deeper then add some code to parse this into an integer
  local basementNum = mod:getBasementNum()
  
  if basementNum == 'XX' or
     basementNum == 'XXI' or
     basementNum == 'XXII' or
     basementNum == 'XXIII' or
     basementNum == 'XXIV' or
     basementNum == 'XXV'
  then
    local seeds = game:GetSeeds()
    local level = game:GetLevel()
    local stage = level:GetStage()
    local rooms = level:GetRooms()
    local bossRoomIdx = rooms:Get(level:GetLastBossRoomListIndex()).SafeGridIndex
    local bossRoom = level:GetRoomByIdx(bossRoomIdx, -1) -- read/write
    
    -- check for 1x1, but it should always be the case in the basement
    if bossRoom and bossRoom.Data and bossRoom.Data.Subtype ~= mod.babyPlumBossId and bossRoom.Data.Shape == RoomShape.ROOMSHAPE_1x1 then
      local roomIdx = level:GetCurrentRoomIndex()
      
      local rng = RNG()
      rng:SetSeed(seeds:GetStageSeed(stage), mod.rngShiftIdx)
      local babyPlumRooms = { '5160', '5161', '5162', '5163', '5165' } -- 5164 only has 3 doors
      local babyPlumRoom = babyPlumRooms[rng:RandomInt(#babyPlumRooms) + 1]
      
      Isaac.ExecuteCommand('goto s.boss.' .. babyPlumRoom)
      local dbg = level:GetRoomByIdx(GridRooms.ROOM_DEBUG_IDX, -1)
      bossRoom.Data = dbg.Data
      
      game:StartRoomTransition(roomIdx, Direction.NO_DIRECTION, RoomTransitionAnim.FADE, nil, -1)
    end
  end
end

function mod:onUpdate()
  if not mod:isChallenge() then
    return
  end
  
  if mod:countFruityPlums() == 0 then
    mod:killAllPlayers()
  end
  
  mod:doBabyPlumRoomLogic()
end

-- filtered to 0-Player
function mod:onPlayerInit(player)
  if not mod:isChallenge() then
    return
  end
  
  if player:GetPlayerType() ~= PlayerType.PLAYER_ISAAC then
    return
  end
  
  if mod:countFruityPlums() == 0 then
    -- limit to one fruity plum
    player:AddCollectible(CollectibleType.COLLECTIBLE_FRUITY_PLUM, 0, true, ActiveSlot.SLOT_PRIMARY, 0)
  end
  for _, v in ipairs({ TrinketType.TRINKET_BABY_BENDER, TrinketType.TRINKET_FORGOTTEN_LULLABY }) do
    player:AddTrinket(v)
    player:UseActiveItem(CollectibleType.COLLECTIBLE_SMELTER, false, false, true, false, -1)
  end
  player:AddTrinket(TrinketType.TRINKET_AAA_BATTERY)
  mod.playerHash = GetPtrHash(player)
end

-- filtered to PLAYER_ISAAC
function mod:onPeffectUpdate(player)
  if not mod:isChallenge() then
    return
  end
  
  if mod.playerHash and mod.playerHash == GetPtrHash(player) then
    -- SetPocketActiveItem crashes in onPlayerInit when continuing a run after fully shutting down the game
    player:SetPocketActiveItem(CollectibleType.COLLECTIBLE_PONY, ActiveSlot.SLOT_POCKET, false)
    player:RespawnFamiliars() -- otherwise fruity plum doesn't show up
    mod.playerHash = nil
  end
end

function mod:getCard(rng, card, includeCards, includeRunes, onlyRunes)
  if not mod:isChallenge() then
    return
  end
  
  -- random dice room effect including D4
  if card == Card.CARD_REVERSE_WHEEL_OF_FORTUNE then
    return Card.CARD_WHEEL_OF_FORTUNE
  end
end

function mod:getBasementNum()
  local level = game:GetLevel()
  local name = level:GetName()
  local num = ''
  
  -- Basement I, Basement III?
  -- loop backwards until we find a space
  -- there might be punctuation at the very end
  -- this works for multi-language
  for i = string.len(name), 1, -1 do
    local c = string.sub(name, i, i)
    if c == ' ' then
      break
    elseif mod:isRomanNum(c) then
      num = c .. num
    end
  end
  
  return num
end

function mod:isRomanNum(c)
  for _, v in ipairs({ 'I', 'V', 'X', 'L', 'C', 'D', 'M' }) do
    if v == c then
      return true
    end
  end
  
  return false
end

function mod:doBabyPlumRoomLogic()
  local room = game:GetRoom()
  
  if room:IsCurrentRoomLastBoss() and room:GetBossID() == mod.babyPlumBossId and room:IsClear() then
    mod:removeTrapdoors()
    mod:spawnTrophy(room:GetCenterPos())
  end
end

function mod:removeTrapdoors()
  local room = game:GetRoom()
  
  for i = 0, room:GetGridSize() - 1 do
    local gridEntity = room:GetGridEntity(i)
    if gridEntity and gridEntity:GetType() == GridEntityType.GRID_TRAPDOOR then
      room:RemoveGridEntity(i, 0, false)
    end
  end
end

function mod:spawnTrophy(pos)
  if #Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TROPHY, 0, false, false) == 0 then
    Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TROPHY, 0, Isaac.GetFreeNearPosition(pos, 3), Vector.Zero, nil)
  end
end

function mod:countFruityPlums()
  return #Isaac.FindByType(EntityType.ENTITY_FAMILIAR, FamiliarVariant.FRUITY_PLUM, 0, false, false)
end

function mod:killAllPlayers()
  for i = 0, game:GetNumPlayers() - 1 do
    local player = game:GetPlayer(i)
    player:Die()
  end
end

function mod:isChallenge()
  local challenge = Isaac.GetChallenge()
  return challenge == Isaac.GetChallengeIdByName('Fruity Plum Challenge')
end

mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.onGameStart)
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.onGameExit)
mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, mod.onNewLevel)
mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.onUpdate)
mod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, mod.onPlayerInit, 0) -- 0 is player, 1 is co-op baby
mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, mod.onPeffectUpdate, PlayerType.PLAYER_ISAAC)
mod:AddCallback(ModCallbacks.MC_GET_CARD, mod.getCard)