INSERT INTO Users VALUES
    ('user1_email', 'user1', 'user1_cc1', 'user1_cc2'),
    ('user2_email', 'user2', 'user2_cc1', 'user2_cc2'),
    ('user3_email', 'user3', 'user3_cc1', 'user3_cc2'),
    ('user4_email', 'user4', 'user4_cc1', 'user4_cc2');

INSERT INTO Creators VALUES
    ('user1_email', 'user1_ct'),
    ('user3_email', 'user3_ct'),
    ('user4_email', 'user4_ct');
	
INSERT INTO Backers VALUES
    ('user2_email', 'user2_street', 'user2_num', 'user2_zip', 'user2_ct'),
    ('user3_email', 'user3_street', 'user3_num', 'user3_zip', 'user3_ct');

INSERT INTO Employees VALUES
    (1, 'employee1', 4000),
    (2, 'employee2', 5000);
	
INSERT INTO ProjectTypes VALUES
    ('p1_type', 1),
    ('p2_type', 2),
    ('p3_type', 2),
    ('p4_type', 1),
    ('p5_type', 2);
	
INSERT INTO Projects VALUES
    (1, 'user1_email', 'p1_type', current_timestamp, 'p1', CURRENT_TIMESTAMP, 200),
    (2, 'user3_email', 'p2_type', current_timestamp, 'p2', current_timestamp, 300),
    (3, 'user4_email', 'p3_type', current_timestamp, 'p3', current_timestamp, 300),
    (4, 'user4_email', 'p4_type', current_timestamp, 'p4', current_timestamp, 100),
    (5, 'user4_email', 'p5_type', current_timestamp, 'p5', current_timestamp, 50);

INSERT INTO Rewards VALUES
    ('rw1', 1, 50),
    ('rw2', 2, 40),
    ('rw3', 3, 45),
    ('rw4', 4, 30),
    ('rw5', 5, 20);

INSERT INTO Backs VALUES
    ('user2_email', 'rw1', 1, CURRENT_TIMESTAMP, NULL, 100),
    ('user3_email', 'rw2', 2, CURRENT_TIMESTAMP, NULL, 200),
    ('user2_email', 'rw2', 2, CURRENT_TIMESTAMP, NULL, 100),
    ('user3_email', 'rw3', 3, CURRENT_TIMESTAMP, NULL, 150),
    ('user2_email', 'rw4', 4, CURRENT_TIMESTAMP, NULL, 100),
    ('user2_email', 'rw5', 5, CURRENT_TIMESTAMP, NULL, 100),
    ('user2_email', 'rw3', 3, CURRENT_TIMESTAMP, NULL, 300),
    ('user3_email', 'rw1', 1, CURRENT_TIMESTAMP, NULL, 100);

INSERT INTO Verifies VALUES
    ('user2_email', 1, CURRENT_TIMESTAMP);

