import json5
import re

def generate_schemas(types, schema_pattern, text_pattern):
    schemas = []
    for type_name in types:
        schema = schema_pattern.replace('[]', f"{type_name.lower()}")
        text = text_pattern.replace('[type]', type_name)
        schemas.append(f'  "{schema}": "{text}"')
    return sorted(schemas)

def update_json_file(file_path, new_schemas):
    # Read the existing JSON5 file
    with open(file_path, 'r') as file:
        content = file.read()

    # Find the position to insert new schemas (just before the last closing brace)
    insert_position = content.rfind('}')

    # Insert new schemas
    updated_content = (
        content[:insert_position] +
        ',\n\n' +  # Add comma and two newlines for separation
        ',\n\n'.join(new_schemas) +  # Join schemas with comma and two newlines between each
        '\n\n' +  # Add two newlines after the last schema
        content[insert_position:]
    )

    # Write the updated content back to the file
    with open(file_path, 'w') as file:
        file.write(updated_content)

def get_types(type_choice):
    if type_choice.lower() == 'entity':
        return [
            "none", "Publication", "Person", "Project", "OrgUnit", "Journal", "JournalVolume",
            "JournalIssue", "DQCheck", "Documentation", "Phenotype", "Study", "ConceptSet"
        ]
    elif type_choice.lower() == 'relationship':
        return [
            "isAuthorOfPublication", "isPublicationOfAuthor", "isProjectOfPublication",
            "isPublicationOfProject", "isOrgUnitOfPublication", "isPublicationOfOrgUnit",
            "isProjectOfPerson", "isPersonOfProject", "isOrgUnitOfPerson", "isPersonOfOrgUnit",
            "isOrgUnitOfProject", "isProjectOfOrgUnit", "isVolumeOfJournal", "isJournalOfVolume",
            "isIssueOfJournalVolume", "isJournalVolumeOfIssue", "isPublicationOfJournalIssue",
            "isJournalIssueOfPublication", "resultsInPhenotype", "isResultOfStudy",
            "resultsInConceptSet", "informsPhenotype", "isInformedByConceptSet", "createsDQCheck",
            "isCreatedByPerson", "createsDocumentation", "createsPhenotype", "conductsStudy",
            "isConductedByPerson", "hasPerson", "isPartOfOrgUnit", "hasConceptSet",
            "isAssociatedWithOrgUnit", "isConductedByOrgUnit", "createsConceptSet", "isUsedInStudy",
            "usesConceptSet", "isDQCheckOfConceptSet", "isConceptSetOfDQCheck",
            "isDocumentationOfConceptSet", "isConceptSetOfDocumentation", "isMemberOfOrgUnit",
            "isConceptSetOfOrgUnit", "isOrgUnitOfConceptSet", "isStudyOfOrgUnit", "isOrgUnitOfStudy",
            "isAuthorOfConceptSet", "isConceptSetOfAuthor", "isEditorOfConceptSet",
            "isConceptSetOfEditor", "isStudyOfAuthor", "isAuthorOfStudy", "isStudyOfEditor",
            "isEditorOfStudy", "isStudyOfConceptSet", "isConceptSetOfStudy", "isDQCheckOfPerson",
            "isPersonOfDQCheck", "isDocumentationOfAuthor", "isAuthorOfDocumentation",
            "isDocumentationOfEditor", "isEditorOfDocumentation", "isPhenotypeOfAuthor",
            "isAuthorOfPhenotype", "isPhenotypeOfEditor", "isEditorOfPhenotype", "isPhenotypeOfStudy",
            "isStudyOfPhenotype", "isPhenotypeOfConceptSet", "isConceptSetOfPhenotype",
            "isMemberOfOrgUnit", "isOrgUnitOfPerson"
        ]
    else:
        return []

def main():
    # Get user input
    type_choice = input("Entity or Relationship Type? ").strip()
    schema_pattern = input("Enter the schema pattern (e.g., '[].y.z' or 'x.[].z' or 'x.y.[]'): ").strip()
    text_pattern = input("Enter the text pattern (use [type] for entity/relationship type, e.g., '[type] input' or 'input [type]'): ").strip()

    # Get types based on user choice
    types = get_types(type_choice)

    if not types:
        print("Invalid type choice. Please choose 'Entity' or 'Relationship'.")
        return

    # Generate schemas
    new_schemas = generate_schemas(types, schema_pattern, text_pattern)

    # Update JSON file
    json_file_path = 'en.json5'
    update_json_file(json_file_path, new_schemas)

    print(f"Generated and integrated {len(new_schemas)} new schemas into {json_file_path}")

if __name__ == "__main__":
    main()