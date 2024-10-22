-- 1.	Based on user engagement and activity levels, 
-- 		which users would you consider the most loyal or valuable? How would you reward or incentivize these users?


WITH cte1 AS 
(
    SELECT user_id, COUNT(*) AS likes_given
    FROM likes
    WHERE created_at >= NOW() - INTERVAL 1 MONTH
    GROUP BY user_id
),
cte2 AS 
(
    SELECT p.user_id, COUNT(*) AS likes_received
    FROM likes l
    JOIN photos p ON l.photo_id = p.id
    WHERE l.created_at >= NOW() - INTERVAL 1 MONTH
    GROUP BY p.user_id
),
cte3 AS 
(
    SELECT user_id, COUNT(*) AS comments_given
    FROM comments
    WHERE created_at >= NOW() - INTERVAL 1 MONTH
    GROUP BY user_id
),
cte4 AS 
(
    SELECT p.user_id, COUNT(*) AS comments_received
    FROM comments c
    JOIN photos p ON c.photo_id = p.id
    WHERE c.created_at >= NOW() - INTERVAL 1 MONTH
    GROUP BY p.user_id
),
cte5 AS 
(
    SELECT user_id, COUNT(*) AS photos_uploaded
    FROM photos
    WHERE created_dat >= NOW() - INTERVAL 1 MONTH
    GROUP BY user_id
),
cte6 AS 
(
    SELECT followee_id AS user_id, COUNT(*) AS followers
    FROM follows
    GROUP BY followee_id
),
cte7 AS 
(
    SELECT follower_id AS user_id, COUNT(*) AS followings
    FROM follows
    GROUP BY follower_id
),
Engagement AS 
(
    SELECT 
        u.id AS user_id,
        u.username,
        COALESCE(lg.likes_given, 0) + COALESCE(lr.likes_received, 0) +
        COALESCE(cg.comments_given, 0) + COALESCE(cr.comments_received, 0) +
        COALESCE(pu.photos_uploaded, 0) + COALESCE(f.followers, 0) +
        COALESCE(fg.followings, 0) AS total_engagement
    FROM 
        users u
    LEFT JOIN cte1 lg ON u.id = lg.user_id
    LEFT JOIN cte2 lr ON u.id = lr.user_id
    LEFT JOIN cte3 cg ON u.id = cg.user_id
    LEFT JOIN cte4 cr ON u.id = cr.user_id
    LEFT JOIN cte5 pu ON u.id = pu.user_id
    LEFT JOIN cte6 f ON u.id = f.user_id
    LEFT JOIN cte7 fg ON u.id = fg.user_id
)
SELECT 
    user_id,
    username,
    total_engagement,
    RANK() OVER (ORDER BY total_engagement DESC) AS engagement_rank
FROM Engagement
ORDER BY engagement_rank;





-- 2.	For inactive users, what strategies would you recommend to re-engage them and encourage them to start posting or engaging again?


WITH LastActivity AS 
(
    SELECT 
        u.id AS user_id,
        MAX(GREATEST(
            (l.created_at),
            (c.created_at),
            (p.created_dat)
        )) AS last_activity
    FROM users u
    LEFT JOIN likes l ON u.id = l.user_id
    LEFT JOIN comments c ON u.id = c.user_id
    LEFT JOIN photos p ON u.id = p.user_id
    GROUP BY u.id
)
SELECT 
    u.id,
    u.username,
    la.last_activity
FROM users u
JOIN LastActivity la ON u.id = la.user_id
WHERE la.last_activity < NOW() - INTERVAL 3 MONTH;





-- 3.	Which hashtags or content topics have the highest engagement rates? How can this information guide content strategy and ad campaigns?



WITH PhotoEngagement AS 
(
    SELECT 
        p.id AS photo_id,
        COALESCE(COUNT(DISTINCT l.user_id), 0) + COALESCE(COUNT(DISTINCT c.id), 0) AS total_engagement
    FROM photos p
    LEFT JOIN likes l ON p.id = l.photo_id
    LEFT JOIN comments c ON p.id = c.photo_id
    GROUP BY p.id
),
HashtagEngagement AS 
(
    SELECT 
        t.id AS tag_id,
        t.tag_name,
        COALESCE(SUM(pe.total_engagement), 0) AS total_engagement
    FROM tags t
    LEFT JOIN photo_tags pt ON t.id = pt.tag_id
    LEFT JOIN PhotoEngagement pe ON pt.photo_id = pe.photo_id
    GROUP BY t.id, t.tag_name
)
SELECT 
    tag_name,
    total_engagement
FROM HashtagEngagement
ORDER BY total_engagement DESC;


-- 4. Are there any patterns or trends in user engagement based on demographics (age, location, gender) or posting times? 
-- 	  How can these insights inform targeted marketing campaigns?


SELECT id, username, account_date, engagement 
FROM (
    SELECT u.id, u.username, 
           DATE_FORMAT(u.created_at, '%Y-%m') AS account_date, 
           IFNULL(p.posts_count, 0) + IFNULL(l.likes_count, 0) + IFNULL(c.comments_count, 0) AS engagement, 
           DENSE_RANK() OVER(ORDER BY IFNULL(p.posts_count, 0) + IFNULL(l.likes_count, 0) + IFNULL(c.comments_count, 0) DESC) AS ranking
    FROM users u
    LEFT JOIN (
        SELECT user_id, COUNT(id) AS posts_count
        FROM photos
        GROUP BY 1
    ) p ON u.id = p.user_id
    LEFT JOIN (
        SELECT user_id, COUNT(user_id) AS likes_count
        FROM likes 
        GROUP BY 1
    ) l ON u.id = l.user_id
    LEFT JOIN (
        SELECT user_id, COUNT(id) AS comments_count
        FROM comments 
        GROUP BY 1
    ) c ON u.id = c.user_id
    GROUP BY 1, 2, 3
) dt 
WHERE ranking = 1;





-- 5.	Based on follower counts and engagement rates, which users would be ideal candidates for influencer marketing campaigns? 
--      How would you approach and collaborate with these influencers?



WITH followers AS(
SELECT u.id user_id
, username
, COUNT(follower_id) AS follower_count
FROM users u 
LEFT JOIN follows f ON u.id=f.followee_id
GROUP BY 1,2
),

-- ENGAGEMENT OF EACH USER 
engagement AS(
SELECT u.id AS user_id
,username
,p.id AS photo_id
,(COUNT(DISTINCT c.user_id)+ COUNT(DISTINCT l.user_id)) AS engagement_recieved
FROM users u 
LEFT JOIN photos p ON u.id=p.user_id
LEFT JOIN comments c ON c.photo_id=p.id
LEFT JOIN likes l ON l.photo_id=p.id
GROUP BY 1,2,3
),

-- potential influencers
influencers AS(
SELECT f.user_id
, f.username
, follower_count
, (SUM(engagement_recieved)/follower_count) avg_engagement_rate
FROM followers f 
JOIN engagement e ON f.user_id=e.user_id
GROUP BY 1,2,3
)

-- Identifying influencers with high follower count and high engagement_rate
SELECT * FROM influencers
ORDER BY 3 DESC, 4 DESC
LIMIT 5;

-- 6.	Based on user behavior and engagement data, 
-- 		how would you segment the user base for targeted marketing campaigns or personalized recommendations?


WITH photoengagementCTE AS 
(
    SELECT
        p.id AS photo_id,
        p.user_id,
        COUNT(DISTINCT l.user_id) AS like_count,
        COUNT(DISTINCT c.id) AS comment_count
    FROM photos p
	LEFT JOIN likes l ON p.id = l.photo_id
	LEFT JOIN comments c ON p.id = c.photo_id
    GROUP BY p.id
),
usersinvolveCTE AS 
(
    SELECT
        pe.user_id,
        SUM(pe.like_count) AS total_likes,
        SUM(pe.comment_count) AS total_comments,
        SUM(pe.like_count + pe.comment_count) AS total_engagement
    FROM photoengagementCTE pe
    GROUP BY pe.user_id
)
SELECT
    ue.user_id,
    u.username,
    ue.total_likes,
    ue.total_comments,
    ue.total_engagement,
    rank() over (order by ue.total_engagement desc) AS ranks
FROM usersinvolveCTE ue
JOIN users u ON ue.user_id = u.id
ORDER BY ue.total_engagement DESC;


-- 8.	How can you use user activity data to identify potential brand ambassadors or advocates 
--      who could help promote Instagram's initiatives or events?


WITH followers AS(
	SELECT u.id user_id,
	username,
	COUNT(follower_id) AS follower_count
	FROM users u 
	LEFT JOIN follows f ON u.id=f.followee_id
	GROUP BY 1,2
),

-- ENGAGEMENT OF EACH USER 
engagement AS(
	SELECT u.id AS user_id,
	username,
	p.id AS photo_id,
	COUNT(DISTINCT c.user_id) comments,
	COUNT(DISTINCT l.user_id) likes 
	FROM users u 
	LEFT JOIN photos p ON u.id=p.user_id
	LEFT JOIN comments c ON c.photo_id=p.id
	LEFT JOIN likes l ON l.photo_id=p.id
	GROUP BY 1,2,3
)

-- potential brand ambassadors  
SELECT f.user_id,
f.username,
follower_count,
SUM(comments) + SUM(likes) total_likes
FROM followers f 
JOIN engagement e ON f.user_id=e.user_id
WHERE follower_count = (SELECT MAX(follower_count) FROM followers)
GROUP BY 1,2,3 
ORDER BY 4 DESC LIMIT 4;






-- 10.	Assuming there's a "User_Interactions" table tracking user engagements, 
-- 		how can you update the "Engagement_Type" column to change all instances of "Like" to "Heart" to align with Instagram's terminology?


UPDATE User_Interactions
SET Engagement_Type = 'Heart'
WHERE Engagement_Type = 'Like';

