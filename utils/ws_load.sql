delete from ws_log_access where 1=1;
delete from ws_log_media where 1=1;
delete from ws_log_data where 1=1;
load from "ws_log_access.unl" insert into ws_log_access;
load from "ws_log_media.unl" insert into ws_log_media;
load from "ws_log_data.unl" insert into ws_log_data;
