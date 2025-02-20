## This is a script I generated that traverses the vocabulary XML file and updates the database with 
# the hierarchical paths of the vocabulary terms.
# Configure the file at `config.ini` with the database connection details and the path to the XML file.
# The script can be run with the following options:
# - `--dry-run` to simulate the changes without committing them to the database.
# - `--test-connection` to test the database connection.
# You can choose which term you will use to test the connection by changing the `sample_term` variable.

global sample_term
sample_term = "Data Anomaly Method"

import xml.etree.ElementTree as ET
import psycopg2
import logging
from psycopg2 import sql
import configparser

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def extract_paths(node, current_path="", is_root=True):
    paths = []
    current_label = node.get("label")
    
    if not is_root:
        new_path = f"{current_path}::{current_label}" if current_path else current_label
        # Add the current node's path, regardless of whether it has children
        paths.append((current_label, new_path))
    else:
        new_path = ""

    is_composed_by = node.find("isComposedBy")
    if is_composed_by:
        for child in is_composed_by.findall("node"):
            paths.extend(extract_paths(child, new_path, is_root=False))
    
    return paths

def test_connection(config):
    try:
        conn = psycopg2.connect(
            dbname=config['Database']['dbname'],
            user=config['Database']['user'],
            password=config['Database']['password'],
            host=config['Database']['host'],
            port=config['Database']['port']
        )
        cursor = conn.cursor()
        
        # Perform a simple query
        cursor.execute("SELECT COUNT(*) FROM metadatavalue;")
        result = cursor.fetchone()
        
        logging.info(f"Successfully connected to the database. There are {result[0]} rows in the metadatavalue table.")
        
        # Test the search query with a parent node term
        
        cursor.execute("SELECT COUNT(*) FROM metadatavalue WHERE text_value = %s;", (sample_term,))
        result = cursor.fetchone()
        
        logging.info(f"Found {result[0]} occurrences of '{sample_term}' in the metadatavalue table.")
        
        cursor.close()
        conn.close()
        return True
    except Exception as e:
        logging.error(f"Failed to connect to the database or run test query: {str(e)}")
        return False

def update_psql_table(term, full_path, cursor, dry_run=False):
    try:
        search_query = sql.SQL("SELECT * FROM metadatavalue WHERE text_value = %s;")
        update_query = sql.SQL("UPDATE metadatavalue SET text_value = %s WHERE text_value = %s;")

        if dry_run:
            logging.info(f"Dry Run: Simulating search for '{term}'. Would replace with: '{full_path}'")
        else:
            cursor.execute(search_query, (term,))
            results = cursor.fetchall()

            if results:
                logging.info(f"Found '{term}' in text_value. Replacing with '{full_path}'.")
                cursor.execute(update_query, (full_path, term))
            else:
                logging.info(f"Term '{term}' not found in database.")
    except Exception as e:
        logging.error(f"Error processing term '{term}': {str(e)}")

def main(dry_run=False, test_conn=False):
    config = configparser.ConfigParser()
    config.read('/data/dspace-angular-dspace-8.1/config/configs/config.ini')

    if test_conn:
        if test_connection(config):
            logging.info("Connection test successful.")
        else:
            logging.error("Connection test failed.")
        return

    conn = None
    cursor = None

    try:
        if not dry_run:
            conn = psycopg2.connect(
                dbname=config['Database']['dbname'],
                user=config['Database']['user'],
                password=config['Database']['password'],
                host=config['Database']['host'],
                port=config['Database']['port']
            )
            cursor = conn.cursor()

        tree = ET.parse(config['Paths']['xml_file'])
        root = tree.getroot()

        paths = extract_paths(root, is_root=True)

        for term, full_path in paths:
            update_psql_table(term, full_path, cursor, dry_run=dry_run)

        if not dry_run and conn:
            conn.commit()
            logging.info("All updates committed successfully.")

    except Exception as e:
        logging.error(f"An error occurred: {str(e)}")
        if conn:
            conn.rollback()
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Update vocabulary in the database.")
    parser.add_argument('--dry-run', action='store_true', help="Perform a dry run without making changes.")
    parser.add_argument('--test-connection', action='store_true', help="Test the database connection.")
    
    args = parser.parse_args()
    
    main(dry_run=args.dry_run, test_conn=args.test_connection)