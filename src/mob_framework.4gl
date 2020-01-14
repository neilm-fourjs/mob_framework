
-- A Genero Mobile Framework Demo with web services.

IMPORT util
IMPORT os

IMPORT FGL mob_lib
IMPORT FGL mob_app_lib
IMPORT FGL mob_ws_lib
IMPORT FGL gl_lib
IMPORT FGL wc_iconMenu

&include "mob_lib.inc"
DEFINE myMenu wc_iconMenu.wc_iconMenu
MAIN
	DEFINE l_menuItem STRING = "."
	CALL mob_lib.init_mob()
	CALL mob_app_lib.init_app()

-- Use a JSON file for the menu data
	LET myMenu.fileName = "myMenu.json"
	OPEN FORM main FROM "mob_framework"
	DISPLAY FORM main

	IF NOT myMenu.init(myMenu.fileName) THEN -- something wrong?
		EXIT PROGRAM
	END IF

	IF NOT mob_lib.login() THEN
		EXIT PROGRAM
	END IF

	DISPLAY mob_app_lib.m_apptitle TO f_apptitle
	DISPLAY IIF( mob_lib.check_network(), "Connected","No Connection") TO f_network
	DISPLAY g_ws_uri TO f_server

	WHILE l_menuItem != "exit" AND l_menuItem != "close" AND l_menuItem != "quit"
		--LET l_menuItem = menu_ui() --tradition menu
		LET l_menuItem = myMenu.ui(FALSE, 10) -- WC menu
		CASE l_menuItem
			WHEN "list_custs"	CALL list_custs()
			WHEN "send_media"	CALL mob_lib.send_media()
			WHEN "list_media1" CALL mob_lib.list_media1()
			WHEN "list_media2" CALL mob_lib.list_media2()
			WHEN "send_data" CALL send_data("This is some test data!")
			WHEN "get_file" CALL mob_lib.copy_file(TRUE)
			WHEN "put_file" CALL mob_lib.copy_file(FALSE)
			WHEN "check_token" CALL mob_lib.check_token()
			WHEN "about" CALL mob_lib.mobile_about()
			WHEN "view_log" CALL mob_lib.view_log()
			WHEN "send_log" CALL mob_lib.send_log()
			WHEN "timer"
				DISPLAY IIF( mob_lib.check_network(), "Connected","No Connection") TO f_network
		END CASE
	END WHILE

END MAIN
--------------------------------------------------------------------------------
FUNCTION menu_ui() RETURNS STRING
	DEFINE l_menuItem STRING
	MENU
		ON ACTION list_custs
			LET l_menuItem = "list_custs"			EXIT MENU
		ON ACTION send_media
			LET l_menuItem = "send_media"			EXIT MENU
		ON ACTION list_media1
			LET l_menuItem = "list_media1"			EXIT MENU
		ON ACTION list_media2
			LET l_menuItem = "list_media2"			EXIT MENU
		ON ACTION send_data
			LET l_menuItem = "send_data"			EXIT MENU
		ON ACTION get_file
			LET l_menuItem = "get_file"			EXIT MENU
		ON ACTION put_file
			LET l_menuItem = "put_file"			EXIT MENU
		ON ACTION check_token
			LET l_menuItem = "check_token"			EXIT MENU
		ON ACTION about
			LET l_menuItem = "about"			EXIT MENU
		ON ACTION view_log
			LET l_menuItem = "view_log"			EXIT MENU
		ON ACTION send_log
			LET l_menuItem = "send_log"			EXIT MENU
		ON ACTION quit
			LET l_menuItem = "quit"			EXIT MENU
		ON ACTION close
			LET l_menuItem = "close"			EXIT MENU
		ON TIMER 10
			LET l_menuItem = "timer"			EXIT MENU
	END MENU
	RETURN l_menuItem
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION list_custs()

	IF mob_app_lib.m_sel_list1.getLength() = 0 THEN
		IF NOT mob_app_lib.get_list1(mob_lib.m_user) THEN
			RETURN
		END IF
	END IF

	OPEN WINDOW custs WITH FORM "cust_list" 

	MESSAGE "Data as of: "||mob_app_lib.m_list1_date
	DISPLAY ARRAY m_sel_list1 TO scr_arr.* ATTRIBUTES(ACCEPT=FALSE,CANCEL=FALSE)
		ON ACTION select
			CALL show_cust( mob_app_lib.m_sel_list1[ arr_curr() ].key )
		ON ACTION back EXIT DISPLAY
	END DISPLAY

	CLOSE WINDOW custs
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION show_cust(l_key STRING)

	IF NOT mob_app_lib.get_dets1( l_key ) THEN
		RETURN 
	END IF

	OPEN WINDOW cust_det WITH FORM "cust_dets"

	DISPLAY BY NAME mob_app_lib.m_Dets1.*

	MENU
		ON ACTION back EXIT MENU
		ON ACTION close EXIT MENU
	END MENU

	CLOSE WINDOW cust_det
END FUNCTION