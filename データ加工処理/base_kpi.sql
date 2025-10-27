-- base_kpiを作るクエリ
-- base_kpi（スケジュールクエリ対応版）
-- 出力先: iris-toreca-469505.daily_dashbord.base_kpi
-- テーブルタイプ: 分割
-- 分割基準: DAY
-- フィールドで分割: _PARTITIONTIME

INSERT INTO `iris-toreca-469505.daily_dashbord.base_kpi`
(_PARTITIONTIME, day, budget, total_amount, cons_point, amount_per_cons_point,s_orip, yojitsusa, dau, regist_UU, paid_UU, arppu, paid_count, arpu, stock_points)

WITH
  point_ AS ( -- 日毎の消費Pt集計
      SELECT
        DATE(created_at) AS day,
        SUM(point) AS cons_point
      FROM `iris-toreca-469505.daily_dashbord.point_activities_log`  
      WHERE 
        partition_date BETWEEN DATE_SUB(CURRENT_DATE("Asia/Tokyo"), INTERVAL 32 DAY)
        AND DATE_SUB(CURRENT_DATE("Asia/Tokyo"), INTERVAL 1 DAY)
        AND activity_type = 1 -- オリパ引くことによる消費に限定
      GROUP BY 1
  ),
  
  pay_ AS ( -- 日毎の課金情報計算
      SELECT
        DATE(created_at) AS day,
        SUM(amount) AS total_amount,
        COUNT(DISTINCT user_id) AS paid_UU,
        COUNT(*) AS paid_count
      FROM `iris-toreca-469505.daily_dashbord.point_purchases_log`
      WHERE 
        partition_date BETWEEN DATE_SUB(CURRENT_DATE("Asia/Tokyo"), INTERVAL 32 DAY)
        AND DATE_SUB(CURRENT_DATE("Asia/Tokyo"), INTERVAL 1 DAY)
      GROUP BY 1
  ),

  regist_ AS ( -- 登録者数計算
      SELECT
        DATE(created_at) AS day,
        COUNT(DISTINCT user_id) AS regist_UU
      FROM `iris-toreca-469505.daily_dashbord.users_regist_log`
      WHERE
        partition_date = DATE_SUB(CURRENT_DATE("Asia/Tokyo"), INTERVAL 1 DAY)
      GROUP BY 1
  ),

  dau_ AS ( -- DAU計算
      SELECT
        DATE(created_at) AS day,
        COUNT(DISTINCT user_id) AS dau
      FROM `iris-toreca-469505.daily_dashbord.point_activities_log`  
      WHERE 
        partition_date BETWEEN DATE_SUB(CURRENT_DATE("Asia/Tokyo"), INTERVAL 32 DAY)
        AND DATE_SUB(CURRENT_DATE("Asia/Tokyo"), INTERVAL 1 DAY)
        AND activity_type != 4 -- point失効除外
      GROUP BY 1
  ),

  budget_ AS ( -- 予算
      SELECT 
        *
      FROM `iris-toreca-469505.daily_dashbord.budget`
  ),

  start_orip AS ( -- 販売開始オリパ数
      SELECT
        DATE(created_at) AS day,
        COUNT(DISTINCT id) AS s_orip
      FROM `iris-toreca-469505.daily_dashbord.packs_master`
      WHERE 
        partition_date = DATE_SUB(CURRENT_DATE("Asia/Tokyo"), INTERVAL 1 DAY)
      GROUP BY 1
  ),

  stock_point_ AS ( -- 保有ポイント
      SELECT
        partition_date AS day,
        SUM(point) AS stock_points
      FROM `iris-toreca-469505.daily_dashbord.stock_point`
      WHERE 
        partition_date BETWEEN DATE_SUB(CURRENT_DATE("Asia/Tokyo"), INTERVAL 32 DAY)
        AND DATE_SUB(CURRENT_DATE("Asia/Tokyo"), INTERVAL 1 DAY)
      GROUP BY 1
  ),

  join_table_ AS (
      SELECT
        budget_.date AS day,
        budget_.budget AS budget,
        pay_.total_amount AS total_amount,
        point_.cons_point AS cons_point,
        SAFE_DIVIDE(pay_.total_amount, point_.cons_point) AS amount_per_cons_point,
        start_orip.s_orip AS s_orip,
        pay_.total_amount - budget_.budget AS yojitsusa,
        dau_.dau AS dau,
        regist_.regist_UU AS regist_UU,
        pay_.paid_UU AS paid_UU,
        SAFE_DIVIDE(pay_.total_amount, pay_.paid_UU) AS arppu,
        pay_.paid_count AS paid_count,
        SAFE_DIVIDE(pay_.total_amount, pay_.paid_count) AS arpu,
        stock_point_.stock_points AS stock_points
      FROM budget_ 
      LEFT JOIN pay_ 
        ON budget_.date = pay_.day
      LEFT JOIN point_
        ON budget_.date = point_.day
      LEFT JOIN start_orip
        ON budget_.date = start_orip.day
      LEFT JOIN dau_
        ON budget_.date = dau_.day
      LEFT JOIN regist_
        ON budget_.date = regist_.day
      LEFT JOIN stock_point_
        ON budget_.date = stock_point_.day
  )

SELECT
  TIMESTAMP(DATE_SUB(CURRENT_DATE("Asia/Tokyo"), INTERVAL 1 DAY)) AS _PARTITIONTIME, -- 前日分パーティション
  day,
  budget,
  total_amount,
  cons_point,
  amount_per_cons_point,
  s_orip,
  yojitsusa,
  dau,
  regist_UU,
  paid_UU,
  arppu,
  paid_count,
  arpu,
  stock_points
FROM join_table_
ORDER BY day ASC;
