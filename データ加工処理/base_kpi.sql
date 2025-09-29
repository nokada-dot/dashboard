-- base_kpiを作るクエリ

WITH
  point_ AS ( -- 日毎の消費Pt集計
      SELECT
        DATE(created_at) AS day
        , SUM(point) AS cons_point
      FROM `iris-toreca-469505.daily_dashbord.point_activities_log`  
      WHERE 
        partition_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 32 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) -- 31日〜1日前のパーティション断面取得
        AND activity_type = 1 -- オリパ引くことによる消費に限定
      GROUP BY 1
  )
  , pay_ AS ( -- 日毎の課金情報計算
      SELECT
        DATE(created_at) AS day
        , SUM(amount) AS total_amount -- 課金額
        , COUNT(DISTINCT(user_id)) AS paid_UU -- 課金者数
        , COUNT(*) AS paid_count -- 課金回数
      FROM `iris-toreca-469505.daily_dashbord.point_purchases_log`
      WHERE 
        partition_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 32 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) -- 31日〜1日前のパーティション断面取得
      GROUP BY 1
  )
  , regist_ AS ( -- 登録者数計算
      SELECT
        DATE(created_at) AS day
        , COUNT(DISTINCT(user_id)) AS regist_UU -- 登録者数
      FROM `iris-toreca-469505.daily_dashbord.users_regist_log`
      WHERE
        partition_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) -- ここは前日断面取得
      GROUP BY 1
  )
  , dau_ AS ( -- dau計算
    SELECT
      DATE(created_at) AS day
      , COUNT(DISTINCT(user_id)) AS dau -- dau
      FROM `iris-toreca-469505.daily_dashbord.point_activities_log`  
      WHERE 
        partition_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 32 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) -- 31日〜1日前のパーティション断面取得
        AND activity_type != 4 -- point失効除外
      GROUP BY 1
  )
  , budget_ AS ( -- 予算とる
      SELECT 
        *
      FROM `iris-toreca-469505.daily_dashbord.budget`
  )
  , start_orip AS ( -- 販売開始オリパ数
      SELECT
        DATE(created_at) AS day
        , COUNT(DISTINCT(id))AS s_orip  -- 販売開始オリパ
      FROM `iris-toreca-469505.daily_dashbord.packs_master`
      WHERE 
        partition_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) -- ここは前日断面取得
      GROUP BY 1
  )
  , stock_point_ AS ( -- 保有ポイント
      SELECT
        partition_date AS day
        , SUM(point) AS stock_points
      FROM `iris-toreca-469505.daily_dashbord.stock_point`
      WHERE 
        partition_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 32 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) -- 31日〜1日前のパーティション断面取得
      GROUP BY 1
  ) 
  , join_table_ AS (
      SELECT
        budget_.date AS day
        , budget_.budget AS budget -- 予算
        , pay_.total_amount AS total_amount -- 売上
        , point_.cons_point AS cons_point -- 消費Pt
        , pay_.total_amount / point_.cons_point AS amount_per_cons_point -- 売上/消費Pt
        , start_orip.s_orip AS s_orip -- 販売開始オリパ
        , pay_.total_amount - budget_.budget AS yojitsusa -- 予算差分
        , dau_.dau AS dau -- dau
        , regist_.regist_UU AS regist_UU -- 新規登録者
        , pay_.paid_UU AS paid_UU -- 課金者数
        , pay_.total_amount / pay_.paid_UU AS arppu -- 客単価
        , pay_.paid_count AS paid_count -- 課金回数
        , pay_.total_amount / pay_.paid_count AS arpu -- 課金単価
        , stock_point_.stock_points AS stock_points -- 保有ポイント合計
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
SELECT * 
FROM join_table_
ORDER BY day ASC

