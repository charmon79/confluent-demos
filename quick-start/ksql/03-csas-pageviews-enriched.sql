CREATE STREAM pageviews_enriched
WITH (
  KAFKA_TOPIC = 'pageviews_enriched',
  PARTITIONS = 1,
  VALUE_FORMAT = 'AVRO'
)
AS
SELECT
  u.userid AS userid, 
  p.pageid, 
  u.regionid, 
  u.gender
FROM PAGEVIEWS p
  LEFT JOIN users u
    ON p.userid = u.userid
EMIT CHANGES;
