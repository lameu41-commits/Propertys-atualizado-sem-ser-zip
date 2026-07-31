-----------------------------------------------------------------------------------------------------------------------------------------
-- INTERIORES NATIVOS (BOB74_IPL)
-----------------------------------------------------------------------------------------------------------------------------------------
-- As coordenadas-base abaixo são dos interiores GTA Online carregados pelo bob74_ipl.
-- Os pontos de Vault/Fridge/Clothes são pontos funcionais próximos à área interna e
-- podem ser refinados conforme a preferência do servidor.
-----------------------------------------------------------------------------------------------------------------------------------------
Internal = {
    Emerald = { ------- corrigido diminuir valor
        Ipl = "GTAOHouseHi8",
        Exit = vec3(-1453.11, -537.42, 74.04),
        Vault = vec3(-1466.2, -527.29, 73.44),
        Fridge = vec3(-1472.51, -536.33, 73.44),
        Clothes = vec3(-1450.05, -549.36, 72.84),
        Furniture = { vec3(-1466.2, -527.29, 73.44), vec3(-1472.51, -536.33, 73.44), vec3(-1458.54, -531.93, 73.44) }
    },

    Ruby = {---------corrigido
        Ipl = "GTAOHouseMid1",
        Exit = vec3(346.31, -1012.22, -99.2),
        Vault = vec3(351.86, -998.84, -99.20),
        Fridge = vec3(344.16, -1001.40, -99.20),
        Clothes = vec3(350.78, -993.59, -99.20),
        Furniture = { vec3(346.15, -1001.71, -99.20), vec3(345.01, -995.49, -99.20), vec3(341.97, -997.45, -99.20), vec3(338.35, -995.22, -99.20), vec3(351.13, -999.23, -99.20) }
    },

    Sapphire = { ------ corrigido
        Ipl = "GTAOHouseHi1",
        Exit = vec3(-174.11, 496.91, 137.67),
        Vault = vec3(-175.31, 492.18, 130.04),
        Fridge = vec3(-165.88, 496.08, 137.65),
        Clothes = vec3(-167.54, 488.74, 133.84),
        Furniture = { vec3(-170.21, 495.82, 137.65), vec3(-168.18, 494.13, 137.65), vec3(-165.88, 496.08, 137.65), vec3(-170.32, 482.18, 133.85), vec3(-174.03, 493.64, 130.04) }
    },

    Amethyst = { ----- corrigido
        Ipl = "GTAOHouseHi2",
        Exit = vec3(340.9412, 437.1798, 149.3925),
        Vault = vec3(337.55, 437.72, 141.77),
        Fridge = vec3(342.18, 432.19, 149.38),
        Clothes = vec3(334.48, 428.91, 145.57),
        Furniture = { vec3(337.55, 437.72, 141.77), vec3(342.18, 432.19, 149.38), vec3(334.48, 428.91, 145.57) }
    },

    Amber = { ------ corrigido
        Ipl = "GTAOHouseHi3",
        Exit = vec3(373.32, 423.03, 145.91),
        Vault = vec3(377.62, 429.13, 138.30),
        Fridge = vec3(376.67, 419.71, 145.9),
        Clothes = vec3(374.37, 411.42, 142.1),
        Furniture = { vec3(377.62, 429.13, 138.30), vec3(376.67, 419.71, 145.9), vec3(374.37, 411.42, 142.1) }
    },

    Galpao = {
        -- Interior nativo de garagem/depósito usado como fallback seguro.
        Ipl = "GTAOHouseLow1",
        Exit = vec3(261.4586, -998.8196, -99.00863),
        Vault = vec3(265.89, -999.41, -99.01)
    },

    Hotel = {
        Ipl = "GTAOHouseLow1",
        Exit = vec3(266.11, -1007.34, -101.01),
        Vault = vec3(265.89, -999.41, -99.01),
        Fridge = vec3(265.81, -995.54, -99.01),
        Clothes = vec3(259.83, -1003.95, -99.01),
        Furniture = { vec3(265.97, -999.46, -99.01), vec3(265.66, -997.40, -99.01), vec3(262.67, -999.88, -99.01), vec3(257.01, -995.84, -99.01) }
    }
}
