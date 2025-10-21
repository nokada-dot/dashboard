-- orip_cp_resultを作るクエリ
-- orip_cp_result（スケジュールクエリ対応版）
-- 出力先: iris-toreca-469505.daily_dashbord.orip_cp_result
-- テーブルタイプ: 分割
-- 分割基準: DAY
-- フィールドで分割: _PARTITIONTIME

INSERT INTO `iris-toreca-469505.daily_dashbord.orip_cp_result`
(_PARTITIONTIME, day, orip_name, cp_flg, cons_point, koukendo)

WITH
  cp_join AS ( -- CP情報結合
      SELECT
        DATE(pl.created_at) AS day,
        pl.about,
        pl.pack_id,
        pl.point,
        pl.user_id,
        cp.cp_name,
        CASE
          WHEN cp.cp_name IS NOT NULL THEN '対象'
          ELSE '対象外'
        END AS cp_flg
      FROM `iris-toreca-469505.daily_dashbord.point_activities_log` AS pl
      LEFT JOIN `iris-toreca-469505.daily_dashbord.cp_master` AS cp
        ON pl.pack_id = cp.pack_id
      WHERE 
        pl.partition_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 32 DAY)
                              AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
        AND pl.activity_type = 1 -- オリパ引くことによる消費に限定
  ),

  cal_orip_notcp AS ( -- CP対象外の集計
      SELECT  
        day,
        pack_id,
        about AS orip_name,
        cp_flg,
        SUM(point) AS cons_point 
      FROM cp_join
      WHERE cp_flg = '対象外'
      GROUP BY day, pack_id, orip_name, cp_flg
  ),

  cal_orip_cp AS ( -- CP対象の集計
      SELECT  
        day,
        pack_id,
        about AS orip_name,
        cp_flg,
        SUM(point) AS cons_point 
      FROM cp_join
      WHERE cp_flg = '対象'
      GROUP BY day, pack_id, orip_name, cp_flg
  ),

  union_table AS ( -- CP対象/対象外縦結合
      SELECT * FROM cal_orip_notcp
      UNION ALL
      SELECT * FROM cal_orip_cp
  ),

  rolling_count_ AS ( -- 回転数
      SELECT
        id AS pack_id,
        _________ AS rolling_count
      FROM `iris-toreca-469505.daily_dashbord.rolling_count`
  )

SELECT
  TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)) AS _PARTITIONTIME, -- 前日分パーティション
  u.day,
  u.orip_name,
  u.cp_flg,
  u.cons_point,
  SAFE_DIVIDE(u.cons_point, r.rolling_count) AS koukendo -- 貢献度
FROM union_table u
LEFT JOIN rolling_count_ r
  ON u.pack_id = r.pack_id
ORDER BY u.day, u.pack_id;
