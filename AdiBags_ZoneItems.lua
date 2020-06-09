--[[
AdiBags_ZoneItems - Groups  items for specific zones, expansions or activities together, an addition to Adirelle's fantastic bag addon AdiBags.
Copyright 2020 Ggreg Taylor
--]]
local addon = LibStub('AceAddon-3.0'):GetAddon('AdiBags')
local L = setmetatable({}, {__index = addon.L})
local setFilter = addon:RegisterFilter("ZoneItems", 93, 'ABEvent-1.0')
setFilter.uiName = L['Zone Specific Items']
setFilter.uiDesc = L['Group zone specific items together.']
local addonName, data  = ...
local Ggbug = true

if Ggbug == true then print('AdiBags - Zone Items loaded.') end

-- debugging values
local debugBagSlot = {1,21}
local lookForId = 174287
local testChannel = -1
-- General Constants
local errNOT_FOUND = -101
local kCategory = 'Zone Item'
local kPfx = '|cff00ffff'  -- teal
--local kPfx2 = '|cffFF99FF' -- bright PINK
local kPfx2 = '|cff3CE13F' -- bright green1
local kPfx3 = '|cff2FEB77' -- bright green2
local kSfx = '|r'
local kCurrBoAMin = 385
-- Set special top-of-bags category for current zone's items
local CURRENT_ZONE_ITEM = 'Current Zone Item'
addon:SetCategoryOrder(CURRENT_ZONE_ITEM,80)
-- Global Variables
local currZoneId, currMap, currMapID, mapName, parentMapID, parentMapName, loadedZoneGroups


-- Expansion #: 1-Vanilla, 2-TBC, 3-LK, 4-MoP, 5-Cata, 6-WoD, 7-Legion, 8-BFA, 9-Shadowlands
------------------------------------------------------------------------------
function setFilter:OnInitialize(b)
  self.db = addon.db:RegisterNamespace('ZoneItems', {
    profile = { 
      enable = true ,
      enableZoneItem = true,
      groupBoATokens = true,
      groupEssences = true,
      groupMechagon = true,
      groupMission = true,
      groupNazjatar = true,
      groupTimeless = true,
      groupPatch8_3 = true,
      groupCorrupted = true,
		  groupRepItems  = true,
      zonePriority = true,
      groupInstanced = false,
      groupPVP = false,
  },
    char = {  },
  })
end
function setFilter:Update()
  self:SendMessage('AdiBags_FiltersChanged')
end
function setFilter:OnEnable()
  addon:OnEnable()
end
function setFilter:OnDisable()
  addon:UpdateFilters()
end
function setFilter:GetOptions()
  return {
    enable = {
      name = L['Enable Zone Item groups'],
      desc = L['Check this if you want to automatically seperate Nazjatar and Mechagon items.'],
      type = 'toggle',
      order = 25,
    },
    groupSetCurrentFirst = {
      name = L['Current Zone First in Bags'],
      type = L['group'],
      inline = true,
      order = 20,
      args = {
        _desc = {
          name = L['Group items relevant for the current zone(s) to top of bags for quicker access.'],
          type = 'description',
          order = 10,
        }, 
        zonePriority = {
          name = L['Enable'],
          desc = L['Only a monster would disable this feature. You aren\'t a monster now, are you?'],
          type = 'toggle',
          order = 33,
        },
      }
    },
    groupSetZoneItemSubgroups = {
      name = L['Battle for Azeroth Groups'],
      type = L['group'],
      inline = true,
      order = 26,
      args = {
        _desc = {
          name = L['Select optional additional sub-groupings.'],
          type = 'description',
          order = 10,
        }, 
        groupMechagon = {
          name = L['Mechagon'],
          desc = L['Group items specific to Mechagon seperately.'],
          type = 'toggle',
          order = 26,
        },
        groupNazjatar = {
          name = L['Nazjatar'],
          desc = L['Group items specific to Nazjatar seperately.'],
          type = 'toggle',
          order = 27,
        },
        groupEssences = {
          name = L['Heart Essences'],
          desc = L['Group Heart of Azeroth essences seperately.'],
          type = 'toggle',
          order = 29,
        },
        groupPatch8_3 = {
          name = L['Uldum, Vale, Visions'],
          desc = L['Group items added in Patch 8.3 for Uldum, Horrific Visions, and Vale of Eternal Blossoms. They really should leave that poor Vale alone.'],
          type = 'toggle',
          order = 30,
        },
        groupCorrupted = {
          name = L[CORRUPTION_TOOLTIP_TITLE],
          desc = L['Group corrupted items.'],
          type = 'toggle',
          order = 34,
        },
      }
    },
    otherMiscGroups = {
      name = L['Other Groupings'],
      type = L['group'],
      inline = true,
      order = 29,
      args = {
        _desc = {
          name = L['Group filters for Prior Expansions and More.'],
          type = 'description',
          order = 10,
        }, 
        groupBoATokens = {
          name = L['BoA Gear Tokens'],
          desc = L['Group Benthic and Black Empire Bind on Account gear tokens seperately.'],
          type = 'toggle',
          order = 25,
        },
        groupRepItems = {
          name = L['Reputation Items'],
          desc = L['Group Reputation on-use and repeatable turn-in items seperately.'],
          type = 'toggle',
          order = 28,
        },
        groupMission = {
          name = L['Garrison & Class Hall'],
          desc = L[GARRISON_LOCATION_TOOLTIP .. '/' ..ORDER_HALL_MISSIONS],
          type = 'toggle',
          order = 31,
        },
        groupTimeless = {
          name = L['Pandaria Timeless Isle'],
          desc = L['Pandaria Timeless Isle-specific items.'],
          type = 'toggle',
          order = 32,
        },
--[[         groupPVP = {
          name = L['PVP - NYI'],
          desc = L['Not yet implemented.'],
          --name = L['PVP Priority Items'],
          --desc = L['Moves PVP-related items to top of bags in Arenas, Battlegrounds as relevant for easier access.'],
          type = 'toggle',
          order = 33,
        },
        groupInstanced = {
          name = L['Party - NYI'],
          desc = L['Not yet implemented.'],
          --name = L['Party Supplies'],
          --desc = L['Prioritizes items for parties. Or raids. Moves consumables such as food, potions, and other enhancement/restoration items to top of bags in instanced content for easier access.'],
          type = 'toggle',
          order = 34,
        }, ]]
      }
    },
  }, addon:GetOptionHandler(self, false, function() return self:Update() end)
end

local function ttCreate()
  local tip, rightside, leftside = CreateFrame("GameTooltip"), {}, {}
  for i = 1,6 do
    local L,R = tip:CreateFontString(), tip:CreateFontString()
    L:SetFontObject(GameFontNormal)
    R:SetFontObject(GameFontNormal)
    tip:AddFontStrings(L,R)
    leftside[i] = L
    rightside[i] = R
  end
  tip.leftside = leftside
  tip.rightside = rightside
  return tip
end
local tooltip = tooltip or ttCreate()

local function loadMapIDs()
  currZoneId = C_Map.GetBestMapForUnit("player")
  if currZoneId ~= nil then
    currMap = C_Map.GetMapInfo(currZoneId)
    currMapID = currMap.mapID
    mapName = currMap.name
    parentMapID = C_Map.GetMapInfo(currMapID).parentMapID
    parentMapName = C_Map.GetMapInfo(parentMapID).name
  end
  -- check if current zone is matched in the arrZoneCodes table set lable to priority color and move top of bags
  loadedZoneGroups = {}
  for i = 1, #data.arrZoneCodes do loadedZoneGroups[i] = {} end
  for id, info in pairs(data.arrZoneCodes) do
    --[1]= { zGroup="Vale", zGroupIds={1530,1570,380,390} },
    local zGroupIds = info.zGroupIds
    loadedZoneGroups[id][1] = id
    loadedZoneGroups[id][2] = info.zGroup -- The Group's name
    loadedZoneGroups[id][3] = info.zGroupIds
  end -- end pairs loop 
end

------------------------------------------------------------------------------
function setFilter:checkItem(itemId, dataArray)
  -- returns zoneID if itemId finds a match in the array otherwise null
  --itemId, zoneId, qty-1, label
  for id, info in pairs(dataArray) do
    --if tonumber(itemId) == lookForId then  ('check item', itemId, info.itemId)
    if tonumber(itemId) == tonumber(info.itemId) then
      for x = 1, #loadedZoneGroups[info.zoneId][3] do
        if tonumber(loadedZoneGroups[info.zoneId][3][x]) == tonumber(currZoneId) then
          if self.db.profile.zonePriority then
            return true, kPfx2 .. loadedZoneGroups[info.zoneId][2] .. kSfx, CURRENT_ZONE_ITEM
          else
            return true, kPfx2 .. loadedZoneGroups[info.zoneId][2] .. kSfx, kCategory
          end
        end
      end
      return true, kPfx .. loadedZoneGroups[info.zoneId][2] .. kSfx, kCategory
    end 
  end
  return false, false, false
end

------------------------------------------------------------------------------
function setFilter:Filter(slotData)
  --Exit zoneItem addon if not enabled
  if not self.db.profile.enable then return end
  if currZoneId ~= C_Map.GetBestMapForUnit("player") or currZoneId == nil then  loadMapIDs() end
	local bagItemID = slotData.itemId
  --funky but GetItemInfo doesn't return corruption info so call specifically for itemLink
  itemLink = GetContainerItemLink(slotData.bag, slotData.slot)
  local itemName,_, itemRarity, itemLevel,itemMinLevel, itemType, itemSubType,_,_, _, _, itemClassID, itemSubClassID, bindType, expacID = GetItemInfo(itemLink)
  if itemLevel == nil then itemLevel = 0 end

  -- Start checking groupings
  -- Heart of Azeroth Essences
  if self.db.profile.groupEssences and (itemClassID == 0 and itemSubClassID == 8 and itemRarity == 6 and expacID ==7) then
    return kPfx .. 'Heart Essence'.. kSfx, 'Essence'
  end
  --Corrupted gear 
  if self.db.profile.groupCorrupted and IsCorruptedItem(itemLink) == true then
    currSubCategory = CORRUPTED_ITEM_LOOT_LABEL
    return kPfx.. currSubCategory .. kSfx, kCategory
  end
    -- Heart Essences
  if self.db.profile.groupEssences then
    local itemFound, groupLabel, retCategory = setFilter:checkItem(bagItemID, data.arrEssence) 
    if itemFound == true  then return groupLabel, retCategory end
  end
  -- Garrison and Order Hall  
  if self.db.profile.groupMission then
    local itemFound, groupLabel, retCategory = setFilter:checkItem(bagItemID, data.arrMissions) 
    if itemFound == true  then return groupLabel, retCategory end
  end
  -- Patch 8.3 Vale/Uldum/Horiffic Visions
  if self.db.profile.groupPatch8_3 then
    local itemFound, groupLabel, retCategory = setFilter:checkItem(bagItemID, data.arrPatch8_3) 
    if itemFound == true  then return groupLabel, retCategory end
  end
  -- Pandaria Timeless Isle
  if self.db.profile.groupTimeless then
    local itemFound, groupLabel, retCategory = setFilter:checkItem(bagItemID, data.arrTimeless) 
    if itemFound == true  then return groupLabel, retCategory end
  end
  -- Patch 8.2 Nazjatar
  if self.db.profile.groupNazjatar then
    -- check Nazjatar general items
    local itemFound, groupLabel, retCategory = setFilter:checkItem(bagItemID, data.arrNazjatar) 
    if itemFound == true  then  return groupLabel, retCategory end
  end
  -- Patch 8.2 Mechagon
  if self.db.profile.groupMechagon then
    local itemFound, groupLabel = setFilter:checkItem(bagItemID, data.arrMechagon) 
    if itemFound == true  then return groupLabel, retCategory end
  end
  if self.db.profile.groupRepItems then
    local itemFound, groupLabel = setFilter:checkItem(bagItemID, data.arrReputation) 
    if itemFound == true  then return groupLabel, retCategory end
  end
   -- BoA Gear Tokens, non-obsolete, check last
  if self.db.profile.groupBoATokens == true and itemLevel >= kCurrBoAMin and (itemClassID == LE_ITEM_CLASS_ARMOR or itemSubClassID == LE_ITEM_CLASS_WEAPON) then
    tooltip:SetOwner(UIParent,"ANCHOR_NONE")
    tooltip:ClearLines()
    if slotData.bag == BANK_CONTAINER then
      tooltip:SetInventoryItem("player", BankButtonIDToInvSlotID(slotData.slot, nil))
    else
      tooltip:SetBagItem(slotData.bag, slotData.slot)
    end
    local bindType = tooltip.leftside[3]:GetText()
    tooltip:Hide()
    tooltip:SetParent(nil)

    if  (bindType ==ITEM_ACCOUNTBOUND or bindType ==ITEM_BNETACCOUNTBOUND) then
      currSubCategory = L['Current BoA']
      return currSubCategory, kCategory
    end
  end

end

