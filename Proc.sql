/* ----- TRIGGERS     ----- */
/* Trigger 1 */
CREATE OR REPLACE FUNCTION check_user()
RETURNS TRIGGER AS $$
DECLARE
 assigned INT := 0;
BEGIN
 SELECT COUNT(*) INTO assigned
 FROM Creators C
 WHERE NEW.email = C.email;
 IF assigned = 0 THEN
   SELECT COUNT(*) INTO assigned
   FROM Backers B
   WHERE NEW.email = B.email;
 END IF;
 IF assigned = 0 THEN
   DELETE FROM Users U WHERE U.email=NEW.email;
   RAISE EXCEPTION 'User has to a backer or creator or both';
   RETURN NULL;
 
 ELSE
   RETURN NEW;
 END IF;
END;
$$ LANGUAGE plpgsql;
 
CREATE CONSTRAINT TRIGGER check_user_type
AFTER INSERT ON Users /*deferrable so only AFTER*/
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_user();


/* Trigger 2 */
CREATE OR REPLACE FUNCTION trigger2_func() RETURNS TRIGGER AS $$
DECLARE
    min NUMERIC;
BEGIN
    SELECT min_amt INTO min
    FROM Rewards
    WHERE Rewards.id = NEW.id AND NEW.name = Rewards.name;
 
    IF min > NEW.amount THEN
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger2
BEFORE
    INSERT
    ON Backs
FOR EACH ROW EXECUTE FUNCTION trigger2_func();

/*Trigger 3*/
CREATE OR REPLACE FUNCTION do_not_add_project()
RETURNS TRIGGER AS $$
DECLARE
    reward_counter NUMERIC;  --Determine the count of the number of reward level
BEGIN
    SELECT COUNT(*) INTO reward_counter
    FROM Rewards AS R
    WHERE R.id = NEW.id;
   
    IF reward_counter > 0 THEN  
        RETURN NEW;   -- Allow adding project, since there exists rewards
    ELSE -- When no reward is available
        RAISE NOTICE 'Project not added! Reason: ';
        RAISE NOTICE 'Adding a project';
        RAISE NOTICE 'without any reward level!';
        RETURN NULL;  
    END IF;
END;
$$ LANGUAGE plpgsql;
 
CREATE TRIGGER reject_adding_project
BEFORE INSERT ON Projects
FOR EACH ROW  
EXECUTE FUNCTION do_not_add_project();

/*Trigger 4*/
CREATE OR REPLACE FUNCTION processing_the_refund()
RETURNS TRIGGER AS $$
DECLARE
    request_date DATE;  --Determine whether refund is requested or not
    project_deadline DATE; -- Project deadline  
BEGIN
    SELECT deadline INTO project_deadline  
    FROM Projects AS P
    WHERE P.id = NEW.pid;
   
    SELECT request INTO request_date
    FROM Backs AS B
    WHERE B.email = NEW.email
    AND B.id = NEW.pid;
   
    IF request_date IS NULL THEN
        RETURN NULL; -- No request, do not process refund
    ELSE -- When refund is requested
        IF request_date - project_deadline > 90 THEN
            RETURN (NEW.email,NEW.pid,NEW.eid,NEW.date,'false');
        ELSE
            RETURN NEW;
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql;
 
CREATE TRIGGER process_refund
BEFORE INSERT ON Refunds
FOR EACH ROW  
EXECUTE FUNCTION processing_the_refund();

/* Trigger 6*/
CREATE OR REPLACE FUNCTION trigger5_func() RETURNS TRIGGER AS
$$
DECLARE
    created_date DATE;
    deadline_date DATE;
BEGIN
    SELECT created, deadline_date INTO created_date, deadline_date
    FROM Projects
    WHERE Projects.id = NEW.id;  
 
    IF NEW.request - created_date < 0 OR deadline_date - NEW.request > 0 THEN
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;
 
CREATE TRIGGER trigger5
BEFORE
    INSERT
    ON Backs
FOR EACH ROW EXECUTE FUNCTION trigger5_func();

/* Trigger 5*/
CREATE OR REPLACE FUNCTION trigger6_func() RETURNS TRIGGER AS
$$
DECLARE
    total NUMERIC;
    goal NUMERIC;
    deadline DATE;
BEGIN
    SELECT SUM(amount) INTO total
    FROM Backs
    WHERE Backs.id = New.id;
 
    SELECT Projects.goal, Projects.deadline INTO goal, deadline
    FROM Projects
    WHERE NEW.id = Projects.id;
 
    IF total >= goal AND NEW.request - deadline > 0 THEN
        RETURN NEW;
    ELSE
        RETURN NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;
 
CREATE TRIGGER trigger6
BEFORE
    UPDATE
    ON Backs
FOR EACH ROW EXECUTE FUNCTION trigger6_func();

/* ------------------------ */





/* ----- PROECEDURES  ----- */
/* Procedure #1 */
CREATE OR REPLACE PROCEDURE add_user(
 email TEXT, name    TEXT, cc1  TEXT,
 cc2   TEXT, street  TEXT, num  TEXT,
 zip   TEXT, country TEXT, kind TEXT
) AS $$
BEGIN
 IF kind IN ('BACKER','CREATOR','BOTH') THEN
   INSERT INTO Users(email,name,cc1,cc2)
   VALUES (email,name,cc1,cc2);
 
   IF kind='BACKER' THEN --should we use LIKE or =
     INSERT INTO Backers(email,street,num,zip,country)
     VALUES (email,street,num,zip,country);
 
   ELSIF kind='CREATOR' THEN
     INSERT INTO Creators(email,country)
     VALUES (email,country);
   ELSE
     INSERT INTO Backers(email,street,num,zip,country)
     VALUES (email,street,num,zip,country);
 
     INSERT INTO Creators(email,country)
     VALUES (email,country);
   END IF;
 END IF;
END;
$$ LANGUAGE plpgsql;


/* Procedure #2 */
CREATE OR REPLACE PROCEDURE add_project(
 id      INT,     email TEXT,   ptype    TEXT,
 created DATE,    name  TEXT,   deadline DATE,
 goal    NUMERIC, names TEXT[],
 amounts NUMERIC[]
) AS $$
DECLARE
    n INT;
BEGIN
    n := array_length(names, 1);
    IF n > 0 THEN
        WITH ins1 AS (
        INSERT INTO Projects VALUES (id,email,ptype,created,name,deadline,goal)
        )
        INSERT INTO Rewards VALUES (names[1], id, amounts[1]);
        FOR idx in 2..n
        LOOP
            INSERT INTO Rewards(name, id, min_amt)
                VALUES (names[idx], id, amounts[idx]);
        END LOOP;
    END IF;
END;
$$ LANGUAGE plpgsql;


/* Procedure #3 */
CREATE OR REPLACE PROCEDURE auto_reject(
  eid INT, today DATE
) AS $$
BEGIN
    UPDATE Refunds
    SET date = today AND accepted = FALSE
    FROM (SELECT Refunds.email, Refunds.eid
        FROM Refunds, Projects
        WHERE Refunds.eid = eid AND Refunds.date - Projects.deadline > 90) AS auto_failed
    WHERE auto_failed.email = Refunds.email AND auto_failed.eid = Refunds.eid;
END;
$$ LANGUAGE plpgsql;
/* ------------------------ */





/* ----- FUNCTIONS    ----- */
/* Function #1  */
/* ----- FUNCTIONS    ----- */
/* Function #1  */
CREATE OR REPLACE FUNCTION find_superbackers(
  today DATE
) RETURNS TABLE(email TEXT, name TEXT) AS $$
-- add declaration here
DECLARE
  curs CURSOR FOR (SELECT Backers.email FROM Backers ORDER BY email ASC);
  r RECORD;
  successful_projects_count INTEGER;
  successful_projects_type_count INTEGER;
  condition_a BOOLEAN;  
  condition_b BOOLEAN;
BEGIN
  email:= '-1';
  today := CURRENT_DATE;
  OPEN curs;
  LOOP
    FETCH curs INTO r;
  EXIT WHEN NOT FOUND;
    IF r.email <> email OR NOT FOUND THEN  
        IF email <> '-1' THEN
            IF NOT EXISTS(SELECT 1 FROM Verifies V WHERE V.email = r.email) THEN
        CONTINUE;
            ELSIF NOT condition_A AND NOT condition_b THEN  
        CONTINUE;
            ELSE  
                name := name;
            END IF;
            condition_a := FALSE;
            condition_b := FALSE;    
        END IF;
    email := r.email;
    SELECT U.name FROM Users U WHERE U.email = r.email INTO name;    
    ELSE
        -- We gather condition A and condition B from backer
        -- Condition A
        SELECT COUNT(id),COUNT(DISTINCT ptype) INTO successful_projects_count, successful_projects_type_count
        FROM (SELECT * FROM Backs B INNER JOIN
        Projects P ON B.email = P.email AND B.id = P.id
        WHERE r.email = B.email
        GROUP BY P.id
        HAVING SUM(B.amount) > P.goal) AS P
       
        WHERE P.email = r.email
       
        AND today - deadline <= 30
       
        GROUP BY email;
       
        
        IF successful_projects_count >= 5 AND successful_projects_type_count >= 3 THEN
            condition_a := TRUE;
        END IF;
       
        -- Condition B  
        IF ALL(SELECT amount FROM Backs B INNER JOIN
        Projects P ON B.email = P.email AND B.id = P.id WHERE r.email = B.email AND request IS NULL AND today - deadline <= 30
        GROUP BY P.id
        HAVING SUM(B.amount) > P.goal)>= 1500 AND
        NOT EXISTS(SELECT 1 FROM Refunds Re WHERE Re.email = r.email) THEN
            condition_b := TRUE;
        END IF;
    END IF;
  RETURN NEXT;
    END LOOP;
    CLOSE curs;
    RETURN;
END;
$$ LANGUAGE plpgsql;



/* Function #2  */
CREATE OR REPLACE FUNCTION find_top_success(
  n INT, today DATE, ptype TEXT
) RETURNS TABLE(id INT, name TEXT, email TEXT,
                amount NUMERIC) AS $$
	SELECT pj.id, pj.name, pj.email, s.total
	FROM Projects pj,
		(SELECT pj.id, SUM(b.amount) AS total, SUM(b.amount)/pj.goal AS funding_ratio
		FROM Projects pj, Backs b
		WHERE pj.ptype = $3 AND pj.id = b.id AND $2 - pj.deadline > 0
		GROUP BY pj.id) AS s(id, total, funding_ratio)
	WHERE pj.id = s.id AND s.total >= pj.goal
	ORDER BY funding_ratio DESC, pj.deadline DESC, pj.id DESC
	LIMIT $1;
$$ LANGUAGE sql;




/* Function #3  */
CREATE OR REPLACE FUNCTION find_top_popular(
  n INT, today DATE, ptype TEXT
) RETURNS TABLE(id INT, name TEXT, email TEXT,
                days INT) AS $$
DECLARE
  type TEXT := ptype;
BEGIN
  RETURN QUERY
  SELECT *
  FROM (SELECT DISTINCT p.id, p.name, p.email, num_of_days_to_reach_goal(today, p.id) AS days
  FROM Projects p, ProjectTypes pt
  WHERE p.ptype = type
  ORDER BY days ASC, id ASC
  LIMIT n) temp_table(id, name, email, days)
  ORDER BY days DESC, id DESC;
END;
$$ LANGUAGE plpgsql;
 
CREATE OR REPLACE FUNCTION num_of_days_to_reach_goal(
  today DATE, p_id INT
) RETURNS INT AS $$
DECLARE
  curs CURSOR FOR (SELECT * FROM Backs WHERE Backs.id = p_id AND today - backing > 0 ORDER BY backing ASC);
  r RECORD;
  goal INT;
  progress INT := 0;
  days INT := 2147483647;
BEGIN
  SELECT Projects.goal INTO goal
  FROM Projects
  WHERE Projects.id = p_id;
 
  OPEN curs;
  LOOP
    FETCH curs INTO r;
    EXIT WHEN NOT FOUND;
    progress := progress + r.amount;
    IF progress >= goal THEN
      days := today - r.backing;
      EXIT;
    END IF;
  END LOOP;
  CLOSE curs;
  RETURN days;
END;
$$ LANGUAGE plpgsql;
/* ------------------------ */