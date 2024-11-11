if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then return end

--[[
Currencies-related enumerations
--]]
local enum = DataStore.Enum

enum.CurrencyIDs = {
		
	-- Miscellaneous
	JusticePoints = 395,
	TimewarpedBadge = 1166,
	DarkmoonPrize = 515,
	EpicureansAward = 81,
	IronpawToken = 402,

	-- Burning Crusade
	SpiritShard = 1704,
	
	-- Wrath of the Lich King
	ChampionsSeal = 241,
	
	-- Cataclysm
	IllustriousJewelcrafter = 361,
	MarkOfTheWorldTree = 416,
	MoteOfDarkness = 614,
	EssenceOfCorruptedDeathwing = 615,
	
	-- Mists of Pandaria
	BloodyCoin = 789,
	ElderCharm = 697,
	LesserCharm = 738,
	MoguRuneOfFate = 752,
	TimelessCoin = 777,
	WarforgedSeal = 776,
	
	-- Warlords of Draenor
	ApexisCrystal = 823,
	ArtifactFragment = 944,
	GarrisonResources = 824,
	SealOfInevitableFate = 1129,
	SealOfTemperedFate = 994,
	Oil = 1101,
	
	-- Legion
	OrderHall = 1220,
	LegionfallWarSupplies = 1342,
	Nethershard = 1226,
	SealOfBrokenFate = 1273,
	SightlessEye = 1149,
	AncientMana = 1155,
	VeiledArgunite = 1508,
	
	-- Battle for Azeroth
	WarResources = 1560,
	SealsOfWartornFate = 1580,
	SeafarersDubloon = 1710,
	BfAWarSupplies = 1587,
	RichAzeriteFragment = 1565,
	CoalescingVisions = 1755,
	TitanResiduum = 1718,
	
	-- Shadowlands 9.0
	Conquest = 1602,
	RedeemedSoul = 1810,
	ReservoirAnima = 1813,
	SoulAsh = 1828,
	Stygia = 1767,
	ValorPoints = 1191,
	
	-- Shadowlands 9.1
	CatalogedResearch = 1931,
	TowerKnowledge = 1904,
	StygianEmber = 1977,
	SoulCinders = 1906,
	
	-- Shadowlands 9.2
	CyphersOfTheFirstOnes = 1979,
	CosmicFlux = 2009,
	
	-- Dragonflight 10.0
	DragonIslesSupplies = 2003,
	ElementalOverflow = 2118,
	StormSigil = 2122,
	Honor = 1792,
	
	-- Dragonflight 10.1
	Flightstones = 2245,
	ParacausalFlakes = 2594,
	RidersofAzerothBadge = 2588,

	-- Dragonflight 10.2
	WhelplingsDreamingCrest = 2706,
	DrakesDreamingCrest = 2707,
	WyrmsDreamingCrest = 2708,
	AspectsDreamingCrest = 2709,
	EmeraldDewdrop = 2650,
	DreamInfusion = 2777,
	MysteriousFragment = 2657, -- This is the only currency so far, didn't want to place in a separate tab
	
	-- War Within 11.0
	Undercoin = 2803,
	ResonanceCrystals = 2815,
	WeatheredHarbingerCrest = 2914,
	CarvedHarbingerCrest = 2915,
	RunedHarbingerCrest = 2916,
	GildedHarbingerCrest = 2917,
	Valorstones = 3008,
	MereldarDerbyMark = 3055,
	Kej = 3056,
	ResidualMemories = 3089,
	NerubArFinery = 3093,
	RestoredCofferKey = 3028,
	BronzeCelebration = 3100,
	
}
