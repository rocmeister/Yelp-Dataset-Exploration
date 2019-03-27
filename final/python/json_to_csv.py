# -*- coding: utf-8 -*-

import sys
import collections
import csv
import json

def read_and_write_file(json_file_path, csv_file_path, column_names):
    """
    Read in the json dataset file and write it out to a csv file, given the
    column names.
    """

    with open(csv_file_path, 'w+') as fout:
        csv_file = csv.writer(fout)
        csv_file.writerow(list(column_names))     # write column names
        with open(json_file_path) as fin:         # write each row
            for line in fin:
                line_contents = json.loads(line)
                csv_file.writerow(get_row(line_contents, column_names))

def get_row(line_contents, column_names):
    """Return a csv compatible row given column names and a dict row contents."""

    row = []
    for column_name in column_names:
        line_value = get_nested_value(line_contents, column_name)
        if line_value is not None:
            row.append('{0}'.format(line_value))
        else:
            row.append('')
    return row

def get_nested_value(d, key):
    """
    Return a dictionary item given a dictionary and a flattened key.

    Example:

      d = {
        'a': {
          'b': 2,
          'c': 3
        }
      }
      key = 'a.b'

      will return: 2
    """

    if d is None:
      return None
    if '.' not in key:
        if key not in d:
            return None
        return d[key]

    base_key, sub_key = key.split('.', maxsplit=1)
    if base_key not in d:
        return None
    sub_dict = d[base_key]
    return get_nested_value(sub_dict, sub_key)

def get_superset_of_column_names_from_file(json_file_path):
    """Read in the json dataset file and return the superset of column names."""

    column_names = set()
    with open(json_file_path) as fin:
        for line in fin:
            line_contents = json.loads(line)
            column_names.update(set(get_column_names(line_contents)))
    return column_names

def get_column_names(line_contents, parent_key=''):
    """
    Return a list of flattened key names given a dict.

    Example:

      line_contents = {
        'a': {
          'b': 2,
          'c': 3
        }
      }

      will return: ['a.b', 'a.c']

    These will be the column names for the eventual csv file.
    """

    column_names = []
    for k, v in line_contents.items():
        column_name = "{0}.{1}".format(parent_key, k) if parent_key else k
        if isinstance(v, collections.MutableMapping):
            column_names.extend(get_column_names(v, column_name))
        else:
            column_names.append(column_name)
    return column_names

if __name__ == '__main__':
    json_file = sys.argv[1]
    csv_file = '{0}.csv'.format(json_file.split('.json')[0])

    column_names = get_superset_of_column_names_from_file(json_file)
    read_and_write_file(json_file, csv_file, column_names)
