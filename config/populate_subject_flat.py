import psycopg2
import logging
import configparser
import argparse
import sys

def test_connection(config):
    """
    Test the database connection and verify access to the metadatavalue table.
    """
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
        
        cursor.close()
        conn.close()
        return True
    except Exception as e:
        logging.error(f"Failed to connect to the database or run test query: {str(e)}")
        return False

def extract_last_component(full_path):
    """
    Extract the last component from a hierarchical metadata path separated by '::'.
    """
    if "::" in full_path:
        return full_path.split("::")[-1].strip()
    return full_path.strip()

def process_metadata(config, dry_run=False):
    """
    Process dc.subject metadata to populate local.subject.flat with the last component.
    Also retrieves and prints the dc.title for each item.
    """
    try:
        conn = psycopg2.connect(
            dbname=config['Database']['dbname'],
            user=config['Database']['user'],
            password=config['Database']['password'],
            host=config['Database']['host'],
            port=config['Database']['port']
        )
        cursor = conn.cursor()

        # Retrieve metadata_field_id for dc.subject, local.subject.flat, and dc.title
        cursor.execute("""
            SELECT metadata_field_id, element, qualifier 
            FROM metadatafieldregistry 
            WHERE (element = 'subject' AND (qualifier IS NULL OR qualifier = 'flat'))
               OR (element = 'title' AND qualifier IS NULL);
        """)
        fields = cursor.fetchall()
        dc_subject_id = None
        local_subject_flat_id = None
        dc_title_id = None

        for field in fields:
            field_id, element, qualifier = field
            if element == 'subject':
                if qualifier is None and dc_subject_id is None:
                    dc_subject_id = field_id
                elif qualifier == 'flat' and local_subject_flat_id is None:
                    local_subject_flat_id = field_id
                else:
                    logging.warning(f"Multiple metadata_field_ids found for subject fields. Using first occurrences: dc_subject_id={dc_subject_id}, local_subject_flat_id={local_subject_flat_id}")
            elif element == 'title' and qualifier is None:
                if dc_title_id is None:
                    dc_title_id = field_id
                else:
                    logging.warning(f"Multiple metadata_field_ids found for title fields. Using the first one: dc_title_id={dc_title_id}")

        # Verify that all required metadata_field_ids were found
        if dc_subject_id is None:
            logging.error("Could not find metadata_field_id for dc.subject.")
            return
        if local_subject_flat_id is None:
            logging.error("Could not find metadata_field_id for local.subject.flat.")
            return
        if dc_title_id is None:
            logging.error("Could not find metadata_field_id for dc.title.")
            return

        logging.info(f"dc.subject metadata_field_id: {dc_subject_id}")
        logging.info(f"local.subject.flat metadata_field_id: {local_subject_flat_id}")
        logging.info(f"dc.title metadata_field_id: {dc_title_id}")

        # Fetch all metadatavalue entries for dc.subject
        cursor.execute(
            "SELECT dspace_object_id, text_value FROM metadatavalue WHERE metadata_field_id = %s;",
            (dc_subject_id,)
        )
        dc_subject_entries = cursor.fetchall()
        logging.info(f"Found {len(dc_subject_entries)} dc.subject entries to process.")

        # Prepare to collect updates
        updates = {}

        for entry in dc_subject_entries:
            dspace_object_id, full_path = entry
            last_component = extract_last_component(full_path)

            if not last_component:
                logging.warning(f"Empty last component for dspace_object_id {dspace_object_id}. Skipping.")
                continue

            if dspace_object_id not in updates:
                updates[dspace_object_id] = set()
            updates[dspace_object_id].add(last_component)

        logging.info(f"Prepared {len(updates)} unique items for local.subject.flat updates.")

        # Iterate over updates and apply them
        for dspace_object_id, flat_terms in updates.items():
            # Fetch dc.title for the current dspace_object_id
            cursor.execute(
                "SELECT text_value FROM metadatavalue WHERE dspace_object_id = %s AND metadata_field_id = %s;",
                (dspace_object_id, dc_title_id)
            )
            title_result = cursor.fetchone()
            dc_title = title_result[0] if title_result else "No Title Found"

            for term in flat_terms:
                if not term:
                    logging.warning(f"Empty term for dspace_object_id {dspace_object_id}. Skipping insertion.")
                    continue

                # Error Checking: Ensure term is indeed the last component
                # This is redundant here since we extracted the last component, but added for extra safety
                expected_term = extract_last_component(term)
                if term != expected_term:
                    logging.error(f"Term mismatch for dspace_object_id {dspace_object_id}: '{term}' != '{expected_term}'. Skipping.")
                    continue

                # Check if the term already exists in local.subject.flat for this item
                cursor.execute(
                    "SELECT 1 FROM metadatavalue WHERE dspace_object_id = %s AND metadata_field_id = %s AND text_value = %s;",
                    (dspace_object_id, local_subject_flat_id, term)
                )
                exists = cursor.fetchone()
                if exists:
                    logging.debug(f"Term '{term}' already exists for dspace_object_id {dspace_object_id} in local.subject.flat.")
                    continue

                # Print the title to stdout
                print(f"DSpace Object ID: {dspace_object_id}, Title: '{dc_title}'")

                if dry_run:
                    logging.info(f"Dry Run: Would insert term '{term}' for dspace_object_id {dspace_object_id} into local.subject.flat.")
                else:
                    # Insert the new local.subject.flat entry
                    cursor.execute(
                        "INSERT INTO metadatavalue (dspace_object_id, metadata_field_id, text_value) VALUES (%s, %s, %s);",
                        (dspace_object_id, local_subject_flat_id, term)
                    )
                    logging.info(f"Inserted term '{term}' for dspace_object_id {dspace_object_id} into local.subject.flat.")

        if not dry_run:
            conn.commit()
            logging.info("All updates committed successfully.")
        else:
            logging.info("Dry run completed. No changes were made to the database.")

    except Exception as e:
        logging.error(f"An error occurred: {str(e)}")
        if not dry_run and conn:
            conn.rollback()
            logging.info("Rolled back any changes due to the error.")
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals() and not conn.closed:
            conn.close()

def main():
    parser = argparse.ArgumentParser(description="Populate local.subject.flat based on dc.subject and print dc.title.")
    parser.add_argument('--dry-run', action='store_true', help="Simulate the changes without committing them to the database.")
    parser.add_argument('--test-connection', action='store_true', help="Test the database connection.")
    parser.add_argument('--stdout', action='store_true', help="Write logs to stdout instead of a log file.")
    args = parser.parse_args()

    # Set up logging
    if args.stdout:
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            stream=sys.stdout
        )
    else:
        logging.basicConfig(
            filename='/data/dspace/log/populate_subject_flat.log',
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )

    # Load configuration
    config = configparser.ConfigParser()
    config.read('/data/dspace-angular-dspace-8.0/config/config.ini')

    if args.test_connection:
        if test_connection(config):
            logging.info("Connection test successful.")
        else:
            logging.error("Connection test failed.")
        return

    process_metadata(config, dry_run=args.dry_run)

if __name__ == "__main__":
    main()
