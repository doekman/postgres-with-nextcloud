postgres-with-nextcloud
=======================

In [Nextcloud][], you can export logs (User Settings > Logs > ... > Download logs). The log file consists of multiple lines, with a JSON-object on each line.

In this repository, you will find SQL to work with those.

**NOTICE**: this repository uses an [ok-profile][ok].


Getting started
---------------

To get started, open a terminal session and go to this repository folder.

	make 

will show how you how to use the makefile. The command

	make nextcloud

will create the table+views (nextcloud). Now load some data:

	tool/loaddoc.sh data/small.log

Now you are ready to query:

	psql
	\d

The last command shows all tables and views you can query from. Let's query some:

	select * from nextcloud.log$all where "user" ilike '%some_name%'; -- Filter on user name
	select * from nextcloud.log$all where "remoteaddr" = '10.20.30.40'; -- Query for client's IP-address

And to quit `psql`, type:

	\q


More
----

* If a line can't be parsed as JSON, you can inspect the line via the view `nextcloud.log$parse_errors`
* If you want to contribute, please create an [issue][issue] so we can discuss first
* I used the convention `nextcloud.log$parse_errors` instead of (the nicer looking) `nextcloud.log:parse_errors`, because identifiers with a colon needs to be double-quoted.


[Nextcloud]: https://nextcloud.com
[ok]: https://github.com/secretGeek/ok-bash
[issue]: https://github.com/doekman/postgres-with-nextcloud/issues
