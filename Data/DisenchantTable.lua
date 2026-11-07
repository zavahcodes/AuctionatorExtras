-------------------------------------------------------------------------------
--  Disenchant data (vanilla). Rows copied from Auctionator's Classic tables
--  (Source_Classic/Enchant/DisenchantingProbabilities.lua), which Forever never
--  loads because it runs Auctionator's retail code path. Only vanilla
--  materials are kept; the last vanilla row of each list is stretched up to
--  item level 100 instead of switching to TBC materials.
--
--  Row format: { minIlvl, maxIlvl, pct, qty, matID, pct, qty, matID, ... }
--  pct is the chance (0-100) of getting qty of matID.
-------------------------------------------------------------------------------
local _, ns = ...

local WEAPON, ARMOR = 2, 4                 -- Enum.ItemClass
local UNCOMMON, RARE, EPIC = 2, 3, 4       -- Enum.ItemQuality

local RARE_ROWS = {
    {11,25,100,1,10978},
    {26,30,100,1,11084},
    {31,35,100,1,11138},
    {36,40,100,1,11139},
    {41,45,100,1,11177},
    {46,50,100,1,11178},
    {51,55,100,1,14343},
    {56,100,99.5,1,14344,0.5,1,20725},
}

local EPIC_ROWS_HEAD = {
    {40,45,33.333333333333,2,11177,33.333333333333,3,11177,33.333333333333,4,11177},
    {46,50,33.333333333333,2,11178,33.333333333333,3,11178,33.333333333333,4,11178},
    {51,55,33.333333333333,2,14343,33.333333333333,3,14343,33.333333333333,4,14343},
    {56,60,100,1,20725},
}

local function WithRow(rows, extra)
    local t = {}
    for i = 1, #rows do t[i] = rows[i] end
    t[#t + 1] = extra
    return t
end

ns.DisenchantTable = {
    [ARMOR] = {
        [UNCOMMON] = {
            {5,15,40,1,10940,40,2,10940,10,1,10938,10,2,10938},
            {16,20,37.5,2,10940,37.5,3,10940,10,1,10939,10,2,10939,5,1,10978},
            {21,25,25,4,10940,25,5,10940,25,6,10940,7.5,1,10998,7.5,2,10998,10,1,10978},
            {26,30,37.5,1,11083,37.5,2,11083,10,1,11082,10,2,11082,5,1,11084},
            {31,35,18.75,2,11083,18.75,3,11083,18.75,4,11083,18.75,5,11083,10,1,11134,10,2,11134,5,1,11138},
            {36,40,37.5,1,11137,37.5,2,11137,10,1,11135,10,2,11135,5,1,11139},
            {41,45,18.75,2,11137,18.75,3,11137,18.75,4,11137,18.75,5,11137,10,1,11174,10,2,11174,5,1,11177},
            {46,50,37.5,1,11176,37.5,2,11176,10,1,11175,10,2,11175,5,1,11178},
            {51,55,18.75,2,11176,18.75,3,11176,18.75,4,11176,18.75,5,11176,10,1,16202,10,2,16202,5,1,14343},
            {56,60,37.5,1,16204,37.5,2,16204,10,1,16203,10,2,16203,5,1,14344},
            {61,100,18.75,2,16204,18.75,3,16204,18.75,4,16204,18.75,5,16204,10,2,16203,10,3,16203,5,1,14344},
        },
        [RARE] = RARE_ROWS,
        [EPIC] = WithRow(EPIC_ROWS_HEAD, {61,100,50,1,20725,50,2,20725}),
    },
    [WEAPON] = {
        [UNCOMMON] = {
            {6,15,10,1,10940,10,2,10940,40,1,10938,40,2,10938},
            {16,20,10,2,10940,10,3,10940,37.5,1,10939,37.5,2,10939,5,1,10978},
            {21,25,5,4,10940,5,5,10940,5,6,10940,37.5,1,10939,37.5,2,10939,10,1,10978},
            {26,30,10,1,11083,10,2,11083,37.5,1,10939,37.5,2,10939,5,1,11084},
            {31,35,5,2,11083,5,3,11083,5,4,11083,5,5,11083,37.5,1,11134,37.5,2,11134,5,1,11138},
            {36,40,10,1,11137,10,2,11137,37.5,1,11135,37.5,2,11135,5,1,11139},
            {41,45,5,2,11137,5,3,11137,5,4,11137,5,5,11137,37.5,1,11174,37.5,2,11174,5,1,11177},
            {46,50,10,1,11176,10,2,11176,37.5,1,11175,37.5,2,11175,5,1,11178},
            {51,55,5.5,2,11176,5.5,3,11176,5.5,4,11176,5.5,5,11176,37.5,1,16202,37.5,2,16202,5,1,14343},
            {56,60,11,1,16204,11,2,16204,37.5,1,16203,37.5,2,16203,5,1,14344},
            {61,100,5.5,2,16204,5.5,3,16204,5.5,4,16204,5.5,5,16204,37.5,2,16203,37.5,3,16203,5,1,14344},
        },
        [RARE] = RARE_ROWS,
        [EPIC] = WithRow(EPIC_ROWS_HEAD, {61,100,33.3,1,20725,66.6,2,20725}),
    },
}

-- Lesser essence -> greater essence (3 lesser = 1 greater, and back).
ns.DisenchantEssencePairs = {
    [10938] = 10939, -- Magic
    [10998] = 11082, -- Astral
    [11134] = 11135, -- Mystic
    [11174] = 11175, -- Nether
    [16202] = 16203, -- Eternal
}

-- English fallback names, used until the client has the item cached.
ns.DisenchantMatNames = {
    [10938] = "Lesser Magic Essence",   [10939] = "Greater Magic Essence",
    [10940] = "Strange Dust",           [10978] = "Small Glimmering Shard",
    [10998] = "Lesser Astral Essence",  [11082] = "Greater Astral Essence",
    [11083] = "Soul Dust",              [11084] = "Large Glimmering Shard",
    [11134] = "Lesser Mystic Essence",  [11135] = "Greater Mystic Essence",
    [11137] = "Vision Dust",            [11138] = "Small Glowing Shard",
    [11139] = "Large Glowing Shard",    [11174] = "Lesser Nether Essence",
    [11175] = "Greater Nether Essence", [11176] = "Dream Dust",
    [11177] = "Small Radiant Shard",    [11178] = "Large Radiant Shard",
    [14343] = "Small Brilliant Shard",  [14344] = "Large Brilliant Shard",
    [16202] = "Lesser Eternal Essence", [16203] = "Greater Eternal Essence",
    [16204] = "Illusion Dust",          [20725] = "Nexus Crystal",
}
