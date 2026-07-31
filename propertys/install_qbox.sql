CREATE TABLE IF NOT EXISTS `propertys` (
  `Name` varchar(100) NOT NULL,
  `Interior` varchar(50) NOT NULL,
  `citizenid` varchar(50) NOT NULL,
  `Serial` varchar(50) NOT NULL,
  `Vault` int unsigned NOT NULL DEFAULT 0,
  `Fridge` int unsigned NOT NULL DEFAULT 0,
  `Tax` datetime DEFAULT NULL,
  `Item` int unsigned NOT NULL DEFAULT 3,
  PRIMARY KEY (`Name`),
  UNIQUE KEY `uk_propertys_serial` (`Serial`),
  KEY `idx_propertys_citizenid` (`citizenid`),
  KEY `idx_propertys_tax` (`Tax`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `propertys_data` (
  `id` varchar(191) NOT NULL,
  `data` longtext NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


CREATE TABLE IF NOT EXISTS `propertys_garages` (
  `property_name` varchar(100) NOT NULL,
  `x` double NOT NULL,
  `y` double NOT NULL,
  `z` double NOT NULL,
  `heading` float NOT NULL DEFAULT 0,
  `updated_by` varchar(50) DEFAULT NULL,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`property_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
