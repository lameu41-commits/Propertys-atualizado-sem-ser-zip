-----------------------------------------------------------------------------------------------------------------------------------------
-- INFORMATIONS
-----------------------------------------------------------------------------------------------------------------------------------------
Informations = {
	Emerald = {
		Price = 1000000,
		Vault = 100,
		Fridge = 25,
		Gemstone = 25000
	},
	Ruby = {
		Price = 1250000,
		Vault = 150,
		Fridge = 40,
		Gemstone = 37500
	},
	Sapphire = {
		Price = 2000000,
		Vault = 200,
		Fridge = 50,
		Gemstone = 50000
	},
	Amethyst = {
		Price = 2500000,
		Vault = 300,
		Fridge = 75,
		Gemstone = 75000
	},
	Amber = {
		Price = 3000000,
		Vault = 400,
		Fridge = 100,
		Gemstone = 100000
	},
	Galpao = {
		Price = 100000000,
		Vault = 200,
		Gemstone = 5000000
	}
}
-----------------------------------------------------------------------------------------------------------------------------------------
-- EXPORTS
-----------------------------------------------------------------------------------------------------------------------------------------
exports("Informations",function()
	local Table = {}
	for Name in pairs(Informations) do
		if Name ~= "Galpao" then
			table.insert(Table,Name)
		end
	end

	return #Table > 0 and Table[math.random(#Table)] or nil
end)