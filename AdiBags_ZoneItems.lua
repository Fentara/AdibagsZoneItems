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

local Ggbug = false
if Ggbug == true then print(addon , 'loaded.') end
-- debugging values
local debugBagSlot = {1,21}
local lookForId = 114622
local testChannel = -1
local bagItemID
-- General Constants
local errNOT_FOUND = -101
local kCategory = 'Zone Item'
local kPfx = '|cff00ffff'  -- teal
--local kPfx2 = '|cffFF99FF' -- bright PINK
local kPfx2 = '|cff3CE13F' -- bright green1
local kPfx3 = '|cff2FEB77' -- bright green2
local kSfx = '|r'
local kCurrBoAMin = 385
local kLowGearThreshold = 40
local kMinExpansionIlevel = 201
-- Set special top-of-bags category for current zone's items
local CURRENT_ZONE_ITEM = 'Current Zone Item'
local CURRENT_ZONE_ITEM2 = 'Current Zone'
local PRIORITY_ITEM = 'Attention!'
addon:SetCategoryOrder(CURRENT_ZONE_ITEM, 80)
addon:SetCategoryOrder(PRIORITY_ITEM, 81)
addon:SetCategoryOrder(CURRENT_ZONE_ITEM2, 79) -- To be ordered after zone match items
-- Global Variables
local currZoneId, currMap, currMapID, mapName, parentMapID, parentMapName

function Ggprint(...) 
  if lookForId == bagItemID and Ggbug == true then print(...) end
end

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
      groupAzerite = true,
      groupLowGear = false,
  },
    char = {  },
  })
end
function setFilter:Update()
  self:SendMessage('AdiBags_FiltersChanged')
end
function setFilter:OnEnable()
  addon:UpdateFilters()
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
      order = 20,
    },
    groupSetCurrentFirst = {
      name = L['Current Zone First in Bags'],
      type = L['group'],
      inline = true,
      order = 24,
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
      order = 28,
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
        groupAzerite = {
          name = L['Azerite Armor'],
          desc = L['Group corrupted items.'],
          type = 'toggle',
          order = 35,
        },
        --[[ groupLowGear = {
          name = L['Low iLevel Seperated'],
          desc = L['Group current expansion low item level gear separately.'],
          type = 'toggle',
          order = 36,
        }, ]]

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
end

------------------------------------------------------------------------------
function setFilter:checkItem(itemId, dataArray)
  -- returns zoneId if itemId finds a match in the array otherwise null
  --itemId, zoneId, qty-1, label
  for id, info in pairs(dataArray) do
    if tonumber(itemId) == tonumber(info.itemId) then
      --if qty is a number and matched by item quantity then mark as labeled  
      if GetItemCount(itemId, true) == tonumber(info.qty) then return true, kPfx .. info.label .. kSfx, PRIORITY_ITEM end

      local isCurrent, zoneGroup = setFilter:isCurrentZone(info.zoneId) 
      if isCurrent and self.db.profile.zonePriority then 
        return true, kPfx2 .. zoneGroup .. kSfx, CURRENT_ZONE_ITEM
      elseif isCurrentZone then 
        return true, kPfx2 .. zoneGroup .. kSfx, kCategory
      else
        return true, kPfx .. zoneGroup .. kSfx, kCategory
      end 
    end -- end itemId match
  end
  return false, false, false
end

function setFilter:isCurrentZone(zoneId)
  for id, info in pairs(data.arrZoneCodes) do 
    if tonumber(id) == tonumber(zoneId) then 
      for x = 1, #info.zGroupIds do
        if tonumber(info.zGroupIds[x]) == currZoneId then return true, info.zGroup end
      end -- end for x
      return false, info.zGroup 
    end
  end 
end

------------------------------------------------------------------------------
function setFilter:Filter(slotData)
  --Exit zoneItem addon if not enabled
  if not self.db.profile.enable then return end
  if currZoneId ~= C_Map.GetBestMapForUnit("player") or currZoneId == nil then  loadMapIDs() end
	bagItemID = slotData.itemId
  --funky but GetItemInfo doesn't return corruption info so call specifically for itemLink
  itemLink = GetContainerItemLink(slotData.bag, slotData.slot)
  local itemName,_, itemRarity, itemLevel,itemMinLevel, itemType, itemSubType,_,_, _, _, itemClassID, itemSubClassID, bindType, expacID, itemSetId = GetItemInfo(itemLink)
  if itemLevel == nil then itemLevel = 0 end

  -- Start checking groupings
  -- Heart of Azeroth Essences
  if self.db.profile.groupEssences and (itemClassID == 0 and itemSubClassID == 8 and itemRarity == 6 and expacID ==7) then
  -- fix this to put first if in HEART
    local isZone, zoneGroupName =setFilter:isCurrentZone(10)
    if isZone and self.db.profile.zonePriority then 
      return kPfx2 .. zoneGroupName.. kSfx, CURRENT_ZONE_ITEM
    else
      return kPfx .. zoneGroupName.. kSfx, kCategory
    end
  end
  --Corrupted gear 
  if self.db.profile.groupCorrupted and IsCorruptedItem(itemLink) == true then
    local isZone, zoneGroupName =setFilter:isCurrentZone(10)
    if isZone and self.db.profile.zonePriority then 
      return kPfx2 .. CORRUPTED_ITEM_LOOT_LABEL.. kSfx, CURRENT_ZONE_ITEM2
    else
      return kPfx .. CORRUPTED_ITEM_LOOT_LABEL.. kSfx, kCategory
    end
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
--[[
  -- PLACEHOLDER CODE FOR LOW ILEVEL/CURRENT EXPANSION GEAR FILTER
    if self.db.profile.groupLowGear and (itemClassID == LE_ITEM_CLASS_WEAPON or itemClassID == LE_ITEM_CLASS_ARMOR) then
    local avgItemLevel, avgItemLevelEquipped, avgItemLevelPvp = GetAverageItemLevel()
    -- exception for items in item sets
     for _, equipmentSetID in pairs(GetEquipmentSetIDs()) do
      GetEquipmentSetInfo(equipmentSetID)
      local itemIDs = GetItemIDs(equipmentSetID)b
      local locations = GetItemLocations(equipmentSetID)
      if itemIDs and locations then
        for invId, location in pairs(locations) do
          if location ~= 0 and location ~= 1 and itemIDs[invId] ~= 0 then
            local player, bank, bags, voidstorage, slot, container  = EquipmentManager_UnpackLocation(location)
            local slotId
            if bags and slot and container then
              slotId = GetSlotId(container, slot)
            elseif bank and slot then
              slotId = GetSlotId(BANK_CONTAINER, slot - BANK_CONTAINER_INVENTORY_OFFSET)
            elseif not (player or voidstorage) or not slot then
              missing = true
            end
            if slotId and not self.slots[slotId] then
              self.slots[slotId] = name 

    if itemLevel >= kMinExpansionIlevel and itemLevel <= (avgItemLevel-kLowGearThreshold) then return kPfx .. L['BfA Gear, Low iLevel'] .. kSfx, itemType end
  end
  ---]]
  -- BfA Azerite Gear
  if self.db.profile.groupAzerite and C_AzeriteEmpoweredItem.IsAzeriteEmpoweredItemByID(itemLink) == true then
    return 'Azerite '.. GetItemClassInfo(LE_ITEM_CLASS_ARMOR) , kCategory
  end
  

   -- BoA Gear Tokens, non-obsolete, check last
  --if self.db.profile.groupBoATokens == true and itemLevel >= kCurrBoAMin and (itemClassID == LE_ITEM_CLASS_ARMOR or itemSubClassID == LE_ITEM_CLASS_WEAPON) then
    if self.db.profile.groupBoATokens == true and itemLevel >= kCurrBoAMin then
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

