----------------------------

-- 질문 게시글 관련 댓글 및 알림

-- 댓글 조회
SELECT *
FROM reply
WHERE inquiry_id = ? AND reply_parent_id IS NULL AND reply_deleted_at IS NULL
ORDER BY reply_created_at;


--댓글 수정
UPDATE reply
SET reply_content = ?, reply_modified_at = NOW()
WHERE reply_id = ? AND reply_deleted_at IS NULL;

-- 댓글 삭제 + 대댓글 삭제
DELIMITER //

CREATE PROCEDURE delete_comment_and_replies (
    IN p_reply_id BIGINT
)
BEGIN
    DECLARE is_parent_comment BOOLEAN;

    -- 해당 댓글이 부모 댓글인지 확인
    SELECT reply_parent_id IS NULL INTO is_parent_comment
    FROM reply
    WHERE reply_id = p_reply_id;

    -- 부모 댓글일 경우: 자신과 대댓글들 soft delete
    IF is_parent_comment THEN
        -- 부모 댓글 soft delete
        UPDATE reply
        SET reply_deleted_at = NOW()
        WHERE reply_id = p_reply_id;

        -- 대댓글들 soft delete
        UPDATE reply
        SET reply_deleted_at = NOW()
        WHERE reply_parent_id = p_reply_id;

    ELSE
        -- 대댓글일 경우: 해당 대댓글만 soft delete
        UPDATE reply
        SET reply_deleted_at = NOW()
        WHERE reply_id = p_reply_id;
    END IF;
END //

DELIMITER ;


-- 댓글 생성 프로시저
DELIMITER //

CREATE PROCEDURE add_comment_and_alert (
    IN p_user_id BIGINT,
    IN p_inquiry_id BIGINT,
    IN p_reply_content VARCHAR(255)
)
BEGIN
    DECLARE post_owner_id BIGINT;

    -- 댓글 등록
    INSERT INTO reply (user_id, inquiry_id, reply_content)
    VALUES (p_user_id, p_inquiry_id, p_reply_content);

    -- 게시글 작성자 확인
    SELECT user_id INTO post_owner_id
    FROM inquiry
    WHERE inquiry_id = p_inquiry_id;

    -- 알림: 게시글 작성자에게만 (자기 자신이 아닌 경우)
    IF post_owner_id != p_user_id THEN
        INSERT INTO alerts (user_id, inquiry_id, notice_message)
        VALUES (post_owner_id, p_inquiry_id, '새 댓글이 달렸습니다.');
    END IF;
END //

DELIMITER ;

-- 대댓글 조회
SELECT *
FROM reply
WHERE reply_parent_id = ? AND reply_deleted_at IS NULL
ORDER BY reply_created_at;

-- 대댓글 수정
UPDATE reply
SET reply_content = ?, reply_modified_at = NOW()
WHERE reply_id = ? AND reply_deleted_at IS NULL;

-- 대댓글 삭제
UPDATE reply
SET reply_deleted_at = NOW()
WHERE reply_id = ? 
  AND reply_parent_id IS NOT NULL;




-- 대댓글 생성 프로시저
DELIMITER //

CREATE PROCEDURE add_reply_to_reply_and_alert (
    IN p_user_id BIGINT,
    IN p_inquiry_id BIGINT,
    IN p_reply_parent_id BIGINT,
    IN p_reply_content VARCHAR(255)
)
BEGIN
    DECLARE parent_writer_id BIGINT;
    DECLARE post_owner_id BIGINT;
    DECLARE parent_inquiry_id BIGINT;

    -- 부모 댓글의 게시글 ID 확인
    SELECT inquiry_id, user_id INTO parent_inquiry_id, parent_writer_id
    FROM reply
    WHERE reply_id = p_reply_parent_id;

    -- 부모 댓글의 게시글 ID가 다르면 예외 처리
    IF parent_inquiry_id != p_inquiry_id THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '대댓글의 부모 댓글이 해당 게시글에 존재하지 않습니다.';
    END IF;

    -- 대댓글 등록
    INSERT INTO reply (user_id, inquiry_id, reply_content, reply_parent_id, reply_created_at)
    VALUES (p_user_id, p_inquiry_id, p_reply_content, p_reply_parent_id, NOW());

    -- 게시글 작성자
    SELECT user_id INTO post_owner_id
    FROM inquiry
    WHERE inquiry_id = p_inquiry_id;

    -- 알림: 부모 댓글 작성자에게 (자기 자신이 아닌 경우)
    IF parent_writer_id != p_user_id THEN
        INSERT INTO alerts (user_id, reply_id, notice_message)
        VALUES (parent_writer_id, p_reply_parent_id, '내 댓글에 대댓글이 달렸습니다.');
    END IF;

    -- 알림: 게시글 작성자에게도 (자기 자신이 아닌 경우)
    IF post_owner_id != p_user_id AND post_owner_id != parent_writer_id THEN
        INSERT INTO alerts (user_id, inquiry_id, notice_message)
        VALUES (post_owner_id, p_inquiry_id, '게시글에 새로운 댓글이 달렸습니다.');
    END IF;
END //

DELIMITER ;

---------------
---- 피해 게시물 댓글 및 알림 관련

-- 피해게시글 댓글조회
SELECT *
FROM reply
WHERE post_id = ? AND reply_parent_id IS NULL AND reply_deleted_at IS NULL
ORDER BY reply_created_at;

-- 피해게시글 댓글수정 
UPDATE reply
SET reply_content = ?, reply_modified_at = NOW()
WHERE reply_id = ? AND reply_deleted_at IS NULL;

-- 피해게시글 댓글삭제 + 대댓글 삭제
DELIMITER //

CREATE PROCEDURE delete_comment_and_replies (
    IN p_reply_id BIGINT
)
BEGIN
    DECLARE is_parent_comment BOOLEAN;

    -- 부모 댓글 여부 확인
    SELECT reply_parent_id IS NULL INTO is_parent_comment
    FROM reply
    WHERE reply_id = p_reply_id;

    IF is_parent_comment THEN
        -- 부모 댓글 삭제
        UPDATE reply
        SET reply_deleted_at = NOW()
        WHERE reply_id = p_reply_id;

        -- 대댓글 삭제
        UPDATE reply
        SET reply_deleted_at = NOW()
        WHERE reply_parent_id = p_reply_id;
    ELSE
        -- 대댓글만 삭제
        UPDATE reply
        SET reply_deleted_at = NOW()
        WHERE reply_id = p_reply_id;
    END IF;
END//

DELIMITER ;

-- 피해게시글 대댓글 조회
SELECT *
FROM reply
WHERE reply_parent_id = ? AND reply_deleted_at IS NULL
ORDER BY reply_created_at;

-- 피해게시글 대댓글 수정
UPDATE reply
SET reply_content = ?, reply_modified_at = NOW()
WHERE reply_id = ? AND reply_deleted_at IS NULL

-- 댓글 달기 + 알림생성
DELIMITER //

CREATE PROCEDURE add_post_comment_and_alert (
    IN p_user_id BIGINT,
    IN p_post_id BIGINT,
    IN p_reply_content VARCHAR(255)
)
BEGIN
    DECLARE post_owner_id BIGINT;

    -- 댓글 등록
    INSERT INTO reply (user_id, post_id, reply_content)
    VALUES (p_user_id, p_post_id, p_reply_content);

    -- 게시글 작성자 확인
    SELECT user_id INTO post_owner_id
    FROM post
    WHERE post_id = p_post_id;

    -- 알림: 게시글 작성자에게만 (자기 자신이 아닌 경우)
    IF post_owner_id != p_user_id THEN
        INSERT INTO alerts (user_id, post_id, notice_message)
        VALUES (post_owner_id, p_post_id, '새 댓글이 달렸습니다.');
    END IF;
END;
//

DELIMITER ;
-- 대댓글달기 + 알림생성
DELIMITER //

CREATE PROCEDURE add_reply_to_reply_on_post_and_alert (
    IN p_user_id BIGINT,
    IN p_post_id BIGINT,
    IN p_reply_parent_id BIGINT,
    IN p_reply_content VARCHAR(255)
)
BEGIN
    DECLARE parent_writer_id BIGINT;
    DECLARE parent_post_id BIGINT;
    DECLARE post_owner_id BIGINT;

    -- 부모 댓글의 게시글 ID 확인
    SELECT post_id, user_id INTO parent_post_id, parent_writer_id
    FROM reply
    WHERE reply_id = p_reply_parent_id;

    -- 부모 댓글이 해당 게시글에 달린 게 맞는지 확인
    IF parent_post_id != p_post_id THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '대댓글의 부모 댓글이 해당 게시글에 존재하지 않습니다.';
    END IF;

    -- 대댓글 등록
    INSERT INTO reply (
        user_id, post_id, reply_content, reply_parent_id, reply_created_at
    ) VALUES (
        p_user_id, p_post_id, p_reply_content, p_reply_parent_id, NOW()
    );

    -- 게시글 작성자 확인
    SELECT user_id INTO post_owner_id
    FROM post
    WHERE post_id = p_post_id;

    -- 알림: 부모 댓글 작성자에게 (자기 자신이 아닌 경우)
    IF parent_writer_id != p_user_id THEN
        INSERT INTO alerts (user_id, reply_id, notice_message)
        VALUES (parent_writer_id, p_reply_parent_id, '내 댓글에 대댓글이 달렸습니다.');
    END IF;

    -- 알림: 게시글 작성자에게도 (자기 자신이 아닌 경우)
    IF post_owner_id != p_user_id AND post_owner_id != parent_writer_id THEN
        INSERT INTO alerts (user_id, post_id, notice_message)
        VALUES (post_owner_id, p_post_id, '게시글에 새로운 댓글이 달렸습니다.');
    END IF;
END;
//

DELIMITER ;


