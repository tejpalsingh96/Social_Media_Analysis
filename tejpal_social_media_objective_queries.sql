SELECT * FROM comments;
SELECT * FROM follows;
SELECT * FROM likes;
SELECT * FROM photo_tags;
SELECT * FROM photos;
SELECT * FROM users;
SELECT * FROM tags;

-- 1.	Are there any tables with duplicate or missing null values? If so, how would you handle them?


SELECT * FROM tags
WHERE id IS NULL OR tag_name IS NULL OR created_at IS NULL;

SELECT * FROM users
WHERE id IS NULL OR username IS NULL OR created_at IS NULL;


SELECT * FROM photos
WHERE id IS NULL OR image_url IS NULL OR user_id IS NULL OR created_dat IS NULL;


SELECT * FROM photo_tags
WHERE photo_id IS NULL OR tag_id IS NULL;

SELECT * FROM likes
WHERE user_id IS NULL OR photo_id IS NULL OR created_at IS NULL;


SELECT * FROM follows
WHERE follower_id IS NULL OR followee_id IS NULL OR created_at IS NULL;


SELECT * FROM comments
WHERE id IS NULL OR comment_text IS NULL OR user_id IS NULL OR photo_id IS NULL OR created_at IS NULL;


-- 2.	What is the distribution of user activity levels (e.g., number of posts, likes, comments) across the user base?

With CommentsCTE as
(
select u.id as UserID,count(c.id) as TotalComments
from comments c
join users u on u.id=c.user_id
group by u.id
order by u.id
),
LikesCTE as
(
select u.id as UserID,count(*) as Totallikes
from likes l
join users u on u.id=l.user_id
group by u.id
order by u.id
),
PostCTE as
(
select u.id as UserID,count(*) as TotalPosts
from photos p
join users u on u.id=p.user_id
group by u.id
order by u.id
)
select 
	u.id as UserID,
    TotalComments,
    TotalLikes,
    TotalPosts
from users u
join CommentsCTE c on u.id=c.UserID
join LikesCTE lc on u.id=lc.UserID
join PostCTE pc on u.id=pc.UserID;





-- 3.	Calculate the average number of tags per post (photo_tags and photos tables).

SELECT ROUND(AVG(tag_count),2) AS avg_tags_per_post 
FROM 
	(SELECT photo_id,COUNT(DISTINCT tag_id) AS tag_count
	FROM photo_tags
	GROUP BY 1
    ) count_tags_per_post;





-- 4.	Identify the top users with the highest engagement rates (likes, comments) on their posts and rank them.

WITH likes_comments AS (
SELECT p.id, p.user_id,
		COUNT(DISTINCT c.id) AS count_comments,
        COUNT(DISTINCT l.user_id) AS count_likes
FROM photos p 
LEFT JOIN comments c 
	ON p.id = c.photo_id
LEFT JOIN likes l 
	ON p.id = l.photo_id
GROUP BY p.id
),
user_likes_comments AS (
SELECT user_id,
		SUM(count_likes) AS total_likes,
        SUM(count_comments) AS total_comments,
        SUM(count_comments + count_likes) AS total_engagement
FROM likes_comments 
GROUP BY user_id
)
SELECT u.user_id, u1.username, u.total_likes, u.total_comments, u.total_engagement,
	RANK() OVER(ORDER BY total_engagement DESC) AS user_rank
FROM user_likes_comments u 
JOIN users u1 
	ON u.user_id = u1.id
ORDER BY total_engagement DESC;





-- 5.	Which users have the highest number of followers and followings?


WITH number_of_followers AS (
SELECT follower_id, COUNT(follower_id) AS follower_count
FROM follows
GROUP BY follower_id
),
number_of_followings AS (
SELECT followee_id, COUNT(followee_id) AS followee_count
FROM follows
GROUP BY followee_id
)
SELECT u.id, u.username,
	MAX(follower_count) AS max_followers,
    MAX(followee_count) AS max_followings
FROM users u 
LEFT JOIN number_of_followers fr 
	ON u.id = fr.follower_id
LEFT JOIN number_of_followings fe 
	ON u.id = fe.followee_id
GROUP BY u.id, u.username
ORDER BY max_followers DESC, max_followings DESC, u.id;





-- 6.	Calculate the average engagement rate (likes, comments) per post for each user.


WITH cte AS 
(
    SELECT
        p.id AS photo_id,
        p.user_id,
        count(DISTINCT l.user_id) AS like_count,
        count(DISTINCT c.id) AS comment_count,
        count(DISTINCT l.user_id) + COUNT(DISTINCT c.id) AS total_engagement
    FROM photos p
	LEFT JOIN likes l on p.id = l.photo_id
	LEFT JOIN comments c on p.id = c.photo_id
    GROUP BY p.id
),
cte2 AS 
(
    SELECT
        pe.user_id,
        sum(pe.total_engagement) AS total_engagement,
        count(pe.photo_id) AS post_count
    FROM cte pe
    GROUP BY pe.user_id
)
SELECT
    ue.user_id,
    u.username,
    ue.total_engagement,
    ue.post_count,
    round((ue.total_engagement / ue.post_count),2) AS average_engagement_per_post
FROM cte2 ue
JOIN users u ON ue.user_id = u.id
ORDER BY ue.user_id;





-- 7.	Get the list of users who have never liked any post (users and likes tables)


SELECT id,username
FROM users WHERE id NOT IN (SELECT user_id FROM likes);





-- 8.	How can you leverage user-generated content (posts, hashtags, photo tags) to create more personalized and engaging ad campaigns?

WITH cte AS(
SELECT u.id AS user_id,
	username,
	t.id AS tag_id,
	tag_name,
	COUNT(DISTINCT l.user_id) AS likes,
	COUNT(DISTINCT c.user_id) AS comments,
    DENSE_RANK() OVER(PARTITION BY u.id ORDER BY (COUNT(DISTINCT l.user_id)+COUNT(DISTINCT c.user_id)) DESC) AS engagement_rank
	FROM users u 
JOIN photos p ON u.id=p.user_id
JOIN photo_tags pt ON p.id=pt.photo_id
JOIN tags t ON t.id=pt.tag_id
JOIN likes l ON pt.photo_id=l.photo_id
JOIN comments c ON pt.photo_id=c.photo_id
GROUP BY 1,2,3,4
)
SELECT user_id, username, tag_name FROM cte
WHERE engagement_rank=1;





-- 9.	Are there any correlations between user activity levels and specific content types 
-- 		(e.g., photos, videos, reels)? How can this information guide content creation and curation strategies?



SELECT t.id AS tag_id, tag_name,
COUNT(DISTINCT pt.photo_id) AS photo_id,
COUNT(DISTINCT l.user_id) AS likes,
COUNT(DISTINCT c.user_id) AS comments,
DENSE_RANK() OVER(ORDER BY COUNT(DISTINCT pt.photo_id) DESC,COUNT(DISTINCT l.user_id)DESC,COUNT(DISTINCT c.user_id)) AS engagement_rank
FROM tags t 
LEFT JOIN photo_tags pt ON t.id=pt.tag_id
LEFT JOIN likes l ON pt.photo_id=l.photo_id
LEFT JOIN comments c ON pt.photo_id=c.photo_id
GROUP BY 1,2;





-- 10.	Calculate the total number of likes, comments, and photo tags for each user.


WITH CommentCTE AS
(
SELECT 
	u.id,
    COUNt(*) AS totalcomments
FROM users u
JOIN comments c ON c.user_id=u.id
GROUP BY u.id
ORDER BY u.id DESC
),
LikesCTE AS
(
SELECT 
	u.id,
    COUNt(*) AS totallikes
FROM users u
JOIN likes l ON l.user_id=u.id
GROUP BY u.id
ORDER BY u.id DESC
),
PhototagCTE AS
(
SELECT 
	p.user_id,
    COUNT(*) AS totalPhototags
from photos p
join photo_tags p1 ON p1.photo_id=p.id
GROUP BY p.user_id
ORDER BY p.user_id DESC
)
SELECT 
	user_id,
    totalcomments,
    totallikes,
    totalPhototags
FROM CommentCTE c 
JOIN LikesCTE l ON l.id=c.id
JOIN PhototagCTE p ON p.user_id=c.id;





-- 11.	Rank users based on their total engagement (likes, comments, shares) over a month.


WITH LikesCount AS 
(
    SELECT  p.user_id,
        COUNT(l.photo_id) AS total_likes
    FROM photos p
    LEFT JOIN likes l ON p.id = l.photo_id
    WHERE l.created_at >= NOW() - INTERVAL 1 MONTH
    GROUP BY p.user_id
),
CommentsCount AS 
(
    SELECT 
        p.user_id,
        COUNT(c.photo_id) AS total_comments
    FROM photos p
    LEFT JOIN comments c ON p.id = c.photo_id
    WHERE c.created_at >= NOW() - INTERVAL 1 MONTH
    GROUP BY p.user_id
),
Engagement AS 
(
    SELECT 
        u.id AS user_id,
        u.username,
        COALESCE(l.total_likes, 0) + COALESCE(c.total_comments, 0) AS total_engagement
    FROM users u
    LEFT JOIN LikesCount l ON u.id = l.user_id
    LEFT JOIN CommentsCount c ON u.id = c.user_id
)
SELECT 
    user_id,
    username,
    total_engagement,
    RANK() OVER (ORDER BY total_engagement DESC) AS engagement_rank
FROM Engagement
ORDER BY engagement_rank;




-- 12.	Retrieve the hashtags that have been used in posts with the highest average number of likes. 
-- 		Use a CTE to calculate the average likes for each hashtag first.



WITH tag_name_and_likes AS (
SELECT t.id tag_id,
tag_name,
pt.photo_id,
COUNT( DISTINCT l.user_id) total_likes,
AVG(COUNT( DISTINCT l.user_id)) OVER(PARTITION BY t.id) AS avg_likes
FROM tags t 
LEFT JOIN photo_tags pt ON t.id=pt.tag_id
JOIN likes l ON l.photo_id=pt.photo_id
GROUP BY 1,2,3
)

SELECT DISTINCT tag_id,tag_name
FROM tag_name_and_likes
WHERE avg_likes IN (SELECT MAX(avg_likes) FROM tag_name_and_likes)
ORDER BY 1;





-- 13.	Retrieve the users who have started following someone after being followed by that person


SELECT f1.follower_id AS user1_as_follower,
f1.followee_id AS user2_as_following,
f1.created_at as followed_at,
f2.follower_id AS user2_as_follower,
f2.followee_id AS user1_as_following,
f2.created_at AS followed_back_at
FROM follows f1
JOIN follows f2 ON f1.followee_id=f2.follower_id
AND f1.follower_id=f2.followee_id
WHERE f2.created_at<f1.created_at
ORDER BY 1;
