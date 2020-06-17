#!/usr/bin/env bash
# Unofficial Bash Strict Mode
set -euo pipefail
IFS=$'\n\t'

# Idea from: <https://stackoverflow.com/a/48396608/56>

if (( $# < 1 )); then
	>&2 echo "Usage: $(basename $0) file_to_load.json"
	exit 1
fi

file_to_load="$1"
if [[ ! -r "$file_to_load" ]]; then
	>&2 echo "Can't read from $file_to_load"
	exit 1
fi

table_schema="nextcloud"
table_name="log"
doc_column="doc"
psql_file="${0/.sh/.psql}"

echo -n "Loading"
((count=0))
while LANG=C IFS= read -r line; do 
	# Can't use "-c" because that can't handle "psql-specific features"
	# see: <https://www.postgresql.org/docs/current/app-psql.html#APP-PSQL-INTERPOLATION>
	result_text="$(psql -v "table_schema=$table_schema" -v "table_name=$table_name" -v "doc_column=$doc_column" -v "content=$line" -f "$psql_file")"
	result_nr=$?
	if [[ $result_text == "INSERT 0 1" ]]; then
		echo -n "."
	else
		echo "$result_text"
		exit $result_nr
	fi
	((count+=1))
	#echo $'----------\n'"${line}"$'\n----------'
done <"$file_to_load"
echo " done; $count lines inserted."
