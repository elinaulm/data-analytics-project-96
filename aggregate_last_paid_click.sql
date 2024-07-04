WITH union_ads AS (
    SELECT
        DATE(campaign_date) AS campaign_date,
        utm_source,
        utm_campaign,
        utm_medium,
        SUM(daily_spent) AS spent
    FROM vk_ads
    GROUP BY 1,2,3,4
    UNION
    SELECT
        DATE(campaign_date) AS campaign_date,
        utm_source,
        utm_campaign,
        utm_medium,
        SUM(daily_spent) AS spent
    FROM ya_ads 
    GROUP BY 1,2,3,4
    ORDER BY 1
),
tab AS (
    SELECT
        visitor_id,
        MAX(visit_date) AS last_visit
    FROM sessions s
    WHERE medium <> 'organic'
    GROUP BY visitor_id
),
last_paid_attribution AS
(
    SELECT
        s.visitor_id,
        s.visit_date,
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id
    FROM tab AS t
    INNER JOIN sessions s ON t.visitor_id = s.visitor_id AND t.last_visit = s.visit_date
    LEFT JOIN leads AS l ON s.visitor_id =l.visitor_id AND t.last_visit <= l.created_at 
    ORDER BY l.amount DESC NULLS LAST, visit_date, utm_source, utm_medium, utm_campaign
),
aggregate_last_paid AS (
    SELECT
        DATE(lpa.visit_date) AS visit_date,
        lpa.utm_source,
        lpa.utm_medium,
        lpa.utm_campaign,
        COUNT(DISTINCT lpa.visitor_id) AS visitors_count,
        COUNT(lpa.lead_id) AS leads_count,
        COUNT(lpa.amount) 
            FILTER (WHERE lpa.closing_reason = 'Успешно реализованно' OR lpa.status_id = 142)
            AS purchases_count,
        SUM(amount) AS revenue
    FROM last_paid_attribution lpa
    GROUP BY 1, 2, 3, 4
)
SELECT 
    alp.visit_date,
    alp.visitors_count,
    alp.utm_source,
    alp.utm_medium,
    alp.utm_campaign,
    ua.spent AS total_cost,
    alp.leads_count,
    alp.purchases_count,
    alp.revenue
FROM aggregate_last_paid alp
LEFT JOIN union_ads ua 
    ON alp.utm_source = ua.utm_source
    AND alp.utm_campaign = ua.utm_campaign
    AND alp.utm_medium = ua.utm_medium 
    AND DATE(alp.visit_date) = ua.campaign_date
ORDER BY revenue DESC NULLS LAST, visit_date, visitors_count DESC, utm_source, utm_medium, utm_campaign;
