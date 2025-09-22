-- detail_kpi_pay_infoを作るクエリ

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
  , pay_sum_ AS ( -- その月、日時点の課金額を計算
      SELECT
        user_id
        , SUM(amount) AS total_amount
      FROM `iris-toreca-469505.daily_dashbord.point_purchases_log`
      WHERE 
        partition_date = "2025-08-21" -- ここは最終的に複数断面とる感じに書き換え
        -- AND DATE(created_at) >= DATE_TRUNC(CURRENT_DATE(), MONTH) -- 当月データに絞り込み           ######### あとでこの処理に戻す！！！ "##################"
        AND DATE(created_at) >= DATE_TRUNC(DATE("2025-08-21"), MONTH)
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
        partition_date = "2025-08-21" -- ここは最終的に複数断面とる感じに書き換え
        -- AND DATE(created_at) >= DATE_TRUNC(CURRENT_DATE(), MONTH) -- 当月データに絞り込み           ######### あとでこの処理に戻す！！！ "##################"
        AND DATE(created_at) >= DATE_TRUNC(DATE("2025-08-21"), MONTH)
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
        , reg_seg -- 利用月数セグメント
        , pay_seg -- 課金セグメント
        , SUM(total_amount) AS total_amount_seg -- セグメント別課金額
        , COUNT(*) AS pu -- セグメント別PU
      FROM pay_info_
      WHERE pay_seg IS NOT NULL -- 無課金者の情報を落とす
      GROUP BY 1,2,3
  )
SELECT * 
FROM pay_detail_ 
ORDER BY 1