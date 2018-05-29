
-- This modulbe contains Application specific code.

IMPORT util

IMPORT FGL gl_lib
IMPORT FGL gl_resources
IMPORT FGL mob_ws_lib

&include "mob_lib.inc"
&include "mob_ws_lib.inc"

PUBLIC DEFINE m_sel_list1 DYNAMIC ARRAY OF RECORD
		key STRING,
		line1 STRING,
		line2 STRING
	END RECORD
PUBLIC DEFINE m_sel_list2 DYNAMIC ARRAY OF RECORD
		key STRING,
		line1 STRING,
		line2 STRING
	END RECORD

PUBLIC DEFINE m_dets1 RECORD
		customer_code					char(8),
		customer_name					varchar(30,0),
		contact_name					varchar(30,0),
		email									varchar(100,0),
		web_passwd						char(10),
		del_addr							integer,
		inv_addr							integer,
		disc_code							char(2),
		credit_limit					integer,
		total_invoices				decimal(12,2),
		outstanding_amount		decimal(12,2),
		updated_date 					DATETIME YEAR TO SECOND
	END RECORD

PUBLIC DEFINE m_list1_date, m_list2_date DATETIME YEAR TO SECOND
PUBLIC DEFINE m_welcome STRING
PUBLIC DEFINE m_apptitle STRING
PUBLIC DEFINE m_logo STRING
PUBLIC DEFINE m_param t_param_rec


FUNCTION init_app()

	LET m_apptitle = gl_resources.gl_getResource("mob_apptitle","Genero Mobile Demo")
	LET m_welcome = gl_resources.gl_getResource("mob_welcome","Welcome to a Simple GeneroMobile Demo Application")
	LET m_logo = gl_resources.gl_getResource("mob_icon","demoicon")

	LET m_param.custId = gl_resources.gl_getResource("param.custId","159")
	LET m_param.jobId = gl_resources.gl_getResource("param.jobId","45546465467")
	LET m_param.jobRef = gl_resources.gl_getResource("param.jobRef","DUMMY")

	LET g_ws_uri = gl_resources.gl_getResource("mob_ws_url","")

END FUNCTION
--------------------------------------------------------------------------------
FUNCTION init_app_db()
	TRY
		DROP TABLE sel_list1
	CATCH
	END TRY
	CREATE TABLE sel_list1 (
		key CHAR(12),
		line1 CHAR(50),
		line2 CHAR(50)
	)

	TRY
		DROP TABLE sel_list2
	CATCH
	END TRY
	CREATE TABLE sel_list2 (
		key CHAR(12),
		line1 CHAR(50),
		line2 CHAR(50)
	)

	TRY
		DROP TABLE dets1
	CATCH
	END TRY
	CREATE TABLE dets1 (
		customer_code        char(8),
		customer_name        varchar(30,0),
		contact_name         varchar(30,0),
		email                varchar(100,0),
		web_passwd           char(10),
		del_addr             integer,
		inv_addr             integer,
		disc_code            char(2),
		credit_limit         integer,
		total_invoices       decimal(12,2),
		outstanding_amount   decimal(12,2),
		updated_date DATETIME YEAR TO SECOND
	)
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION get_list1(l_user STRING) RETURNS BOOLEAN
	DEFINE x SMALLINT
	DEFINE l_json STRING
	DEFINE l_user_local BOOLEAN
	DEFINE l_updated_date DATETIME YEAR TO SECOND
	DEFINE l_now DATETIME YEAR TO SECOND

	LET l_user_local = FALSE
	LET l_now = CURRENT
	SELECT updated_date INTO l_updated_date FROM table_updated WHERE table_name = "sel_list1"
	IF l_updated_date IS NOT NULL
	AND l_updated_date > ( l_now - 1 UNITS DAY ) THEN
		LET l_user_local = TRUE
	END IF

	IF NOT check_network() THEN -- no connection
		IF NOT l_user_local AND l_updated_date IS NOT NULL THEN -- stale data
			CALL gl_lib.gl_winMessage("Warning",SFMT("Data is from %1\nYou are not connected to a network",l_updated_date),"exclamation")
			LET l_user_local = TRUE
		END IF
		IF l_updated_date IS NULL THEN -- no data
			CALL gl_lib.gl_winMessage("Error","No local data and no connection!","exclamation")
			LET m_list1_date = NULL
			RETURN FALSE
		END IF
	END IF

	IF l_user_local THEN
		CALL m_sel_list1.clear()
		DECLARE cust_cur CURSOR FOR SELECT * FROM sel_list1
		FOREACH cust_cur INTO m_sel_list1[ m_sel_list1.getLength() + 1].*
		END FOREACH
		CALL m_sel_list1.deleteElement( m_sel_list1.getLength() )
		LET m_list1_date = l_updated_date
		RETURN TRUE
	END IF

	LET l_json = mob_ws_lib.ws_call("getList1", l_user)
	IF l_json IS NULL THEN RETURN FALSE END IF

	CALL util.JSON.parse(l_json, m_sel_list1 )
	DELETE FROM sel_list1
	FOR x = 1 TO m_sel_list1.getLength()
		INSERT INTO sel_list1 VALUES( m_sel_list1[x].* )
	END FOR
	LET m_list1_date = l_now
	DELETE FROM table_updated WHERE table_name = "sel_list1"
	INSERT INTO table_updated VALUES("sel_list1",l_now )
	MESSAGE m_sel_list1.getLength()," from server"
	DISPLAY m_sel_list1.getLength()," from server"
	RETURN TRUE
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION get_dets1(l_key STRING) RETURNS BOOLEAN
	DEFINE l_json STRING
	DEFINE l_now DATETIME YEAR TO SECOND

	INITIALIZE m_dets1.* TO NULL
	SELECT * INTO m_dets1.* FROM dets1 WHERE customer_code = l_key

	LET l_now = CURRENT
	IF m_dets1.updated_date IS NOT NULL
	AND m_dets1.updated_date > ( l_now - 1 UNITS DAY ) THEN
		RETURN TRUE -- got data from DB
	ELSE
		IF NOT check_network() THEN
			CALL gl_lib.gl_winMessage("Error","Not connected and Data not available locally","exclamation")
			RETURN FALSE
		END IF
	END IF

	LET l_json = mob_ws_lib.ws_call("getDets1", l_key )
	IF l_json IS NULL THEN RETURN FALSE END IF

	CALL util.JSON.parse(l_json, m_dets1)
	LET m_dets1.updated_date = l_now
	DELETE FROM dets1 WHERE customer_code = l_key
	INSERT INTO dets1 VALUES(m_dets1.*)
	RETURN TRUE
END FUNCTION