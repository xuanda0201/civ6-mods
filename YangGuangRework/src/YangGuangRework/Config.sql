-- Independent selection entry; the source leader and his items remain untouched.
CREATE TEMP TABLE XGYG_Player AS SELECT * FROM Players
 WHERE LeaderType='LEADER_PHANTA_YANG_GUANG' AND Domain='Players:Expansion2_Players';
UPDATE XGYG_Player SET LeaderType='LEADER_XGYG',LeaderName='LOC_LEADER_XGYG_NAME',
 LeaderIcon='ICON_LEADER_XGYG',LeaderAbilityName='LOC_TRAIT_XGYG_NAME',
 LeaderAbilityDescription='LOC_TRAIT_XGYG_DESCRIPTION',LeaderAbilityIcon='ICON_LEADER_XGYG';
INSERT INTO Players SELECT * FROM XGYG_Player;
DROP TABLE XGYG_Player;
INSERT INTO PlayerItems(Domain,CivilizationType,LeaderType,Type,Icon,Name,Description,SortIndex)
 SELECT Domain,CivilizationType,'LEADER_XGYG',Type,Icon,Name,Description,SortIndex FROM PlayerItems
 WHERE LeaderType='LEADER_PHANTA_YANG_GUANG' AND Domain='Players:Expansion2_Players'
 AND Type NOT IN ('IMPROVEMENT_PHANTA_DYNASTY_CANGLIN','DISTRICT_PHANTA_SUI_GRANARY',
                  'IMPROVEMENT_PHANTA_GREAT_WALL_QIN');
INSERT INTO PlayerItems(Domain,CivilizationType,LeaderType,Type,Icon,Name,Description,SortIndex) VALUES
 ('Players:Expansion2_Players','CIVILIZATION_CHINA','LEADER_XGYG','UNIT_XGYG_WUYA','ICON_UNIT_XGYG_WUYA','LOC_UNIT_XGYG_WUYA_NAME','LOC_UNIT_XGYG_WUYA_DESCRIPTION',40);
