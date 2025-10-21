-- detail_kpi_pay_infoを作るクエリ

-- detail_kpi_pay_info（スケジュールクエリ対応版）
-- 出力先: iris-toreca-469505.daily_dashbord.detail_kpi_pay_info
-- テーブルタイプ: 分割
-- 分割基準: DAY
-- フィールドで分割: _PARTITIONTIME

INSERT INTO `iris-toreca-469505.daily_dashbord.detail_kpi_pay_info`
(_PARTITIONTIME, day, reg_seg, pay_seg, total_amount_seg, pu)

WITH
  reg_seg_ AS ( -- ユーザーごとに利用月数セグメント付与
      SELECT
        user_id,
        CASE
          WHEN DATE_DIFF(CURRENT_DATE(), DATE(created_at), MONTH) = 0 THEN '01_登録初月'
          WHEN DATE_DIFF(CURRENT_DATE(), DATE(created_at), MONTH) <= 6 THEN '02_短期利用者(2~6ヶ月)'
          ELSE '03_長期利用者(7ヶ月以上)'
        END AS reg_seg
      FROM `iris-toreca-469505.daily_dashbord.users_regist_log`
      WHERE partition_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
  ),

  pay_sum_ AS ( -- 当月の課金総額（ユーザー単位）
      SELECT
        user_id,
        SUM(amount) AS total_amount
      FROM `iris-toreca-469505.daily_dashbord.point_purchases_log`
      WHERE 
        partition_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 32 DAY)
        AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
        AND DATE(created_at) >= DATE_TRUNC(CURRENT_DATE(), MONTH)
      GROUP BY 1
  ),

  pay_seg_ AS ( -- ユーザーごとの課金セグメント
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

  user_base_ AS ( -- 利用月数セグメントと課金セグメント統合
      SELECT
        reg_seg_.user_id,
        pay_seg_.total_amount,
        reg_seg_.reg_seg,
        pay_seg_.pay_seg
      FROM reg_seg_
      LEFT JOIN pay_seg_
        ON reg_seg_.user_id = pay_seg_.user_id
  ),

  pay_log_ AS ( -- 日別課金ログ集計
      SELECT
        user_id,
        DATE(created_at) AS day,
        SUM(amount) AS total_amount
      FROM `iris-toreca-469505.daily_dashbord.point_purchases_log`
      WHERE 
        partition_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 32 DAY)
        AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
        AND DATE(created_at) >= DATE_TRUNC(CURRENT_DATE(), MONTH)
      GROUP BY 1,2
  ),

  pay_info_ AS ( -- 課金情報＋セグメント情報
      SELECT
        pay_log_.user_id,
        pay_log_.day,
        pay_log_.total_amount,
        user_base_.reg_seg,
        user_base_.pay_seg
      FROM pay_log_
      LEFT JOIN user_base_
        ON pay_log_.user_id = user_base_.user_id
  ),

  pay_detail_ AS ( -- セグメント別集計
      SELECT
        day,
        reg_seg,
        pay_seg,
        SUM(total_amount) AS total_amount_seg,
        COUNT(*) AS pu
      FROM pay_info_
      WHERE pay_seg IS NOT NULL
      GROUP BY 1,2,3
  )

SELECT
  TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)) AS _PARTITIONTIME, -- 前日分をパーティションとして挿入
  day,
  reg_seg,
  pay_seg,
  total_amount_seg,
  pu
FROM pay_detail_
ORDER BY day;
