-- detail_kpi_action_infoを作るクエリ

WITH
  reg_seg_ AS ( -- ユーザーごとに利用月数セグメント付与
      SELECT
        user_id
        , CASE
            WHEN DATE_DIFF(CURRENT_DATE(),DATE(created_at),MONTH) = 0 THEN '01_登録初月'
            WHEN DATE_DIFF(CURRENT_DATE(),DATE(created_at),MONTH) <= 6  THEN '02_短期利用者(2~6ヶ月)'
            ELSE '03_長期利用者(7ヶ月以上)' 
          END AS reg_seg -- 利用月数セグメント
      FROM `iris-toreca-469505.daily_dashbord.users_regist_log`
      WHERE
        partition_date = "2025-08-21" -- ここは動的前日断面にとる感じに書き換え
  )
  , activity_ AS ( -- 行動ログ
      SELECT
        user_id
        , DATE(created_at) AS day
      FROM `iris-toreca-469505.daily_dashbord.point_activities_log`  
      WHERE 
        partition_date = "2025-08-21" -- ここは最終的に複数断面とる感じに書き換え
        AND activity_type != 4 -- point失効除く
        -- AND DATE(created_at) >= DATE_TRUNC(CURRENT_DATE(), MONTH) -- 当月データに絞り込み           ######### あとでこの処理に戻す！！！ "##################"
        AND DATE(created_at) >= DATE_TRUNC(DATE("2025-08-21"), MONTH)
  )
  , action_ AS ( -- アクションログとセグメントジョイン
      SELECT
        activity_.user_id
        , activity_.day
        , reg_seg_.reg_seg
      FROM activity_
      LEFT JOIN reg_seg_
        ON activity_.user_id = reg_seg_.user_id
  )
  , calc_ AS ( -- 利用月数セグメント別アクティブユーザー数
      SELECT
        day
        , reg_seg
        , COUNT(DISTINCT(user_id)) AS active_UU
      FROM action_
      GROUP BY 1,2
  )
SELECT
  *
FROM calc_
ORDER BY 1
