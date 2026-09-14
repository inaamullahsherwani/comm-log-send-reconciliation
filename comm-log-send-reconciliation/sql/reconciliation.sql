WITH RECURSIVE
eligible_campaigns AS (
  SELECT id
  FROM campaign
  WHERE merchant_id = 501
    AND creation_status IN ('approved','aborted','resumed','stopped')
    AND processing_status = 'processed'
),

walk AS (
  SELECT id AS campaign_id, id AS cur_id, parent_id AS cur_parent
  FROM campaign WHERE merchant_id = 501
  UNION ALL
  SELECT w.campaign_id, c.id, c.parent_id
  FROM walk w JOIN campaign c ON w.cur_parent = c.id
),
campaign_root AS (
  SELECT campaign_id, cur_id AS root_id
  FROM walk
  WHERE cur_parent IS NULL
),
family_size AS (
  SELECT root_id, COUNT(*) AS n_campaigns
  FROM campaign_root
  GROUP BY root_id
),
tagged AS (
  SELECT cr.campaign_id, cr.root_id,
         CASE WHEN fs.n_campaigns > 1 THEN 'chain' ELSE 'standalone' END AS family_type
  FROM campaign_root cr JOIN family_size fs ON fs.root_id = cr.root_id
),
eligible_log AS (
  SELECT l.customer_id, t.root_id, t.family_type
  FROM communication_log l
  JOIN eligible_campaigns e ON e.id = l.communication_id
  JOIN tagged t ON t.campaign_id = l.communication_id
  WHERE l.merchant_id = 501 AND l.communication_type = '2' 
)
SELECT
  (SELECT COUNT(*) FROM (SELECT DISTINCT root_id, customer_id FROM eligible_log WHERE family_type = 'chain'))
  + (SELECT COUNT(*) FROM eligible_log WHERE family_type = 'standalone') AS target_base;