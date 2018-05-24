
CONSTANT WS_VER = 3

TYPE t_param_rec RECORD
	custid STRING,
	jobid STRING,
	jobref STRING
END RECORD

TYPE  t_ws_reply_rec RECORD
		ver SMALLINT,
		stat SMALLINT,
		type STRING,
		reply STRING
	END RECORD

TYPE t_img_info RECORD
		username STRING,
		custid INTEGER,
		jobid STRING,
		jobref STRING,
		uri STRING,
		filename STRING,
		filesize STRING,
		type STRING,
		timestamp STRING,
		id STRING,
		sent_ok BOOLEAN,
		send_reply STRING
	END RECORD
