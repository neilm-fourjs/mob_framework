
-- Application Specific backend Code

IMPORT os
IMPORT util
IMPORT FGL gl_lib
IMPORT FGL mob_db_backend

GLOBALS
	DEFINE g_user STRING
END GLOBALS

PUBLIC DEFINE m_media_uri STRING
PUBLIC DEFINE m_media_path STRING
PUBLIC DEFINE m_files_path STRING

FUNCTION init_app_backend() RETURNS STRING
	DEFINE l_host STRING

	LET m_media_path = fgl_getEnv("MEDIAPATH")
	IF NOT os.path.exists( m_media_path ) THEN
		IF NOT os.path.mkdir( m_media_path ) THEN
			RETURN SFMT(%"ERR: Media Path Failed to create %1!",m_media_path)
		END IF
	END IF
	CALL gl_lib.gl_logIt(SFMT("Media Path:%1",m_media_path))

	LET m_files_path = fgl_getEnv("FILESPATH")
	IF m_files_path.getLength() < 1 THEN LET m_files_path = "../mob_files" END IF

	LET l_host = gl_lib.gl_getHostName()
	IF DOWNSHIFT(fgl_getEnv("FORCEHTTP")) = "yes" THEN
		LET m_media_uri = "http://"||l_host||"/"||fgl_getEnv("MEDIAURI")
	ELSE
		LET m_media_uri = "https://"||l_host||"/"||fgl_getEnv("MEDIAURI")
	END IF
	CALL gl_lib.gl_logIt(SFMT("Media URI:%1",m_media_uri))

	RETURN NULL
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION process_file(l_file STRING) RETURNS STRING
	DEFINE l_file_path, l_newpath STRING

	LET l_file_path = os.path.join(m_files_path, g_user CLIPPED)
	IF NOT os.path.exists(l_file_path) THEN
		IF NOT os.path.mkdir( l_file_path ) THEN
			CALL gl_lib.gl_logIt(SFMT(%"New Directory Create '%1' Failed!",l_file_path))
			RETURN SFMT(%"ERR: Media Path Failed to create %1!",l_file_path)
		ELSE
			CALL gl_lib.gl_logIt(SFMT(%"New Directory Created '%1'",l_file_path))
		END IF
	END IF

	LET l_newpath = os.path.join( l_file_path, os.path.basename(l_file) )

	IF os.Path.copy(l_file, l_newpath) THEN
		CALL gl_lib.gl_logIt(SFMT(%"File %1 copied to %2",l_file, l_newpath))
		IF NOT os.path.delete(l_file) THEN
			CALL gl_lib.gl_logIt(SFMT(%"Failed to delete %1",l_file))
		END IF
	ELSE
		CALL gl_lib.gl_logIt(SFMT(%"Failed to copy %1 to %2",l_file,l_newpath))
		RETURN %"ERR: File processing failed!"
	END IF

--	CALL mob_db_backend.db_log_file( l_file )

	RETURN "Okay"
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION process_media(l_file STRING, l_vid BOOLEAN, l_imgid STRING ) RETURNS STRING
	DEFINE l_media_path, l_newpath STRING

	LET l_media_path = os.path.join(m_media_path,l_imgid)
	IF NOT os.path.mkdir( l_media_path ) THEN
		RETURN SFMT(%"ERR: Media Path Failed to create %1!",l_media_path)
	END IF

	LET l_newpath = os.path.join( l_media_path, os.path.basename(l_file) )

	IF os.Path.copy(l_file, l_newpath) THEN
		IF NOT os.path.delete(l_file) THEN
			CALL gl_lib.gl_logIt(SFMT(%"Failed to delete %1",l_file))
		END IF
	ELSE
		CALL gl_lib.gl_logIt(SFMT(%"Failed to copy %1 to %2",l_file,l_newpath))
		RETURN %"ERR: Media processing failed!"
	END IF

	RUN "./mk_thumbnail.sh "||l_media_path||" "||os.path.basename(l_file) WITHOUT WAITING

	CALL mob_db_backend.db_log_media( IIF(l_vid,"V","P"), os.path.join( l_imgid, os.path.basename(l_file) )
 )

	RETURN "Okay"
END FUNCTION
--------------------------------------------------------------------------------
#+ A get url to a media file
#+ 
#+ @param l_file File Name
#+ @param l_mtime Optional file mod time
FUNCTION getURL( l_file STRING, l_mtime STRING) RETURNS STRING
	DEFINE l_mtime_i INTEGER
	IF l_mtime IS NOT NULL THEN
		LET l_mtime_i = util.Datetime.toSecondsSinceEpoch( util.Datetime.parse( l_mtime, "%Y-%m-%d %H:%M:%S" ) )
		RETURN m_media_uri||"/"||l_file||"?m="||l_mtime_i
	ELSE
		RETURN m_media_uri||"/"||l_file
	END IF
END FUNCTION