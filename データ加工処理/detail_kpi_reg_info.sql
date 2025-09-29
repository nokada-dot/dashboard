-- detail_kpi_reg_infoを作るクエリ

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
        partition_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) -- ここは前日断面取得
  )
  , pay_sum_ AS ( -- その月、日時点の課金額を計算
      SELECT
        user_id
        , SUM(amount) AS total_amount
      FROM `iris-toreca-469505.daily_dashbord.point_purchases_log`
      WHERE 
        partition_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 32 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) -- 31日〜1日前のパーティション断面取得
        AND DATE(created_at) >= DATE_TRUNC(CURRENT_DATE(), MONTH) -- 当月データに絞り込み 
      GROUP BY 1
  )
  , pay_seg_ AS ( -- その月、日時点の課金セグメント付与
      SELECT 
        user_id
        , total_amount -- 課金額
        , CASE
            WHEN total_amount <= 1000 THEN '01_ライト(1~1,000円)'
            WHEN total_amount <= 10000 THEN '02_ミドル(1,000~10,000円)'
            WHEN total_amount <= 100000 THEN '03_ヘビー(10,000~100,000円)'
            WHEN total_amount > 100000 THEN '04_超ヘビー(100,000以上)'
            ELSE 'その他'
          END AS pay_seg -- 課金セグメント
      FROM pay_sum_
  )
  , user_base_ AS ( -- 利用月数セグメントと課金セグメントを統合
      SELECT
        reg_seg_.user_id
        , pay_seg_.total_amount
        , reg_seg_.reg_seg
        , pay_seg_.pay_seg
      FROM reg_seg_
      LEFT JOIN pay_seg_
        ON reg_seg_.user_id = pay_seg_.user_id
  )
  , pay_log_ AS ( -- 課金ログ呼び出して、日毎の課金額集計
      SELECT
        user_id
        , DATE(created_at) AS day
        , SUM(amount) AS total_amount
      FROM `iris-toreca-469505.daily_dashbord.point_purchases_log`
      WHERE 
        partition_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 32 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) -- 31日〜1日前のパーティション断面取得
        AND DATE(created_at) >= DATE_TRUNC(CURRENT_DATE(), MONTH) -- 当月データに絞り込み
      GROUP BY 1,2
  )
  , pay_info_ AS ( -- 課金情報にユーザー情報ジョイン
      SELECT
        pay_log_.user_id
        , pay_log_.day
        , pay_log_.total_amount
        , user_base_.reg_seg
        , user_base_.pay_seg
      FROM pay_log_
      LEFT JOIN user_base_
        ON pay_log_.user_id = user_base_.user_id
  )
  , pay_detail_ AS ( -- 課金系の情報集計
      SELECT
        day
        , 'ARPPU' AS type
        , reg_seg
        , SUM(total_amount) / COUNT(*) AS val -- arppu
      FROM pay_info_
      WHERE pay_seg IS NOT NULL -- 無課金者の情報を落とす
      GROUP BY 1,2,3
  )
  , point_ AS ( -- pointログ呼び出し,集計
      SELECT
        user_id
        , DATE(created_at) AS day
        , activity_type
        , SUM(point) AS cons_point
      FROM `iris-toreca-469505.daily_dashbord.point_activities_log`  
      WHERE 
        partition_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 32 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) -- 31日〜1日前のパーティション断面取得
      GROUP BY 1,2,3
  )
  , point_user_base_ AS ( -- ポイント情報とユーザー情報ジョイン
      SELECT
        point_.user_id
        , user_base_.reg_seg
        , point_.day
        , point_.activity_type
        , point_.cons_point
      FROM point_
      LEFT JOIN user_base_
        ON point_.user_id = user_base_.user_id
  )
  , point_detail_gain AS ( -- ポイント系の情報集計_獲得
      SELECT
        day
        , 'cons_point_gain' AS type
        , reg_seg
        , SUM(cons_point) AS val
      FROM point_user_base_
      WHERE activity_type IN (0,2,3,5)
      GROUP BY 1,2,3
  )
  , point_detail_cons AS ( -- ポイント系の情報集計_減少
      SELECT
        day
        , 'cons_point_cons' AS type
        , reg_seg
        , SUM(cons_point) AS val
      FROM point_user_base_
      WHERE activity_type IN (1,4)
      GROUP BY 1,2,3
  )
  , union_ AS(
      SELECT
        *
      FROM pay_detail_
      UNION ALL
      SELECT
        *
      FROM point_detail_gain      
      UNION ALL
      SELECT
        *
      FROM point_detail_cons  
  )


SELECT * 
FROM union_ 
ORDER BY 1