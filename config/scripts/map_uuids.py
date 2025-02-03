#!/usr/bin/env python3

import argparse
import os
import pdb
import sys
import gzip
import pandas as pd
import psycopg2
from psycopg2 import sql
import configparser
import csv

def parse_arguments():
    parser = argparse.ArgumentParser(description='Map UUIDs in CSV files to their corresponding text values (titles).')
    parser.add_argument('--input_dir', '-i', required=True, help='Directory containing the CSV files to process.')
    parser.add_argument('--columns', '-c', required=True, help='Comma-separated list of columns that contain UUIDs.')
    parser.add_argument('--log_file', '-l', required=True, help='Path to the log file.')
    parser.add_argument('--output_suffix', '-s', default='_mapped', help='Suffix to add to output CSV files.')
    parser.add_argument('--config', '-f', default='/data/dspace-angular-dspace-8.0/config/configs/config.ini',
                        help='Path to the config.ini file containing database connection details.')
    return parser.parse_args()

def log(message, log_file):
    timestamp = pd.Timestamp.now().strftime('%Y-%m-%d %H:%M:%S')
    log_entry = f"{timestamp} : {message}"
    print(log_entry)
    with open(log_file, 'a') as f:
        f.write(log_entry + '\n')

def fetch_uuid_mapping(config, log_file):
    """
    Fetches a dictionary mapping from dspace_object_id -> text_value
    BUT only for metadata_field_id = 73 (title).
    """
    try:
        # Extract database connection parameters from config.ini
        if not config.has_section('database'):
            log("Error: 'database' section not found in config.ini.", log_file)
            sys.exit(1)
        
        db_host = config.get('database', 'host', fallback=None)
        db_name = config.get('database', 'database', fallback=None)
        db_user = config.get('database', 'user', fallback=None)
        db_password = config.get('database', 'password', fallback=None)
        db_port = config.get('database', 'port', fallback='5432')  # Default PostgreSQL port
        
        if not all([db_host, db_name, db_user, db_password]):
            log("Error: Missing database connection parameters in config.ini.", log_file)
            sys.exit(1)
        
        # Establish connection to PostgreSQL
        conn = psycopg2.connect(
            host=db_host,
            database=db_name,
            user=db_user,
            password=db_password,
            port=db_port
        )
        cursor = conn.cursor()
        
        # ************* KEY CHANGE: Filter by metadata_field_id = 73 *************
        cursor.execute("""
            SELECT dspace_object_id, metadata_field_id, text_value
            FROM metadatavalue
            WHERE metadata_field_id IN (7, 34, 73, 211)
        """)
        # ************************************************************************

        rows = cursor.fetchall()
        # pdb.set_trace()
        # For each object_id, we’ll store a dict of the form:
        #   mapping[object_id] = {
        #       7: [possibly multiple text_values],
        #       34: [...],
        #       73: [...]
        #   }

        mapping = {}
        for (obj_id, field_id, text_value) in rows:
            if obj_id not in mapping:
                mapping[obj_id] = {}
            if field_id not in mapping[obj_id]:
                mapping[obj_id][field_id] = []
            mapping[obj_id][field_id].append(text_value)
        cursor.close()
        conn.close()
        log(f"Fetched {len(mapping)} UUID mappings (titles) from the database.", log_file)
        return mapping
    except Exception as e:
        log(f"Error connecting to Postgres or fetching data: {e}", log_file)
        sys.exit(1)

def process_csv(file_path, columns, mapping, log_file, output_suffix):
    try:
        # Determine if the file is gzipped
        if file_path.endswith('.gz'):
            df = pd.read_csv(gzip.open(file_path, 'rt', encoding='utf-8'), dtype=str, quotechar='"', quoting=csv.QUOTE_MINIMAL)
        else:
            df = pd.read_csv(file_path, dtype=str, quotechar='"', quoting=csv.QUOTE_MINIMAL)
        
        log(f"Processing file: {file_path}", log_file)
        
        for col in columns:
            if col not in df.columns:
                log(f"Column '{col}' not found in {file_path}. Skipping.", log_file)
                continue
            new_col = f"{col}_value"
            # pdb.set_trace()
            df[new_col] = df[col].apply(lambda x: map_uuids(x, mapping, log_file, col))
            log(f"Added column '{new_col}' to {file_path}.", log_file)
        
        # Save the updated DataFrame back to CSV
        base, ext = os.path.splitext(file_path)
        
        output_file = f"{base}{output_suffix}{ext}"
        # pdb.set_trace()
        print(output_file)
        
        with open(output_file, 'w', encoding='utf-8', newline='') as f:
            df.to_csv(f, index=False, quoting=csv.QUOTE_MINIMAL)
        
        log(f"Saved mapped CSV to {output_file}.", log_file)
        
    except Exception as e:
        log(f"Error processing file {file_path}: {e}", log_file)

def map_uuids(cell, mapping, log_file, column_name):
    """
    Maps one or more UUIDs (separated by commas) to their 'title' (field 73).
    If a UUID is not found in the dictionary, the UUID remains unchanged.
    Multiple mapped values are separated by semicolons.
    """
    if pd.isna(cell):
        return ''
    uuids = [uuid.strip() for uuid in cell.split(',')]
    values = []
    for uuid in uuids:
        try:
            if uuid in mapping:
                # Check if there are titles (field 73) for this object
                if 73 in mapping[uuid]:
                    # Take the first title if multiple exist
                    values.append(mapping[uuid][73][0])
                elif 211 in mapping[uuid]: # OrgUnit
                    # Take the first title if multiple exist
                    values.append(mapping[uuid][211][0])
                else:
                    # pdb.set_trace()
                    # No title found, keep original UUID
                    log(f"UUID '{uuid}' in column '{column_name}' has no title (field 73).", log_file)
                    values.append(uuid)
            else:
                # UUID not found in mapping
                # log(f"UUID '{uuid}' in column '{column_name}' not found in mapping.", log_file)
                values.append(uuid)
        except (KeyError, IndexError, TypeError) as e:
            # Handle any dictionary access errors
            log(f"Error processing UUID '{uuid}' in column '{column_name}': {str(e)}", log_file)
            values.append(uuid)
    return ';'.join(values)  # Use semicolon to separate multiple mapped values

def main():
    args = parse_arguments()
    input_dir = args.input_dir
    columns = [col.strip() for col in args.columns.split(',')]
    log_file = args.log_file
    output_suffix = args.output_suffix
    config_path = args.config

    # Read and parse config.ini
    config = configparser.ConfigParser()
    if not os.path.isfile(config_path):
        log(f"Error: config.ini file not found at {config_path}.", log_file)
        sys.exit(1)
    
    config.read(config_path)
    log(f"Read configuration from {config_path}.", log_file)

    # Fetch the UUID -> Title mapping (only from metadata_field_id = 73)
    log("Fetching UUID mapping (titles) from the database.", log_file)
    mapping = fetch_uuid_mapping(config, log_file)

    # Process each CSV file in the input directory
    for root, dirs, files in os.walk(input_dir):
        for file in files:
            if (file.endswith('.csv') or file.endswith('.csv.gz')) and 'mapped' not in file:
                file_path = os.path.join(root, file)
                process_csv(file_path, columns, mapping, log_file, output_suffix)

    log("UUID mapping process completed.", log_file)

if __name__ == "__main__":
    main()
