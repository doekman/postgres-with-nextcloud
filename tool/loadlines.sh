#!/usr/bin/env python3

import argparse, csv, json, plistlib, os.path, re, sys
from decimal import Decimal
from sqlalchemy import create_engine, MetaData
from sqlalchemy.sql import text
import xml.etree.ElementTree
import xml.parsers.expat.errors

def load_json_log(filename, verbose, encoding=None):
    '''Loads json log file (each line contains a json row)
    '''
    global line_nr, nr_warnings
    (line_nr, nr_warnings) = (0,0)
    with open(filename, encoding=encoding) as f:
        for line in f:
            try:
                line_nr += 1
                yield json.loads(line)
            except json.JSONDecodeError as de:
                if verbose:
                    format_error(f'\nWarning: error decoding JSON at log-file line {line_nr} and position {de.pos} (line {de.lineno} and column {de.colno}); Error added to row.', de.msg, do_exit=False)
                nr_warnings += 1
                yield dict(log_line_nr=line_nr, log_line_status='error', exception=dict(pos=de.pos, lineno=de.lineno, colno=de.colno, msg=de.msg, doc=de.doc))

def format_error(msg, native_msg, do_exit=True):
    print(msg, file=sys.stderr)
    print('-> '+native_msg, file=sys.stderr)
    if do_exit:
        exit(2)

def get_truncate_query(schema, table):
    return text(f'''
TRUNCATE TABLE {schema}.{table}
RESTART IDENTITY
;''')

def get_insert_query(schema, table, doc_column):
    return text(f'''
INSERT INTO {schema}.{table}({doc_column})
VALUES(:doc)
;''')


def update_message(nr_rows, last_msg, final=False):
    print('\b'*len(last_msg), end='')
    last_msg = '{} rows...'.format(nr_rows)
    print(last_msg, end='')
    if final:
        print('.')
    return last_msg

def create_argument_parser():
    parser = argparse.ArgumentParser(description='Laadt documenten (met een array op root-level) in een json(b)-tabel in een postgres-database, en print het aantal verwerkte rijen.')
    parser.add_argument('--alchemy-echo', '-ae',   action='store_true',                                        help='print also all executed SQL statements')
    parser.add_argument('--verbose', '-v',         action='store_true',                                        help='print more text')
    parser.add_argument('--truncate-table', '-tt', action='store_true',                                        help='empty (truncate) table before inserting')
    parser.add_argument('--db', metavar='CONNECTION_STRING',  type=str, default='postgres:///doc_db',          help='database connection string')
    parser.add_argument('--db-schema', metavar='DB_SCHEMA',   type=str, default='nextcloud',                   help='Naam van het database schema.')
    parser.add_argument('--table', metavar='TABLE_NAME',      type=str, default='log',                         help='Naam van de tabel.')
    parser.add_argument('--doc-column', metavar='DOC_COLUMN', type=str, default='doc', help='Kolom naam waar het XML document (als JSON) wordt opgeslagen')
    parser.add_argument('--encoding', metavar='ENCODING', type=str, default=None, help='Specify the encoding of the input file.')
    parser.add_argument('doc_file', metavar='DOC_FILE', type=str, help='Dit document (afhankelijk van --file-type) wordt in de database geladen')
    return parser

if __name__ == '__main__':
    args = create_argument_parser().parse_args()

    nr_rows, last_msg = 0, ''
    engine = create_engine(args.db, convert_unicode=True, echo=args.alchemy_echo)
    print('Inserting ', end='')
    with engine.begin() as conn:
        if args.truncate_table:
            query = get_truncate_query(args.db_schema, args.table)
            conn.execute(query, dict())
        for row in load_json_log(args.doc_file, args.verbose, args.encoding):
            query = get_insert_query(args.db_schema, args.table, args.doc_column)
            conn.execute(query, dict(doc=json.dumps(row)))
            if nr_rows % 100 == 0:
                last_msg = update_message(nr_rows, last_msg)
            nr_rows += 1
    last_msg = update_message(nr_rows, last_msg, final=True)
    print('Done, %d lines proccessed with %d warnings' % (line_nr, nr_warnings))
