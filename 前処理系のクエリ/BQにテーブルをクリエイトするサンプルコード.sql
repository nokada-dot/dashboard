- 型を指定して新規のパーティションテーブルを作成
CREATE TABLE `iris-toreca-469505.daily_dashbord.point_activities_log`
PARTITION BY partition_date  -- パーティションキーを created_at の日付に
AS
SELECT
  CAST(user_id AS INT64) AS user_id,
  CAST(pack_id AS INT64) AS pack_id,
  CAST(point AS INT64) AS point,
  CAST(activity_type AS INT64) AS activity_type,
  CAST(play_count AS INT64) AS play_count,
  CAST(about AS string) AS about,
  CAST(created_at AS TIMESTAMP) AS created_at,  
  DATE("2025-08-21") AS partition_date
FROM `iris-toreca-469505.daily_dashbord.point_log`
WHERE DATE(_PARTITIONTIME) = DATE("2025-08-26");
