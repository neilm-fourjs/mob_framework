
-- Mobile Web Service Functions

IMPORT util
IMPORT os
IMPORT com
IMPORT security

IMPORT FGL gl_lib

CONSTANT WS_VER = 2

PUBLIC DEFINE m_security_token STRING
PUBLIC DEFINE m_ret RECORD
		ver SMALLINT,
		stat SMALLINT,
		type STRING,
		reply STRING
	END RECORD

--------------------------------------------------------------------------------
FUNCTION ws_getSecurityToken( l_xml_creds STRING )
-- call the restful service to get the security token
	IF NOT doRestRequest( SFMT("getToken?xml=%1",l_xml_creds)) THEN
		RETURN NULL
	END IF

	IF m_ret.ver != WS_VER THEN
		CALL gl_lib.gl_winMessage("Error",SFMT("Webversion Version Mismatch\nGot %1, expected %2",m_ret.ver,WS_VER),"exclamation")
	END IF

	LET m_security_token = m_ret.reply
	RETURN m_security_token
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION ws_call(l_func STRING, l_key STRING) RETURNS STRING
	IF NOT doRestRequest(SFMT("%1?token=%2&key=%3",l_func,m_security_token,l_key)) THEN
		RETURN NULL
	END IF
	RETURN m_ret.reply
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION ws_putMedia(l_files) RETURNS STRING
	DEFINE l_files DYNAMIC ARRAY OF RECORD
		filename STRING,
		size STRING,
		vid BOOLEAN
	END RECORD
	DEFINE x SMALLINT
	DEFINE l_tS DATETIME YEAR TO SECOND
	DEFINE l_info DYNAMIC ARRAY OF RECORD
		filename STRING,
		filesize STRING,
		type STRING,
		timestamp STRING,
		id STRING
	END RECORD

	LET l_ts = CURRENT
	FOR x = 1 TO l_files.getLength()
		LET l_info[x].filename = l_files[x].filename
		LET l_info[x].filesize = l_files[x].size
		LET l_info[x].timestamp = l_ts
		LET l_info[x].type = IIF(l_files[x].vid,"Video","Photo")
		LET l_info[x].id = security.RandomGenerator.CreateUUIDString()
	END FOR
	IF NOT doRestRequestData(SFMT("sendData?token=%1",m_security_token), util.JSON.stringify(l_info)) THEN
		RETURN NULL
	END IF

	FOR x = 1 TO l_files.getLength()
		IF NOT doRestRequestMedia(SFMT("%1?token=%2",IIF(l_files[x].vid,"putVideo","putPhoto"), m_security_token), l_files[x].filename, l_files[x].vid) THEN
			RETURN NULL
		END IF
	END FOR
	RETURN "Media Sent"
END FUNCTION
--------------------------------------------------------------------------------
-- Send some json data back to server
--
-- @params l_data String JSON data
FUNCTION ws_sendData(l_data STRING) RETURNS STRING
	IF NOT doRestRequestData(SFMT("sendData?token=%1",m_security_token),l_data) THEN
		RETURN NULL
	END IF
	RETURN "Data Sent"
END FUNCTION
--------------------------------------------------------------------------------
-- Send some json data back to server
--
-- @params l_data String JSON data
FUNCTION ws_checkToken() RETURNS STRING
	IF NOT doRestRequest(SFMT("checkToken?token=%1",m_security_token)) THEN
		RETURN NULL
	END IF
	RETURN "Token Okay"
END FUNCTION

-- Private functions

--------------------------------------------------------------------------------
-- Do the web service REST call to check for a new GDC
PRIVATE FUNCTION doRestRequest(l_param STRING) RETURNS BOOLEAN
	DEFINE l_url STRING
	DEFINE l_req com.HttpRequest
	DEFINE l_resp com.HttpResponse
	DEFINE l_stat SMALLINT

	LET l_url = fgl_getResource("mob_framework.ws_url")||l_param
	CALL gl_lib.gl_logIt("doRestRequest URL:"||NVL(l_url,"NULL"))

	TRY
		LET l_req = com.HttpRequest.Create(l_url)
		CALL l_req.setMethod("GET")
		CALL l_req.setHeader("Content-Type", "application/json")
		CALL l_req.setHeader("Accept", "application/json")
		CALL l_req.doRequest()
		LET l_resp = l_req.getResponse()
		LET l_stat = l_resp.getStatusCode()
		IF l_stat = 200 THEN
			CALL util.JSON.parse( l_resp.getTextResponse(), m_ret )
		ELSE
			LET m_ret.reply = SFMT("WS Call #1 Failed!\n%1-%2",l_stat, l_resp.getStatusDescription())
			LET m_ret.stat = l_stat
		END IF
	CATCH
		LET l_stat = STATUS
		LET m_ret.reply = ERR_GET( l_stat )
	END TRY
	CALL gl_lib.gl_logIt("m_ret reply:"||NVL(m_ret.reply,"NULL"))
	IF m_ret.stat != 200 THEN
		CALL gl_lib.gl_winMessage("WS Error", m_ret.reply,"exclamation")
		RETURN FALSE
	END IF
	RETURN TRUE
END FUNCTION
--------------------------------------------------------------------------------
-- Do the web service REST call to POST a Photo
PRIVATE FUNCTION doRestRequestMedia(l_param STRING, l_media_file STRING, l_vid BOOLEAN) RETURNS BOOLEAN
	DEFINE l_url STRING
	DEFINE l_req com.HttpRequest
	DEFINE l_resp com.HttpResponse
	DEFINE l_stat SMALLINT


	LET l_url = fgl_getResource("mob_framework.ws_url")||l_param
	CALL gl_lib.gl_logIt("doRestRequest URL:"||NVL(l_url,"NULL"))

	DISPLAY "Media File:",l_media_file
	TRY
		LET l_req = com.HttpRequest.Create(l_url)
		CALL l_req.setMethod("POST")
		IF l_vid THEN
			CALL l_req.setHeader("Content-Type", "video/mp4")
		ELSE
			CALL l_req.setHeader("Content-Type", "image/jpg")
		END IF
		CALL l_req.setHeader("Accept", "application/json")
		CALL l_req.setVersion("1.0")
		CALL l_req.doFileRequest(l_media_file)
		LET l_resp = l_req.getResponse()
		LET l_stat = l_resp.getStatusCode()
		IF l_stat = 200 THEN
			CALL util.JSON.parse( l_resp.getTextResponse(), m_ret )
		ELSE
			LET m_ret.reply = SFMT("WS Call #2 Failed!\n%1-%2",l_stat, l_resp.getStatusDescription())
			LET m_ret.stat = l_stat
		END IF
	CATCH
		LET l_stat = STATUS
		LET m_ret.reply = ERR_GET( l_stat )
	END TRY
	CALL gl_lib.gl_logIt("m_ret reply:"||NVL(m_ret.reply,"NULL"))
	IF m_ret.stat != 200 THEN
		CALL gl_lib.gl_winMessage("WS Error", m_ret.reply,"exclamation")
		RETURN FALSE
	END IF
	RETURN TRUE
END FUNCTION
--------------------------------------------------------------------------------
-- Do the web service REST call to POST some Data
PRIVATE FUNCTION doRestRequestData(l_param STRING, l_data STRING)
	DEFINE l_url STRING
	DEFINE l_req com.HttpRequest
	DEFINE l_resp com.HttpResponse
	DEFINE l_stat SMALLINT

	LET l_url = fgl_getResource("mob_framework.ws_url")||l_param
	CALL gl_lib.gl_logIt("doRestRequestData URL:"||NVL(l_url,"NULL"))

	TRY
		LET l_req = com.HttpRequest.Create(l_url)
		CALL l_req.setMethod("POST")
		CALL l_req.setHeader("Content-Type", "application/json")
		CALL l_req.setHeader("Accept", "application/json")
		CALL l_req.setVersion("1.0")
		CALL l_req.doTextRequest(l_data)
		LET l_resp = l_req.getResponse()
		LET l_stat = l_resp.getStatusCode()
		IF l_stat = 200 THEN
			CALL util.JSON.parse( l_resp.getTextResponse(), m_ret )
		ELSE
			LET m_ret.reply = SFMT("WS Call #3 Failed!\n%1-%2",l_stat, l_resp.getStatusDescription())
			LET m_ret.stat = l_stat
		END IF
	CATCH
		LET l_stat = STATUS
		LET m_ret.reply = ERR_GET( l_stat )
	END TRY
	CALL gl_lib.gl_logIt("m_ret reply:"||NVL(m_ret.reply,"NULL"))
	IF m_ret.stat != 200 THEN
		CALL gl_lib.gl_winMessage("WS Error", m_ret.reply,"exclamation")
		RETURN FALSE
	END IF
	RETURN TRUE
END FUNCTION