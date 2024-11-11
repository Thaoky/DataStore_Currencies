--[[	*** DataStore_Currencies ***
Written by : Thaoky, EU-Marécages de Zangar
July 6th, 2009
--]]
if not DataStore then return end

local addonName, addon = ...
local thisCharacter
local thisCharacterArcheology
local currenciesCatalog
local currenciesHeaders
local currenciesInfo
local currenciesMax

local DataStore = DataStore
local TableInsert, strsplit, tonumber, ipairs, C_CurrencyInfo = table.insert, strsplit, tonumber, ipairs, C_CurrencyInfo
local GetCurrencyListSize, GetCurrencyListInfo, ExpandCurrencyList, GetNumArchaeologyRaces, GetArchaeologyRaceInfo = GetCurrencyListSize, GetCurrencyListInfo, ExpandCurrencyList, GetNumArchaeologyRaces, GetArchaeologyRaceInfo
local isRetail = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)

local enum = DataStore.Enum.CurrencyIDs
local bit64 = LibStub("LibBit64")

local accountWideCurrencies = {}

local headersState
local headerCount

local function SaveHeaders_Retail()
	headersState = {}
	headerCount = 0		-- use a counter to avoid being bound to header names, which might not be unique.
	
	for i = C_CurrencyInfo.GetCurrencyListSize(), 1, -1 do		-- 1st pass, expand all categories
		local info = C_CurrencyInfo.GetCurrencyListInfo(i)
		if info.isHeader then
			headerCount = headerCount + 1
			if not info.isHeaderExpanded then
				C_CurrencyInfo.ExpandCurrencyList(i, 1)
				headersState[headerCount] = true
			end
		end
	end
end

local function RestoreHeaders_Retail()
	headerCount = 0
	for i = C_CurrencyInfo.GetCurrencyListSize(), 1, -1 do
		local info = C_CurrencyInfo.GetCurrencyListInfo(i)
		
		if info.isHeader then
			headerCount = headerCount + 1
			if headersState[headerCount] then
				C_CurrencyInfo.ExpandCurrencyList(i, 0)		-- collapses the header
			end
		end
	end
	headersState = nil
end

local function SaveHeaders_NonRetail()
	headersState = {}
	headerCount = 0		-- use a counter to avoid being bound to header names, which might not be unique.
	
	for i = GetCurrencyListSize(), 1, -1 do		-- 1st pass, expand all categories
		local _, isHeader, isExpanded = GetCurrencyListInfo(i)
		if isHeader then
			headerCount = headerCount + 1
			if not isExpanded then
				ExpandCurrencyList(i, 1)
				headersState[headerCount] = true
			end
		end
	end
end

local function RestoreHeaders_NonRetail()
	headerCount = 0
	for i = GetCurrencyListSize(), 1, -1 do
		local _, isHeader = GetCurrencyListInfo(i)
		if isHeader then
			headerCount = headerCount + 1
			if headersState[headerCount] then
				ExpandCurrencyList(i, 0)		-- collapses the header
			end
		end
	end
	headersState = nil
end

local function RegisterHeader(name)
	return DataStore:StoreToSetAndList(currenciesHeaders, name)
end

local function RegisterCurrency(name, id)
	-- ["Nethershard"] = 28
	local currencyIndex = DataStore:StoreToSetAndList(currenciesCatalog, name)
	
	-- [28] = 132775
	-- iconFileID in retail, itemID in non-retail
	currenciesInfo[currencyIndex] = id 
	
	return currencyIndex
end

local function SaveCurrency(categoryIndex, currencyIndex, count)
	local attrib = categoryIndex					-- bit  0-7 : parent category index, 8 bits = 256 values
		+ bit64:LeftShift(currencyIndex, 8)		-- bits 8-17 : currency index, 10 bits = 1024 values
		+ bit64:LeftShift(count, 18)				-- bits 18+ : Item count
	
	TableInsert(thisCharacter.Currencies, attrib)
end


-- *** Scanning functions ***
local function ScanCurrencyTotals(id)
	local info = C_CurrencyInfo.GetCurrencyInfo(id)
	if not info then return end
	
	local char = thisCharacter
	char.Totals = char.Totals or {}
	
	char.Totals[id] = info.quantity								-- bits 0-19 = quantity
		+ bit64:LeftShift(info.quantityEarnedThisWeek, 20)	-- bits 20+ = quantity earned this week
	
	currenciesMax[id] = info.maxQuantity						-- bits 0-19 = max quantity
		+ bit64:LeftShift(info.maxWeeklyQuantity, 20)		-- bits 20+ = max quantity per week
end

local professionTrackers = {
	[3057] = true,		-- 11.0 Profession Tracker - Alchemy
	[3058] = true,		-- 11.0 Profession Tracker - Blacksmithing
	[3059] = true,		-- 11.0 Profession Tracker - Enchanting
	[3060] = true,		-- 11.0 Profession Tracker - Engineering
	[3061] = true,		-- 11.0 Profession Tracker - Herbalism
	[3062] = true,		-- 11.0 Profession Tracker - Inscription
	[3063] = true,		-- 11.0 Profession Tracker - Jewelcrafting
	[3064] = true,		-- 11.0 Profession Tracker - Leatherworking
	[3065] = true,		-- 11.0 Profession Tracker - Mining
	[3066] = true,		-- 11.0 Profession Tracker - Skinning
	[3067] = true,		-- 11.0 Profession Tracker - Tailoring
}

local hiddenCurrencies = {
	[2785] = 3057,		-- Khaz Algar Alchemy Knowledge
	[2786] = 3058,		-- Khaz Algar Blacksmithing Knowledge
	[2787] = 3059,		-- Khaz Algar Enchanting Knowledge
	[2788] = 3060,		-- Khaz Algar Engineering Knowledge
	[2789] = 3061,		-- Khaz Algar Herbalism Knowledge
	[2790] = 3062,		-- Khaz Algar Inscription Knowledge
	[2791] = 3063,		-- Khaz Algar Jewelcrafting Knowledge
	[2792] = 3064,		-- Khaz Algar Leatherworking Knowledge
	[2793] = 3065,		-- Khaz Algar Mining Knowledge
	[2794] = 3066,		-- Khaz Algar Skinning Knowledge
	[2795] = 3067,		-- Khaz Algar Tailoring Knowledge
}

local function ScanHiddenCurrency(currencyID)
	local trackerCurrencyID = hiddenCurrencies[currencyID]
	-- exit if currency is unkown
	if not trackerCurrencyID then return end
	
	local info = C_CurrencyInfo.GetCurrencyInfo(trackerCurrencyID)
	if not info then return end
	
	local categoryIndex = RegisterHeader("Hidden")
	local currencyIndex = RegisterCurrency(info.name, info.iconFileID)
	
	SaveCurrency(categoryIndex, currencyIndex, info.quantity)
	ScanCurrencyTotals(trackerCurrencyID)
end

local function ScanCurrencies_Retail()
	SaveHeaders_Retail()
	
	local char = thisCharacter
	wipe(char.Currencies)
	if char.Totals then wipe(char.Totals) end
	
	local categoryIndex = 0
	
	for i = 1, C_CurrencyInfo.GetCurrencyListSize() do
		local info = C_CurrencyInfo.GetCurrencyListInfo(i)
		
		if info.isHeader then
			categoryIndex = RegisterHeader(info.name)
		else
			local currencyIndex = RegisterCurrency(info.name, info.iconFileID)
			SaveCurrency(categoryIndex, currencyIndex, info.quantity)
			
			-- If the currency has a link, we can scan its totals
			local link = C_CurrencyInfo.GetCurrencyListLink(i)
			if link then
				ScanCurrencyTotals(C_CurrencyInfo.GetCurrencyIDFromLink(link))
			end
		end
	end
	
	RestoreHeaders_Retail()
	
	char.lastUpdate = time()
end

local function ScanCurrencies_NonRetail()
	SaveHeaders_NonRetail()
	
	local char = thisCharacter
	local currencies = char.Currencies
	wipe(currencies)
	
	local categoryIndex = 0
	
	for i = 1, GetCurrencyListSize() do
		local name, isHeader, _, _, _, count, _, _, _, _, _, itemID = GetCurrencyListInfo(i)

		name = name or ""
		if isHeader then
			-- currencies[i] = format("0|%s", name)
			categoryIndex = RegisterHeader(name)
		else
			-- currencies[i] = format("1|%s|%d|%d", name, count or 0, itemID or 0)
			
			local currencyIndex = RegisterCurrency(name, itemID or 0)
			SaveCurrency(categoryIndex, currencyIndex, count or 0)
		end
	end
	
	RestoreHeaders_NonRetail()
	
	char.lastUpdate = time()
end

local ScanCurrencies = isRetail and ScanCurrencies_Retail or ScanCurrencies_NonRetail

local function ScanReservoirCurrencies()
	-- ** 9.0 Anima Currency **
	local currencyID = C_CovenantSanctumUI.GetAnimaInfo()
	local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)

	local categoryIndex = RegisterHeader(EXPANSION_NAME8)		-- Get the category index for "Shadowlands"
	local currencyIndex = RegisterCurrency(info.name, info.iconFileID)
	
	SaveCurrency(categoryIndex, currencyIndex, info.quantity)
	
	-- ** 9.0 Redeemed Soul Currency **
	for _, currencyID in ipairs(C_CovenantSanctumUI.GetSoulCurrencies()) do
    	info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
		currencyIndex = RegisterCurrency(info.name, info.iconFileID)
		SaveCurrency(categoryIndex, currencyIndex, info.quantity)
		ScanCurrencyTotals(currencyID)
	end	
end

local function ScanArcheology()
	thisCharacterArcheology = thisCharacterArcheology or {}
	local currencies = thisCharacterArcheology
	
	for i = 1, GetNumArchaeologyRaces() do
		-- Warning for extreme caution here: while testing MoP, the following line of code triggered an error while trying to activate a glyph.
		-- _, _, _, currencies[i] = GetArchaeologyRaceInfo(i)
		-- The work around is to simply unroll the code on two lines.. I'll have to investigate why
		-- At first sight, the problem seems to come from addressing the table element direcly, same has happened in DataStore_Stats.
		
		local _, _, _, n = GetArchaeologyRaceInfo(i)
		currencies[i] = n > 0 and n or nil
	end
end

-- *** Event Handlers ***
local function OnPlayerAlive()
	ScanCurrencies()
end

local function OnCurrencyDisplayUpdate(event, currencyID)
	if isRetail then ScanHiddenCurrency(currencyID) end

	ScanCurrencies()
	
	if isRetail then
		ScanArcheology()
	end
end


local sourceGUID

local function OnCurrencyTransferLogUpdate()
	-- Don't even bother if the PreClick did not provide a proper GUID
	if not sourceGUID then return end

	-- When the transfer log is updated, only update the count of the sender.
	-- The receiver is the current character, and is already handled above.
	-- Problem : the transaction log's most recent entry does not contain the source character GUID, hence the HookScript on the confirm button.
	-- Tested with characters on the same realm, connected realm, different realm, different subscription on the same account, all are invalid.
	local transferLog = C_CurrencyInfo.FetchCurrencyTransferTransactions()
	if not transferLog then return end
	
	-- The latest transaction is not guaranteed to always be in position 1 (tests have proven it)
	-- so find the highest timestamp
	local lastOp = transferLog[1]
	local maxTimestamp = lastOp.timestamp
	
	for k, v in pairs(transferLog) do
		if v.timestamp > maxTimestamp then
			lastOp = transferLog[k]
			maxTimestamp = lastOp.timestamp
			-- the tests further prove that this loop finds the proper latest transaction, but while the names are ok, the GUIDs are nil.. thanks bliz .. again.
			-- print(k .. " q: " .. lastOp.quantityTransferred)
			-- print(k .. " gs: " .. (lastOp.sourceCharacterGUID or "nil"))			
			-- print(k .. " gd: " .. (lastOp.destinationCharacterGUID or "nil"))
		end
	end
	
	if not lastOp then return end
	
	local index = DataStore:GetCharacterIDByGUID(sourceGUID)
	if not index then return end

	local info = C_CurrencyInfo.GetBasicCurrencyInfo(lastOp.currencyType)
	local transferredCurrencyName = info.name

	local senderDB = DataStore_Currencies_Characters[index]
	if senderDB and senderDB.Currencies and transferredCurrencyName then
		
		-- Loop on all currencies
		for k, currency in pairs(senderDB.Currencies) do
			local currencyIndex = bit64:GetBits(currency, 8, 10)			-- bits 8-17 : currency index, 10 bits = 1024 values
			local name = currenciesCatalog.List[currencyIndex]

			-- When the matching currency is found, update its count
			if name == transferredCurrencyName then
				-- Get the old count
				local count = bit64:RightShift(currency, 18)					-- bits 18+ : Item count
				local newCount = count - lastOp.totalQuantityConsumed
				local categoryIndex = bit64:GetBits(currency, 0, 8)		-- bit  0-7 : parent category index, 8 bits = 256 values
			
				-- Then update it with the new data.
				senderDB.Currencies[k] = categoryIndex							-- bit  0-7 : parent category index, 8 bits = 256 values
					+ bit64:LeftShift(currencyIndex, 8)							-- bits 8-17 : currency index, 10 bits = 1024 values
					+ bit64:LeftShift(newCount, 18)								-- bits 18+ : Item count				
				
				sourceGUID = nil
				
				return
			end
		end
	end
end

local function OnChatMsgSystem(event, arg)
	if arg and arg == ITEM_REFUND_MSG then
		ScanCurrencies()
		ScanArcheology()
	end
end

local function OnArtifactHistoryReady()
	ScanArcheology()
end

local function OnCovenantSanctumInteractionStarted(event, interactionType)

	if interactionType == Enum.PlayerInteractionType.CovenantSanctum then
		ScanReservoirCurrencies()
	end
end

-- ** Mixins **
local function _GetCurrencyHeaders()
	-- return all referenced headers, but in a sorted array
	return DataStore:SortedArrayClone(currenciesHeaders.List)
end

local function _GetNumCurrencies(character)
	return #character.Currencies
end

local function _GetCurrencyInfo(character, index)
	local currency = character.Currencies[index]
	
	local categoryIndex = bit64:GetBits(currency, 0, 8)		-- bit  0-7 : parent category index, 8 bits = 256 values
	local currencyIndex = bit64:GetBits(currency, 8, 10)		-- bits 8-17 : currency index, 10 bits = 1024 values
	local count = bit64:RightShift(currency, 18)			-- bits 18+ : Item count
	
	return currenciesCatalog.List[currencyIndex],	-- name
		count,
		currenciesInfo[currencyIndex],					-- iconID / itemID
		currenciesHeaders.List[categoryIndex]			-- category
end

-- normally not necessary anymore, needs testing
-- local function _GetCurrencyInfo_NonRetail(character, index)
	-- local currency = character.Currencies[index]
	-- local isHeader, name, count, itemID = strsplit("|", currency)
	
	-- isHeader = (isHeader == "0" and true or nil)
	
	-- return isHeader, name, tonumber(count), tonumber(itemID)
-- end

local function _GetCurrencyInfoByName(character, token)

	for i = 1, #character.Currencies do
		local name, count, info, category = _GetCurrencyInfo(character, i)
	
		if name == token then
			return name, count, info, category
		end
	end
end

-- normally not necessary anymore, needs testing
-- local function _GetCurrencyInfoByName_NonRetail(character, token)
	-- local name, count, itemID
	
	-- for i = 1, #character.Currencies do
		-- _, name, count, itemID = strsplit("|", character.Currencies[i])

		-- if name == token then	-- if it's the token we're looking for, return
			-- return tonumber(count), tonumber(itemID)
		-- end
	-- end
-- end

local function _GetCurrencyItemCount_Retail(character, searchedID)
	local _, count = _GetCurrencyInfo(character, searchedID)
	
	return count
end

local currencyIDs = {
	-- source : http://www.wowhead.com/?items=10
	
	-- epic
	[29434] = true,		-- badge of justice
	[45624] = true,		-- emblem of conquest
	[40752] = true,		-- emblem of heroism
	[47241] = true,		-- emblem of triumph
	[40753] = true,		-- emblem of valor
	[49426] = true,		-- emblem of frost (3.3)
	
	-- blue
	[43228] = true,		-- stone keeper's shard
	
	-- green
	[20560] = true,		-- alterac mark of honor
	[20559] = true,		-- arathi basin mark of honor
	[43016] = true,		-- dalaran cooking award
	[41596] = true,		-- dalaran jewelcrafting token
	[29024] = true,		-- eots mark of honor
	[47395] = true,		-- isle of conquest mark of honor
	[42425] = true,		-- strand of the ancients mark of honor
	[20558] = true,		-- warsong gulch mark of honor
	[43589] = true,		-- wintergrasp mark of honor
	
	-- white
	[43307] = true,		-- arena points
	[44990] = true,		-- champion's seal
	[43308] = true,		-- honor points
	[37836] = true,		-- venture coin
}

local function _GetCurrencyItemCount_NonRetail(character, searchedID)
	if currencyIDs[searchedID] then
		local isHeader, currencyCount, itemID
		
		for i = 1, #character.Currencies do
			isHeader, _, currencyCount, itemID = strsplit("|", character.Currencies[i])
		
			if isHeader == "1" then
				if tonumber(itemID) == searchedID then
					return tonumber(currencyCount)
				end
			end
		end
	end
	
	return 0
end

local function _GetCurrencyTotals(character, id)
	if character.Totals then
		local info = character.Totals[id]
		local maxInfo = currenciesMax[id]
		
		if info and maxInfo then
			return bit64:GetBits(info, 0, 20),		-- bits 0-19 = quantity
				bit64:RightShift(info, 20),			-- bits 20+ = quantity earned this week	
				bit64:GetBits(maxInfo, 0, 20),		-- bits 0-19 = max quantity
				bit64:RightShift(maxInfo, 20)			-- bits 20+ = max quantity per week
		end
	end
	
	return 0, 0, 0, 0
end

DataStore:OnAddonLoaded(addonName, function()
	DataStore:RegisterModule({
		addon = addon,
		addonName = addonName,
		rawTables = {
			"DataStore_Currencies_Catalog",		-- Set & List of currencies
			"DataStore_Currencies_Headers",		-- Set & List of category headers
			"DataStore_Currencies_Info",			-- [id] = iconFileID (retail) or = itemID (non-retail)
			"DataStore_Currencies_Max",			-- [id] = max quantity & max quantity per week
		},
		characterTables = {
			["DataStore_Currencies_Characters"] = {
				GetNumCurrencies = _GetNumCurrencies,
				GetCurrencyInfo = _GetCurrencyInfo,
				GetCurrencyInfoByName = _GetCurrencyInfoByName,
				GetCurrencyItemCount = isRetail and _GetCurrencyItemCount_Retail or _GetCurrencyItemCount_NonRetail,
				GetCurrencyTotals = isRetail and _GetCurrencyTotals,
			},
			["DataStore_Currencies_Archeology"] = {
				GetArcheologyCurrencyInfo = isRetail and function(character, index)
					return character[index] or 0
				end,
			},
		}
	})
	
	thisCharacter = DataStore:GetCharacterDB("DataStore_Currencies_Characters", true)
	thisCharacter.Currencies = thisCharacter.Currencies or {}
	
	thisCharacterArcheology = DataStore:GetCharacterDB("DataStore_Currencies_Archeology", true)
	
	currenciesCatalog = DataStore:CreateSetAndList(DataStore_Currencies_Catalog)
	currenciesHeaders = DataStore:CreateSetAndList(DataStore_Currencies_Headers)
	
	currenciesInfo = DataStore_Currencies_Info
	currenciesMax = DataStore_Currencies_Max	
	
	-- Stop here for non-retail
	if not isRetail then return end
	
	DataStore:RegisterMethod(addon, "GetCurrencyHeaders", _GetCurrencyHeaders)
	DataStore:RegisterMethod(addon, "IsCurrencyAccountWide", function(currencyName) return accountWideCurrencies[currencyName] end)
end)

DataStore:OnPlayerLogin(function()
	addon:ListenTo("PLAYER_ALIVE", OnPlayerAlive)
	addon:ListenTo("CURRENCY_DISPLAY_UPDATE", OnCurrencyDisplayUpdate)
	
	-- Stop here for non-retail
	if not isRetail then return end
	
	addon:ListenTo("CHAT_MSG_SYSTEM", OnChatMsgSystem)
	addon:ListenTo("CURRENCY_TRANSFER_LOG_UPDATE", OnCurrencyTransferLogUpdate)
	addon:ListenTo("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", OnCovenantSanctumInteractionStarted)
	
	-- Get the names of account wide currencies
	local currencyIDs = {
		2032,			-- Trader's Tender
	}
	
	for _, currencyID in pairs(currencyIDs) do
		local currency = C_CurrencyInfo.GetCurrencyInfo(2032)
		if currency and currency.name then
			accountWideCurrencies[currency.name] = true
		end
	end
	
	-- Hook the Confirm button to get the sourceGUID BEFORE the transfer occurs.
	CurrencyTransferMenu.ConfirmButton:HookScript("PreClick", function(self) 
		local data = CurrencyTransferMenu:GetSourceCharacterData()
	
		if data then
			sourceGUID = data.characterGUID
		end
	end)	
	
end)
