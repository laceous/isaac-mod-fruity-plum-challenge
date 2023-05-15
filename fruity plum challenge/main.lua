local mod = RegisterMod('Fruity Plum Challenge', 1)
local game = Game()

mod.bossId = 84 -- baby plum
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

function mod:doBabyPlumRoomLogic()
  local room = game:GetRoom()
  
  if room:IsCurrentRoomLastBoss() and room:GetBossID() == mod.bossId and room:IsClear() then
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
mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.onUpdate)
mod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, mod.onPlayerInit, 0) -- 0 is player, 1 is co-op baby
mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, mod.onPeffectUpdate, PlayerType.PLAYER_ISAAC)
mod:AddCallback(ModCallbacks.MC_GET_CARD, mod.getCard)