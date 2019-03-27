# -*- coding: utf-8 -*-

import sys
import collections
import csv
import json

category_map = {
    'Afghan': 'Afghan',
    'African': 'African',
    'Senegalese': 'African',
    'South African': 'African',
    'American (New)': 'American',
    'American (Traditional)': 'American',
    'Arabian': 'Arabian',
    'Argentine': 'Argentine',
    'Armenian': 'Armenian',
    'Asian Fusion': 'Asian Fusion',
    'Australian': 'Australian',
    'Austrian': 'Austrian',
    'Bangladeshi': 'Bangladeshi',
    'Barbeque': 'Barbeque',
    'Basque': 'Basque',
    'Belgian': 'Belgian',
    'Brasseries': 'Brasseries',
    'Brazilian': 'Brazilian',
    'Breakfast & Brunch': 'Breakfast & Brunch',
    'British': 'British',
    'Buffets': 'Buffets',
    'Bulgarian': 'Bulgarian',
    'Burgers': 'Burgers',
    'Burmese': 'Burmese',
    'Cafes': 'Cafes',
    'Themed Cafes': 'Cafes',
    'Cafeteria': 'Cafeteria',
    'Cajun/Creole': 'Cajun/Creole',
    'Cambodian': 'Cambodian',
    'Caribbean': 'Caribbean',
    'Dominican': 'Caribbean',
    'Haitian': 'Caribbean',
    'Puerto Rican': 'Caribbean',
    'Trinidadian': 'Caribbean',
    'Catalan': 'Catalan',
    'Cheesesteaks': 'Cheesesteaks',
    'Chicken Shop': 'Chicken Shop',
    'Chicken Wings': 'Chicken Wings',
    'Chinese': 'Chinese',
    'Cantonese': 'Chinese',
    'Dim Sum': 'Chinese',
    'Hainan': 'Chinese',
    'Shanghainese': 'Chinese',
    'Szechuan': 'Chinese',
    'Comfort Food': 'Comfort Food',
    'Creperies': 'Creperies',
    'Cuban': 'Cuban',
    'Czech': 'Czech',
    'Delis': 'Delis',
    'Diners': 'Diners',
    'Dinner Theater': 'Dinner Theater',
    'Ethiopian': 'Ethiopian',
    'Fast Food': 'Fast Food',
    'Filipino': 'Filipino',
    'Fish & Chips': 'Fish & Chips',
    'Fondue': 'Fondue',
    'Food Court': 'Food Court',
    'Food Stands': 'Food Stands',
    'French': 'French',
    'Mauritius': 'French',
    'Reunion': 'French',
    'Game Meat': 'Game Meat',
    'Gastropubs': 'Gastropubs',
    'Georgian': 'Georgian',
    'German': 'German',
    'Gluten-Free': 'Gluten-Free',
    'Greek': 'Greek',
    'Guamanian': 'Guamanian',
    'Halal': 'Halal',
    'Hawaiian': 'Hawaiian',
    'Himalayan/Nepalese': 'Himalayan/Nepalese',
    'Honduran': 'Honduran',
    'Hong Kong Style Cafe': 'Hong Kong Style Cafe',
    'Hot Dogs': 'Hot Dogs',
    'Hot Pot': 'Hot Pot',
    'Hungarian': 'Hungarian',
    'Iberian': 'Iberian',
    'Indian': 'Indian',
    'Indonesian': 'Indonesian',
    'Irish': 'Irish',
    'Italian': 'Italian',
    'Calabrian': 'Italian',
    'Sardinian': 'Italian',
    'Sicilian': 'Italian',
    'Tuscan': 'Italian',
    'Japanese': 'Japanese',
    'Conveyor Belt Sushi': 'Japanese',
    'Izakaya': 'Japanese',
    'Japanese Curry': 'Japanese',
    'Ramen': 'Japanese',
    'Teppanyaki': 'Japanese',
    'Kebab': 'Kebab',
    'Korean': 'Korean',
    'Kosher': 'Kosher',
    'Laotian': 'Laotian',
    'Latin American': 'Latin American',
    'Colombian': 'Latin American',
    'Salvadoran': 'Latin American',
    'Venezuelan': 'Latin American',
    'Live/Raw Food': 'Live/Raw Food',
    'Malaysian': 'Malaysian',
    'Mediterranean': 'Mediterranean',
    'Falafel': 'Mediterranean',
    'Mexican': 'Mexican',
    'Tacos': 'Mexican',
    'Middle Eastern': 'Middle Eastern',
    'Egyptian': 'Middle Eastern',
    'Lebanese': 'Middle Eastern',
    'Modern European': 'Modern European',
    'Mongolian': 'Mongolian',
    'Moroccan': 'Moroccan',
    'New Mexican Cuisine': 'New Mexican Cuisine',
    'Nicaraguan': 'Nicaraguan',
    'Noodles': 'Noodles',
    'Pakistani': 'Pakistani',
    'Pan Asian': 'Pan Asian',
    'Persian/Iranian': 'Persian/Iranian',
    'Peruvian': 'Peruvian',
    'Pizza': 'Pizza',
    'Polish': 'Polish',
    'Polynesian': 'Polynesian',
    'Pop-Up Restaurants': 'Pop-Up Restaurants',
    'Portuguese': 'Portuguese',
    'Poutineries': 'Poutineries',
    'Russian': 'Russian',
    'Salad': 'Salad',
    'Sandwiches': 'Sandwiches',
    'Scandinavian': 'Scandinavian',
    'Scottish': 'Scottish',
    'Seafood': 'Seafood',
    'Singaporean': 'Singaporean',
    'Slovakian': 'Slovakian',
    'Soul Food': 'Soul Food',
    'Soup': 'Soup',
    'Southern': 'Southern',
    'Spanish': 'Spanish',
    'Sri Lankan': 'Sri Lankan',
    'Steakhouses': 'Steakhouses',
    'Supper Clubs': 'Supper Clubs',
    'Sushi Bars': 'Sushi Bars',
    'Syrian': 'Syrian',
    'Taiwanese': 'Taiwanese',
    'Tapas Bars': 'Tapas Bars',
    'Tapas/Small Plates': 'Tapas/Small Plates',
    'Tex-Mex': 'Tex-Mex',
    'Thai': 'Thai',
    'Turkish': 'Turkish',
    'Ukrainian': 'Ukrainian',
    'Uzbek': 'Uzbek',
    'Vegan': 'Vegan',
    'Vegetarian': 'Vegetarian',
    'Vietnamese': 'Vietnamese',
    'Waffles': 'Waffles',
    'Wraps': 'Wraps'
}

def read_and_write_file(json_file_path, csv_file_path, column_names):
    """
    Read in the json dataset file and write it out to a csv file, given the
    column names.
    """

    column_names_list = list(column_names)
    categories_index = column_names_list.index('categories')
    with open(csv_file_path, 'w+') as fout:
        csv_file = csv.writer(fout)
        csv_file.writerow(list(column_names))     # write column names
        with open(json_file_path) as fin:         # write each row
            for line in fin:
                line_contents = json.loads(line)
                row = get_row(line_contents, column_names)
                # skip non-restaurant business
                if 'Restaurants' not in row[categories_index]:
                    continue
                # assign restaurant category
                row[categories_index] = assign_category(row[categories_index])
                if row[categories_index] == 'Unknown':
                    continue
                csv_file.writerow(row)

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

def assign_category(categories):
    for category in categories.strip('"').split(', '):
        if category in category_map:
            return category_map[category]
    return 'Unknown'

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

    base_key, sub_key = key.split('.', 1)
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
