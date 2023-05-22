local mod = RegisterMod('Fruity Plum Challenge', 1)
local game = Game()

mod.babyPlumBossId = 84
mod.rngShiftIdx = 35
mod.playerHash = nil

function mod:onGameStart(isContinue)
  if not mod:isChallenge() and not mod:isGiantChallenge() then
    return
  end
  
  if not isContinue then
    local seeds = game:GetSeeds()
    seeds:AddSeedEffect(SeedEffect.SEED_INFINITE_BASEMENT)
    
    local itemPool = game:GetItemPool()
    -- remove items that could change our loadout
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_CLICKER)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_D4)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_D100)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_D_INFINITY)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_ESAU_JR)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_GENESIS)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_LEMEGETON)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_METRONOME)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_MISSING_NO)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_SACRIFICIAL_ALTAR)
    itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_TMTRAINER)
    itemPool:RemoveTrinket(TrinketType.TRINKET_ERROR)
    itemPool:RemoveTrinket(TrinketType.TRINKET_EXPANSION_PACK)
    itemPool:RemoveTrinket(TrinketType.TRINKET_M)
    
    if mod:isChallenge() then
      itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_FRUITY_PLUM)
    elseif mod:isGiantChallenge() then
      itemPool:RemoveCollectible(CollectibleType.COLLECTIBLE_PLUM_FLUTE)
    end
  end
end

function mod:onGameExit()
  mod.playerHash = nil
end

function mod:onNewRoom()
  if not mod:isGiantChallenge() then
    return
  end
  
  local player = game:GetPlayer(0)
  player:UseActiveItem(CollectibleType.COLLECTIBLE_PLUM_FLUTE, false, false, true, false, -1, 0)
end

function mod:onNewLevel()
  if not mod:isChallenge() and not mod:isGiantChallenge() then
    return
  end
  
  -- force baby plum by XX
  -- check past this number just in case something like book of rev was used
  if mod:getBasementNum() >= 20 then
    local seeds = game:GetSeeds()
    local level = game:GetLevel()
    local stage = level:GetStage()
    local rooms = level:GetRooms()
    local bossRoomRo = rooms:Get(level:GetLastBossRoomListIndex()) -- read-only
    local bossRoom = bossRoomRo and level:GetRoomByIdx(bossRoomRo.SafeGridIndex, -1) -- read/write
    
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
  if not mod:isChallenge() and not mod:isGiantChallenge() then
    return
  end
  
  if mod:isChallenge() and mod:countFruityPlums() == 0 then
    mod:killAllPlayers()
  end
  
  mod:doBabyPlumRoomLogic()
end

-- filtered to 0-Player
function mod:onPlayerInit(player)
  if not mod:isChallenge() and not mod:isGiantChallenge() then
    return
  end
  
  if player:GetPlayerType() ~= PlayerType.PLAYER_ISAAC then
    return
  end
  
  if mod:isChallenge() then
    if mod:countFruityPlums() == 0 then
      -- limit to one fruity plum
      player:AddCollectible(CollectibleType.COLLECTIBLE_FRUITY_PLUM, 0, true, ActiveSlot.SLOT_PRIMARY, 0)
    end
    for _, v in ipairs({ TrinketType.TRINKET_BABY_BENDER, TrinketType.TRINKET_FORGOTTEN_LULLABY }) do
      player:AddTrinket(v)
      player:UseActiveItem(CollectibleType.COLLECTIBLE_SMELTER, false, false, true, false, -1, 0)
    end
  end
  
  player:AddTrinket(TrinketType.TRINKET_AAA_BATTERY)
  mod.playerHash = GetPtrHash(player)
end

-- filtered to PLAYER_ISAAC
function mod:onPeffectUpdate(player)
  if not mod:isChallenge() and not mod:isGiantChallenge() then
    return
  end
  
  if mod.playerHash and mod.playerHash == GetPtrHash(player) then
    -- SetPocketActiveItem crashes in onPlayerInit when continuing a run after fully shutting down the game
    player:SetPocketActiveItem(CollectibleType.COLLECTIBLE_PONY, ActiveSlot.SLOT_POCKET, false)
    player:RespawnFamiliars() -- otherwise fruity plum doesn't show up
    mod.playerHash = nil
  end
end

function mod:onFamiliarUpdate(familiar)
  if not mod:isGiantChallenge() then
    return
  end
  
  -- 3 to 7, at 7 she leaves, reset to 3
  if familiar.State == 7 then
    familiar.State = 3
  end
end

function mod:getCard(rng, card, includeCards, includeRunes, onlyRunes)
  if not mod:isChallenge() and not mod:isGiantChallenge() then
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
  
  -- Basement I, Basement III?
  -- there might be punctuation at the very end
  -- XL is disabled via cursefilter so we don't need to worry about: Basement XL! XL
  -- this works for multi-language
  local num = string.match(name, ' ([IVXLCDM]+)%p*$')
  
  if num then
    return mod:romanToInt(num)
  end
  
  return 0
end

-- this doesn't validate roman numerals
-- IIII will return 4
-- IL will return 51 rather than 49
function mod:romanToInt(s)
  local num = 0
  
  local i, l = 1, string.len(s)
  while i <= l do
    local c = string.sub(s, i, i + 1)
    local n = string.len(c) == 2 and mod:getRomanVal(c)
    if n then
      i = i + 1
    else
      c = string.sub(s, i, i)
      n = mod:getRomanVal(c)
    end
    
    if n then
      num = num + n
    end
    
    i = i + 1
  end
  
  return num
end

function mod:getRomanVal(c)
  local tbl = {
    I  = 1,
    IV = 4,
    V  = 5,
    IX = 9,
    X  = 10,
    XL = 40,
    L  = 50,
    XC = 90,
    C  = 100,
    CD = 400,
    D  = 500,
    CM = 900,
    M  = 1000
  }
  
  return tbl[c]
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

function mod:isGiantChallenge()
  local challenge = Isaac.GetChallenge()
  return challenge == Isaac.GetChallengeIdByName('Fruity Plum Challenge (Giant)')
end

mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.onGameStart)
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.onGameExit)
mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, mod.onNewLevel)
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.onNewRoom)
mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.onUpdate)
mod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, mod.onPlayerInit, 0) -- 0 is player, 1 is co-op baby
mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, mod.onPeffectUpdate, PlayerType.PLAYER_ISAAC)
mod:AddCallback(ModCallbacks.MC_FAMILIAR_UPDATE, mod.onFamiliarUpdate, FamiliarVariant.BABY_PLUM)
mod:AddCallback(ModCallbacks.MC_GET_CARD, mod.getCard)