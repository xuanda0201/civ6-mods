-- Runs after HD and both dependencies. Adds a NEW leader; no source leader rows change.
-- Dependency sanity check; the database loader reports missing source definitions.
CREATE TEMP TABLE XGYG_Required (Present INTEGER NOT NULL CHECK(Present=1));
INSERT INTO XGYG_Required SELECT CASE WHEN
 EXISTS(SELECT 1 FROM Leaders WHERE LeaderType='LEADER_PHANTA_YANG_GUANG') AND
 EXISTS(SELECT 1 FROM Traits WHERE TraitType='TRAIT_LEADER_PHANTA_YANG_GUANG') AND
 EXISTS(SELECT 1 FROM Traits WHERE TraitType='TRAIT_PHANTA_DYNASTY_SUI') AND
 EXISTS(SELECT 1 FROM Traits WHERE TraitType='TRAIT_PHANTA_DYNASTY_QIN') AND
 EXISTS(SELECT 1 FROM Traits WHERE TraitType='TRAIT_LEADER_KUBLAI') AND
 EXISTS(SELECT 1 FROM Traits WHERE TraitType='TRAIT_LEADER_CLEOPATRA_ALT') AND
 EXISTS(SELECT 1 FROM Units WHERE UnitType='UNIT_FRIGATE') AND
 EXISTS(SELECT 1 FROM Civics WHERE CivicType='CIVIC_MERCENARIES') THEN 1 ELSE 0 END;
DROP TABLE XGYG_Required;

INSERT INTO Types(Type,Kind) VALUES
 ('TRAIT_XGYG_REWORK','KIND_TRAIT'),('TRAIT_XGYG_WUYA','KIND_TRAIT'),
 ('UNIT_XGYG_WUYA','KIND_UNIT'),('ABILITY_XGYG_WUYA','KIND_ABILITY'),
 ('ABILITY_XGYG_ESCORTED','KIND_ABILITY');
INSERT INTO Traits(TraitType,Name,Description) VALUES
 ('TRAIT_XGYG_REWORK','LOC_TRAIT_XGYG_NAME','LOC_TRAIT_XGYG_DESCRIPTION'),
 ('TRAIT_XGYG_WUYA','LOC_UNIT_XGYG_WUYA_NAME','LOC_UNIT_XGYG_WUYA_DESCRIPTION');

-- Independent leader identity, using the original visual references.
INSERT INTO Types(Type,Kind) VALUES ('LEADER_XGYG','KIND_LEADER');
INSERT INTO Leaders(LeaderType,Name,InheritFrom,SceneLayers) VALUES
 ('LEADER_XGYG','LOC_LEADER_XGYG_NAME','LEADER_DEFAULT',4);
INSERT INTO CivilizationLeaders(CivilizationType,LeaderType,CapitalName)
 SELECT CivilizationType,'LEADER_XGYG',CapitalName FROM CivilizationLeaders WHERE LeaderType='LEADER_PHANTA_YANG_GUANG';
INSERT INTO LoadingInfo(LeaderType,ForegroundImage,BackgroundImage,PlayDawnOfManAudio)
 SELECT 'LEADER_XGYG',ForegroundImage,BackgroundImage,PlayDawnOfManAudio FROM LoadingInfo WHERE LeaderType='LEADER_PHANTA_YANG_GUANG';
INSERT INTO DiplomacyInfo(Type,BackgroundImage)
 SELECT 'LEADER_XGYG',BackgroundImage FROM DiplomacyInfo WHERE Type='LEADER_PHANTA_YANG_GUANG';
INSERT INTO LeaderQuotes(LeaderType,Quote)
 SELECT 'LEADER_XGYG',Quote FROM LeaderQuotes WHERE LeaderType='LEADER_PHANTA_YANG_GUANG';
INSERT INTO HistoricalAgendas(LeaderType,AgendaType)
 SELECT 'LEADER_XGYG',AgendaType FROM HistoricalAgendas WHERE LeaderType='LEADER_PHANTA_YANG_GUANG';
-- Retain the original leader's capital/move-capital/unlock modifiers under a new
-- trait. The original population-burning script never matches our new identity.
INSERT INTO TraitModifiers(TraitType,ModifierId)
 SELECT 'TRAIT_XGYG_REWORK',ModifierId FROM TraitModifiers
 WHERE TraitType='TRAIT_LEADER_PHANTA_YANG_GUANG';
INSERT INTO LeaderTraits(LeaderType,TraitType) VALUES
 ('LEADER_XGYG','TRAIT_XGYG_REWORK'),
 ('LEADER_XGYG','TRAIT_UNIT_PHANTA_FUBING'),('LEADER_XGYG','TRAIT_UNIT_PHANTA_XIAOGUO'),
 ('LEADER_XGYG','TRAIT_XGYG_WUYA');

-- One displayed leader ability. Reuse the installed rules under our own trait,
-- keeping all source traits and their other leaders untouched. HD's scripted
-- Kublai check is bridged through its supported captured-trait player property.
INSERT OR IGNORE INTO TraitModifiers(TraitType,ModifierId)
 SELECT 'TRAIT_XGYG_REWORK',ModifierId FROM TraitModifiers
 WHERE TraitType IN ('TRAIT_PHANTA_DYNASTY_SUI','TRAIT_LEADER_KUBLAI',
                     'TRAIT_LEADER_CLEOPATRA_ALT');

-- Copy Qin construction modifiers only, not Qin leader/guest/elite-soldier traits.
-- Unlocks are already supplied by Yang Guang/Sui; do not grant the same reward twice.
INSERT OR IGNORE INTO TraitModifiers(TraitType,ModifierId)
 SELECT 'TRAIT_XGYG_REWORK',ModifierId FROM TraitModifiers
 WHERE TraitType='TRAIT_PHANTA_DYNASTY_QIN'
 AND ModifierId NOT IN ('MODFEAT_PHANTA_DYNASTY_QIN_UNLOCK_CANAL','MODFEAT_PHANTA_DYNASTY_QIN_UNLOCK_DAM');

-- Four-way intercourse: foreign incoming routes, land/sea/mixed alike.
INSERT INTO TraitModifiers(TraitType,ModifierId) VALUES
 ('TRAIT_XGYG_REWORK','XGYG_INCOMING_GOLD'),('TRAIT_XGYG_REWORK','XGYG_INCOMING_CULTURE');
INSERT INTO Modifiers(ModifierId,ModifierType) VALUES
 ('XGYG_INCOMING_GOLD','MODIFIER_PLAYER_CITIES_ADJUST_TRADE_ROUTE_YIELD_FROM_OTHERS'),
 ('XGYG_INCOMING_CULTURE','MODIFIER_PLAYER_CITIES_ADJUST_TRADE_ROUTE_YIELD_FROM_OTHERS');
INSERT INTO ModifierArguments(ModifierId,Name,Value) VALUES
 ('XGYG_INCOMING_GOLD','YieldType','YIELD_GOLD'),('XGYG_INCOMING_GOLD','Amount',2),
 ('XGYG_INCOMING_GOLD','Domestic',0),
 ('XGYG_INCOMING_CULTURE','YieldType','YIELD_CULTURE'),('XGYG_INCOMING_CULTURE','Amount',1),
 ('XGYG_INCOMING_CULTURE','Domestic',0);

-- Copy the final installed frigate row, including mod-added columns, without
-- assuming the base game's schema. The new PK makes this a separate unit.
CREATE TEMP TABLE XGYG_Unit AS SELECT * FROM Units WHERE UnitType='UNIT_FRIGATE';
UPDATE XGYG_Unit SET UnitType='UNIT_XGYG_WUYA',Name='LOC_UNIT_XGYG_WUYA_NAME',
 Description='LOC_UNIT_XGYG_WUYA_DESCRIPTION',TraitType='TRAIT_XGYG_WUYA',
 PrereqTech=NULL,PrereqCivic='CIVIC_MERCENARIES';
INSERT INTO Units SELECT * FROM XGYG_Unit;
DROP TABLE XGYG_Unit;
CREATE TEMP TABLE XGYG_UnitXP2 AS SELECT * FROM Units_XP2 WHERE UnitType='UNIT_FRIGATE';
UPDATE XGYG_UnitXP2 SET UnitType='UNIT_XGYG_WUYA';
INSERT INTO Units_XP2 SELECT * FROM XGYG_UnitXP2;
DROP TABLE XGYG_UnitXP2;
INSERT INTO UnitReplaces(CivUniqueUnitType,ReplacesUnitType) VALUES('UNIT_XGYG_WUYA','UNIT_FRIGATE');
INSERT INTO UnitUpgrades(Unit,UpgradeUnit)
 SELECT 'UNIT_XGYG_WUYA',UpgradeUnit FROM UnitUpgrades WHERE Unit='UNIT_FRIGATE';
INSERT INTO UnitAiInfos(UnitType,AiType)
 SELECT 'UNIT_XGYG_WUYA',AiType FROM UnitAiInfos WHERE UnitType='UNIT_FRIGATE';
INSERT INTO TypeTags(Type,Tag) SELECT 'UNIT_XGYG_WUYA',Tag FROM TypeTags WHERE Type='UNIT_FRIGATE';
INSERT INTO Tags(Tag,Vocabulary) VALUES('CLASS_XGYG_WUYA','ABILITY_CLASS');
INSERT INTO TypeTags(Type,Tag) VALUES('UNIT_XGYG_WUYA','CLASS_XGYG_WUYA'),
 ('ABILITY_XGYG_WUYA','CLASS_XGYG_WUYA'),('ABILITY_XGYG_ESCORTED','CLASS_TRADER');
INSERT INTO UnitAbilities(UnitAbilityType,Name,Description,Inactive) VALUES
 ('ABILITY_XGYG_WUYA','LOC_UNIT_XGYG_WUYA_NAME','LOC_ABILITY_XGYG_WUYA',0),
 ('ABILITY_XGYG_ESCORTED','LOC_XGYG_ESCORT_NAME','LOC_XGYG_ESCORT_DESCRIPTION',1);
INSERT INTO UnitAbilityModifiers(UnitAbilityType,ModifierId) VALUES
  ('ABILITY_XGYG_ESCORTED','XGYG_ESCORT_LAND'),('ABILITY_XGYG_ESCORTED','XGYG_ESCORT_SEA');
INSERT INTO Modifiers(ModifierId,ModifierType,SubjectRequirementSetId) VALUES
 ('XGYG_WUYA_STRENGTH','MODIFIER_UNIT_ADJUST_COMBAT_STRENGTH',NULL),
 ('XGYG_ESCORT_LAND','MODIFIER_PLAYER_UNIT_ADJUST_TRADE_ROUTE_PLUNDER_IMMUNITY',NULL),
 ('XGYG_ESCORT_SEA','MODIFIER_PLAYER_UNIT_ADJUST_TRADE_ROUTE_PLUNDER_IMMUNITY',NULL);
INSERT INTO ModifierArguments(ModifierId,Name,Value) VALUES
 ('XGYG_WUYA_STRENGTH','Amount',5),('XGYG_ESCORT_LAND','DomainType','DOMAIN_LAND'),
 ('XGYG_ESCORT_SEA','DomainType','DOMAIN_SEA');
-- Gameplay maintains one inactive position ability for coast OR friendly canal.
-- One ability count means overlapping conditions cannot double the bonus.
INSERT INTO Types(Type,Kind) VALUES('ABILITY_XGYG_POSITION','KIND_ABILITY');
INSERT INTO UnitAbilities(UnitAbilityType,Name,Description,Inactive) VALUES
 ('ABILITY_XGYG_POSITION','LOC_UNIT_XGYG_WUYA_NAME','LOC_ABILITY_XGYG_WUYA',1);
INSERT INTO TypeTags(Type,Tag) VALUES('ABILITY_XGYG_POSITION','CLASS_XGYG_WUYA');
INSERT INTO UnitAbilityModifiers(UnitAbilityType,ModifierId) VALUES
 ('ABILITY_XGYG_POSITION','XGYG_WUYA_STRENGTH');
INSERT INTO ModifierStrings(ModifierId,Context,Text) VALUES
 ('XGYG_WUYA_STRENGTH','Preview','LOC_XGYG_STRENGTH_PREVIEW');
