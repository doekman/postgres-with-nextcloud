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
	select id
	,      COALESCE((doc#>>'{message,Code}')::int, -1)
	                                       as code
	,      COALESCE(NULLIF(doc#>>'{message,Message}',''),doc#>>'{message,CustomMessage}',NULLIF(doc#>>'{message}',''))
	                                       as message
	,      doc#>>'{message,CustomMessage}' as custom_message
	,      doc#>>'{time}'                  as time
	,      doc#>>'{user}'                  as user
	,      (doc#>>'{level}')::int          as level
	,      doc#>>'{app}'                   as app
	,      doc#>>'{message,Exception}'     as exception
	,      doc#>>'{message,File}'          as file
	,      (doc#>>'{message,Line}')::int   as line
	,      doc#>>'{message,Trace}'         as trace
	,      doc#>>'{version}'               as version
	,      doc#>>'{remoteAddr}'            as remoteAddr
	,      doc#>>'{userAgent}'             as userAgent
	,      doc#>>'{reqId}'                 as reqId
	,      doc#>>'{url}'                   as url
	,      doc#>>'{method}'                as method
	,      replace(doc#>>'{time}','T',' ')::timestamp with time zone 
	                                       as timestamp_time
	from nextcloud.log
	where not doc @> '{"log_line_status":true}'::jsonb
;
