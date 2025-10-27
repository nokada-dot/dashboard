-- detail_kpi_action_infoを作るクエリ
DECLARE target_date DATE DEFAULT DATE_SUB(CURRENT_DATE("Asia/Tokyo"), INTERVAL 1 DAY); -- 前日データを対象

INSERT INTO `iris-toreca-469505.daily_dashbord.detail_kpi_action_info`
(day, reg_seg, active_UU, _PARTITIONTIME)

WITH
  reg_seg_ AS ( -- ユーザーごとに利用月数セグメント付与
      SELECT
        user_id,
        CASE
          WHEN DATE_DIFF(CURRENT_DATE("Asia/Tokyo"), DATE(created_at), MONTH) = 0 THEN '01_登録初月'
          WHEN DATE_DIFF(CURRENT_DATE("Asia/Tokyo"), DATE(created_at), MONTH) <= 6 THEN '02_短期利用者(2~6ヶ月)'
          ELSE '03_長期利用者(7ヶ月以上)'
        END AS reg_seg
      FROM `iris-toreca-469505.daily_dashbord.users_regist_log`
      WHERE partition_date = target_date
  ),

  activity_ AS ( -- 行動ログ
      SELECT
        user_id,
        DATE(created_at) AS day
      FROM `iris-toreca-469505.daily_dashbord.point_activities_log`
      WHERE
        partition_date BETWEEN DATE_SUB(CURRENT_DATE("Asia/Tokyo"), INTERVAL 32 DAY)
                          AND DATE_SUB(CURRENT_DATE("Asia/Tokyo"), INTERVAL 1 DAY)
        AND activity_type != 4 -- point失効除く
        AND DATE(created_at) >= DATE_TRUNC(CURRENT_DATE("Asia/Tokyo"), MONTH) -- 当月データのみ
  ),

  action_ AS ( -- アクションログとセグメントジョイン
      SELECT
        a.user_id,
        a.day,
        r.reg_seg
      FROM activity_ a
      LEFT JOIN reg_seg_ r
        ON a.user_id = r.user_id
  ),

  calc_ AS ( -- 利用月数セグメント別アクティブユーザー数
      SELECT
        day,
        reg_seg,
        COUNT(DISTINCT user_id) AS active_UU
      FROM action_
      GROUP BY 1,2
  )

SELECT
  day,
  reg_seg,
  active_UU,
  TIMESTAMP(target_date) AS _PARTITIONTIME -- ← パーティション列として挿入
FROM calc_
ORDER BY 1;
