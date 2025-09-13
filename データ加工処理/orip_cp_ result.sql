-- orip_cp_resultを作るクエリ

WITH
  cp_join AS ( -- CP情報結合
      SELECT
        DATE(created_at) AS day
        , about
        , pl.pack_id
        , point
        , user_id
        , cp_name
        , CASE
            WHEN cp_name IS NOT NULL THEN '対象'
            ELSE '対象外'
          END AS cp_flg
      FROM `iris-toreca-469505.daily_dashbord.point_activities_log`  as pl
      LEFT JOIN `iris-toreca-469505.daily_dashbord.cp_master` as cp
        ON pl.pack_id = cp.pack_id
        WHERE 
          partition_date = "2025-08-21" -- ここは最終的に複数断面とる感じに書き換え
        AND activity_type = 1 -- オリパ引くことによる消費に限定
  )
  , cal_orip_notcp AS ( -- 日、オリパごとの消費ポイントを集計するクエリ(CP対象外)
      SELECT  
        day
        , pack_id
        , about AS orip_name
        , cp_flg
        , SUM(point) AS cons_point 
      FROM cp_join
      WHERE cp_flg = '対象外'
      GROUP BY
        day
        , pack_id
        , orip_name
        , cp_flg
  )
  , cal_orip_cp AS ( -- 日、オリパごとの消費ポイントを集計するクエリ(CP対象)
      SELECT  
        day
        , pack_id
        , about AS orip_name
        , cp_flg
        , SUM(point) AS cons_point 
      FROM cp_join
      WHERE cp_flg = '対象'
      GROUP BY
        day
        , pack_id
        , orip_name
        , cp_flg
  )
  , union_table AS ( -- CP対象と対象外を縦結合
      SELECT 
        *
      FROM cal_orip_notcp
      UNION ALL
      SELECT 
        *
      FROM cal_orip_cp
  )
  , rolling_count_ AS ( -- 回転数呼び出し
      SELECT
        id AS pack_id
        ,_________ AS rolling_count -- 回転数
      FROM `iris-toreca-469505.daily_dashbord.rolling_count`
  )

SELECT
  day
  , pack_id
  , orip_name
  , cp_flg
  , cons_point -- 消費ポイント
  , cons_point / rolling_count AS koukendo -- 貢献度
FROM union_table
LEFT JOIN rolling_count_
  USING(pack_id)

