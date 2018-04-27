IMPORT com
IMPORT os
IMPORT FGL WSHelper

TYPE t_status RECORD
	code INTEGER,
	desc STRING
END RECORD

TYPE t_reqInfoTyp RECORD
	method		STRING,
	ctype			STRING,	 # check the Content-Type
	informat	STRING,	 # short word for Content Type 
	caccept		STRING,	 # check which format the client accepts
	outformat	STRING,	 # short word for Accept
	path			STRING,
	scheme		STRING,
	host			STRING,
	port			STRING,
	query			STRING,
	items	  	WSHelper.WSQueryType
END RECORD

PUBLIC DEFINE m_err t_status
PUBLIC DEFINE m_reqInfo t_reqInfoTyp
--------------------------------------------------------------------------------
FUNCTION gl_getHeaderByName(l_req com.HTTPServiceRequest, l_head STRING) RETURNS STRING
	DEFINE l_name STRING
	DEFINE x INTEGER

	FOR x = 1 TO l_req.getRequestHeaderCount()
		LET l_name = l_req.getRequestHeaderName(x)
		IF l_head.equalsIgnoreCase( l_name.toLowerCase() ) THEN
			RETURN l_req.getRequestHeaderValue(x)
		END IF
	END FOR

	RETURN NULL
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION gl_getReqInfo(l_req com.HTTPServiceRequest)
	INITIALIZE m_reqInfo TO NULL

	LET m_reqInfo.informat = "JSON"
	LET m_reqInfo.outformat = "JSON"
	LET m_reqInfo.method = l_req.getMethod()

	CALL WSHelper.SplitUrl( l_req.getURL() )
  	RETURNING m_reqInfo.scheme,
            m_reqInfo.host,
            m_reqInfo.port,
            m_reqInfo.path,
            m_reqInfo.query

	LET m_reqInfo.path = os.path.baseName( m_reqInfo.path )

	DISPLAY "Host:",m_reqInfo.host
	DISPLAY "Port:",m_reqInfo.port
	DISPLAY "Path:",m_reqInfo.path
	DISPLAY "Query:",m_reqInfo.query

	LET m_reqInfo.ctype = gl_getHeaderByName(l_req,"Content-Type")
	IF m_reqInfo.ctype.getIndexOf("/xml",1) THEN
		LET m_reqInfo.informat = "XML"
	END IF
	
	LET m_reqInfo.caccept = gl_getHeaderByName(l_req,"Accept")
	IF m_reqInfo.caccept.getIndexOf("/xml",1) THEN
		LET m_reqInfo.outformat = "XML"
	END IF
	
	CALL l_req.getURLQuery(m_reqInfo.items)
  
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION gl_setError(l_str STRING)
	DISPLAY l_str
END FUNCTION
--------------------------------------------------------------------------------
-- returns 0 if element not found
FUNCTION gl_getParameterIndex(l_str STRING) RETURNS INTEGER
	DEFINE x INTEGER

	FOR x = 1 TO m_reqInfo.items.getLength()
		IF l_str.equals(m_reqInfo.items[x].name) THEN 
			RETURN x
		END IF
	END FOR

	RETURN 0
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION gl_getParameterValue(x INTEGER) RETURNS STRING
	RETURN m_reqInfo.items[x].value
END FUNCTION