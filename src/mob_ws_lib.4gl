
-- Mobile Web Service Functions

IMPORT util
IMPORT com

IMPORT FGL gl_lib

CONSTANT WS_VER = 1

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
FUNCTION ws_putPhoto(l_photo_file STRING) RETURNS STRING
	IF NOT doRestRequestPhoto(SFMT("putPhoto?token=%1",m_security_token),l_photo_file) THEN
		RETURN NULL
	END IF
	RETURN "Photo Sent"
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

-- Do Rest call
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
PRIVATE FUNCTION doRestRequestPhoto(l_param STRING, l_photo_file STRING) RETURNS BOOLEAN
	DEFINE l_url STRING
  DEFINE l_req com.HttpRequest
  DEFINE l_resp com.HttpResponse
  DEFINE l_stat SMALLINT

	LET l_url = fgl_getResource("mob_framework.ws_url")||l_param
	CALL gl_lib.gl_logIt("doRestRequest URL:"||NVL(l_url,"NULL"))

	DISPLAY "Photo:",l_photo_file
  TRY
    LET l_req = com.HttpRequest.Create(l_url)
    CALL l_req.setMethod("POST")
    CALL l_req.setHeader("Content-Type", "image/jpg")
    CALL l_req.setHeader("Accept", "application/json")
		CALL l_req.setVersion("1.0")
		CALL l_req.doFileRequest(l_photo_file)
    LET l_resp = l_req.getResponse()
    LET l_stat = l_resp.getStatusCode()
    IF l_stat = 200 THEN
      CALL util.JSON.parse( l_resp.getTextResponse(), m_ret )
    ELSE
			LET m_ret.reply = SFMT("WS Call #2 Failed!\n%1-%2",l_stat, l_resp.getStatusDescription())
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
FUNCTION doRestRequestData(l_param STRING, l_data STRING)
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