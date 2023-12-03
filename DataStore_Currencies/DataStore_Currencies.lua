--[[	*** DataStore_Currencies ***
Written by : Thaoky, EU-Marécages de Zangar
July 6th, 2009
--]]
if not DataStore then return end

local addonName = "DataStore_Currencies"

_G[addonName] = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")

local addon = _G[addonName]

local enum = DataStore.Enum.CurrencyIDs

-- TODO: Deprecated, enums are used with GetCurrencyTotals, also deprecate the specific methods below
local CURRENCY_ID_JUSTICE = 395
local CURRENCY_ID_VALOR = 1191
local CURRENCY_ID_APEXIS = 823
local CURRENCY_ID_GARRISON = 824
local CURRENCY_ID_SOTF = 994		-- Seals of Tempered Fate (WoD)
local CURRENCY_ID_ORDER_HALL = 1220
local CURRENCY_ID_SOBF = 1273		-- Seals of the Broken Fate (Legion)



local AddonDB_Defaults = {
	global = {
		Reference = {
			Currencies = {},			-- ex: [1] = "Dungeon and Raid", [2] = "Justice Points", ...
			CurrencyTextRev = {},	-- reverse lookup

			Headers = {},			-- ex: [1] = "Dungeon and Raid", [2] = "Miscellaneous", ...
			HeadersRev = {},		-- reverse lookup of Headers
		},
		Characters = {
			['*'] = {				-- ["Account.Realm.Name"] 
				lastUpdate = nil,
				Currencies = {},
				CurrencyInfo = {},
				Archeology = {},
			}
		}
	}
}

-- *** Utility functions ***
local bAnd = bit.band

local function LeftShift(value, numBits)
	return value * (2 ^ numBits)
end

local function RightShift(value, numBits)
	-- for bits beyond bit 31
	return math.floor(value / 2^numBits)
end

local headersState
local headerCount

local function SaveHeaders_Common()
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

local function RestoreHeaders_Common()
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

local function SaveHeaders_Wrath()
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

local function RestoreHeaders_Wrath()
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
	local ref = addon.db.global.Reference

	-- if this header is not yet referenced ..
	if not ref.HeadersRev[name] then
	
		table.insert(ref.Headers, name)			-- ex: [1] = "Shadowlands"
		ref.HeadersRev[name] = #ref.Headers		-- ["Shadowlands"] = 1
	end
	
	return ref.HeadersRev[name]			-- return this header's index
end

local function RegisterCurrency(name, iconFileID)
	local ref = addon.db.global.Reference
	
	-- if this currency is not yet referenced ..
	if not ref.CurrencyTextRev[name] then
	
		table.insert(ref.Currencies, format("%s|%s", name, iconFileID or ""))	-- ex; [28] = "Nethershard|132775"
		ref.CurrencyTextRev[name] = #ref.Currencies										-- ["Nethershard"] = 28
	end
	
	return ref.CurrencyTextRev[name]		-- return this currency's index
end

local function SaveCurrency(character, categoryIndex, currencyIndex, count)
	-- 07/01/2021 : Changed bit layout to better fit future additions
	
	-- bit  0-6 : parent category index, 7 bits = 128 values, should be safe for a while ..
	local attrib = categoryIndex
		
	-- bits 7-16 : currency index, 10 bits = 1024 values, should leave room for some time too ..
	attrib = attrib + LeftShift(currencyIndex, 7)
	
	-- bits 17- : Item count
	attrib = attrib + LeftShift(count, 17)

	table.insert(character.Currencies, attrib)
end


-- *** Scanning functions ***
local function ScanCurrencyTotals(id, divWeekly, divTotal)
	local denomWeekly = divWeekly or 1
	local denomTotal = divTotal or 1
	
	local info = C_CurrencyInfo.GetCurrencyInfo(id)
	
	addon.ThisCharacter.CurrencyInfo[id] = format("%s-%s-%s-%s", 
		info.quantity or 0, 
		info.quantityEarnedThisWeek or 0, 
		math.floor(info.maxWeeklyQuantity / denomWeekly) or 0, 
		math.floor(info.maxQuantity / denomTotal) or 0)
end

local function ScanCurrencies_Common()
	SaveHeaders_Common()
	
	local char = addon.ThisCharacter
	wipe(char.Currencies)
	
	local categoryIndex = 0
	local currencyIndex = 0
	
	for i = 1, C_CurrencyInfo.GetCurrencyListSize() do
		local info = C_CurrencyInfo.GetCurrencyListInfo(i)
		
		if info.isHeader then
			categoryIndex = RegisterHeader(info.name)
		else
			currencyIndex = RegisterCurrency(info.name, info.iconFileID)
			SaveCurrency(char, categoryIndex, currencyIndex, info.quantity)
			
			-- If the currency has a link, we can scan its totals
			local link = C_CurrencyInfo.GetCurrencyListLink(i)
			if link then
				ScanCurrencyTotals(C_CurrencyInfo.GetCurrencyIDFromLink(link))
			end
		end
	end
	
	RestoreHeaders_Common()
	
	char.lastUpdate = time()
end

local function ScanCurrencies_Wrath()
	SaveHeaders_Wrath()
	
	local currencies = addon.ThisCharacter.Currencies
	wipe(currencies)
	
	for i = 1, GetCurrencyListSize() do
		local name, isHeader, _, _, _, count, _, _, _, _, _, itemID = GetCurrencyListInfo(i)

		name = name or ""
		if isHeader then
			currencies[i] = "0|" .. name
		else
			currencies[i] = "1|" .. name .. "|" .. (count or 0) .. "|" .. (itemID or 0)
		end
	end
	
	RestoreHeaders_Wrath()
	
	addon.ThisCharacter.lastUpdate = time()
end

local ScanCurrencies = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) and ScanCurrencies_Common or ScanCurrencies_Wrath

local function ScanReservoirCurrencies()
	local char = addon.ThisCharacter
	
	-- ** 9.0 Anima Currency **
	local currencyID = C_CovenantSanctumUI.GetAnimaInfo()
	local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)

	local categoryIndex = RegisterHeader(EXPANSION_NAME8)		-- Get the category index for "Shadowlands"
	local currencyIndex = RegisterCurrency(info.name, info.iconFileID)
	SaveCurrency(char, categoryIndex, currencyIndex, info.quantity)
	
	-- ** 9.0 Redeemed Soul Currency **
	for _, currencyID in ipairs(C_CovenantSanctumUI.GetSoulCurrencies()) do
    	info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
		currencyIndex = RegisterCurrency(info.name, info.iconFileID)
		SaveCurrency(char, categoryIndex, currencyIndex, info.quantity)
		ScanCurrencyTotals(currencyID)
	end	
end

local function ScanArcheology()
	local currencies = addon.ThisCharacter.Archeology
	wipe(currencies)
	
	for i = 1, GetNumArchaeologyRaces() do
		-- Warning for extreme caution here: while testing MoP, the following line of code triggered an error while trying to activate a glyph.
		-- _, _, _, currencies[i] = GetArchaeologyRaceInfo(i)
		-- The work around is to simply unroll the code on two lines.. I'll have to investigate why
		-- At first sight, the problem seems to come from addressing the table element direcly, same has happened in DataStore_Stats.
		
		local _, _, _, n = GetArchaeologyRaceInfo(i)
		currencies[i] = n
	end

end

-- *** Event Handlers ***
local function OnPlayerAlive()
	ScanCurrencies()
end

local function OnCurrencyDisplayUpdate()
	ScanCurrencies()
	
	if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
		ScanArcheology()
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
	return DataStore:SortedArrayClone(addon.db.global.Reference.Headers)
end

local function _GetNumCurrencies(character)
	return #character.Currencies
end

local function _GetCurrencyInfo(character, index)
	local ref = addon.db.global.Reference
	local currency = character.Currencies[index]
	
	local catIndex = bAnd(currency, 127)
	local refIndex = bAnd(RightShift(currency, 7), 1023)
	local count = RightShift(currency, 17)

	local info = ref.Currencies[refIndex]
	local name, icon = strsplit("|", info or "")
	local category = ref.Headers[catIndex]
	
	return name, count, icon, category
end

local function _GetCurrencyInfo_Wrath(character, index)
	local currency = character.Currencies[index]
	local isHeader, name, count, itemID = strsplit("|", currency)
	
	isHeader = (isHeader == "0" and true or nil)
	
	return isHeader, name, tonumber(count), tonumber(itemID)
end

local function _GetCurrencyInfoByName(character, token)
	local ref = addon.db.global.Reference
	
	for i = 1, #character.Currencies do
		local name, count, icon, category = _GetCurrencyInfo(character, i)
	
		if name == token then
			return name, count, icon, category
		end
	end
end

local function _GetCurrencyInfoByName_Wrath(character, token)
	local name, count, itemID
	
	for i = 1, #character.Currencies do
		_, name, count, itemID = strsplit("|", character.Currencies[i])

		if name == token then	-- if it's the token we're looking for, return
			return tonumber(count), tonumber(itemID)
		end
	end
end

local function _GetCurrencyItemCount(character, searchedID)
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

local function _GetCurrencyItemCount_Wrath(character, searchedID)
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

local function _GetArcheologyCurrencyInfo(character, index)
	return character.Archeology[index] or 0
end

local function _GetCurrencyTotals(character, id)
	local info = character.CurrencyInfo[id]
	if not info then
		return 0, 0, 0, 0
	end
	
	local amount, earnedThisWeek, weeklyMax, totalMax = strsplit("-", info)
	return tonumber(amount), tonumber(earnedThisWeek), tonumber(weeklyMax), tonumber(totalMax)
end

local function _GetJusticePoints(character)
	return _GetCurrencyTotals(character, CURRENCY_ID_JUSTICE)
end

local function _GetValorPoints(character)
	return _GetCurrencyTotals(character, CURRENCY_ID_VALOR)
end

local function _GetValorPointsPerWeek(character)
	local info = character.CurrencyInfo[CURRENCY_ID_VALOR]
	if not info then
		return 0
	end
	
	local _, earnedThisWeek = strsplit("-", info)
	return tonumber(earnedThisWeek)
end

local function _GetGarrisonResources(character)
	return _GetCurrencyTotals(character, CURRENCY_ID_GARRISON)
end

local function _GetApexisCrystals(character)
	return _GetCurrencyTotals(character, CURRENCY_ID_APEXIS)
end

local function _GetSealsOfFate(character)
	return _GetCurrencyTotals(character, CURRENCY_ID_SOTF)
end

local function _GetSealsOfBrokenFate(character)
	return _GetCurrencyTotals(character, CURRENCY_ID_SOBF)
end

local function _GetOrderHallResources(character)
	return _GetCurrencyTotals(character, CURRENCY_ID_ORDER_HALL)
end

local function _GetNethershards(character)
	return _GetCurrencyTotals(character, enum.Nethershard)
end

local function _GetWarSupplies(character)
	return _GetCurrencyTotals(character, enum.LegionfallWarSupplies)
end

local function _GetBfAWarResources(character)
	return _GetCurrencyTotals(character, enum.WarResources)
end

local function _GetBfASealsOfWartornFate(character)
	return _GetCurrencyTotals(character, enum.SealsOfWartornFate)
end

local function _GetBfADubloons(character)
	return _GetCurrencyTotals(character, enum.SeafarersDubloon)
end

local function _GetBfAWarSupplies(character)
	return _GetCurrencyTotals(character, enum.BfAWarSupplies)
end

local function _GetBfARichAzerite(character)
	return _GetCurrencyTotals(character, enum.RichAzeriteFragment)
end

local function _GetBfACoalescingVisions(character)
	return _GetCurrencyTotals(character, enum.CoalescingVisions)
end

local function _GetBfATitanResiduum(character)
	return _GetCurrencyTotals(character, enum.TitanResiduum)
end

local function _GetRedeemedSouls(character)
	return _GetCurrencyTotals(character, enum.RedeemedSoul)
end

local function _GetReservoirAnima(character)
	return _GetCurrencyTotals(character, enum.ReservoirAnima)
end


local PublicMethods = {
	GetCurrencyHeaders = _GetCurrencyHeaders,
	GetNumCurrencies = _GetNumCurrencies,
	GetCurrencyInfo = _GetCurrencyInfo,
	GetCurrencyInfoByName = _GetCurrencyInfoByName,
	GetCurrencyItemCount = _GetCurrencyItemCount,
	GetArcheologyCurrencyInfo = _GetArcheologyCurrencyInfo,
	GetCurrencyTotals = _GetCurrencyTotals,
	GetJusticePoints = _GetJusticePoints,
	GetValorPoints = _GetValorPoints,
	GetValorPointsPerWeek = _GetValorPointsPerWeek,
	GetApexisCrystals = _GetApexisCrystals,
	GetGarrisonResources = _GetGarrisonResources,
	GetSealsOfFate = _GetSealsOfFate,
	GetSealsOfBrokenFate = _GetSealsOfBrokenFate,
	GetOrderHallResources = _GetOrderHallResources,
	GetNethershards = _GetNethershards,
	GetWarSupplies = _GetWarSupplies,
	GetBfAWarResources = _GetBfAWarResources,
	GetBfASealsOfWartornFate = _GetBfASealsOfWartornFate,
	GetBfADubloons = _GetBfADubloons,
	GetBfAWarSupplies = _GetBfAWarSupplies,
	GetBfARichAzerite = _GetBfARichAzerite,
	GetBfACoalescingVisions = _GetBfACoalescingVisions,
	GetBfATitanResiduum = _GetBfATitanResiduum,
	GetRedeemedSouls = _GetRedeemedSouls,
	GetReservoirAnima = _GetReservoirAnima,
}

if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then
	-- if we're not in retail, overwrite the whole table
	PublicMethods = {
		GetNumCurrencies = _GetNumCurrencies,
		GetCurrencyInfo = _GetCurrencyInfo_Wrath,
		GetCurrencyInfoByName = _GetCurrencyInfoByName_Wrath,
		GetCurrencyItemCount = _GetCurrencyItemCount_Wrath,
	}
end

function addon:OnInitialize()
	addon.db = LibStub("AceDB-3.0"):New(addonName .. "DB", AddonDB_Defaults)

	DataStore:RegisterModule(addonName, addon, PublicMethods)
	
	DataStore:SetCharacterBasedMethod("GetNumCurrencies")
	DataStore:SetCharacterBasedMethod("GetCurrencyInfo")
	DataStore:SetCharacterBasedMethod("GetCurrencyInfoByName")
	DataStore:SetCharacterBasedMethod("GetCurrencyItemCount")
	
	-- Stop here for non-retail
	if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then return end
	
	DataStore:SetCharacterBasedMethod("GetArcheologyCurrencyInfo")
	DataStore:SetCharacterBasedMethod("GetCurrencyTotals")
	DataStore:SetCharacterBasedMethod("GetJusticePoints")
	DataStore:SetCharacterBasedMethod("GetValorPoints")
	DataStore:SetCharacterBasedMethod("GetValorPointsPerWeek")
	DataStore:SetCharacterBasedMethod("GetApexisCrystals")
	DataStore:SetCharacterBasedMethod("GetGarrisonResources")
	DataStore:SetCharacterBasedMethod("GetSealsOfFate")
	DataStore:SetCharacterBasedMethod("GetSealsOfBrokenFate")
	DataStore:SetCharacterBasedMethod("GetOrderHallResources")
	DataStore:SetCharacterBasedMethod("GetNethershards")
	DataStore:SetCharacterBasedMethod("GetWarSupplies")
	DataStore:SetCharacterBasedMethod("GetBfAWarResources")
	DataStore:SetCharacterBasedMethod("GetBfASealsOfWartornFate")
	DataStore:SetCharacterBasedMethod("GetBfADubloons")
	DataStore:SetCharacterBasedMethod("GetBfAWarSupplies")
	DataStore:SetCharacterBasedMethod("GetBfARichAzerite")
	DataStore:SetCharacterBasedMethod("GetBfACoalescingVisions")
	DataStore:SetCharacterBasedMethod("GetBfATitanResiduum")
	DataStore:SetCharacterBasedMethod("GetRedeemedSouls")
	DataStore:SetCharacterBasedMethod("GetReservoirAnima")
end

function addon:OnEnable()
	addon:RegisterEvent("PLAYER_ALIVE", OnPlayerAlive)
	addon:RegisterEvent("CURRENCY_DISPLAY_UPDATE", OnCurrencyDisplayUpdate)
	
	-- Stop here for non-retail
	if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then return end
	
	addon:RegisterEvent("CHAT_MSG_SYSTEM", OnChatMsgSystem)
	addon:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", OnCovenantSanctumInteractionStarted)
	
	local _, _, arch = GetProfessions()

	if arch and RequestArtifactCompletionHistory then
		--	ARTIFACT_HISTORY_READY deprecated in 8.0
		-- addon:RegisterEvent("ARTIFACT_HISTORY_READY", OnArtifactHistoryReady)
		RequestArtifactCompletionHistory()		-- this will trigger ARTIFACT_HISTORY_READY
	end
end

function addon:OnDisable()
	addon:UnregisterEvent("PLAYER_ALIVE")
	addon:UnregisterEvent("CURRENCY_DISPLAY_UPDATE")
	
	-- Stop here for non-retail
	if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then return end
	
	addon:UnregisterEvent("CHAT_MSG_SYSTEM")
	addon:UnregisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
end
