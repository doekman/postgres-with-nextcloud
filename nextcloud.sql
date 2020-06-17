drop schema if exists nextcloud cascade
;
create schema nextcloud
;
drop table if exists nextcloud.log cascade;
create table nextcloud.log
(	id  serial  primary key
,	doc jsonb   NOT NULL
);
create index log_doc_idx on nextcloud.log using gin(doc);
create index log_time_idx ON nextcloud.log ((doc->>'time'));

drop view if exists nextcloud.log$parse_errors;
create view nextcloud.log$parse_errors as
	select id
	,      doc->>'log_line_status'    log_line_status
	,      doc->>'log_line_nr'        log_line_nr
	,      doc#>>'{exception,pos}'     exception_pos
	,      doc#>>'{exception,lineno}'  exception_lineno
	,      doc#>>'{exception,colno}'   exception_colno
	,      doc#>>'{exception,msg}'     exception_msg
	,      doc#>>'{exception,doc}'     exception_doc
	from nextcloud.log
	where doc @> '{"log_line_status":true}'::jsonb
;

--[ prefixedc with explain ]--------------------------------------------------------------------------
--where doc->>'log_line_status' IS NOT NULL
--Seq Scan on nextcloud_log  (cost=0.00..3281.10 rows=25550 width=228)
--  Filter: ((doc ->> 'log_line_status'::text) IS NOT NULL)
--------------------------------------------------------------------------------------------------
--where doc @> '{"log_line_status":true}'::jsonb
--Seq Scan on nextcloud_log  (cost=0.00..2834.43 rows=26 width=228)
--  Filter: (doc @> '{"log_line_status": true}'::jsonb)
--------------------------------------------------------------------------------------------------

drop view if exists nextcloud.log$all;
create or replace view nextcloud.log$all as
	with baseline as (
		select id
		,      COALESCE((doc#>>'{message,Code}')::int, -1)
		                                           as code
		,      COALESCE(NULLIF(doc#>>'{message,Message}',''),doc#>>'{message,CustomMessage}',NULLIF(doc#>>'{message}',''))
		                                           as message
		,      doc#>>'{message,CustomMessage}'     as custom_message
		,      doc#>>'{time}'                      as time_text
		,      doc#>>'{user}'                      as user_name -- "user" needs to be double-quoted
		,      (doc#>>'{level}')::int              as level
		,      doc#>>'{app}'                       as app
		,      doc#>>'{message,Exception}'         as exception
		,      doc#>>'{message,File}'              as file
		,      (doc#>>'{message,Line}')::int       as line
		,      doc#>>'{message,Trace}'             as trace
		,      doc#>>'{version}'                   as version
		,      doc#>>'{remoteAddr}'                as remote_addr
		,      doc#>>'{userAgent}'                 as user_agent
		,      doc#>>'{reqId}'                     as req_id
		,      replace(doc#>>'{url}', '%20', ' ')  as url
		,      doc#>>'{method}'                    as method
		from nextcloud.log
		where not doc @> '{"log_line_status":true}'::jsonb
	)
	select	id, message, time_text, user_name
	,		case when url ilike '/remote.php/dav/files/%'   then substring(url from '/remote.php/dav/files/[^/]+(/.*)')
				when url ilike '/remote.php/webdav/%'      then substring(url from '/remote.php/webdav(/.*)')
				when url ilike '/public.php/webdav/%'      then substring(url from '/public.php/webdav(/.*)')
				when url ilike '/remote.php/dav/uploads/%' then substring(url from '/remote.php/dav/uploads/[^/]+(/.*)')
				else NULL
			end path
	,		remote_addr, user_agent, method, url
	,		req_id, code, level, app, custom_message, exception, file, line, trace, version
	,		replace(time_text, 'T', ' ')::timestamp with time zone as time_timestamp
	from baseline
;
