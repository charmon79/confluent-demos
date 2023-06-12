CREATE SOURCE STREAM pageviews (
    viewtime bigint, 
    userid varchar, 
    pageid varchar
)
WITH
(
    kafka_topic='pageviews', 
    value_format='AVRO'
);
