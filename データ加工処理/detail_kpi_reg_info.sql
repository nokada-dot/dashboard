-- detail_kpi_reg_infoを作るクエリ

DECLARE target_date DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY); -- 実行日の前日を対象

INSERT INTO `iris-toreca-469505.daily_dashbord.detail_kpi_reg_info`
(_PARTITIONTIME, day, type, reg_seg, val)

WITH
  reg_seg_ AS (
      SELECT
        user_id,
        CASE
          WHEN DATE_DIFF(CURRENT_DATE(), DATE(created_at), MONTH) = 0 THEN '01_登録初月'
          WHEN DATE_DIFF(CURRENT_DATE(), DATE(created_at), MONTH) <= 6 THEN '02_短期利用者(2~6ヶ月)'
          ELSE '03_長期利用者(7ヶ月以上)'
        END AS reg_seg
      FROM `iris-toreca-469505.daily_dashbord.users_regist_log`
      WHERE partition_date = target_date
  ),

  pay_sum_ AS (
      SELECT
        user_id,
        SUM(amount) AS total_amount
      FROM `iris-toreca-469505.daily_dashbord.point_purchases_log`
      WHERE 
        partition_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 32 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
        AND DATE(created_at) >= DATE_TRUNC(CURRENT_DATE(), MONTH)
      GROUP BY 1
  ),

  pay_seg_ AS (
      SELECT 
        user_id,
        total_amount,
        CASE
          WHEN total_amount <= 1000 THEN '01_ライト(1~1,000円)'
          WHEN total_amount <= 10000 THEN '02_ミドル(1,000~10,000円)'
          WHEN total_amount <= 100000 THEN '03_ヘビー(10,000~100,000円)'
          WHEN total_amount > 100000 THEN '04_超ヘビー(100,000以上)'
          ELSE 'その他'
        END AS pay_seg
      FROM pay_sum_
  ),

  user_base_ AS (
      SELECT
        r.user_id,
        p.total_amount,
        r.reg_seg,
        p.pay_seg
      FROM reg_seg_ r
      LEFT JOIN pay_seg_ p
        ON r.user_id = p.user_id
  ),

  pay_log_ AS (
      SELECT
        user_id,
        DATE(created_at) AS day,
        SUM(amount) AS total_amount
      FROM `iris-toreca-469505.daily_dashbord.point_purchases_log`
      WHERE 
        partition_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 32 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
        AND DATE(created_at) >= DATE_TRUNC(CURRENT_DATE(), MONTH)
      GROUP BY 1,2
  ),

  pay_info_ AS (
      SELECT
        p.user_id,
        p.day,
        p.total_amount,
        u.reg_seg,
        u.pay_seg
      FROM pay_log_ p
      LEFT JOIN user_base_ u
        ON p.user_id = u.user_id
  ),

  pay_detail_ AS (
      SELECT
        day,
        'ARPPU' AS type,
        reg_seg,
        SUM(total_amount) / COUNT(*) AS val
      FROM pay_info_
      WHERE pay_seg IS NOT NULL
      GROUP BY 1,2,3
  ),

  point_ AS (
      SELECT
        user_id,
        DATE(created_at) AS day,
        activity_type,
        SUM(point) AS cons_point
      FROM `iris-toreca-469505.daily_dashbord.point_activities_log`
      WHERE 
        partition_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 32 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
      GROUP BY 1,2,3
  ),

  point_user_base_ AS (
      SELECT
        p.user_id,
        u.reg_seg,
        p.day,
        p.activity_type,
        p.cons_point
      FROM point_ p
      LEFT JOIN user_base_ u
        ON p.user_id = u.user_id
  ),

  point_detail_gain AS (
      SELECT
        day,
        'cons_point_gain' AS type,
        reg_seg,
        SUM(cons_point) AS val
      FROM point_user_base_
      WHERE activity_type IN (0,2,3,5)
      GROUP BY 1,2,3
  ),

  point_detail_cons AS (
      SELECT
        day,
        'cons_point_cons' AS type,
        reg_seg,
        SUM(cons_point) AS val
      FROM point_user_base_
      WHERE activity_type IN (1,4)
      GROUP BY 1,2,3
  ),

  union_ AS (
      SELECT * FROM pay_detail_
      UNION ALL
      SELECT * FROM point_detail_gain
      UNION ALL
      SELECT * FROM point_detail_cons
  )

SELECT 
  TIMESTAMP(target_date) AS _PARTITIONTIME,
  day,
  type,
  reg_seg,
  val
FROM union_
ORDER BY 1;
